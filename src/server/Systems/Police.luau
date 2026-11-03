--!strict
-- Suspicion bar, the Meridian yard security officers, Drop & Run, capture.
-- Each officer runs a small state machine so they never move in lockstep:
--   patrol -> walk to a random yard point, then pause and look around, check
--             a dumpster, or keep walking
--   investigate -> walk to where a suspicious player was, then search there
--   chase -> run at the target; nearby officers radio in and join
--   search -> after losing someone, sweep the last known spot, then patrol

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Npc = require(script.Parent.Parent.Npc)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Search = require(script.Parent.Search)

local P = Config.Police
local SU = Config.Suspicion
local W = Config.World
local TICK = 0.1
local SPAWN_POINT = W.SPAWN + Vector3.new(0, 1, 0)

local LINES = {
	spot = { "HEY! Stop right there!", "Security! Don't move!", "You! Freeze!" },
	backup = { "I need backup at the yard!", "Unit two, moving to assist!", "Copy, on my way!" },
	investigate = { "Who's there?", "Hello? Anybody back here?", "I heard something..." },
	lost = { "Lost 'em.", "Where'd they go?", "Must've slipped out." },
	caught = { "Gotcha. Empty those pockets.", "Nice try, kid." },
	idle = { "Quiet night.", "Another double shift...", "Copy that, all clear." },
}

type Officer = {
	npc: Npc.Npc,
	state: string,
	goal: Vector3,
	untilTime: number,
	lookAt: number,
	target: Player?,
	speed: number,
	catchTimer: number,
	status: TextLabel,
	speech: TextLabel,
	speechToken: number,
	whistle: Sound,
	light: SpotLight,
}

local suspicion: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local loseTimer: { [Player]: number } = {}
local lastSeen: { [Player]: Vector3 } = {}
local officers: { Officer } = {}
local rng = Random.new()

local Police = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function isChased(player: Player): boolean
	return player:GetAttribute("Chased") == true
end

local function setSuspicion(player: Player, value: number)
	suspicion[player] = value
	player:SetAttribute("Suspicion", math.floor(value + 0.5))
end

local function say(o: Officer, lines: { string })
	o.speechToken += 1
	local token = o.speechToken
	local gui = o.speech.Parent :: BillboardGui
	o.speech.Text = pick(lines)
	gui.Enabled = true
	task.delay(2.6, function()
		if o.speechToken == token then
			gui.Enabled = false
		end
	end)
end

local function setStatus(o: Officer, text: string, color: Color3?)
	o.status.Text = text
	if color then
		o.status.TextColor3 = color
	end
end

-- Goals are clamped to the yard plus a short leash so officers stay on post.
local function clampToPost(goal: Vector3): Vector3
	local rc = W.RED_CENTER
	local hx, hz = W.RED_SIZE.X / 2 + P.LEASH, W.RED_SIZE.Y / 2 + P.LEASH
	return Vector3.new(
		math.clamp(goal.X, rc.X - hx, rc.X + hx),
		goal.Y,
		math.clamp(goal.Z, rc.Z - hz, rc.Z + hz)
	)
end

local function redDumpsters(): { Vector3 }
	local out = {}
	for _, spec in W.Dumpsters do
		if spec.zone == "Red" then
			table.insert(out, spec.pos)
		end
	end
	return out
end
local RED_DUMPSTERS = redDumpsters()

local function nearestPoint(from: Vector3, list: { Vector3 }): Vector3
	local best, bestD = list[1], math.huge
	for _, p in list do
		local d = (flat(p) - flat(from)).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

local function setState(o: Officer, state: string, goal: Vector3?, duration: number?)
	o.state = state
	if goal then
		o.goal = goal
	end
	o.untilTime = os.clock() + (duration or 0)
	o.lookAt = 0
end

local function nextPatrolPoint(o: Officer): Vector3
	local here = o.npc.root.Position
	for _ = 1, 6 do
		local p = pick(W.GUARD_POINTS)
		local d = (flat(p) - flat(here)).Magnitude
		if d > 30 and d < 220 then
			return p
		end
	end
	return pick(W.GUARD_POINTS)
