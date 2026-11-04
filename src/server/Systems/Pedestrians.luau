--!strict
-- Townspeople, so the streets never feel empty. Most of them walk: along a
-- sidewalk, then on to the next block, sometimes crossing at the corner.
-- Some hang out: waiting at a bus stop, queueing at a food cart, sitting on a
-- plaza bench. Each one is busier where the city is denser (more downtown,
-- fewer on the hills). Any of them will barter (see Barter.luau); a walker
-- stops while an offer is open.

local CollectionService = game:GetService("CollectionService")

local CityPlan = require(game:GetService("ReplicatedStorage").Shared.CityPlan)
local Npc = require(script.Parent.Parent.Npc)

local WALKERS = 64
local LOITERERS = 26
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
	southside = 2,
	eastgate = 1.5,
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
	while npc.model.Parent do
		-- Walk to the end of this block, a few points at a time.
		local last = if dir > 0 then #path else 1
		while i ~= last and npc.model.Parent do
			i = math.clamp(i + dir * 2, 1, #path)
			walkTo(npc, path[i], busy)
			if rng:NextNumber() < 0.04 then
				npc:stop()
				task.wait(rng:NextNumber(2, 6)) -- window shopping, checking a phone
			end
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
			path = nextPath
			if startEnd <= finishEnd then
				i, dir = 1, 1
			else
				i, dir = #path, -1
			end
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
	local spots = CityPlan.HANGOUTS
	for i = 1, math.min(LOITERERS, #spots) do
		local spot = spots[rng:NextInteger(1, #spots)]
		task.delay(WALKERS * 0.25 + i * 0.3, loiterer, i, folder, spot)
	end
end

return Pedestrians
