--!strict
-- Client-side city traffic on CityPlan's road graph. Cars drive in the
-- right-hand lane along each street's curve, at that road's speed (slow in
-- cul-de-sacs, fast on the freeway). At junctions they obey the traffic
-- lights (shared, clock-driven phases), otherwise take turns, then pick a
-- random way on; dead ends become U-turns around the turning circle. They
-- queue behind the car ahead and stop for people in front of them.
-- Purely visual: each client runs its own, near its player, so it costs no
-- network traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CityPlan = require(Shared:WaitForChild("CityPlan"))

local player = Players.LocalPlayer
local rng = Random.new()

local SPEED = { freeway = 58, arterial = 36, collector = 28, street = 24, court = 18, hill = 26 }
local ACCEL = 14
local BRAKE = 40
local FOLLOW_GAP = 17
local CAR_COUNT = 26
local NEAR = 420 -- spawn within this distance of the player
local FAR = 620 -- recycle beyond this
local LOCK_TIMEOUT = 6
local PHASE = 16 -- seconds per green phase; the last 3 are amber

type Node = CityPlan.Node
type Lane = {
	from: Node,
	to: Node,
	pts: { Vector3 }, -- lane centre line (road base height)
	cum: { number }, -- distance along the lane at each point
	length: number,
	speed: number,
	reverse: Lane?,
	group: string, -- signal group of its approach: "A" (east-west) or "B"
}
type Turn = {
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	length: number,
	t: number,
	next: Lane,
	node: Node,
}
type Car = {
	model: Model,
	root: BasePart,
	offset: CFrame,
	lift: number,
	lane: Lane,
	s: number,
	speed: number,
	turn: Turn?,
	holding: Node?,
}

local Traffic = {}

local lanes: { Lane } = {}
local laneOut: { [Node]: { Lane } } = {}
local cars: { Car } = {}
local locks: { [Node]: { car: Car, at: number } } = {}
local folder: Folder

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ─── lanes ────────────────────────────────────────────────────────────────

