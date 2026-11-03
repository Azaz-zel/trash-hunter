--!strict
-- Dumpster searching, "rummage" style: dig for a moment, then pick one of
-- several trash bags. Every bag is rolled on the server up front; the client
-- only learns how heavy each bag looks (a noisy hint) and, with the
-- Flashlight, the rarity of one bag. After the pick, the other bags are shown
-- so near-misses are visible. Then: keep / dig deeper (new bags, better odds,
-- lose this find) / leave. Per-player cooldown per dumpster.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Loot = require(Shared.Loot)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Social = require(script.Parent.Social)
local Progress = require(script.Parent.Progress)

local S = Config.Search
local T = Config.TOOL_EFFECT
local rng = Random.new()

type Session = {
	dumpster: Model,
	depth: number,
	token: number,
	bags: { Loot.Roll }?, -- rolled, waiting for a pick
	pending: Loot.Roll?, -- picked, waiting for keep / deeper / leave
}

local sessions: { [Player]: Session } = {}
local cooldowns: { [Player]: { [Model]: number } } = {}
local lastPrompt: { [Player]: number } = {}
local tokenCounter = 0

local Search = {}

local function dumpsterPos(dumpster: Model): Vector3
	return dumpster:GetPivot().Position
end

-- Police reads this attribute: 0 = not rummaging, otherwise the suspicion multiplier.
local function setDigging(player: Player, mult: number)
	player:SetAttribute("Digging", mult)
end

local function endSession(player: Player, applyCooldown: boolean)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	setDigging(player, 0)
	Router.send(player, "searchEnded", { dumpster = session.dumpster })
	if applyCooldown then
		local list = cooldowns[player]
		if list then
			list[session.dumpster] = os.clock() + S.COOLDOWN
		end
		Router.send(player, "cooldown", { dumpster = session.dumpster, seconds = S.COOLDOWN })
	end
end

