--!strict
-- Dumpster searching, "rummage" style: dig for a moment, then pick one of
-- several trash bags. Every bag is rolled on the server up front; the client
-- only learns how heavy each bag looks (a noisy hint) and, with the
-- Flashlight, the rarity of one bag. After the pick, the other bags are shown
-- so near-misses are visible. Then: keep / dig deeper (new bags, better odds,
-- lose this find) / leave. Per-player cooldown per dumpster.
--
-- Skill and flow on top of the luck:
-- - Perfect Dig: while rummaging a marker sweeps the bar; tapping inside the
--   gold zone ("Perfect") adds an extra bag and better odds, inside the wider
--   zone ("Good") better odds. The server times the tap itself and only
--   accepts the client's reading within TAP_SLACK (lag), so it cannot be faked.
-- - Combo: each search within COMBO_WINDOW of the last raises the odds, up
--   to COMBO_MAX. Shown on the HUD (player attributes Combo / ComboUntil).
-- - Fresh drops: every FRESH_EVERY seconds a few dumpsters are refilled
--   (attribute Fresh, sparkles, gold on the map). The first pick takes it.

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
local Ranks = require(script.Parent.Ranks)

local S = Config.Search
local T = Config.TOOL_EFFECT
local rng = Random.new()

type Session = {
	dumpster: Model,
	depth: number,
	token: number,
	started: number, -- os.clock() when this dig began
	duration: number,
	zone: number, -- centre of the gold zone (0..1 of the bar)
	grade: string?, -- "perfect" | "good" | "miss" once tapped
	bags: { Loot.Roll }?, -- rolled, waiting for a pick
	pending: Loot.Roll?, -- picked, waiting for keep / deeper / leave
}

local sessions: { [Player]: Session } = {}
local cooldowns: { [Player]: { [Model]: number } } = {}
local lastPrompt: { [Player]: number } = {}
local combos: { [Player]: { n: number, last: number } } = {}
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
	if dumpster:GetAttribute("Fresh") then
		boost += S.FRESH_BOOST
	end
	local combo = combos[player]
	if combo and os.clock() - combo.last < S.COMBO_WINDOW then
		boost += S.COMBO_STEP * combo.n
	end
	if session.grade == "perfect" then
		boost += S.PERFECT_BOOST
	elseif session.grade == "good" then
		boost += S.GOOD_BOOST
	end
	local profile = Data.get(player)
	if profile and Data.hasTool(profile, "detector") then
		boost += T.DETECTOR_BOOST
	end
	-- Bought luck: Lucky Charm pass, Lucky Hour.
	local luck = Config.Robux.LUCK
	if player:GetAttribute("Pass_lucky") then
		boost += luck.CHARM_BOOST
	end
	if profile and profile.luckUntil > os.time() then
		boost += luck.HOUR_BOOST
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

-- Rolls the bags for a finished dig (or a Bag Reroll) and shows them.
local function rollBags(player: Player, session: Session, profile: any)
	local city = session.dumpster:GetAttribute("City") or "maple"
	local count = S.BAGS
		+ (if session.grade == "perfect" then 1 else 0)
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
	Router.send(player, "searchBags", {
		dumpster = session.dumpster,
		bags = looks,
		depth = session.depth,
		grade = session.grade,
		timeout = S.CHOICE_TIMEOUT,
	})
