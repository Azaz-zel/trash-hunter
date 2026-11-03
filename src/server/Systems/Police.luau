--!strict
-- Suspicion bar, the security guard NPC (patrol / investigate / chase / catch),
-- Drop & Run, and capture. Chase movement walks straight at the target when
-- the line is clear and falls back to PathfindingService around fences.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Search = require(script.Parent.Search)

local P = Config.Police
local SU = Config.Suspicion
local W = Config.World
local TICK = 0.1
local SPAWN_POINT = W.HIDEOUT_CENTER + Vector3.new(0, 1, 8)

local suspicion: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local loseTimer: { [Player]: number } = {}

local npc: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local status: TextLabel? = nil
local whistle: Sound? = nil
local patrolIndex = 1
local catchTimer = 0
local lastMove = 0
local path: { PathWaypoint }? = nil
local pathIndex = 2
local pathBusy = false
local lastPath = 0

local Police = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isChased(player: Player): boolean
	return player:GetAttribute("Chased") == true
end

local function setSuspicion(player: Player, value: number)
	suspicion[player] = value
	player:SetAttribute("Suspicion", math.floor(value + 0.5))
end

local function setStatus(text: string, color: Color3?)
	if status then
		status.Text = text
		if color then
			status.TextColor3 = color
		end
	end
end

