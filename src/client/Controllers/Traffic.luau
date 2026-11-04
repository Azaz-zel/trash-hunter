--!strict
-- Client-side city traffic on CityPlan's road graph. Cars drive in the
-- right-hand lane along each street's curve, at that road's speed limit
-- (slow in cul-de-sacs, fast on the freeway), and follow the rules:
-- - Traffic lights (CityPlan.signalState, one clock for the whole city):
--   go on green, stop on red, and on amber stop unless too close to stop
--   comfortably. This controller also lights the signal lamps.
-- - Stop signs: a full stop at the line, then first come, first served.
-- - Never enter a junction while crossing traffic is in it, or when there is
--   no room on the street beyond (no blocking the box).
-- - Keep a gap to the car ahead, and stop for people (players and
--   townspeople) in front of them, crosswalks included.
-- Dead ends become U-turns around the turning circle. Purely visual: each
-- client runs its own, near its player, so it costs no network traffic.

local CollectionService = game:GetService("CollectionService")

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
local COMFORT_BRAKE = 16 -- deceleration a driver accepts to stop for an amber light
local FOLLOW_GAP = 17
local CAR_COUNT = 44
local NEAR = 420 -- spawn within this distance of the player
local FAR = 620 -- recycle beyond this
local LOCK_TIMEOUT = 8 -- a junction claim older than this is stale
local STOP_WAIT = 0.9 -- seconds stopped at a stop sign before going
local PEOPLE_REFRESH = 0.2

type Node = CityPlan.Node
type Lane = {
	from: Node,
	to: Node,
	pts: { Vector3 }, -- lane centre line (road base height)
	cum: { number }, -- distance along the lane at each point
	length: number,
	speed: number,
	reverse: Lane?,
	group: string, -- signal phase group of its approach ("A" or "B")
	stop: boolean, -- stop sign at its end
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
	plan: Lane?, -- the lane it will take at the coming junction
	committed: boolean, -- caught by an amber light too close to stop: clears the junction
	waited: number, -- seconds stopped at the stop line
	cruise: number, -- share of the speed limit this driver keeps (0.85 to 1)
}

local Traffic = {}

