--!strict
-- City police and wanted stars. Outside the Meridian yard (whose security
-- has its own suspicion meter, see Police.luau) the city police notice two
-- crimes: driving through a red light, and running someone over. Each crime
-- adds heat; every HEAT_PER_STAR of heat is a wanted star (up to MAX_STARS).
--
-- While wanted, officers arrive on foot from out of sight (COPS_PER_STAR per
-- star) and chase you; from CRUISER_FROM stars police cruisers join, follow
-- the roads to you, ram through, drop an officer when you are on foot, and
-- arrest you if your car stops next to them. Staying out of every officer's
-- reach for LOSE_TIME
-- (+4 s per star), or reaching a Hideout, clears the stars. Running for too
-- long adds a star. Caught means arrested (Police.arrest): the same penalty
-- as a yard bust.
--
-- Player attributes: Wanted (stars) and WantedSearch (0..1, how close the
-- police are to losing you), read by the client HUD and traffic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local CityPlan = require(Shared.CityPlan)
local Router = require(script.Parent.Parent.Router)
local Npc = require(script.Parent.Parent.Npc)
local Guard = require(script.Parent.Guard)
local Police = require(script.Parent.Police)
local Pedestrians = require(script.Parent.Pedestrians)

local WC = Config.Wanted
local TICK = 0.1

local LINES = {
	arrive = {
		"Police! Stop right there!",
		"City police! Freeze!",
		"You! Hands where I can see them!",
	},
	chase = { "Suspect is on foot!", "Don't make this harder!", "Stop running!" },
	lost = { "Lost the suspect.", "Where'd they go?", "All units, suspect lost." },
	caught = { "You're under arrest.", "Gotcha. Hands behind your back." },
}

type Cop = {
	npc: Npc.Npc,
	target: Player?,
	catch: number,
	leaving: number?, -- os.clock() when it gives up and walks off
	nextLine: number,
}

local Wanted = {}

local rng = Random.new()
local heat: { [Player]: number } = {}
local stars: { [Player]: number } = {}
local starSince: { [Player]: number } = {}
local loseTimer: { [Player]: number } = {}
local lastCarPos: { [Player]: Vector3 } = {}
local hitCooldown: { [Instance]: number } = {}
local cops: { Cop } = {}

