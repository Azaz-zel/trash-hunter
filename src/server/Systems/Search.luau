--!strict
-- Dumpster searching: dig timer, Perfect Dig tap, server-side loot roll,
-- the take / dig deeper / leave choice, and per-player dumpster cooldowns.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Loot = require(Shared.Loot)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Social = require(script.Parent.Social)

local S = Config.Search
local rng = Random.new()

type Session = {
	dumpster: Model,
	depth: number,
	token: number,
	startedAt: number,
	duration: number,
	sweetStart: number,
	sweetEnd: number,
	tapped: boolean,
	perfect: boolean,
	pending: Loot.Roll?,
}

local sessions: { [Player]: Session } = {}
local cooldowns: { [Player]: { [Model]: number } } = {}
local lastPrompt: { [Player]: number } = {}
local tokenCounter = 0

local Search = {}

local function dumpsterPos(dumpster: Model): Vector3
	return dumpster:GetPivot().Position
end

-- Police reads this attribute: 0 = not digging, otherwise the suspicion multiplier.
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

local resolve: (Player, any) -> (boolean, string?)

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
	setDigging(player, 0)

	local boost = session.depth * Config.Boost.PER_DEEPER
	if session.dumpster:GetAttribute("Zone") == "Red" then
		boost += Config.Boost.RED_ZONE
	end
	if session.perfect then
		boost += Config.Boost.PERFECT
	end
	if Social.hasFriendHere(player) then
		boost += Config.Boost.FRIEND
	end
	-- The very first search is a guaranteed Rare (GDD FTUE).
	local force = if profile.tutorial == 0 and session.depth == 0 then 3 else nil
	local roll = Loot.roll(rng, boost, force)
	session.pending = roll
	Data.discover(profile, roll.itemId, roll.mutation)
	if roll.rarity >= 5 then
		Social.announce(player, roll.itemId, roll.mutation, roll.rarity)
	end

	Router.send(player, "searchResult", {
		dumpster = session.dumpster,
		itemId = roll.itemId,
		mutation = roll.mutation,
		rarity = roll.rarity,
		value = roll.value,
		perfect = session.perfect,
		depth = session.depth,
		canDeeper = session.depth < S.MAX_DEEPER,
	})
	Data.push(player)

	task.delay(S.CHOICE_TIMEOUT, function()
		local current = sessions[player]
		if current and current.token == token and current.pending then
			resolve(player, "take")
		end
	end)
end

local function beginDig(player: Player, session: Session)
	tokenCounter += 1
	local token = tokenCounter
	local sweetStart = rng:NextNumber(S.SWEET_MIN, S.SWEET_MAX)
	session.token = token
	session.startedAt = os.clock()
	session.duration = if session.depth == 0 then S.TIME else S.DEEPER_TIME
	session.sweetStart = sweetStart
	session.sweetEnd = sweetStart + S.SWEET_WIDTH
	session.tapped = false
	session.perfect = false
	session.pending = nil
	setDigging(player, if session.depth == 0 then 1 else Config.Suspicion.DEEPER_MULT)
	Router.send(player, "searchStarted", {
		dumpster = session.dumpster,
		duration = session.duration,
		sweetStart = session.sweetStart,
		sweetEnd = session.sweetEnd,
		depth = session.depth,
	})
	task.delay(session.duration, finishDig, player, token)
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
	local readyAt = cooldowns[player] and cooldowns[player][dumpster]
	if readyAt and readyAt > os.clock() then
		return false, `Picked clean. Back in {math.ceil(readyAt - os.clock())}s.`
	end
	if #profile.backpack >= Data.capacity(profile) then
		return false, "Backpack full! Sell at the Hideout."
	end
	local session: Session = {
		dumpster = dumpster,
		depth = 0,
		token = 0,
		startedAt = 0,
		duration = 0,
		sweetStart = 0,
		sweetEnd = 0,
		tapped = false,
		perfect = false,
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
		if #profile.backpack >= Data.capacity(profile) then
			return false, "Backpack full"
		end
		Data.addItem(profile, found.itemId, found.mutation)
		Data.advanceTutorial(profile, 0)
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
	end

	Router.on("digTap", 0.1, function(player)
		local session = sessions[player]
		if not session or session.pending or session.tapped then
			return false, nil
		end
		session.tapped = true
		local elapsed = os.clock() - session.startedAt
		local from = session.sweetStart * session.duration - 0.05
		local to = session.sweetEnd * session.duration + S.TAP_GRACE
		session.perfect = elapsed >= from and elapsed <= to
		return true, session.perfect
	end)

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