local lanes: { Lane } = {}
local laneOut: { [Node]: { Lane } } = {}
local cars: { Car } = {}
-- Cars inside each junction: their phase group and when they entered.
local inside: { [Node]: { [Car]: { group: string, at: number } } } = {}
local people: { Vector3 } = {}
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
			local lane: Lane = {
				from = from,
				to = to,
				pts = pts,
				cum = cum,
				length = length,
				speed = SPEED[e.kind] or 26,
				reverse = nil,
				group = CityPlan.signalGroup(to, e),
				stop = not to.signal and not to.bulb and #to.edges >= 3,
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

-- ─── signal lamps ────────────────────────────────────────────────────────

local LAMP_ON = {
	Red = Color3.fromRGB(255, 50, 40),
	Yellow = Color3.fromRGB(255, 190, 40),
	Green = Color3.fromRGB(60, 230, 110),
}
local LAMP_OFF = Color3.fromRGB(28, 28, 30)
local LAMP_FOR = { green = "Green", amber = "Yellow", red = "Red" }
local lampState: { [string]: string } = {}

local function paintSignal(signal: Instance)
	local group = signal:GetAttribute("Group")
	local lit = LAMP_FOR[lampState[if group == "B" then "B" else "A"] or "red"]
	for name, color in LAMP_ON do
		local bulb = signal:FindFirstChild(name)
		if bulb and bulb:IsA("BasePart") then
			local on = name == lit
			bulb.Color = if on then color else LAMP_OFF
			bulb.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- Repaints every signal head when a phase group changes state.
local function updateLamps()
	local t = workspace:GetServerTimeNow()
	local changed = false
	for _, group in { "A", "B" } do
		local state = CityPlan.signalState(group, t)
		if lampState[group] ~= state then
			lampState[group] = state
			changed = true
		end
	end
	if changed then
		for _, signal in CollectionService:GetTagged("TrafficSignal") do
			paintSignal(signal)
		end
	end
end

local function bezier(c: Turn, t: number): Vector3
	local u = 1 - t
	return c.p0 * (u * u * u) + c.p1 * (3 * u * u * t) + c.p2 * (3 * u * t * t) + c.p3 * (t * t * t)
end

-- Picks the way on at the coming junction (a U-turn only at dead ends).
local function chooseNext(lane: Lane): Lane?
	local options = {}
	for _, l in laneOut[lane.to] or {} do
		if l ~= lane.reverse and l.length > 6 then
			table.insert(options, l)
		end
	end
	if #options == 0 then
		return lane.reverse -- dead end: around the turning circle
	end
	return options[rng:NextInteger(1, #options)]
end

local function beginTurn(car: Car, nextLane: Lane)
	local node = car.lane.to
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
		local list = inside[held]
		if list then
			list[car] = nil
		end
		car.holding = nil
	end
end

-- May `car` (arriving in phase `group`) enter junction `node` now? At a
-- signal, not while cars of the crossing phase are still in it; at a stop
-- sign, one car at a time.
local function junctionClear(node: Node, car: Car, group: string, now: number): boolean
	local list = inside[node]
	if not list then
		return true
	end
	for other, entry in list do
		if now - entry.at > LOCK_TIMEOUT then
			list[other] = nil
		elseif other ~= car and (not node.signal or entry.group ~= group) then
			return false
		end
	end
	return true
end

-- Is there room on `lane` beyond the junction (don't block the box)?
local function exitClear(car: Car, lane: Lane): boolean
	for _, other in cars do
		if other ~= car then
			if other.turn then
				if other.turn.next == lane then
					return false
				end
			elseif other.lane == lane and other.s < FOLLOW_GAP + 4 then
				return false
			end
		end
	end
	return true
end

-- Puts a car on a random lane near the player (but not right on top of them).
local function place(car: Car, around: Vector3)
	for _ = 1, 40 do
		local l = lanes[rng:NextInteger(1, #lanes)]
		local s = rng:NextNumber(0, l.length)
		local pos = at(l, s)
		local dist = (flat(pos) - flat(around)).Magnitude
		local free = l.length - s > 45 -- not right at a junction
		for _, other in cars do
			if other ~= car and other.lane == l and math.abs(other.s - s) < FOLLOW_GAP * 1.5 then
				free = false
				break
			end
		end
		if free and l.length > 20 and dist < NEAR and dist > 70 then
			car.lane, car.s, car.turn, car.speed = l, s, nil, l.speed * 0.6
			car.plan, car.committed, car.waited = nil, false, 0
			return
		end
	end
	local l = lanes[rng:NextInteger(1, #lanes)]
	car.lane, car.s, car.turn, car.speed = l, 0, nil, 0
	car.plan, car.committed, car.waited = nil, false, 0
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

-- Positions of players and townspeople near this client's player.
local function refreshPeople()
	table.clear(people)
	local around = playerPos()
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(people, root.Position)
		end
	end
	local town = workspace:FindFirstChild("Town")
	local walkers = town and town:FindFirstChild("Pedestrians")
	if walkers and around then
		for _, npc in walkers:GetChildren() do
			local root = npc:FindFirstChild("HumanoidRootPart")
			if
				root
				and root:IsA("BasePart")
				and (flat(root.Position) - flat(around)).Magnitude < FAR
			then
				table.insert(people, root.Position)
			end
		end
	end
end

-- Someone standing or walking in the car's path (it looks further ahead
-- the faster it goes).
local function personAhead(pos: Vector3, fwd: Vector3, speed: number): boolean
	local f = flat(fwd)
	if f.Magnitude < 0.01 then
		return false
	end
	f = f.Unit
	local reach = 9 + speed * 0.45
	local right = Vector3.new(-f.Z, 0, f.X)
	for _, p in people do
		if math.abs(p.Y - pos.Y) < 12 then
			local rel = flat(p - pos)
			local ahead = rel:Dot(f)
			if ahead > 0 and ahead < reach and math.abs(rel:Dot(right)) < 5.5 then
				return true
			end
		end
	end
	return false
end

local function step(car: Car, dt: number, now: number, clock: number)
	local pos: Vector3
	local fwd: Vector3
	local target = car.lane.speed * car.cruise
	local turn = car.turn
	if turn then
		turn.t = math.min(1, turn.t + car.speed * dt / turn.length)
		pos = bezier(turn, turn.t)
		local ahead = bezier(turn, math.min(1, turn.t + 0.05))
		fwd = if (ahead - pos).Magnitude > 0.01
			then (ahead - pos).Unit
			else select(2, at(turn.next, 0))
		target = math.min(target, 14)
		-- Queue behind whoever is just past the junction.
		local left = (1 - turn.t) * turn.length
		for _, other in cars do
			if other ~= car and not other.turn and other.lane == turn.next then
				if left + other.s < FOLLOW_GAP then
					target = 0
				end
			end
		end
		if turn.t >= 1 then
			car.lane, car.s, car.turn = turn.next, 0, nil
			car.plan, car.committed, car.waited = nil, false, 0
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
		if toEnd < 45 then
			local node = l.to
			car.plan = car.plan or chooseNext(l)
			-- Slow for the junction.
			target = math.min(target, math.max(if node.bulb then 6 else 9, toEnd * 0.6))
			local allowed = true
			if node.signal then
				local state = CityPlan.signalState(l.group, clock)
				if state == "amber" and not car.committed then
					-- Too close to stop comfortably: carry on through.
					car.committed = car.speed * car.speed / (2 * COMFORT_BRAKE) > toEnd - 2
				end
				allowed = state == "green" or car.committed
				if not allowed then
					target = math.min(target, math.max(0, (toEnd - 2) * 1.2))
				end
			elseif l.stop then
				if toEnd < 2.5 and car.speed < 0.6 then
					car.waited += dt
				end
				allowed = car.waited >= STOP_WAIT
				if not allowed then
					target = math.min(target, math.max(0, (toEnd - 1.2) * 1.1))
				end
			end
			if toEnd < 1.5 then
				local nextLane = car.plan
				local busy = node.signal or l.stop
				if
					allowed
					and nextLane
					and (not busy or junctionClear(node, car, l.group, now))
					and exitClear(car, nextLane)
				then
					beginTurn(car, nextLane)
					if busy then
						inside[node] = inside[node] or {}
						inside[node][car] = { group = l.group, at = now }
						car.holding = node
					end
				else
					-- Wait at the line; a light that went red meanwhile holds it.
					target, car.speed, car.committed = 0, 0, false
				end
			end
		end
		car.s = math.min(l.length, car.s + car.speed * dt)
	end
	if personAhead(pos, fwd, car.speed) then
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
			plan = nil,
			committed = false,
			waited = 0,
			cruise = rng:NextNumber(0.85, 1),
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
	-- Signal lamps run even before the cars load.
	CollectionService:GetInstanceAddedSignal("TrafficSignal"):Connect(paintSignal)
	task.spawn(function()
		while true do
			updateLamps()
			task.wait(0.1)
		end
	end)
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
		local scan = 0
		RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			local clock = workspace:GetServerTimeNow()
			dt = math.min(dt, 0.1)
			scan += dt
			if scan > PEOPLE_REFRESH then
				scan = 0
				refreshPeople()
			end
			for _, car in cars do
				step(car, dt, now, clock)
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
