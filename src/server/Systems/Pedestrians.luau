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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

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
	local base = spot.cf
		* CFrame.new(rng:NextNumber(-4, 4), 3.2 + CityPlan.SURFACE, rng:NextNumber(-1, 3))
	local npc = Npc.new("civilian", "Local" .. index, base, folder, rng)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = 5
	setupTrader(npc)
	if spot.kind == "bench" then
		npc.humanoid.Sit = true
	end
	while npc.model.Parent do
		task.wait(rng:NextNumber(6, 18))
		if
			spot.kind ~= "bench"
			and (tonumber(npc.model:GetAttribute("BusyUntil")) or 0) < os.clock()
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
	while npc.model.Parent do
		task.wait(rng:NextNumber(8, 20))
		if (tonumber(npc.model:GetAttribute("BusyUntil")) or 0) < os.clock() then
			local goal = (spot.cf * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(7, 8.5))).Position
			npc:moveToward(goal, os.clock())
			task.wait(1.5)
			npc:stop()
			npc:face(spot.cf.LookVector) -- toward the stall and the street
		end
	end
end

function Pedestrians.start()
	local town = workspace:WaitForChild("Town")
	local folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = town
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
