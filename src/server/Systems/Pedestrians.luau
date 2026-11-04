--!strict
-- Townspeople, so the streets never feel empty. Most of them walk: along a
-- sidewalk, then on to the next block, sometimes crossing at the corner (at
-- a signal they wait for the walk phase). Some hang out: waiting at a bus
-- stop, queueing at a food cart, sitting on a plaza bench. Street vendors
-- (hot dog, taco and halal carts and the like) mind their stalls, often
-- with a customer or two. Walkers are busier where the city is denser, and
-- a walker far from every player moves to a street near one, so wherever
-- players are the town feels alive. Any of them will barter (see
-- Barter.luau); a walker stops while an offer is open.
--
-- People react to the city: they run from wanted players, police chases and
-- cars tearing past, get knocked down by cars (Wanted.luau decides when),
-- turn to look at a player who comes close, and vendors call out to passers-by.
-- At night about two walkers in five go home; they come back in the morning.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CityPlan = require(game:GetService("ReplicatedStorage").Shared.CityPlan)
local Npc = require(script.Parent.Parent.Npc)

local WALKERS = 84
local LOITERERS = 30
local CUSTOMERS = 26 -- spread over the vendor stalls
local NEAR_PLAYER = 650 -- a walker this close to a player stays where it is
local MOVE_MIN, MOVE_MAX = 140, 420 -- a moved walker lands this far from a player
local NAMES = {
	"Dave",
	"Linda",
	"Marcus",
	"Priya",
	"Tony",
	"Beth",
	"Carlos",
	"Mei",
	"Gus",
	"Nora",
	"Ray",
	"Tasha",
	"Hal",
	"June",
	"Omar",
	"Rita",
	"Sam",
	"Ivy",
	"Walt",
	"Dot",
	"Yuki",
	"Dex",
	"Rin",
	"Jax",
}
-- How likely a walker is to start in each district (density).
local DENSITY = {
	downtown = 5,
	midtown = 3,
	beach = 3,
	southside = 4, -- the Hideout's district: the first streets players see
	eastgate = 2,
	oldport = 2,
	industrial = 0.6,
	docks = 0.6,
	hills = 0.5,
}

local Pedestrians = {}

local rng = Random.new()

local REACT_TICK = 0.3
local FLEE_SECONDS = 4.5
local FLEE_SPEED = 15
local SHOUTS = {
	flee = { "Whoa!", "Watch it!", "Help!", "Are you crazy?!", "Run!" },
	hit = { "OW! My back!", "Hey! I'm walking here!", "Somebody get his plate!", "Ugh..." },
	greet = { "Hey.", "Nice day, huh?", "You lost?", "Mornin'.", "...", "Sup." },
}
local CALLOUTS = {
	hotdog = { "Hot dogs! Get 'em while they're hot!", "Two for five, today only!" },
	tacos = { "Tacos! Best in the city!", "Al pastor, fresh off the grill!" },
	halal = { "Chicken over rice! White sauce, hot sauce!", "Halal food, come get it!" },
	pretzel = { "Pretzels! Warm and salty!", "Soft pretzels here!" },
	coffee = { "Coffee! Wake up, city!", "Espresso, two bucks!" },
	news = { "Read all about it!", "Daily paper, get your paper!" },
	icecream = { "Ice cream! Beat the heat!", "Two scoops, one price!" },
	noodles = { "Hot noodles, open all night!", "Ramen! Neon special!" },
}

type Person = {
	npc: any,
	kind: string, -- "walker" | "local" | "vendor" | "customer"
	label: string?, -- vendor stall kind
	walkSpeed: number,
	nextTalk: number,
	fleeing: boolean,
}
local people: { [Instance]: Person } = {}
local offDuty: Folder -- walkers at home for the night (ServerStorage)

local function register(npc: any, kind: string, label: string?)
	people[npc.model] = {
		npc = npc,
		kind = kind,
		label = label,
		walkSpeed = npc.humanoid.WalkSpeed,
		nextTalk = os.clock() + rng:NextNumber(3, 20),
		fleeing = false,
	}
	npc.model.Destroying:Connect(function()
		people[npc.model] = nil
	end)
end

