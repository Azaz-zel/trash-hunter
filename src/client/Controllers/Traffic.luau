--!strict
-- Client-side city traffic. Cars follow the road network from MapData: they
-- drive in the right-hand lane, pick a random turn at every intersection, take
-- turns entering an intersection, queue behind the car ahead and stop for
-- players in front of them. Purely visual (each client runs its own), so it
-- costs no network traffic; cars are kept near the local player and recycled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapData = require(Shared:WaitForChild("MapData"))

local player = Players.LocalPlayer
local rng = Random.new()

local ROAD_TOP = 0.2
local LANE = 8 -- lane centre, studs right of the road centre line
local STOP_GAP = MapData.ROAD_WIDTH / 2 + 3 -- stop line before an intersection
local CRUISE = 34
local ACCEL = 14
local BRAKE = 40
local FOLLOW_GAP = 17
local CAR_COUNT = 22
local NEAR = 380 -- spawn within this distance of the player
local FAR = 560 -- recycle beyond this
local LOCK_TIMEOUT = 8

type Node = { pos: Vector3, out: { Edge }, cross: boolean }
type Edge = {
	from: Node,
	to: Node,
	fwd: Vector3,
	right: Vector3,
	a: Vector3, -- lane start (after the previous stop line)
	b: Vector3, -- lane end (at the next stop line)
	length: number,
	reverse: Edge?,
}
type Car = {
	model: Model,
	root: BasePart,
	offset: CFrame, -- root CFrame relative to the model pivot
	lift: number,
	edge: Edge,
	s: number, -- distance along the edge lane
	speed: number,
	turn: {
		p0: Vector3,
		p1: Vector3,
		p2: Vector3,
		p3: Vector3,
		length: number,
		t: number,
		next: Edge,
		node: Node,
	}?,
	holding: Node?, -- intersection this car has reserved
}

local Traffic = {}

local nodes: { Node } = {}
local edges: { Edge } = {}
local cars: { Car } = {}
local locks: { [Node]: { car: Car, at: number } } = {}
local folder: Folder

-- ─── road graph ───────────────────────────────────────────────────────────

local function nodeAt(pos: Vector3, cross: boolean): Node
	for _, n in nodes do
		if (n.pos - pos).Magnitude < 2 then
			n.cross = n.cross or cross
			return n
		end
	end
	local n: Node = { pos = pos, out = {}, cross = cross }
	table.insert(nodes, n)
	return n
end

local function point(road: any, along: number): Vector3
	return if road.axis == "X"
		then Vector3.new(along, 0, road.at)
		else Vector3.new(road.at, 0, along)
end

local function buildGraph()
	for _, road in MapData.ROADS do
		local stops = {}
		for _, other in MapData.ROADS do
			if
				other.axis ~= road.axis
				and other.at >= road.from - 1
				and other.at <= road.to + 1
				and road.at >= other.from - 1
				and road.at <= other.to + 1
			then
				table.insert(stops, { at = other.at, cross = true })
			end
		end
		table.sort(stops, function(a, b)
			return a.at < b.at
		end)
		-- Road ends become dead-end nodes unless an intersection is right there.
		if #stops == 0 or stops[1].at - road.from > 40 then
			table.insert(stops, 1, { at = road.from, cross = false })
		end
		if #stops == 0 or road.to - stops[#stops].at > 40 then
			table.insert(stops, { at = road.to, cross = false })
		end
		for i = 1, #stops - 1 do
			local n1 = nodeAt(point(road, stops[i].at), stops[i].cross)
			local n2 = nodeAt(point(road, stops[i + 1].at), stops[i + 1].cross)
			local pair = {}
			for _, dir in { { n1, n2 }, { n2, n1 } } do
				local from, to = dir[1], dir[2]
				local fwd = (to.pos - from.pos).Unit
				local right = Vector3.new(-fwd.Z, 0, fwd.X)
				local a = from.pos + fwd * (if from.cross then STOP_GAP else 0) + right * LANE
				local b = to.pos - fwd * (if to.cross then STOP_GAP else 0) + right * LANE
				local e: Edge = {
					from = from,
					to = to,
					fwd = fwd,
					right = right,
					a = a,
					b = b,
					length = math.max((b - a):Dot(fwd), 1),
					reverse = nil,
				}
				table.insert(edges, e)
				table.insert(from.out, e)
				table.insert(pair, e)
			end
			pair[1].reverse = pair[2]
			pair[2].reverse = pair[1]
		end
	end
end

local function bezier(c: any, t: number): Vector3
	local u = 1 - t
	return c.p0 * (u * u * u) + c.p1 * (3 * u * u * t) + c.p2 * (3 * u * t * t) + c.p3 * (t * t * t)
end

