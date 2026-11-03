--!strict
-- Player profiles: load, autosave, release. One DataStore key per player,
-- written only with UpdateAsync. A session lock stops two servers from
-- overwriting each other when a player hops servers quickly.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Types = require(Shared.Types)
local Router = require(script.Parent.Parent.Router)

type Profile = Types.PlayerProfile
type BagItem = Types.BagItem

local VERSION = 1
local LOCK_STALE = 300 -- seconds; older locks belong to a crashed server
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_WAIT = 3
local SAVE_ATTEMPTS = 3

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local releaseCallbacks: { (Player, Profile) -> () } = {}

local Data = {}
Data.persistent = true

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function sanitizeBag(list: any, max: number): { BagItem }
	local out: { BagItem } = {}
	if typeof(list) ~= "table" then
		return out
	end
	for _, entry in list do
		if #out >= max then
			break
		end
		if
			typeof(entry) == "table"
			and typeof(entry.uid) == "string"
			and typeof(entry.id) == "string"
			and Items.ById[entry.id]
			and (entry.mutation == nil or Items.MutationById[entry.mutation])
		then
			table.insert(out, { uid = entry.uid, id = entry.id, mutation = entry.mutation })
		end
	end
	return out
end

-- Turns whatever is stored (or nil for a new player) into a valid profile.
local function reconcile(raw: any): Profile
	local data = if typeof(raw) == "table" then raw else {}
	local level = math.clamp(math.floor(tonumber(data.backpackLevel) or 1), 1, #Config.Backpack)
	local collection: { [string]: boolean } = {}
	if typeof(data.collection) == "table" then
		for k, v in data.collection do
			if typeof(k) == "string" and v == true then
				collection[k] = true
			end
		end
	end
	local tools: { [string]: boolean } = {}
	if typeof(data.tools) == "table" then
		for id in Config.Tools do
			if data.tools[id] == true then
				tools[id] = true
			end
		end
	end
	local ownedCars: { [string]: boolean } = { [Config.Cars[1].id] = true }
	if typeof(data.ownedCars) == "table" then
		for _, car in Config.Cars do
			if data.ownedCars[car.id] == true then
				ownedCars[car.id] = true
			end
		end
	end
	local car = if typeof(data.car) == "string" and ownedCars[data.car]
		then data.car
		else Config.Cars[1].id
	local receipts: { string } = {}
	if typeof(data.receipts) == "table" then
		for _, r in data.receipts do
			if typeof(r) == "string" then
				table.insert(receipts, r)
			end
		end
	end
	return {
		version = VERSION,
		cash = math.max(math.floor(tonumber(data.cash) or 0), 0),
		backpackLevel = level,
		-- Extra room covers the Bigger Pockets pass; capacity is enforced on insert.
		backpack = sanitizeBag(
			data.backpack,
			Config.Backpack[level].capacity + Config.Robux.POCKETS_BONUS
		),
		shelf = sanitizeBag(data.shelf, Config.SHELF_SLOTS),
		collection = collection,
		tutorial = math.clamp(math.floor(tonumber(data.tutorial) or 0), 0, 4),
		nextUid = math.max(math.floor(tonumber(data.nextUid) or 1), 1),
		tools = tools,
		car = car,
		ownedCars = ownedCars,
		trunk = sanitizeBag(data.trunk, 40),
		milestones = math.clamp(math.floor(tonumber(data.milestones) or 0), 0, #Config.Milestones),
		receipts = receipts,
		sinceEpic = math.max(math.floor(tonumber(data.sinceEpic) or 0), 0),
		sinceLegendary = math.max(math.floor(tonumber(data.sinceLegendary) or 0), 0),
	}
end

local function lockedByOther(old: any): boolean
	return typeof(old) == "table"
		and typeof(old.lock) == "table"
		and old.lock.jobId ~= game.JobId
		and os.time() - (tonumber(old.lock.time) or 0) < LOCK_STALE
end

local function load(player: Player): Profile?
	if not Data.persistent or not store then
		return reconcile(nil)
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local profile: Profile? = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player), function(old)
				if lockedByOther(old) then
					profile = nil
					return nil
				end
				local fresh = reconcile(old)
				profile = fresh
				local saved: any = table.clone(fresh)
				saved.lock = { jobId = game.JobId, time = os.time() }
				return saved
			end)
		end)
		if ok and profile then
			return profile
		end
		if not ok then
			warn(`[Data] load attempt {attempt} for {player.Name} failed: {err}`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(LOAD_RETRY_WAIT)
	end
	return nil
end

local function save(player: Player, profile: Profile, release: boolean): boolean
	if not Data.persistent or not store then
		return true
	end
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player), function(old)
				if lockedByOther(old) then
					return nil -- another server owns this profile now; never overwrite it
				end
				local saved: any = table.clone(profile)
				saved.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return saved
			end)
		end)
		if ok then
			return true
		end
		warn(`[Data] save attempt {attempt} for {player.Name} failed: {err}`)
		task.wait(2 ^ attempt)
	end
	return false
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil -- first caller wins; stops a double save on shutdown
	for _, cb in releaseCallbacks do
		local ok, err = pcall(cb, player, profile)
		if not ok then
			warn("[Data] release callback failed: " .. tostring(err))
		end
	end
	save(player, profile, true)