function Search.cancel(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	-- Once something was revealed the dumpster counts as searched.
	endSession(player, session.pending ~= nil or session.depth > 0)
	Router.send(player, "searchCancelled", { reason = reason, dumpster = session.dumpster })
end

-- Rare+ finds float above the dumpster for everyone nearby.
local function showFindPop(dumpster: Model, roll: Loot.Roll)
	local body = dumpster:FindFirstChild("Body")
	if not body then
		return
	end
	local pop = Instance.new("BillboardGui")
	pop.Name = "FindPop"
	pop.Size = UDim2.fromOffset(260, 56)
	pop.StudsOffset = Vector3.new(0, 6, 0)
	pop.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Items.Rarities[roll.rarity].color
	label.TextStrokeTransparency = 0
	label.Text = Items.label(roll.itemId, roll.mutation)
	label.Parent = pop
	pop.Parent = body
	game:GetService("Debris"):AddItem(pop, 3)
end

local function boostFor(player: Player, session: Session): number
	local boost = session.depth * Config.Boost.PER_DEEPER
	local dumpster = session.dumpster
	if dumpster:GetAttribute("Zone") == "Red" then
		boost += Config.Boost.RED_ZONE
	end
	-- Richer districts throw out better stuff (set by World from Config.Districts).
	boost += tonumber(dumpster:GetAttribute("DistrictBoost")) or 0
	if dumpster:GetAttribute("District") == workspace:GetAttribute("HotDistrict") then
		boost += Config.HOT_DISTRICT_BOOST
	end
	if dumpster:GetAttribute("Heavy") then
		boost += Config.Boost.HEAVY
	end
	if Social.hasFriendHere(player) then
		boost += Config.Boost.FRIEND
	end
	local profile = Data.get(player)
	if profile and Data.hasTool(profile, "detector") then
		boost += T.DETECTOR_BOOST
	end
	return boost
end

-- A bag's look: 1 light, 2 medium, 3 heavy. Correlates with rarity, but noisy.
local function weightOf(roll: Loot.Roll): number
	local score = roll.rarity + rng:NextNumber(-1.6, 1.6)
	return if score < 2.2 then 1 elseif score < 3.8 then 2 else 3
end

local resolve: (Player, any) -> (boolean, string?)
local pick: (Player, any) -> (boolean, string?)

local function finishDig(player: Player, token: number)
	local session = sessions[player]
	if not session or session.token ~= token then
		return
	end
	local profile = Data.get(player)
	if not profile then
		Search.cancel(player, "error")
		return
	end
	if
		Guard.isFlagged(player)
		or Guard.distance(player, dumpsterPos(session.dumpster)) > S.KEEP_RANGE
	then
		Search.cancel(player, "moved")
		return
	end

	local city = session.dumpster:GetAttribute("City") or "maple"
	local count = S.BAGS
		+ (if Data.hasTool(profile, "crowbar") then 1 else 0)
		+ (if city == "port" and Data.hasTool(profile, "magnet") then 1 else 0)
	local boost = boostFor(player, session)
	-- The very first search is a guaranteed Rare whichever bag is picked (GDD FTUE).
	local force = if profile.tutorial == 0 and session.depth == 0 then 3 else nil
	local bags: { Loot.Roll } = {}
	local looks = {}
	for i = 1, count do
		bags[i] = Loot.roll(rng, boost, force, city)
		looks[i] = { weight = weightOf(bags[i]) }
	end
	-- Pity: after a long dry streak one bag is guaranteed to be good.
	if not force then
		local pityRarity = if profile.sinceLegendary >= Config.PITY.LEGENDARY
			then 5
			elseif profile.sinceEpic >= Config.PITY.EPIC then 4
			else nil
		if pityRarity then
			local lucky = rng:NextInteger(1, count)
			bags[lucky] = Loot.roll(rng, boost, pityRarity, city)
			looks[lucky] = { weight = weightOf(bags[lucky]) }
		end
	end
	if Data.hasTool(profile, "flashlight") then
		local lit = rng:NextInteger(1, count)
		looks[lit].rarity = bags[lit].rarity
	end
	session.bags = bags
	Router.send(
		player,
		"searchBags",
		{ dumpster = session.dumpster, bags = looks, depth = session.depth }
	)

	task.delay(S.CHOICE_TIMEOUT, function()
		local current = sessions[player]
		if current and current.token == token and current.bags then
			pick(player, rng:NextInteger(1, #bags))
		end
	end)
end

local function beginDig(player: Player, session: Session)
	tokenCounter += 1
	local token = tokenCounter
	session.token = token
	session.bags = nil
	session.pending = nil
	local profile = Data.get(player)
	local duration = if session.depth == 0 then S.TIME else S.DEEPER_TIME
	if profile and Data.hasTool(profile, "gloves") then
		duration *= T.GLOVES_SPEED
	end
	setDigging(player, if session.depth == 0 then 1 else Config.Suspicion.DEEPER_MULT)
	Router.send(
		player,
		"searchStarted",
		{ dumpster = session.dumpster, duration = duration, depth = session.depth }
	)
	task.delay(duration, finishDig, player, token)
end

pick = function(player: Player, index: any): (boolean, string?)
	local session = sessions[player]
	local bags = session and session.bags
	if not session or not bags then
		return false, nil
	end
	if
		typeof(index) ~= "number"
		or index ~= index
		or index % 1 ~= 0
		or index < 1
		or index > #bags
	then
		return false, nil
	end
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local roll = bags[index]
	session.bags = nil
	session.pending = roll
	-- Pity counters move only on picks, so a player always benefits from them.
	profile.sinceEpic = if roll.rarity >= 4 then 0 else profile.sinceEpic + 1
	profile.sinceLegendary = if roll.rarity >= 5 then 0 else profile.sinceLegendary + 1
	Data.discover(profile, roll.itemId, roll.mutation, player)
	Progress.track(player, "search", {
		district = session.dumpster:GetAttribute("DistrictId"),
		red = session.dumpster:GetAttribute("Zone") == "Red",
		city = session.dumpster:GetAttribute("City") or "maple",
		rarity = roll.rarity,
	})
	if roll.rarity >= 3 then
		showFindPop(session.dumpster, roll)
	end
	if roll.rarity >= 5 then
		Social.announce(player, roll.itemId, roll.mutation, roll.rarity)
	end
	local all = {}
	for i, b in bags do
		all[i] = { itemId = b.itemId, mutation = b.mutation, rarity = b.rarity, value = b.value }
	end
	Router.send(player, "searchResult", {
		dumpster = session.dumpster,
		itemId = roll.itemId,
		mutation = roll.mutation,
		rarity = roll.rarity,
		value = roll.value,
		picked = index,
		bags = all,
		depth = session.depth,
		canDeeper = session.depth < S.MAX_DEEPER,
	})
	Data.push(player)
	local token = session.token
	task.delay(S.CHOICE_TIMEOUT, function()
		local current = sessions[player]
		if current and current.token == token and current.pending then
			resolve(player, "take")
		end
	end)
	return true, nil
end

-- Another player standing at the same heavy bin holds the lid up.
local function hasHelper(player: Player, dumpster: Model): boolean
	for _, other in Players:GetPlayers() do
		if other ~= player and Guard.distance(other, dumpsterPos(dumpster)) <= S.RANGE + 4 then
			return true
		end
	end
	return false
end

local function tryStart(player: Player, dumpster: Model): (boolean, string?)
	if sessions[player] then
		return false, nil
	end
	local profile = Data.get(player)
	if not profile then
		return false, "Still loading your save..."
	end
	if Guard.isFlagged(player) or not Guard.root(player) then
		return false, nil
	end
	if player:GetAttribute("Chased") then
		return false, "No time to dig. Run!"
	end
	if Guard.distance(player, dumpsterPos(dumpster)) > S.RANGE then
		return false, "Get closer to the dumpster."
	end
	local locked = Progress.gateMessage(player, dumpster:GetAttribute("DistrictId"))
	if locked then
		return false, locked
	end
	if dumpster:GetAttribute("Heavy") and not hasHelper(player, dumpster) then
		return false, "Too heavy to lift alone. Bring a friend!"
	end
	local readyAt = cooldowns[player] and cooldowns[player][dumpster]
	if readyAt and readyAt > os.clock() then
		return false, `Picked clean. Back in {math.ceil(readyAt - os.clock())}s.`
	end
	if #profile.backpack >= Data.capacity(profile, player) then
		return false, "Backpack full! Stash it in your car or sell at the Hideout."
	end
	local session: Session =
		{ dumpster = dumpster, depth = 0, token = 0, bags = nil, pending = nil }
	sessions[player] = session
	beginDig(player, session)
	return true, nil
end

resolve = function(player: Player, choice: any): (boolean, string?)
	local session = sessions[player]
	if not session or not session.pending then
		return false, "Nothing to choose"
	end
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local found = session.pending :: Loot.Roll
	if choice == "take" then
		if #profile.backpack >= Data.capacity(profile, player) then
			return false, "Backpack full"
		end
		Data.addItem(profile, found.itemId, found.mutation)
		Data.advanceTutorial(profile, 0, player)
		endSession(player, true)
		Data.push(player)
		return true, nil
	elseif choice == "deeper" then
		if session.depth >= S.MAX_DEEPER then
			return false, "Nothing deeper"
		end
		if Guard.distance(player, dumpsterPos(session.dumpster)) > S.KEEP_RANGE then
			Search.cancel(player, "moved")
			return false, "Too far away"
		end
		session.depth += 1
		beginDig(player, session)
		return true, nil
	elseif choice == "leave" then
		endSession(player, true)
		return true, nil
	end
	return false, "Bad choice"
end

local function bindDumpster(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local prompt = instance:FindFirstChild("SearchPrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.3 then
			return
		end
		lastPrompt[player] = now
		local ok, message = tryStart(player, instance)
		if not ok and message then
			Router.send(player, "toast", { text = message })
		end
	end)
end

function Search.isSearching(player: Player): boolean
	return sessions[player] ~= nil
end

function Search.init()
	if game:GetService("RunService"):IsStudio() then
		Loot.selfCheck()
		require(Shared.ItemModels).selfCheck()
		require(Shared.Quests).selfCheck()
	end
	Router.on("pickBag", 0.2, pick)
	Router.on("resolve", 0.2, resolve)
end

function Search.start()
	CollectionService:GetInstanceAddedSignal("Dumpster"):Connect(bindDumpster)
	for _, dumpster in CollectionService:GetTagged("Dumpster") do
		bindDumpster(dumpster)
	end

	local function onPlayerAdded(player: Player)
		cooldowns[player] = {}
		setDigging(player, 0)
		player.CharacterAdded:Connect(function()
			Search.cancel(player, "respawn")
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		cooldowns[player] = nil
		lastPrompt[player] = nil
	end)
end

return Search