local function buildNpc(): boolean
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	local uniform = Color3.fromRGB(38, 62, 150)
	desc.HeadColor = skin
	desc.LeftArmColor = uniform
	desc.RightArmColor = uniform
	desc.TorsoColor = uniform
	desc.LeftLegColor = Color3.fromRGB(28, 32, 50)
	desc.RightLegColor = Color3.fromRGB(28, 32, 50)
	local ok, result =
		pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok then
		warn("[Police] could not build the guard: " .. tostring(result))
		return false
	end
	local model = result :: Model
	model.Name = "SecurityGuard"
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	hum.DisplayName = "Security"
	hum.WalkSpeed = P.PATROL_SPEED
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge

	-- Cap so the guard reads as a guard from far away.
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.6, 1.4, 1.4)
	cap.Color = uniform
	cap.CanCollide = false
	cap.Massless = true
	cap.CFrame = head.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = cap
	weld.Parent = cap
	cap.Parent = model

	local flashlight = Instance.new("SpotLight")
	flashlight.Face = Enum.NormalId.Front
	flashlight.Angle = P.VISION_HALF_ANGLE * 2
	flashlight.Range = P.VISION_RANGE
	flashlight.Brightness = 4
	flashlight.Color = Color3.fromRGB(255, 240, 180)
	flashlight.Parent = head

	-- Ground beam showing the vision cone so getting spotted always feels fair.
	local a0 = Instance.new("Attachment")
	a0.Name = "ConeStart"
	a0.CFrame = CFrame.new(0, -2.7, -1)
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(math.rad(90), 0, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "ConeEnd"
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
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
	beam.Transparency = NumberSequence.new(0.55, 0.9)
	beam.LightEmission = 0.5
	beam.Parent = hrp

	-- Positional, so everyone nearby hears a chase start, not just the target.
	local sound = Instance.new("Sound")
	sound.Name = "Whistle"
	sound.SoundId = Config.Sounds.WHISTLE
	sound.Volume = 1
	sound.RollOffMaxDistance = 140
	sound.Parent = head
	whistle = sound

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(60, 60)
	bubble.StudsOffset = Vector3.new(0, 3, 0)
	bubble.AlwaysOnTop = true
	bubble.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = bubble
	bubble.Parent = head

	model:PivotTo(CFrame.new(W.PATROL[1] + Vector3.new(0, 3, 0)))
	model.Parent = workspace:WaitForChild("Town")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetNetworkOwner(nil)
		end
	end

	-- Server-driven walk cycle, loaded once the rig is in the DataModel
	-- (tracks loaded earlier silently stay empty). The rig's own Animate LocalScript never runs on an NPC.
	local oldAnimate = model:FindFirstChild("Animate")
	if oldAnimate then
		oldAnimate:Destroy()
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = hum
		animator = created
	end
	local function track(id: string, priority: Enum.AnimationPriority): AnimationTrack
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local t = (animator :: Animator):LoadAnimation(anim)
		t.Priority = priority
		t.Looped = true
		return t
	end
	local idle = track("rbxassetid://507766388", Enum.AnimationPriority.Idle)
	local walk = track("rbxassetid://913402848", Enum.AnimationPriority.Movement)
	local run = track("rbxassetid://913376220", Enum.AnimationPriority.Movement)
	idle:Play()
	local moving: AnimationTrack? = nil
	hum.Running:Connect(function(speed)
		local want = if speed < 0.5 then nil elseif speed > P.PATROL_SPEED * 1.3 then run else walk
		if want == moving then
			return
		end
		if moving then
			moving:Stop(0.2)
		end
		moving = want
		if want then
			want:Play(0.2)
		end
	end)

	npc, humanoid, root, status = model, hum, hrp, label
	return true
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(player: Player): boolean
	local target = Guard.root(player)
	if not target or not root or not npc then
		return false
	end
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local to = target.Position - eye
	if to.Magnitude > P.VISION_RANGE then
		return false
	end
	local look = flat(root.CFrame.LookVector)
	local dir = flat(to)
	if dir.Magnitude < 0.1 then
		return true
	end
	if look.Unit:Dot(dir.Unit) < math.cos(math.rad(P.VISION_HALF_ANGLE)) then
		return false
	end
	sightParams.FilterDescendantsInstances = { npc, player.Character :: Model }
	return workspace:Raycast(eye, to, sightParams) == nil
end

local moveParams = RaycastParams.new()
moveParams.FilterType = Enum.RaycastFilterType.Exclude

local function computePath(goal: Vector3)
	if pathBusy or not root then
		return
	end
	pathBusy = true
	lastPath = os.clock()
	local from = root.Position
	task.spawn(function()
		local p =
			PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(p.ComputeAsync, p, from, goal)
		if ok and p.Status == Enum.PathStatus.Success then
			path = p:GetWaypoints()
			pathIndex = 2
		else
			path = nil
		end
		pathBusy = false
	end)
end

local function moveToward(goal: Vector3, now: number)
	if not humanoid or not root or not npc or now - lastMove < 0.2 then
		return
	end
	lastMove = now
	local filter: { Instance } = { npc }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	moveParams.FilterDescendantsInstances = filter
	local origin = root.Position
	local hit = workspace:Raycast(origin, flat(goal - origin), moveParams)
	if not hit then
		path = nil
		humanoid:MoveTo(goal)
		return
	end
	if now - lastPath > 0.6 then
		computePath(goal)
	end
	local current = path
	if current and current[pathIndex] then
		local waypoint = current[pathIndex]
		if (flat(waypoint.Position) - flat(origin)).Magnitude < 3 then
			pathIndex += 1
			waypoint = current[pathIndex] or waypoint
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	end
end

local function endChase(player: Player, reason: string, newSuspicion: number)
	if not isChased(player) then
		return
	end
	player:SetAttribute("Chased", false)
	loseTimer[player] = nil
	setSuspicion(player, newSuspicion)
	Router.send(player, "chase", { on = false, reason = reason })
end

local function startChase(player: Player)
	player:SetAttribute("Chased", true)
	loseTimer[player] = 0
	Search.cancel(player, "spotted")
	Router.send(player, "chase", { on = true })
	if whistle then
		whistle:Play()
	end
end

-- Empties the backpack; returns how many items and how much cash they were worth.
local function confiscate(player: Player): (number, number)
	local profile = Data.get(player)
	if not profile then
		return 0, 0
	end
	local count, value = #profile.backpack, 0
	for _, entry in profile.backpack do
		value += Items.value(entry.id, entry.mutation)
	end
	table.clear(profile.backpack)
	Data.push(player)
	return count, value
end

local function capture(player: Player)
	local count, value = confiscate(player)
	Search.cancel(player, "captured")
	player:SetAttribute("Chased", false)
	loseTimer[player] = nil
	setSuspicion(player, 0)
	immuneUntil[player] = os.clock() + P.IMMUNITY_AFTER_CAPTURE
	catchTimer = 0
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
			junk.Material = Enum.Material.SmoothPlastic
			junk.CanCollide = true
			junk.Position = hrp.Position + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
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
		Data.advanceTutorial(profile, 3)
		Data.push(player)
	end

	if isChased(player) then
		setSuspicion(player, 100)
		if Guard.inHideout(player) and not Guard.isFlagged(player) then
			endChase(player, "safe", 0)
			return
		end
		local distance = if root
			then (flat(hrp.Position) - flat(root.Position)).Magnitude
			else math.huge
		if distance > P.LOSE_DISTANCE then
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
	if inRed and canSee(player) then
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

local function updateNpc(dt: number, now: number)
	if not root or not humanoid then
		return
	end
	-- Nearest chased player is the target.
	local target: Player? = nil
	local best = math.huge
	for _, player in Players:GetPlayers() do
		local hrp = Guard.root(player)
		if hrp and isChased(player) then
			local d = (flat(hrp.Position) - flat(root.Position)).Magnitude
			if d < best then
				best, target = d, player
			end
		end
	end

	if target then
		local hrp = Guard.root(target) :: BasePart
		humanoid.WalkSpeed = P.CHASE_SPEED
		setStatus("!", Color3.fromRGB(255, 70, 60))
		local goal = hrp.Position
		local offset = flat(goal - W.RED_CENTER)
		if offset.Magnitude > P.LEASH then
			goal = W.RED_CENTER + offset.Unit * P.LEASH
		end
		moveToward(goal, now)
		if best <= P.CATCH_RANGE then
			catchTimer += dt
			if catchTimer >= P.CATCH_TIME then
				capture(target)
			end
		else
			catchTimer = math.max(0, catchTimer - dt)
		end
		return
	end
	catchTimer = 0

	-- Investigate the most suspicious trespasser.
	local suspect: Player? = nil
	local highest = SU.WARN_LOW
	for _, player in Players:GetPlayers() do
		local hrp = Guard.root(player)
		local s = suspicion[player] or 0
		if hrp and s >= highest and Guard.inRedZone(hrp.Position) then
			highest, suspect = s, player
		end
	end
	if suspect then
		humanoid.WalkSpeed = P.PATROL_SPEED * 1.25
		setStatus("?", Color3.fromRGB(255, 220, 60))
		moveToward((Guard.root(suspect) :: BasePart).Position, now)
		return
	end

	humanoid.WalkSpeed = P.PATROL_SPEED
	setStatus("")
	local goal = W.PATROL[patrolIndex]
	if (flat(goal) - flat(root.Position)).Magnitude < 4 then
		patrolIndex = patrolIndex % #W.PATROL + 1
		goal = W.PATROL[patrolIndex]
	end
	moveToward(goal, now)
end

function Police.init()
	Router.on("dropAndRun", 0.5, dropAndRun)

	-- Leaving or resetting mid-chase counts as getting caught (GDD section 5).
	Data.onRelease(function(player, profile)
		if isChased(player) then
			table.clear(profile.backpack)
		end
	end)
end

function Police.start()
	buildNpc()

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
		updateNpc(step, now)
	end)
end

return Police