end

local function buildOfficer(index: number, at: Vector3): Officer?
	local npc = Npc.new(
		"police",
		"SecurityOfficer" .. index,
		CFrame.new(at + Vector3.new(0, 3, 0)),
		workspace:WaitForChild("Town"),
		rng
	)
	if not npc then
		return nil
	end
	local head, hrp = npc.head, npc.root

	local flashlight = Instance.new("SpotLight")
	flashlight.Face = Enum.NormalId.Front
	flashlight.Angle = P.VISION_HALF_ANGLE * 2
	flashlight.Range = P.VISION_RANGE
	flashlight.Brightness = 3
	flashlight.Color = Color3.fromRGB(255, 244, 210)
	flashlight.Parent = head

	-- Faint ground cone so getting spotted always feels fair.
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.new(0, -2.7, -1)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(math.rad(90), 0, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.new(0, -2.7, -P.VISION_RANGE)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(math.rad(90), 0, 0)
	a1.Parent = hrp
	local beam = Instance.new("Beam")
	beam.Name = "VisionCone"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 1
	beam.Width1 = 2 * P.VISION_RANGE * math.tan(math.rad(P.VISION_HALF_ANGLE))
	beam.FaceCamera = false
	beam.Segments = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160))
	beam.Transparency = NumberSequence.new(0.72, 0.95)
	beam.LightEmission = 0.4
	beam.Parent = hrp

	local whistle = Instance.new("Sound")
	whistle.Name = "Whistle"
	whistle.SoundId = Config.Sounds.WHISTLE
	whistle.Volume = 1
	whistle.RollOffMaxDistance = 160
	whistle.Parent = head

	local function billboard(name: string, offset: number, size: UDim2): TextLabel
		local gui = Instance.new("BillboardGui")
		gui.Name = name
		gui.Size = size
		gui.StudsOffset = Vector3.new(0, offset, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = gui
		gui.Parent = head
		return label
	end
	local status = billboard("Status", 3.2, UDim2.fromOffset(44, 44))
	local speech = billboard("Speech", 5, UDim2.fromOffset(260, 36))
	local speechGui = speech.Parent :: BillboardGui
	speechGui.Enabled = false
	speechGui.MaxDistance = 90
	speech.TextColor3 = Color3.fromRGB(255, 244, 220)

	local speed = P.PATROL_SPEED + rng:NextNumber(-1, 1)
	npc.humanoid.WalkSpeed = speed
	local o: Officer = {
		npc = npc,
		state = "patrol",
		goal = at,
		untilTime = 0,
		lookAt = 0,
		target = nil,
		speed = speed,
		catchTimer = 0,
		status = status,
		speech = speech,
		speechToken = 0,
		whistle = whistle,
		light = flashlight,
	}
	setState(o, "patrol", nextPatrolPoint(o))
	return o
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function sees(o: Officer, player: Player): boolean
	local target = Guard.root(player)
	if not target then
		return false
	end
	local root = o.npc.root
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local to = target.Position - eye
	if to.Magnitude > P.VISION_RANGE then
		return false
	end
	local dir = flat(to)
	if
		dir.Magnitude > 0.1
		and flat(root.CFrame.LookVector).Unit:Dot(dir.Unit)
			< math.cos(math.rad(P.VISION_HALF_ANGLE))
	then
		return false
	end
	sightParams.FilterDescendantsInstances = { o.npc.model, player.Character :: Model }
	return workspace:Raycast(eye, to, sightParams) == nil
end

local function nearestOfficer(pos: Vector3): (Officer?, number)
	local best: Officer? = nil
	local bestD = math.huge
	for _, o in officers do
		local d = (flat(o.npc.root.Position) - flat(pos)).Magnitude
		if d < bestD then
			best, bestD = o, d
		end
	end
	return best, bestD
end

local function endChase(player: Player, reason: string, newSuspicion: number)
	if not isChased(player) then
		return
	end
	player:SetAttribute("Chased", false)
	loseTimer[player] = nil
	setSuspicion(player, newSuspicion)
	Router.send(player, "chase", { on = false, reason = reason })
	local spot = lastSeen[player]
	for _, o in officers do
		if o.target == player then
			o.target = nil
			if reason == "lost" or reason == "safe" then
				say(o, LINES.lost)
			end
			setState(o, "search", clampToPost(spot or o.npc.root.Position), 0)
		end
	end
	local any = false
	for _, other in Players:GetPlayers() do
		any = any or isChased(other)
	end
	workspace:SetAttribute("Alarm", any)
end

local function startChase(player: Player)
	player:SetAttribute("Chased", true)
	loseTimer[player] = 0
	Search.cancel(player, "spotted")
	Router.send(player, "chase", { on = true })
	workspace:SetAttribute("Alarm", true)
	local hrp = Guard.root(player)
	if not hrp then
		return
	end
	local first = nearestOfficer(hrp.Position)
	for _, o in officers do
		local d = (flat(o.npc.root.Position) - flat(hrp.Position)).Magnitude
		if o == first or d <= P.BACKUP_RADIUS then
			o.target = player
			setState(o, "chase")
			if o == first then
				say(o, LINES.spot)
				o.whistle:Play()
			else
				task.delay(rng:NextNumber(0.6, 1.4), say, o, LINES.backup)
			end
		end
	end
end

local function confiscate(player: Player): (number, number)
	local profile = Data.get(player)
	if not profile then
		return 0, 0
	end
	-- The guard lets you keep your best find(s) so a bust stings, not crushes.
	local order = table.clone(profile.backpack)
	table.sort(order, function(a, b)
		return Items.value(a.id, a.mutation) > Items.value(b.id, b.mutation)
	end)
	local count, value = 0, 0
	for i, entry in order do
		if i > P.KEEP_ON_CAPTURE then
			Data.removeItem(profile.backpack, entry.uid)
			count += 1
			value += Items.value(entry.id, entry.mutation)
		end
	end
	Data.push(player)
	return count, value
end

local function capture(player: Player, by: Officer)
	local count, value = confiscate(player)
	Search.cancel(player, "captured")
	say(by, LINES.caught)
	endChase(player, "captured", 0)
	immuneUntil[player] = os.clock() + P.IMMUNITY_AFTER_CAPTURE
	Guard.teleport(player, SPAWN_POINT)
	Router.send(player, "busted", { count = count, value = value })
end

local function dropAndRun(player: Player): (boolean, string?)
	if not isChased(player) then
		return false, nil
	end
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local order = table.clone(profile.backpack)
	table.sort(order, function(a, b)
		return Items.value(a.id, a.mutation) < Items.value(b.id, b.mutation)
	end)
	local dropCount = math.ceil(#order / 2)
	for i = 1, dropCount do
		Data.removeItem(profile.backpack, order[i].uid)
	end
	Data.push(player)
	immuneUntil[player] = os.clock() + P.IMMUNITY_AFTER_DROP
	endChase(player, "dropped", P.SUSPICION_AFTER_DROP)
	Router.send(player, "dropped", { count = dropCount })

	local hrp = Guard.root(player)
	if hrp then
		for i = 1, math.min(dropCount, 6) do
			local junk = Instance.new("Part")
			junk.Name = "DroppedJunk"
			junk.Size = Vector3.new(0.8, 0.8, 0.8)
			junk.Color = Items.Rarities[Items.ById[order[i].id].rarity].color
			junk.CanCollide = true
			junk.Position = hrp.Position
				+ Vector3.new(rng:NextNumber(-2, 2), 1, rng:NextNumber(-2, 2))
			junk.Parent = workspace
			game:GetService("Debris"):AddItem(junk, 6)
		end
	end
	return true, nil
end

local function updateSuspicion(player: Player, dt: number, now: number)
	local hrp = Guard.root(player)
	if not hrp then
		return
	end
	local inRed = Guard.inRedZone(hrp.Position)
	local profile = Data.get(player)
	if inRed and profile and profile.tutorial == 3 then
		Data.advanceTutorial(profile, 3, player)
		Data.push(player)
	end

	local seenBy: Officer? = nil
	for _, o in officers do
		if sees(o, player) then
			seenBy = o
			break
		end
	end
	if seenBy then
		lastSeen[player] = hrp.Position
	end

	if isChased(player) then
		setSuspicion(player, 100)
		if Guard.inHideout(player) and not Guard.isFlagged(player) then
			endChase(player, "safe", 0)
			return
		end
		local _, distance = nearestOfficer(hrp.Position)
		if distance > P.LOSE_DISTANCE or (not seenBy and distance > P.LOSE_DISTANCE / 2) then
			loseTimer[player] = (loseTimer[player] or 0) + dt
			if (loseTimer[player] :: number) >= P.LOSE_TIME then
				endChase(player, "lost", SU.WARN_LOW - 1)
			end
		else
			loseTimer[player] = 0
		end
		return
	end

	local s = suspicion[player] or 0
	local immune = (immuneUntil[player] or 0) > now
	local gain = 0
	local digging = tonumber(player:GetAttribute("Digging")) or 0
	if inRed and digging > 0 then
		gain += SU.SEARCH_RATE * digging
	end
	if inRed and seenBy then
		gain += if digging > 0 then SU.SEEN_RATE else SU.SEEN_IDLE_RATE
	end
	if gain > 0 and not immune then
		s = math.min(100, s + gain * dt)
	else
		s = math.max(0, s - (if inRed then SU.DECAY_IN_RED else SU.DECAY_OUTSIDE) * dt)
	end
	setSuspicion(player, s)
	if s >= 100 and not immune then
		startChase(player)
	end
end

-- Assign the closest free officer to look into anyone who got suspicious.
local function dispatchInvestigations()
	for _, player in Players:GetPlayers() do
		local hrp = Guard.root(player)
		local s = suspicion[player] or 0
		if not hrp or isChased(player) or s < SU.WARN_LOW or not Guard.inRedZone(hrp.Position) then
			continue
		end
		local busy = false
		for _, o in officers do
			if o.target == player then
				busy = true
				break
			end
		end
		if busy then
			if s >= SU.WARN_HIGH then
				-- Keep the assigned officer's goal fresh while it is getting hot.
				for _, o in officers do
					if o.target == player and o.state == "investigate" then
						o.goal = clampToPost(hrp.Position)
					end
				end
			end
			continue
		end
		local best: Officer? = nil
		local bestD = math.huge
		for _, o in officers do
			if o.state ~= "chase" and o.target == nil then
				local d = (flat(o.npc.root.Position) - flat(hrp.Position)).Magnitude
				if d < bestD then
					best, bestD = o, d
				end
			end
		end
		if best then
			best.target = player
			setState(best, "investigate", clampToPost(hrp.Position))
			say(best, LINES.investigate)
		end
	end
end

local function lookAround(o: Officer, now: number)
	if now >= o.lookAt then
		o.lookAt = now + rng:NextNumber(0.9, 1.6)
		local a = rng:NextNumber(0, math.pi * 2)
		o.npc:face(Vector3.new(math.cos(a), 0, math.sin(a)))
	end
end

local function updateOfficer(o: Officer, dt: number, now: number)
	local npc = o.npc
	local pos = npc.root.Position
	local arrived = (flat(o.goal) - flat(pos)).Magnitude < 4

	if o.state == "chase" then
		local target = o.target
		local hrp = target and Guard.root(target)
		if not target or not hrp or not isChased(target) then
			o.target = nil
			setState(o, "search", pos, 0)
			return
		end
		npc.humanoid.WalkSpeed = P.CHASE_SPEED
		setStatus(o, "!", Color3.fromRGB(255, 70, 60))
		npc:moveToward(clampToPost(hrp.Position), now)
		local d = (flat(hrp.Position) - flat(pos)).Magnitude
		if d <= P.CATCH_RANGE then
			o.catchTimer += dt
			if o.catchTimer >= P.CATCH_TIME then
				o.catchTimer = 0
				capture(target, o)
			end
		else
			o.catchTimer = math.max(0, o.catchTimer - dt)
		end
		return
	end
	o.catchTimer = 0

	if o.state == "investigate" then
		local target = o.target
		if not target or not target.Parent or (suspicion[target] or 0) < SU.WARN_LOW * 0.5 then
			o.target = nil
			setState(o, "search", o.goal, 0)
			return
		end
		npc.humanoid.WalkSpeed = P.INVESTIGATE_SPEED
		setStatus(o, "?", Color3.fromRGB(255, 220, 60))
		if arrived then
			lookAround(o, now)
		else
			npc:moveToward(o.goal, now)
		end
		return
	end

	o.target = nil
	if o.state == "search" then
		npc.humanoid.WalkSpeed = o.speed
		setStatus(o, "?", Color3.fromRGB(200, 200, 200))
		if arrived then
			if o.untilTime == 0 then
				o.untilTime = now + rng:NextNumber(4, 6)
			end
			lookAround(o, now)
			if now >= o.untilTime then
				setState(o, "patrol", nextPatrolPoint(o))
			end
		else
			npc:moveToward(o.goal, now)
		end
		return
	end

	setStatus(o, "")
	npc.humanoid.WalkSpeed = o.speed
	if o.state == "pause" then
		lookAround(o, now)
		if now >= o.untilTime then
			setState(o, "patrol", nextPatrolPoint(o))
		end
		return
	end
	if o.state == "check" then
		if arrived then
			if o.untilTime == 0 then
				o.untilTime = now + rng:NextNumber(2.5, 4)
				npc:face(o.goal - pos)
			end
			if now >= o.untilTime then
				setState(o, "patrol", nextPatrolPoint(o))
			end
		else
			npc:moveToward(o.goal, now)
		end
		return
	end

	-- patrol
	if arrived then
		local roll = rng:NextNumber()
		if roll < 0.45 then
			npc:stop()
			setState(o, "pause", nil, rng:NextNumber(2, 5))
			if rng:NextNumber() < 0.2 then
				say(o, LINES.idle)
			end
		elseif roll < 0.7 then
			local dumpster = nearestPoint(pos, RED_DUMPSTERS)
			local stand = dumpster + (flat(pos - dumpster).Unit * 7)
			setState(o, "check", stand, 0)
		else
			setState(o, "patrol", nextPatrolPoint(o))
		end
	else
		npc:moveToward(o.goal, now)
	end
end

function Police.init()
	Router.on("dropAndRun", 0.5, dropAndRun)

	-- Leaving mid-chase counts as getting caught (GDD section 5).
	Data.onRelease(function(player, profile)
		if isChased(player) then
			table.clear(profile.backpack)
		end
	end)
end

function Police.start()
	for i = 1, P.GUARD_COUNT do
		local start = W.GUARD_POINTS[(i * 5 - 4 - 1) % #W.GUARD_POINTS + 1]
		local o = buildOfficer(i, start)
		if o then
			table.insert(officers, o)
		end
	end
	workspace:SetAttribute("Alarm", false)

	local function onPlayerAdded(player: Player)
		setSuspicion(player, 0)
		player:SetAttribute("Chased", false)
		player.CharacterAdded:Connect(function(character)
			local hum = character:WaitForChild("Humanoid") :: Humanoid
			hum.Died:Connect(function()
				if isChased(player) then
					local count, value = confiscate(player)
					endChase(player, "reset", 0)
					Router.send(player, "busted", { count = count, value = value })
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		suspicion[player] = nil
		immuneUntil[player] = nil
		loseTimer[player] = nil
		lastSeen[player] = nil
		for _, o in officers do
			if o.target == player then
				o.target = nil
				setState(o, "patrol", nextPatrolPoint(o))
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			updateSuspicion(player, step, now)
		end
		dispatchInvestigations()
		local night = workspace:GetAttribute("Night") == true
		for _, o in officers do
			o.light.Brightness = if night then 5 else 1.5
			updateOfficer(o, step, now)
		end
	end)
end

return Police