local function offsetLine(points: { Vector3 }, offset: number): { Vector3 }
	local out = {}
	for i, p in points do
		local a = points[math.max(i - 1, 1)]
		local b = points[math.min(i + 1, #points)]
		local d = flat(b) - flat(a)
		local t = if d.Magnitude > 0 then d.Unit else Vector3.xAxis
		table.insert(out, p + Vector3.new(-t.Z, 0, t.X) * offset)
	end
	return out
end

local function cumulative(pts: { Vector3 }): ({ number }, number)
	local cum = { 0 }
	for i = 2, #pts do
		cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude
	end
	return cum, cum[#cum]
end

-- Point and direction at distance s along a lane.
local function at(l: Lane, s: number): (Vector3, Vector3)
	local pts, cum = l.pts, l.cum
	for i = 2, #pts do
		if s <= cum[i] or i == #pts then
			local seg = cum[i] - cum[i - 1]
			local t = if seg > 0 then math.clamp((s - cum[i - 1]) / seg, 0, 1) else 0
			local d = pts[i] - pts[i - 1]
			return pts[i - 1]:Lerp(pts[i], t), if d.Magnitude > 0 then d.Unit else Vector3.zAxis
		end
	end
	return pts[#pts], Vector3.zAxis
end

-- Cuts `trim0` off the start and `trim1` off the end of a polyline.
local function trimmed(pts: { Vector3 }, trim0: number, trim1: number): { Vector3 }
	local cum, total = cumulative(pts)
	local s0, s1 = math.min(trim0, total * 0.4), math.max(total - trim1, total * 0.6)
	local probe: Lane = { pts = pts, cum = cum } :: any
	local out = { (at(probe, s0)) }
	for i = 2, #pts - 1 do
		if cum[i] > s0 + 0.5 and cum[i] < s1 - 0.5 then
			table.insert(out, pts[i])
		end
	end
	table.insert(out, (at(probe, s1)))
	return out
end

local function trimFor(n: Node): number
	return if n.bulb then CityPlan.BULB_R * 0.6 else n.gap
end

local function buildLanes()
	for _, e in CityPlan.EDGES do
		local offset = if e.w >= 30 then e.w * 0.24 else 4.6
		local pair = {}
		for _, forward in { true, false } do
			local src = e.points
			if not forward then
				src = table.clone(src)
				local n = #src
				for i = 1, n // 2 do
					src[i], src[n - i + 1] = src[n - i + 1], src[i]
				end
			end
			local from, to = if forward then e.a else e.b, if forward then e.b else e.a
			local pts = trimmed(offsetLine(src, offset), trimFor(from), trimFor(to))
			local cum, length = cumulative(pts)
			local endDir = flat(pts[#pts] - pts[math.max(#pts - 1, 1)])
			local lane: Lane = {
				from = from,
				to = to,
				pts = pts,
				cum = cum,
				length = length,
				speed = SPEED[e.kind] or 26,
				reverse = nil,
				group = if math.abs(endDir.X) >= math.abs(endDir.Z) then "A" else "B",
			}
			table.insert(lanes, lane)
			laneOut[from] = laneOut[from] or {}
			table.insert(laneOut[from], lane)
			table.insert(pair, lane)
		end
		pair[1].reverse = pair[2]
		pair[2].reverse = pair[1]
	end
end

-- Which approach group has green right now (nil = all red / amber).
local function greenGroup(): string?
	local t = workspace:GetServerTimeNow()
	local phase = math.floor(t / PHASE) % 2
	if t % PHASE > PHASE - 3 then
		return nil
	end
	return if phase == 0 then "A" else "B"
end
Traffic.greenGroup = greenGroup

local function bezier(c: Turn, t: number): Vector3
	local u = 1 - t
	return c.p0 * (u * u * u) + c.p1 * (3 * u * u * t) + c.p2 * (3 * u * t * t) + c.p3 * (t * t * t)
end

local function planTurn(car: Car): boolean
	local node = car.lane.to
	local options = {}
	for _, l in laneOut[node] or {} do
		if l ~= car.lane.reverse and l.length > 6 then
			table.insert(options, l)
		end
	end
	if #options == 0 and car.lane.reverse then
		table.insert(options, car.lane.reverse) -- dead end: around the turning circle
	end
	if #options == 0 then
		return false
	end
	local nextLane = options[rng:NextInteger(1, #options)]
	local p0 = car.lane.pts[#car.lane.pts]
	local p3 = nextLane.pts[1]
	local _, d0 = at(car.lane, car.lane.length)
	local _, d3 = at(nextLane, 0)
	local k = math.max((p3 - p0).Magnitude * 0.45, if node.bulb then CityPlan.BULB_R else 0)
	local turn: Turn = {
		p0 = p0,
		p1 = p0 + d0 * k,
		p2 = p3 - d3 * k,
		p3 = p3,
		length = 0,
		t = 0,
		next = nextLane,
		node = node,
	}
	local last = p0
	for i = 1, 10 do
		local p = bezier(turn, i / 10)
		turn.length += (p - last).Magnitude
		last = p
	end
	turn.length = math.max(turn.length, 1)
	car.turn = turn
	return true
end

-- ─── cars ─────────────────────────────────────────────────────────────────

local function makeMovable(model: Model): (BasePart, CFrame, number)
	local root = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	model.PrimaryPart = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if d ~= root then
				d.Anchored = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	root.Anchored = true
	local cf, size = model:GetBoundingBox()
	local lift = model:GetPivot().Y - (cf.Y - size.Y / 2)
	return root, model:GetPivot():ToObjectSpace(root.CFrame), lift
end

local function playerPos(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function release(car: Car)
	local held = car.holding
	if held then
		local lock = locks[held]
		if lock and lock.car == car then
			locks[held] = nil
		end
		car.holding = nil
	end
end

-- Puts a car on a random lane near the player (but not right on top of them).
local function place(car: Car, around: Vector3)
	for _ = 1, 40 do
		local l = lanes[rng:NextInteger(1, #lanes)]
		local s = rng:NextNumber(0, l.length)
		local pos = at(l, s)
		local dist = (flat(pos) - flat(around)).Magnitude
		if l.length > 20 and dist < NEAR and dist > 70 then
			car.lane, car.s, car.turn, car.speed = l, s, nil, l.speed * 0.6
			return
		end
	end
	local l = lanes[rng:NextInteger(1, #lanes)]
	car.lane, car.s, car.turn, car.speed = l, 0, nil, 0
end

local function gapAhead(car: Car): number
	local best = math.huge
	for _, other in cars do
		if other ~= car and other.lane == car.lane and not other.turn and not car.turn then
			local d = other.s - car.s
			if d > 0 and d < best then
				best = d
			end
		end
	end
	return best
end

local function blockedByPlayer(pos: Vector3, fwd: Vector3): boolean
	local f = flat(fwd)
	if f.Magnitude < 0.01 then
		return false
	end
	f = f.Unit
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and math.abs(root.Position.Y - pos.Y) < 12 then
			local rel = flat(root.Position - pos)
			local ahead = rel:Dot(f)
			local side = math.abs(rel:Dot(Vector3.new(-f.Z, 0, f.X)))
			if ahead > 0 and ahead < 16 and side < 6 then
				return true
			end
		end
	end
	return false
end

local function step(car: Car, dt: number, now: number, green: string?)
	local pos: Vector3
	local fwd: Vector3
	local target = car.lane.speed
	local turn = car.turn
	if turn then
		turn.t = math.min(1, turn.t + car.speed * dt / turn.length)
		pos = bezier(turn, turn.t)
		local ahead = bezier(turn, math.min(1, turn.t + 0.05))
		fwd = if (ahead - pos).Magnitude > 0.01
			then (ahead - pos).Unit
			else select(2, at(turn.next, 0))
		target = math.min(target, 14)
		if turn.t >= 1 then
			car.lane, car.s, car.turn = turn.next, 0, nil
			release(car)
		end
	else
		local l = car.lane
		pos, fwd = at(l, car.s)
		local gap = gapAhead(car)
		if gap < FOLLOW_GAP then
			target = 0
		elseif gap < FOLLOW_GAP * 2.5 then
			target = math.min(target, l.speed * (gap - FOLLOW_GAP) / (FOLLOW_GAP * 1.5))
		end
		local toEnd = l.length - car.s
		if toEnd < 40 then
			-- Slow for the junction; at the stop line wait for the light or a gap.
			target = math.min(target, math.max(8, toEnd * 0.6))
			local node = l.to
			if node.signal and green ~= l.group and toEnd < 22 then
				target = math.min(target, math.max(0, (toEnd - 2) * 1.2))
			end
			if toEnd < 1.5 then
				local lock = locks[node]
				local redLight = node.signal and green ~= l.group
				local busy = lock ~= nil and lock.car ~= car and now - lock.at < LOCK_TIMEOUT
				if redLight or busy then
					target, car.speed = 0, 0
				elseif planTurn(car) then
					locks[node] = { car = car, at = now }
					car.holding = node
				else
					target = 0
				end
			end
		end
		car.s = math.min(l.length, car.s + car.speed * dt)
	end
	if blockedByPlayer(pos, fwd) then
		target = 0
	end
	if target > car.speed then
		car.speed = math.min(target, car.speed + ACCEL * dt)
	else
		car.speed = math.max(target, car.speed - BRAKE * dt)
	end
	local level = Vector3.new(fwd.X, fwd.Y, fwd.Z)
	local cf = CFrame.lookAt(pos, pos + level) + Vector3.new(0, CityPlan.SURFACE + car.lift, 0)
	car.root.CFrame = cf * car.offset
end

local function spawnCars(templates: { Model }, police: Model?)
	local around = playerPos() or CityPlan.HIDEOUT
	for i = 1, CAR_COUNT do
		local source = if police and i <= 3
			then police
			else templates[rng:NextInteger(1, #templates)]
		local model = source:Clone()
		local root, offset, lift = makeMovable(model)
		local car: Car = {
			model = model,
			root = root,
			offset = offset,
			lift = lift,
			lane = lanes[1],
			s = 0,
			speed = 0,
			turn = nil,
			holding = nil,
		}
		place(car, around)
		model.Parent = folder
		table.insert(cars, car)
	end
end

function Traffic.init()
	folder = Instance.new("Folder")
	folder.Name = "Traffic"
	folder.Parent = workspace
	buildLanes()
end

function Traffic.start()
	task.spawn(function()
		local templateFolder = ReplicatedStorage:WaitForChild("VehicleTemplates", 60)
		if not templateFolder then
			return
		end
		-- The server fills the folder after loading the car asset; wait for it.
		local templates = {}
		for _ = 1, 60 do
			table.clear(templates)
			for _, t in templateFolder:GetChildren() do
				if t:IsA("Model") and t.Name ~= "PoliceCar" then
					table.insert(templates, t)
				end
			end
			if #templates > 0 then
				break
			end
			task.wait(1)
		end
		if #templates == 0 or #lanes == 0 then
			warn("[Traffic] no car templates or lanes; traffic disabled")
			return
		end
		local police = templateFolder:FindFirstChild("PoliceCar")
		spawnCars(templates, if police and police:IsA("Model") then police else nil)
		local recycle = 0
		RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			local green = greenGroup()
			dt = math.min(dt, 0.1)
			for _, car in cars do
				step(car, dt, now, green)
			end
			recycle += dt
			if recycle > 1 then
				recycle = 0
				local around = playerPos()
				if around then
					for _, car in cars do
						if (flat(car.root.Position) - flat(around)).Magnitude > FAR then
							release(car)
							place(car, around)
						end
					end
				end
			end
		end)
	end)
end

return Traffic
