--!strict
-- City police and wanted stars. Outside the Meridian yard (whose security
-- has its own suspicion meter, see Police.luau) the city police notice two
-- crimes: driving through a red light, and running someone over. Each crime
-- adds heat; every HEAT_PER_STAR of heat is a wanted star (up to MAX_STARS).
--
-- While wanted, officers arrive on foot from out of sight (COPS_PER_STAR per
-- star) and chase you. Staying out of every officer's reach for LOSE_TIME
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

local function spawnCop(target: Player): Cop?
	local root = Guard.root(target)
	if not root then
		return nil
	end
	local at = spawnPointNear(root.Position)
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
		for model, t in hitCooldown do
			if t < now or not model.Parent then
				hitCooldown[model] = nil
			end
		end
	end)
end

return Wanted