end

local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = stats
	stats.Parent = player
end

local function onPlayerAdded(player: Player)
	setupLeaderstats(player)
	local profile = load(player)
	if not player.Parent then
		if profile and Data.persistent then
			save(player, profile, true) -- left while loading: drop the lock we just took
		end
		return
	end
	if not profile then
		player:Kick("Your save is still busy on another server. Please rejoin in a minute.")
		return
	end
	profiles[player] = profile
	Data.push(player)
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, profile)
	end
end

function Data.get(player: Player): Profile?
	return profiles[player]
end

function Data.onLoaded(cb: (Player, Profile) -> ())
	table.insert(loadedCallbacks, cb)
end

-- Runs just before the final save, while the profile can still be changed.
function Data.onRelease(cb: (Player, Profile) -> ())
	table.insert(releaseCallbacks, cb)
end

-- Players owning a game pass have it cached as an attribute by Shop.
function Data.capacity(profile: Profile, player: Player?): number
	local bonus = if player and player:GetAttribute("Pass_pockets")
		then Config.Robux.POCKETS_BONUS
		else 0
	return Config.Backpack[profile.backpackLevel].capacity + bonus
end

function Data.trunkCapacity(profile: Profile): number
	for _, car in Config.Cars do
		if car.id == profile.car then
			return car.trunk
		end
	end
	return 0
end

function Data.hasTool(profile: Profile, id: string): boolean
	return profile.tools[id] == true
end

function Data.addItem(profile: Profile, itemId: string, mutation: string?): BagItem
	local entry = { uid = tostring(profile.nextUid), id = itemId, mutation = mutation }
	profile.nextUid += 1
	table.insert(profile.backpack, entry)
	return entry
end

function Data.removeItem(list: { BagItem }, uid: any): BagItem?
	if typeof(uid) ~= "string" then
		return nil
	end
	for i, entry in list do
		if entry.uid == uid then
			return table.remove(list, i)
		end
	end
	return nil
end

function Data.discover(profile: Profile, itemId: string, mutation: string?, player: Player?)
	profile.collection[itemId] = true
	if mutation then
		profile.collection[Items.collectionKey(itemId, mutation)] = true
	end
	-- Collection milestones pay out once each.
	local found = 0
	for _, item in Items.List do
		if profile.collection[item.id] then
			found += 1
		end
	end
	local nextMilestone = Config.Milestones[profile.milestones + 1]
	while nextMilestone and found >= nextMilestone.found do
		profile.milestones += 1
		profile.cash += nextMilestone.cash
		if player then
			Router.send(
				player,
				"milestone",
				{ found = nextMilestone.found, cash = nextMilestone.cash }
			)
		end
		nextMilestone = Config.Milestones[profile.milestones + 1]
	end
end

function Data.snapshot(profile: Profile, player: Player?): Types.State
	local next = Config.Backpack[profile.backpackLevel + 1]
	local passes: { [string]: boolean } = {}
	if player then
		for id in Config.Robux.Passes do
			passes[id] = player:GetAttribute("Pass_" .. id) == true
		end
	end
	return {
		cash = profile.cash,
		backpack = profile.backpack,
		capacity = Data.capacity(profile, player),
		backpackLevel = profile.backpackLevel,
		nextUpgrade = if next then { capacity = next.capacity, price = next.price } else nil,
		shelf = profile.shelf,
		shelfSlots = Config.SHELF_SLOTS,
		collection = profile.collection,
		tutorial = profile.tutorial,
		tools = profile.tools,
		car = profile.car,
		ownedCars = profile.ownedCars,
		trunk = profile.trunk,
		trunkCapacity = Data.trunkCapacity(profile),
		passes = passes,
	}
end

function Data.push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value = profile.cash
	end
	Router.send(player, "state", Data.snapshot(profile, player))
end

local FUNNEL = { "First search", "First sale", "First upgrade", "Entered the yard" }

-- Also logs the onboarding funnel so drop-off shows in Creator Analytics.
function Data.advanceTutorial(profile: Profile, fromStep: number, player: Player?)
	if profile.tutorial == fromStep then
		profile.tutorial = fromStep + 1
		if player then
			pcall(function()
				game:GetService("AnalyticsService")
					:LogOnboardingFunnelStepEvent(player, fromStep + 1, FUNNEL[fromStep + 1])
			end)
		end
	end
end

-- Saves right away; used before granting Robux purchases.
function Data.saveNow(player: Player): boolean
	local profile = profiles[player]
	return if profile then save(player, profile, false) else false
end

function Data.init()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DATASTORE_NAME)
	if ok then
		store = result
		if RunService:IsStudio() then
			local probeOk, probeErr = pcall(function()
				return (store :: DataStore):GetAsync("__probe")
			end)
			if not probeOk then
				Data.persistent = false
				warn(
					"[Data] DataStore unavailable in Studio, progress will not be saved. "
						.. "Turn on Game Settings > Security > Enable Studio Access to API Services. "
						.. tostring(probeErr)
				)
			end
		end
	else
		Data.persistent = false
		warn("[Data] DataStore unavailable: " .. tostring(result))
	end
end

function Data.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(release)

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(save, player, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return Data