local function planTurn(car: Car): boolean
	local node = car.edge.to
	local options = {}
	for _, e in node.out do
		if e ~= car.edge.reverse and e.length > 6 then
			table.insert(options, e)
		end
	end
	if #options == 0 and car.edge.reverse then
		table.insert(options, car.edge.reverse) -- dead end: U-turn
	end
	if #options == 0 then
		return false
	end
	local nextEdge = options[rng:NextInteger(1, #options)]
	local p0, p3 = car.edge.b, nextEdge.a
	local k = (p3 - p0).Magnitude * 0.45
	local turn = {
		p0 = p0,
		p1 = p0 + car.edge.fwd * k,
		p2 = p3 - nextEdge.fwd * k,
		p3 = p3,
		length = 0,
		t = 0,
		next = nextEdge,
		node = node,
	}
	local last = p0
	for i = 1, 8 do
		local p = bezier(turn, i / 8)
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

-- Puts a car on a random lane near the player (but not right on top of them).
local function place(car: Car, around: Vector3)
	for _ = 1, 30 do
		local e = edges[rng:NextInteger(1, #edges)]
		local s = rng:NextNumber(0, e.length)
		local pos = e.a + e.fwd * s
		local dist = (pos - around).Magnitude
		if e.length > 20 and dist < NEAR and dist > 70 then
			car.edge, car.s, car.turn, car.speed = e, s, nil, CRUISE * 0.6
			return
		end
	end
	local e = edges[rng:NextInteger(1, #edges)]
	car.edge, car.s, car.turn, car.speed = e, 0, nil, 0
end

local function release(car: Car)
	if car.holding then
		local lock = locks[car.holding]
		if lock and lock.car == car then
			locks[car.holding] = nil
		end
		car.holding = nil
	end
end

-- Distance to the nearest car ahead in the same lane (or math.huge).
local function gapAhead(car: Car): number
	local best = math.huge
	for _, other in cars do
		if other ~= car and other.edge == car.edge and not other.turn and not car.turn then
			local d = other.s - car.s
			if d > 0 and d < best then
				best = d
			end
		end
	end
	return best
end

local function blockedByPlayer(pos: Vector3, fwd: Vector3): boolean
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local rel = root.Position - pos
			local ahead = rel:Dot(fwd)
			local side = math.abs(rel:Dot(Vector3.new(-fwd.Z, 0, fwd.X)))
			if ahead > 0 and ahead < 16 and side < 6 then
				return true
			end
		end
	end
	return false
end

local function step(car: Car, dt: number, now: number)
	local pos: Vector3
	local fwd: Vector3
	local target = CRUISE
	if car.turn then
		local turn = car.turn
		turn.t = math.min(1, turn.t + car.speed * dt / turn.length)
		pos = bezier(turn, turn.t)
		local ahead = bezier(turn, math.min(1, turn.t + 0.05))
		fwd = if (ahead - pos).Magnitude > 0.01 then (ahead - pos).Unit else turn.next.fwd
		target = CRUISE * 0.5
		if turn.t >= 1 then
			car.edge, car.s, car.turn = turn.next, 0, nil
			release(car)
		end
	else
		local e = car.edge
		pos = e.a + e.fwd * car.s
		fwd = e.fwd
		local gap = gapAhead(car)
		if gap < FOLLOW_GAP then
			target = 0
		elseif gap < FOLLOW_GAP * 2.5 then
			target = math.min(target, CRUISE * (gap - FOLLOW_GAP) / (FOLLOW_GAP * 1.5))
		end
		local toEnd = e.length - car.s
		if toEnd < 30 then
			-- Slow for the corner; at the stop line wait for the intersection.
			target = math.min(target, math.max(10, toEnd))
			if toEnd < 1.5 then
				local lock = locks[e.to]
				if lock and lock.car ~= car and now - lock.at < LOCK_TIMEOUT then
					target = 0
					car.speed = 0
				elseif planTurn(car) then
					locks[e.to] = { car = car, at = now }
					car.holding = e.to
				else
					target = 0
				end
			end
		end
		car.s = math.min(e.length, car.s + car.speed * dt)
	end
	if blockedByPlayer(pos, fwd) then
		target = 0
	end
	if target > car.speed then
		car.speed = math.min(target, car.speed + ACCEL * dt)
	else
		car.speed = math.max(target, car.speed - BRAKE * dt)
	end
	local cf = CFrame.lookAt(pos, pos + fwd) + Vector3.new(0, ROAD_TOP + car.lift, 0)
	car.root.CFrame = cf * car.offset
end

local function spawnCars(templates: { Model }, police: Model?)
	local around = playerPos() or Vector3.zero
	for i = 1, CAR_COUNT do
		-- A couple of patrol cruisers roam with the traffic.
		local source = if police and i <= 2
			then police
			else templates[rng:NextInteger(1, #templates)]
		local model = source:Clone()
		local root, offset, lift = makeMovable(model)
		local car: Car = {
			model = model,
			root = root,
			offset = offset,
			lift = lift,
			edge = edges[1],
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
	buildGraph()
end

function Traffic.start()
	task.spawn(function()
		local templateFolder = ReplicatedStorage:WaitForChild("VehicleTemplates", 60)
		if not templateFolder then
			return
		end
		local templates = {}
		for _, t in templateFolder:GetChildren() do
			if t:IsA("Model") and t.Name ~= "PoliceCar" then
				table.insert(templates, t)
			end
		end
		if #templates == 0 or #edges == 0 then
			return
		end
		local police = templateFolder:FindFirstChild("PoliceCar")
		spawnCars(templates, if police and police:IsA("Model") then police else nil)
		local recycle = 0
		RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			dt = math.min(dt, 0.1)
			for _, car in cars do
				step(car, dt, now)
			end
			-- Every second, move far-away cars back near the player.
			recycle += dt
			if recycle > 1 then
				recycle = 0
				local around = playerPos()
				if around then
					for _, car in cars do
						if (car.root.Position - around).Magnitude > FAR then
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