end

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

	rollBags(player, session, profile)

	task.delay(S.CHOICE_TIMEOUT, function()
		local current = sessions[player]
		local offered = current and current.token == token and current.bags
		if offered then
			pick(player, rng:NextInteger(1, #offered))
		end
	end)
end

local function beginDig(player: Player, session: Session)
	tokenCounter += 1
	local token = tokenCounter
	session.token = token
	session.bags = nil
	session.pending = nil
	session.grade = nil
	local profile = Data.get(player)
	local duration = if session.depth == 0 then S.DIG_TIME else S.DEEPER_TIME * 1.4
	if profile and Data.hasTool(profile, "gloves") then
		duration *= T.GLOVES_SPEED
	end
	session.started = os.clock()
	session.duration = duration
	-- The gold zone sits in the back half so there is time to react.
	session.zone = rng:NextNumber(0.5, 0.85)
	setDigging(player, if session.depth == 0 then 1 else Config.Suspicion.DEEPER_MULT)
	Router.send(player, "searchStarted", {
		dumpster = session.dumpster,
		duration = duration,
		depth = session.depth,
		zone = session.zone,
		perfect = S.PERFECT_WIDTH,
		good = S.GOOD_WIDTH,
	})
	task.delay(duration, finishDig, player, token)
end

-- Perfect Dig tap. `at` is where the client saw the marker (0..1); the
-- server's own clock must agree within TAP_SLACK.
local function digTap(player: Player, at: any): (boolean, any)
	local session = sessions[player]
	if not session or session.bags or session.pending or session.grade then
		return false, nil
	end
	if typeof(at) ~= "number" or at ~= at then
		return false, nil
	end
	-- The client saw the dig start one trip late and its tap arrives one
	-- trip late: take the round trip off the server's own timing.
	local okPing, ping = pcall(player.GetNetworkPing, player)
	local trip = if okPing and typeof(ping) == "number" then math.min(ping, 0.5) else 0.1
	local measured = (os.clock() - session.started - 2 * trip) / session.duration
	if at < 0 or at > 1 or measured > 1.15 or math.abs(measured - at) > S.TAP_SLACK then
		session.grade = "miss"
		return true, "miss"
	end
	local off = math.abs(at - session.zone)
	session.grade = if off <= S.PERFECT_WIDTH / 2
		then "perfect"
		elseif off <= S.GOOD_WIDTH / 2 then "good"
		else "miss"
	if session.grade == "perfect" then
		Ranks.add(player, Config.Levels.PERFECT_XP)
	end
	return true, session.grade
end

-- Bag Reroll: new bags in place of the ones on offer.
local function reroll(player: Player): (boolean, string?)
	local session = sessions[player]
	local profile = Data.get(player)
	if not session or not session.bags or not profile then
		return false, nil
	end
	if profile.rerolls <= 0 then
		return false, "No rerolls left. Get more in the Robux shop."
	end
	profile.rerolls -= 1
	rollBags(player, session, profile)
	Data.push(player)
	return true, nil
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
	-- Combo: the first pick at each dumpster counts.
	if session.depth == 0 then
		local now = os.clock()
		local c = combos[player]
		local n = if c and now - c.last < S.COMBO_WINDOW then math.min(S.COMBO_MAX, c.n + 1) else 1
		combos[player] = { n = n, last = now }
		local profile2 = Data.get(player)
		if profile2 and n > profile2.bestCombo then
			profile2.bestCombo = n
		end
		player:SetAttribute("Combo", n)
		player:SetAttribute("ComboUntil", workspace:GetServerTimeNow() + S.COMBO_WINDOW)
	end
	if session.dumpster:GetAttribute("Fresh") then
		session.dumpster:SetAttribute("Fresh", false)
	end
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
		grade = session.grade,
		combo = player:GetAttribute("Combo"),
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
	local session: Session = {
		dumpster = dumpster,
		depth = 0,
		token = 0,
		started = 0,
		duration = 1,
		zone = 0.5,
		grade = nil,
		bags = nil,
		pending = nil,
	}
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

-- Refills dumpsters with fresh trash. `by` names a player who paid for it
-- (Garbage Truck Day, twice the usual count); `replace` clears the previous
-- fresh set first. The weekend event doubles the count.
function Search.freshDrop(by: string?, replace: boolean)
	local pool = {}
	for _, model in CollectionService:GetTagged("Dumpster") do
		if replace then
			model:SetAttribute("Fresh", false)
		end
		if
			model:GetAttribute("Zone") ~= "Red"
			and not model:GetAttribute("Tutorial")
			and not model:GetAttribute("Heavy")
			and not model:GetAttribute("Fresh")
		then
			table.insert(pool, model)
		end
	end
	local weekend = workspace:GetAttribute("Event") == "weekend"
	local count = S.FRESH_COUNT
		* (if weekend then Config.Events.WEEKEND_FRESH_MULT else 1)
		* (if by then 2 else 1)
	for _ = 1, math.min(count, #pool) do
		local model = table.remove(pool, rng:NextInteger(1, #pool)) :: Model
		model:SetAttribute("Fresh", true)
	end
	Router.broadcast("toast", {
		text = if by
			then `{by} called the Garbage Truck! Fresh drops everywhere (gold on the map).`
			else "Fresh trash just got dumped! Look for gold on the map.",
		color = Color3.fromRGB(255, 205, 60),
	})
end

-- Instant Refill: every dumpster this player emptied is ready again.
function Search.refill(player: Player)
	local list = cooldowns[player]
	if list then
		table.clear(list)
	end
	Router.send(player, "cooldownClear", nil)
end

function Search.isSearching(player: Player): boolean
	return sessions[player] ~= nil
end

function Search.init()
	if game:GetService("RunService"):IsStudio() then
		Loot.selfCheck()
		require(Shared.ItemModels).selfCheck()
		require(Shared.Quests).selfCheck()
		require(Shared.CityPlan).selfCheck()
		require(Shared.Levels).selfCheck()
	end
	Router.on("pickBag", 0.2, pick)
	Router.on("digTap", 0.3, digTap)
	Router.on("reroll", 0.5, reroll)
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
		combos[player] = nil
	end)

	-- Fresh drops: refill a few dumpsters now and then, with sparkles.
	local function setFresh(model: Model, on: boolean)
		local body = model:FindFirstChild("Body")
		local sparkle = body and body:FindFirstChild("FreshSparkle")
		if on and body and not sparkle then
			local e = Instance.new("ParticleEmitter")
			e.Name = "FreshSparkle"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80))
			e.Rate = 6
			e.Lifetime = NumberRange.new(1, 1.6)
			e.Speed = NumberRange.new(2, 4)
			e.SpreadAngle = Vector2.new(40, 40)
			e.Size = NumberSequence.new(0.5, 0)
			e.LightEmission = 1
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = body
		elseif not on and sparkle then
			sparkle:Destroy()
		end
	end
	local function publish()
		local list = {}
		for _, model in CollectionService:GetTagged("Dumpster") do
			if model:GetAttribute("Fresh") then
				table.insert(list, tostring(model:GetAttribute("Index")))
			end
		end
		workspace:SetAttribute("FreshDumpsters", table.concat(list, ","))
	end
	CollectionService:GetInstanceAddedSignal("Dumpster"):Connect(function(model)
		model:GetAttributeChangedSignal("Fresh"):Connect(function()
			setFresh(model, model:GetAttribute("Fresh") == true)
			publish()
		end)
	end)
	for _, model in CollectionService:GetTagged("Dumpster") do
		model:GetAttributeChangedSignal("Fresh"):Connect(function()
			setFresh(model, model:GetAttribute("Fresh") == true)
			publish()
		end)
	end
	task.spawn(function()
		while true do
			Search.freshDrop(nil, true)
			task.wait(S.FRESH_EVERY)
		end
	end)
end

return Search