type Cruiser = {
	model: Model,
	root: BasePart,
	align: AlignPosition,
	orient: AlignOrientation,
	target: Player?,
	path: { Vector3 },
	step: number,
	replanAt: number,
	catch: number,
	deployAt: number,
	leaving: number?,
	lift: number,
}
local cruisers: { Cruiser } = {}
local folder: Folder

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pick(list: { string }): string
	return list[rng:NextInteger(1, #list)]
end

-- Sidewalk points in 100-stud cells, for finding where officers walk in from.
local CELL = 100
local walkCells: { [string]: { Vector3 } } = {}
for _, path in CityPlan.SIDEWALKS do
	for _, p in path do
		local key = math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)
		walkCells[key] = walkCells[key] or {}
		table.insert(walkCells[key], p)
	end
end

local function spawnPointNear(pos: Vector3): Vector3?
	local list = {}
	local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
	local reach = math.ceil(WC.SPAWN_MAX / CELL)
	for gx = cx - reach, cx + reach do
		for gz = cz - reach, cz + reach do
			for _, p in walkCells[gx .. "," .. gz] or {} do
				local d = (flat(p) - flat(pos)).Magnitude
				if d > WC.SPAWN_MIN and d < WC.SPAWN_MAX then
					table.insert(list, p)
				end
			end
		end
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- The car a player is driving, if any.
local function carOf(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return nil, nil
	end
	local model = seat:FindFirstAncestorWhichIsA("Model")
	while model and model.Parent and model.Parent:IsA("Model") do
		model = model.Parent :: Model
	end
	return model, seat
end

local function setStars(player: Player, n: number)
	if (stars[player] or 0) ~= n then
		starSince[player] = os.clock()
	end
	stars[player] = n
	player:SetAttribute("Wanted", n)
end

local function clear(player: Player, reason: string)
	if (stars[player] or 0) == 0 then
		heat[player] = 0
		return
	end
	heat[player] = 0
	loseTimer[player] = 0
	setStars(player, 0)
	player:SetAttribute("WantedSearch", 0)
	Router.send(player, "wanted", { stars = 0, reason = reason })
	local now = os.clock()
	for _, c in cruisers do
		if c.target == player then
			c.target = nil
			c.leaving = now
		end
	end
	for _, cop in cops do
		if cop.target == player then
			cop.target = nil
			cop.leaving = now
			if reason == "lost" or reason == "safe" then
				cop.npc:say(pick(LINES.lost))
			end
		end
	end
end

-- Call a Lawyer (Robux product): the stars are gone.
function Wanted.pardon(player: Player)
	clear(player, "lawyer")
end

local function crime(player: Player, amount: number, text: string, at: Vector3)
	if Guard.inRedZone(at) then
		return -- the yard's own security deals with it
	end
	heat[player] = (heat[player] or 0) + amount
	local want = math.min(WC.MAX_STARS, math.floor((heat[player] :: number) / WC.HEAT_PER_STAR))
	local before = stars[player] or 0
	if want > before then
		setStars(player, want)
		Router.send(player, "wanted", { stars = want, crime = text })
	else
		Router.send(player, "crime", { text = text })
	end
	Pedestrians.panic(at, 45, "Somebody call the cops!")
end

-- ─── crimes ───────────────────────────────────────────────────────────────

local SIGNALS: { CityPlan.Node } = {}
for _, n in CityPlan.NODES do
	if n.signal then
		table.insert(SIGNALS, n)
	end
end

-- Entering a signalled junction on red (amber is allowed).
local function checkRedLight(player: Player, pos: Vector3, speed: number)
	local prev = lastCarPos[player]
	lastCarPos[player] = pos
	if not prev or speed < 6 then
		return
	end
	for _, n in SIGNALS do
		local now = (flat(pos) - flat(n.pos)).Magnitude
		local before = (flat(prev) - flat(n.pos)).Magnitude
		if now < n.gap and before >= n.gap then
			-- The approach it came in on: the leg pointing back at where it was.
			local back = flat(prev - n.pos)
			local best, bestDot = nil :: CityPlan.Edge?, -2
			for _, e in n.edges do
				local d = CityPlan.leaving(e, n):Dot(back.Unit)
				if d > bestDot then
					best, bestDot = e, d
				end
			end
			if best then
				local state = CityPlan.signalState(
					CityPlan.signalGroup(n, best),
					workspace:GetServerTimeNow()
				)
				if state == "red" then
					crime(player, WC.RED_LIGHT, "Ran a red light", pos)
				end
			end
			return
		end
	end
end

local function checkHits(player: Player, car: Model, seat: BasePart, speed: number)
	if speed < WC.HIT_SPEED then
		return
	end
	local town = workspace:FindFirstChild("Town")
	local people = town and town:FindFirstChild("Pedestrians")
	if not people then
		return
	end
	local center = car:GetPivot().Position
	local vel = seat.AssemblyLinearVelocity
	local now = os.clock()
	for _, model in people:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or root.Anchored then
			continue
		end
		if (hitCooldown[model] or 0) > now then
			continue
		end
		local rel = root.Position - center
		if flat(rel).Magnitude < 7 and math.abs(rel.Y) < 7 then
			hitCooldown[model] = now + 4
			Pedestrians.knock(model, flat(vel) * 0.7 + Vector3.new(0, 28, 0))
			crime(player, WC.HIT_PERSON, "Hit a pedestrian", root.Position)
		end
	end
end

-- ─── officers ─────────────────────────────────────────────────────────────

local function spawnCop(target: Player, from: Vector3?): Cop?
	local root = Guard.root(target)
	if not root then
		return nil
	end
	local at = from or spawnPointNear(root.Position)
	if not at then
		return nil
	end
	local npc = Npc.new(
		"police",
		"CityCop",
		CFrame.lookAt(at + Vector3.new(0, 3, 0), root.Position),
		folder,
		rng
	)
	if not npc then
		return nil
	end
	npc.humanoid.WalkSpeed = WC.COP_SPEED
	npc.model:SetAttribute("Cop", true)
	npc:say(pick(LINES.arrive))
	local cop: Cop =
		{ npc = npc, target = target, catch = 0, leaving = nil, nextLine = os.clock() + 6 }
	table.insert(cops, cop)
	return cop
end

local function updateCop(cop: Cop, dt: number, now: number)
	local npc = cop.npc
	local target = cop.target
	if cop.leaving then
		if now - (cop.leaving :: number) > 6 then
			npc:destroy()
			local k = table.find(cops, cop)
			if k then
				table.remove(cops, k)
			end
		else
			npc:stop()
		end
		return
	end
	local root = target and Guard.root(target)
	if not target or not root then
		cop.leaving = now
		return
	end
	npc:moveToward(root.Position, now)
	if now >= cop.nextLine then
		cop.nextLine = now + rng:NextNumber(6, 11)
		npc:say(pick(LINES.chase))
	end
	local car, seat = carOf(target)
	local d = (flat(root.Position) - flat(npc.root.Position)).Magnitude
	local close = if car and seat
		then d < 8 and seat.AssemblyLinearVelocity.Magnitude < 3
		else d < WC.CATCH_RANGE
	if close then
		cop.catch += dt
		if cop.catch >= WC.CATCH_TIME then
			npc:say(pick(LINES.caught))
			Police.arrest(target)
			clear(target, "arrested")
		end
	else
		cop.catch = math.max(0, cop.catch - dt)
	end
end

-- ─── cruisers ─────────────────────────────────────────────────────────────

-- Road points from `from` to `to` along CityPlan's graph.
local function roadPath(from: Vector3, to: Vector3): { Vector3 }
	local nodes = CityPlan.route(from, to)
	local points = {}
	for k, n in nodes do
		local nextNode = nodes[k + 1]
		local e = nextNode and CityPlan.edgeBetween(n, nextNode)
		if e then
			local pts = e.points
			local forward = e.a == n
			for q = 1, #pts do
				table.insert(points, pts[if forward then q else #pts - q + 1])
			end
		else
			table.insert(points, n.pos)
		end
	end
	table.insert(points, to)
	return points
end

local function spawnCruiser(target: Player): Cruiser?
	local root = Guard.root(target)
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("VehicleTemplates")
	local source = templates and templates:FindFirstChild("PoliceCar")
	if not root or not source or not source:IsA("Model") then
		return nil
	end
	-- Start at a junction out of sight down the road.
	local start: Vector3? = nil
	for _ = 1, 40 do
		local n = CityPlan.NODES[rng:NextInteger(1, #CityPlan.NODES)]
		local d = (flat(n.pos) - flat(root.Position)).Magnitude
		if #n.edges > 0 and d > 160 and d < 320 and n.pos.Y < 1 then
			start = n.pos
			break
		end
	end
	if not start then
		return nil
	end
	local model = source:Clone()
	model.Name = "PoliceCruiser"
	local body = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	model.PrimaryPart = body
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			if d ~= body then
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = d
				w.Parent = d
			end
		elseif
			d:IsA("Script")
			or d:IsA("LocalScript")
			or d:IsA("Constraint") and not d:IsA("WeldConstraint")
		then
			d:Destroy()
		end
	end
	local bb, size = model:GetBoundingBox()
	local lift = model:GetPivot().Y - (bb.Y - size.Y / 2) + CityPlan.SURFACE
	model:PivotTo(
		CFrame.lookAt(start + Vector3.new(0, lift, 0), root.Position + Vector3.new(0, lift, 0))
	)
	local attach = Instance.new("Attachment")
	attach.Parent = body
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attach
	align.MaxForce = math.huge
	align.MaxVelocity = WC.CRUISER_SPEED
	align.Responsiveness = 40
	align.Position = body.Position
	align.Parent = body
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attach
	orient.MaxTorque = math.huge
	orient.Responsiveness = 25
	orient.CFrame = body.CFrame
	orient.Parent = body
	-- Roof lights, flashing red and blue.
	local lamps = {}
	for k, side in { -1, 1 } do
		local lamp = Instance.new("Part")
		lamp.Name = "Siren"
		lamp.Size = Vector3.new(1.3, 0.4, 0.7)
		lamp.CFrame = bb * CFrame.new(side * 0.8, size.Y / 2 + 0.2, 0)
		lamp.Color = if k == 1 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 90, 255)
		lamp.Material = Enum.Material.Neon
		lamp.CanCollide = false
		lamp.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = lamp
		w.Parent = lamp
		local glow = Instance.new("PointLight")
		glow.Color = lamp.Color
		glow.Range = 24
		glow.Parent = lamp
		lamp.Parent = model
		table.insert(lamps, glow)
	end
	if Config.Sounds.SIREN ~= "" then
		local siren = Instance.new("Sound")
		siren.SoundId = Config.Sounds.SIREN
		siren.Looped = true
		siren.Volume = 0.7
		siren.RollOffMaxDistance = 350
		siren.Parent = body
		siren:Play()
	end
	model.Parent = folder
	body:SetNetworkOwner(nil)
	local cruiser: Cruiser = {
		model = model,
		root = body,
		align = align,
		orient = orient,
		target = target,
		path = {},
		step = 1,
		replanAt = 0,
		catch = 0,
		deployAt = os.clock() + 4,
		leaving = nil,
		lift = lift,
	}
	task.spawn(function()
		local on = false
		while model.Parent do
			on = not on
			lamps[1].Brightness = if on then 5 else 0
			lamps[2].Brightness = if on then 0 else 5
			task.wait(0.3)
		end
	end)
	table.insert(cruisers, cruiser)
	return cruiser
end

local function updateCruiser(c: Cruiser, dt: number, now: number)
	local pos = c.root.Position
	if c.leaving then
		if now - (c.leaving :: number) > 5 then
			c.model:Destroy()
			local k = table.find(cruisers, c)
			if k then
				table.remove(cruisers, k)
			end
		end
		return
	end
	local target = c.target
	local troot = target and Guard.root(target)
	if not target or not troot then
		c.leaving = now
		return
	end
	local tpos = troot.Position
	local d = (flat(tpos) - flat(pos)).Magnitude
	local aim: Vector3
	if d < 70 then
		aim = tpos -- close: straight at them
	else
		if now >= c.replanAt or c.step > #c.path then
			c.replanAt = now + 2.5
			c.path = roadPath(pos, tpos)
			c.step = 1
		end
		while c.step < #c.path and (flat(c.path[c.step]) - flat(pos)).Magnitude < 10 do
			c.step += 1
		end
		aim = c.path[c.step] or tpos
	end
	local ground = Vector3.new(aim.X, CityPlan.groundY(aim.X, aim.Z) + c.lift, aim.Z)
	c.align.Position = ground
	local dir = flat(ground - pos)
	if dir.Magnitude > 1 then
		c.orient.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
	end
	-- Arrest a driver whose car stopped beside the cruiser.
	local car, seat = carOf(target)
	if car and seat then
		if d < WC.CRUISER_CATCH and seat.AssemblyLinearVelocity.Magnitude < 3 then
			c.catch += dt
			if c.catch >= WC.CATCH_TIME * 2 then
				Police.arrest(target)
				clear(target, "arrested")
			end
		else
			c.catch = math.max(0, c.catch - dt)
		end
	elseif d < 25 and now >= c.deployAt then
		-- On foot nearby: an officer jumps out.
		c.deployAt = now + 12
		spawnCop(target, pos + Vector3.new(0, 1, 0))
	end
end

local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude

local function updateWanted(player: Player, dt: number, now: number)
	local root = Guard.root(player)
	local n = stars[player] or 0
	if not root then
		return
	end
	if n == 0 then
		heat[player] = math.max(0, (heat[player] or 0) - WC.DECAY * dt)
		return
	end
	if Guard.inHideout(player) and not Guard.isFlagged(player) then
		clear(player, "safe")
		return
	end
	-- Enough officers on the case?
	local mine, total = 0, 0
	local nearest = math.huge
	local seen = false
	for _, cop in cops do
		if not cop.leaving then
			total += 1
			if cop.target == player then
				mine += 1
				local d = (flat(cop.npc.root.Position) - flat(root.Position)).Magnitude
				nearest = math.min(nearest, d)
				if not seen and d < WC.LOSE_RANGE then
					sight.FilterDescendantsInstances = { cop.npc.model, player.Character :: Model }
					local eye = cop.npc.root.Position + Vector3.new(0, 1.5, 0)
					seen = workspace:Raycast(eye, root.Position - eye, sight) == nil
				end
			end
		end
	end
	if mine < n * WC.COPS_PER_STAR and total < WC.MAX_COPS then
		spawnCop(player)
		nearest = math.min(nearest, WC.SPAWN_MAX)
	end
	-- Cruisers from CRUISER_FROM stars; they count as officers for losing you.
	local myCars, allCars = 0, 0
	for _, c in cruisers do
		if not c.leaving then
			allCars += 1
			if c.target == player then
				myCars += 1
				nearest = math.min(nearest, (flat(c.root.Position) - flat(root.Position)).Magnitude)
			end
		end
	end
	if n >= WC.CRUISER_FROM and myCars < n - WC.CRUISER_FROM + 1 and allCars < WC.MAX_CRUISERS then
		spawnCruiser(player)
	end
	-- Losing them: out of reach, or out of sight (slower).
	local need = WC.LOSE_TIME + 4 * n
	local t = loseTimer[player] or 0
	if nearest > WC.LOSE_RANGE then
		t += dt
	elseif not seen and nearest > 30 then
		t += dt * 0.5
	else
		t = math.max(0, t - dt * 2)
	end
	loseTimer[player] = t
	player:SetAttribute("WantedSearch", math.clamp(t / need, 0, 1))
	if t >= need then
		clear(player, "lost")
		return
	end
	-- Running for a long time draws more police.
	if n < WC.MAX_STARS and now - (starSince[player] or now) > WC.ESCALATE_AFTER then
		heat[player] = (n + 1) * WC.HEAT_PER_STAR
		setStars(player, n + 1)
		Router.send(player, "wanted", { stars = n + 1, crime = "Evading the police" })
	end
end

function Wanted.start()
	folder = Instance.new("Folder")
	folder.Name = "CityPolice"
	folder.Parent = workspace:WaitForChild("Town")

	local function onPlayer(player: Player)
		setStars(player, 0)
		player:SetAttribute("WantedSearch", 0)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		heat[player], stars[player], starSince[player] = nil, nil, nil
		loseTimer[player], lastCarPos[player] = nil, nil
		for _, cop in cops do
			if cop.target == player then
				cop.target = nil
				cop.leaving = os.clock()
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
			local car, seat = carOf(player)
			if car and seat then
				local speed = seat.AssemblyLinearVelocity.Magnitude
				checkRedLight(player, seat.Position, speed)
				checkHits(player, car, seat, speed)
			else
				lastCarPos[player] = nil
			end
			updateWanted(player, step, now)
		end
		for i = #cops, 1, -1 do
			local cop = cops[i]
			if cop then
				updateCop(cop, step, now)
			end
		end
		for i = #cruisers, 1, -1 do
			local c = cruisers[i]
			if c then
				updateCruiser(c, step, now)
			end
		end
		for model, t in hitCooldown do
			if t < now or not model.Parent then
				hitCooldown[model] = nil
			end
		end
	end)
end

return Wanted