local function shout(list: { string }): string
	return list[rng:NextInteger(1, #list)]
end

-- Sidewalks weighted by district density.
local weighted: { { path: { Vector3 }, w: number } } = {}
local totalWeight = 0
for _, path in CityPlan.SIDEWALKS do
	local d = CityPlan.district(path[math.ceil(#path / 2)])
	local w = if d then DENSITY[d.id] or 1 else 0
	if w > 0 then
		table.insert(weighted, { path = path, w = w })
		totalWeight += w
	end
end

local function pickSidewalk(): { Vector3 }
	local roll = rng:NextNumber() * totalWeight
	for _, entry in weighted do
		roll -= entry.w
		if roll <= 0 then
			return entry.path
		end
	end
	return weighted[1].path
end

-- The sidewalk that starts nearest a point (for walking on after a block).
local function sidewalkNear(pos: Vector3, exclude: { Vector3 }): { Vector3 }?
	local best, bestD = nil, 60
	for _, entry in weighted do
		local path = entry.path
		if path ~= exclude then
			for _, endpoint in { path[1], path[#path] } do
				local d = (Vector3.new(endpoint.X, 0, endpoint.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
				if d < bestD then
					best, bestD = path, d
				end
			end
		end
	end
	return best
end

-- Sidewalks bucketed by the cell (CELL studs) of their middle point, for
-- finding streets near a player quickly.
local CELL = 200
local cells: { [string]: { { Vector3 } } } = {}
for _, entry in weighted do
	local mid = entry.path[math.ceil(#entry.path / 2)]
	local key = math.floor(mid.X / CELL) .. "," .. math.floor(mid.Z / CELL)
	cells[key] = cells[key] or {}
	table.insert(cells[key], entry.path)
end

local function playerRoots(): { Vector3 }
	local list = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function flatDir(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.xAxis
end

-- A sidewalk near a player (but out of sight distance), for a walker who
-- has wandered far from everyone. nil while nobody is far away from it.
local function sidewalkNearPlayers(pos: Vector3): ({ Vector3 }?, number)
	local roots = playerRoots()
	if #roots == 0 then
		return nil, 0
	end
	for _, r in roots do
		if flatDist(r, pos) < NEAR_PLAYER then
			return nil, 0
		end
	end
	local target = roots[rng:NextInteger(1, #roots)]
	local candidates = {}
	local cx, cz = math.floor(target.X / CELL), math.floor(target.Z / CELL)
	local reach = math.ceil(MOVE_MAX / CELL)
	for gx = cx - reach, cx + reach do
		for gz = cz - reach, cz + reach do
			for _, path in cells[gx .. "," .. gz] or {} do
				table.insert(candidates, path)
			end
		end
	end
	if #candidates == 0 then
		return nil, 0
	end
	for _ = 1, 20 do
		local path = candidates[rng:NextInteger(1, #candidates)]
		local i = rng:NextInteger(1, #path)
		local d = flatDist(path[i], target)
		if d > MOVE_MIN and d < MOVE_MAX then
			local seen = false
			for _, r in roots do
				if flatDist(path[i], r) < MOVE_MIN then
					seen = true
				end
			end
			if not seen then
				return path, i
			end
		end
	end
	return nil, 0
end

-- At a signalled corner, wait until the traffic beside the walker has green
-- with time left to cross (cars follow the same CityPlan clock).
local function waitToCross(npc: any, from: Vector3, to: Vector3)
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if dir.Magnitude < 14 then
		return -- same corner, no street to cross
	end
	local node = CityPlan.nearestNode(from)
	if not node.signal or flatDist(node.pos, from) > node.gap + 30 then
		return
	end
	local group = CityPlan.crossingGroup(node, dir)
	local deadline = os.clock() + 45
	npc:stop()
	while npc.model.Parent and os.clock() < deadline do
		local state, left = CityPlan.signalState(group, workspace:GetServerTimeNow())
		if state == "green" and left > 5 then
			return
		end
		task.wait(0.5)
	end
end

local function setupTrader(npc: any)
	local name = NAMES[rng:NextInteger(1, #NAMES)]
	npc.model:SetAttribute("DisplayName", name)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = npc.root
	CollectionService:AddTag(npc.model, "Trader")
end

local function walkTo(npc: any, goal: Vector3, busy: () -> boolean)
	local deadline = os.clock() + 60
	while npc.model.Parent and os.clock() < deadline do
		local pos = npc.root.Position
		if Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude < 3 then
			return
		end
		while busy() do
			npc:stop()
			task.wait(0.5)
		end
		-- Running away or knocked down: the reaction loop has the body.
		while
			(tonumber(npc.model:GetAttribute("FleeUntil")) or 0) > os.clock()
			or npc.humanoid.PlatformStand
		do
			task.wait(0.3)
		end
		npc:moveToward(goal, os.clock())
		task.wait(0.35)
	end
end

local function walker(index: number, folder: Instance)
	local path = pickSidewalk()
	local i = rng:NextInteger(1, #path)
	local npc = Npc.new(
		"civilian",
		"Pedestrian" .. index,
		CFrame.new(path[i] + Vector3.new(0, 3, 0)),
		folder,
		rng
	)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = rng:NextNumber(5.5, 8.5)
	setupTrader(npc)
	register(npc, "walker")
	local nightOwl = index % 5 >= 2 -- the rest go home at night
	local function busy(): boolean
		return (tonumber(npc.model:GetAttribute("BusyUntil")) or 0) > os.clock()
	end
	local dir = if rng:NextNumber() < 0.5 then 1 else -1
	-- Nobody around to see this one: move it to a street near a player.
	local function relocate(): boolean
		if busy() then
			return false
		end
		local near, at = sidewalkNearPlayers(npc.root.Position)
		if not near then
			return false
		end
		path, i = near, at
		dir = if rng:NextNumber() < 0.5 then 1 else -1
		npc:stop()
		npc.model:PivotTo(CFrame.new(path[i] + Vector3.new(0, 3, 0)))
		return true
	end
	local steps = 0
	while npc.model.Parent do
		-- Walk to the end of this block, a few points at a time.
		local last = if dir > 0 then #path else 1
		local moved = false
		while i ~= last and npc.model.Parent do
			i = math.clamp(i + dir * 2, 1, #path)
			walkTo(npc, path[i], busy)
			if rng:NextNumber() < 0.04 then
				npc:stop()
				task.wait(rng:NextNumber(2, 6)) -- window shopping, checking a phone
			end
			steps += 1
			if steps % 3 == 0 and relocate() then
				moved = true
				break
			end
		end
		if moved then
			continue
		end
		-- Home for the night; back out in the morning near whoever is about.
		if not nightOwl and workspace:GetAttribute("Night") == true and not busy() then
			npc:stop()
			npc.model.Parent = offDuty
			while workspace:GetAttribute("Night") == true do
				workspace:GetAttributeChangedSignal("Night"):Wait()
			end
			task.wait(rng:NextNumber(0, 20))
			npc.model.Parent = folder
			if not relocate() then
				npc.model:PivotTo(CFrame.new(path[i] + Vector3.new(0, 3, 0)))
			end
			continue
		end
		-- At the corner: cross to the next block, or turn back.
		local nextPath = sidewalkNear(path[last], path)
		if nextPath and rng:NextNumber() < 0.85 then
			local startEnd = (Vector3.new(nextPath[1].X, 0, nextPath[1].Z) - Vector3.new(
				path[last].X,
				0,
				path[last].Z
			)).Magnitude
			local finishEnd = (
				Vector3.new(nextPath[#nextPath].X, 0, nextPath[#nextPath].Z)
				- Vector3.new(path[last].X, 0, path[last].Z)
			).Magnitude
			local corner = path[last]
			path = nextPath
			if startEnd <= finishEnd then
				i, dir = 1, 1
			else
				i, dir = #path, -1
			end
			waitToCross(npc, corner, path[i])
			walkTo(npc, path[i], busy)
		else
			dir = -dir
		end
	end
end

-- Stands or sits around a hangout spot, shifting about now and then.
local function loiterer(index: number, folder: Instance, spot: CityPlan.Hangout)
	-- On a bench: sit on the seat itself (left or right half); elsewhere mill about.
	local base = if spot.kind == "bench"
		then spot.cf * CFrame.new(if rng:NextNumber() < 0.5 then -1.5 else 1.5, 2.9, -0.1)
		else spot.cf * CFrame.new(
			rng:NextNumber(-4, 4),
			3.2 + CityPlan.SURFACE,
			rng:NextNumber(-1, 3)
		)
	local npc = Npc.new("civilian", "Local" .. index, base, folder, rng)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = 5
	setupTrader(npc)
	register(npc, "local")
	if spot.kind == "bench" then
		npc.humanoid.Sit = true
	end
	while npc.model.Parent do
		task.wait(rng:NextNumber(6, 18))
		if
			spot.kind ~= "bench"
			and (tonumber(npc.model:GetAttribute("BusyUntil")) or 0) < os.clock()
			and (tonumber(npc.model:GetAttribute("FleeUntil")) or 0) < os.clock()
		then
			local goal = (spot.cf * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-2, 4))).Position
			npc:moveToward(goal, os.clock())
			task.wait(2)
			npc:stop()
			npc:face(-spot.cf.LookVector)
		end
	end
end

-- A vendor minds the stall from its +X end, facing the sidewalk.
local function vendor(index: number, folder: Instance, spot: CityPlan.Hangout)
	local cf = spot.cf * CFrame.new(4.6, 3.2 + CityPlan.SURFACE, 1.6) * CFrame.Angles(0, math.pi, 0)
	local npc = Npc.new("civilian", "Vendor" .. index, cf, folder, rng)
	if not npc then
		return
	end
	npc.root.Anchored = true
	setupTrader(npc)
	register(npc, "vendor", spot.label)
	local prompt = npc.root:FindFirstChild("TradePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ObjectText =
			`{npc.model:GetAttribute("DisplayName")} ({CityPlan.VENDOR_NAMES[spot.label or ""] or "Vendor"})`
	end
end

-- A customer stands at the stall on the sidewalk's shop side, facing it,
-- shifting about now and then.
local function customer(index: number, folder: Instance, spot: CityPlan.Hangout)
	local x = rng:NextNumber(-2.5, 2.5)
	local base = spot.cf * CFrame.new(x, 3.2 + CityPlan.SURFACE, 7.6)
	local npc = Npc.new("civilian", "Customer" .. index, base, folder, rng)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = 4
	setupTrader(npc)
	register(npc, "customer")
	while npc.model.Parent do
		task.wait(rng:NextNumber(8, 20))
		if
			(tonumber(npc.model:GetAttribute("BusyUntil")) or 0) < os.clock()
			and (tonumber(npc.model:GetAttribute("FleeUntil")) or 0) < os.clock()
		then
			local goal = (spot.cf * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(7, 8.5))).Position
			npc:moveToward(goal, os.clock())
			task.wait(1.5)
			npc:stop()
			npc:face(spot.cf.LookVector) -- toward the stall and the street
		end
	end
end

-- Runs from `from` for a few seconds, then gets back to its business.
local function flee(person: Person, from: Vector3, line: string?)
	local npc = person.npc
	if npc.root.Anchored or npc.humanoid.PlatformStand or npc.model.Parent == offDuty then
		return
	end
	local away = flatDir(npc.root.Position - from)
	npc.model:SetAttribute("FleeUntil", os.clock() + FLEE_SECONDS)
	npc.humanoid.WalkSpeed = FLEE_SPEED
	npc.humanoid.Sit = false
	npc:moveToward(npc.root.Position + away * 40, os.clock())
	if line then
		npc:say(line, 2)
	end
	if not person.fleeing then
		person.fleeing = true
		task.delay(FLEE_SECONDS, function()
			person.fleeing = false
			if npc.model.Parent then
				npc.humanoid.WalkSpeed = person.walkSpeed
				npc:stop()
			end
		end)
	end
end

-- Everyone within `radius` of `at` runs; one of them shouts `line`.
function Pedestrians.panic(at: Vector3, radius: number, line: string?)
	local shouted = false
	for _, person in people do
		local root = person.npc.root
		if flatDist(root.Position, at) < radius then
			if person.kind == "vendor" then
				if not shouted and line then
					person.npc:say(line, 2.5)
					shouted = true
				end
			else
				flee(person, at, if not shouted then line else nil)
				shouted = shouted or line ~= nil
			end
		end
	end
end

-- A car knocked this person down (called by Wanted.luau).
function Pedestrians.knock(model: Instance, push: Vector3)
	local person = people[model]
	if not person then
		return
	end
	person.npc:knock(push)
	person.npc:say(shout(SHOUTS.hit), 2.5)
end

-- Every REACT_TICK: run from danger, look at players who come close, and
-- vendors call out to passers-by.
local function react()
	local threats: { { pos: Vector3, radius: number } } = {}
	local onFoot: { Vector3 } = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			continue
		end
		local seat = humanoid.SeatPart
		local speed = if seat then seat.AssemblyLinearVelocity.Magnitude else 0
		if (tonumber(p:GetAttribute("Wanted")) or 0) > 0 or p:GetAttribute("Chased") == true then
			table.insert(threats, { pos = root.Position, radius = 28 })
		elseif seat and speed > 30 then
			table.insert(
				threats,
				{ pos = root.Position + seat.AssemblyLinearVelocity * 0.4, radius = 16 }
			)
		end
		if not seat then
			table.insert(onFoot, root.Position)
		end
	end
	-- Officers sprinting through clear the sidewalk too.
	local town = workspace:FindFirstChild("Town")
	local police = town and town:FindFirstChild("CityPolice")
	if police then
		for _, cop in police:GetChildren() do
			local root = cop:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				table.insert(threats, { pos = root.Position, radius = 10 })
			end
		end
	end
	local now = os.clock()
	for _, person in people do
		local npc = person.npc
		if npc.model.Parent == offDuty or npc.humanoid.PlatformStand then
			continue
		end
		local pos = npc.root.Position
		if person.kind ~= "vendor" and not person.fleeing then
			for _, t in threats do
				if flatDist(pos, t.pos) < t.radius then
					flee(person, t.pos, if rng:NextNumber() < 0.35 then shout(SHOUTS.flee) else nil)
					break
				end
			end
		end
		if person.fleeing then
			continue
		end
		-- Someone on foot right next to them.
		local nearest: Vector3? = nil
		local nearestD = if person.kind == "vendor" then 22 else 9
		for _, w in onFoot do
			local d = flatDist(pos, w)
			if d < nearestD then
				nearest, nearestD = w, d
			end
		end
		local target = nearest
		if not target then
			continue
		end
		if person.kind == "vendor" then
			npc.root.CFrame = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
			if now >= person.nextTalk then
				person.nextTalk = now + rng:NextNumber(18, 35)
				local lines = CALLOUTS[person.label or ""] or CALLOUTS.hotdog
				npc:say(shout(lines), 3)
				if rng:NextNumber() < 0.5 then
					npc:play("wave")
				end
			end
		elseif person.kind ~= "walker" then
			npc:face(target - pos)
			if now >= person.nextTalk and rng:NextNumber() < 0.3 then
				person.nextTalk = now + rng:NextNumber(25, 60)
				npc:say(shout(SHOUTS.greet), 2)
			end
		end
	end
end

function Pedestrians.start()
	local town = workspace:WaitForChild("Town")
	local folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = town
	offDuty = Instance.new("Folder")
	offDuty.Name = "PedestriansOffDuty"
	offDuty.Parent = ServerStorage
	task.spawn(function()
		while true do
			task.wait(REACT_TICK)
			react()
		end
	end)
	if #weighted == 0 then
		return
	end
	for i = 1, WALKERS do
		task.delay(i * 0.25, walker, i, folder)
	end
	local spots, stalls = {}, {}
	for _, spot in CityPlan.HANGOUTS do
		table.insert(if spot.kind == "vendor" then stalls else spots, spot)
	end
	local t = WALKERS * 0.25
	for i = 1, math.min(LOITERERS, #spots) do
		local spot = spots[rng:NextInteger(1, #spots)]
		task.delay(t + i * 0.3, loiterer, i, folder, spot)
	end
	t += LOITERERS * 0.3
	-- Vendors nearest the Hideout first (CityPlan lists them that way).
	for i, spot in stalls do
		task.delay(t + i * 0.2, vendor, i, folder, spot)
	end
	t += #stalls * 0.2
	for i = 1, math.min(CUSTOMERS, #stalls) do
		-- The stalls nearest the Hideout get one each, the rest go at random.
		local spot = if i <= #stalls // 2 then stalls[i] else stalls[rng:NextInteger(1, #stalls)]
		task.delay(t + i * 0.3, customer, i, folder, spot)
	end
end

return Pedestrians
