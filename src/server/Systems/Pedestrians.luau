--!strict
-- Townspeople walking the sidewalks so the streets never feel empty. Each one
-- strolls back and forth along a sidewalk line, stopping now and then (window
-- shopping, checking a phone). Each one will barter (see Barter.luau): the
-- walker stops while an offer is open.

local CollectionService = game:GetService("CollectionService")

local CityPlan = require(game:GetService("ReplicatedStorage").Shared.CityPlan)
local Npc = require(script.Parent.Parent.Npc)

local COUNT = 56
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
}
local WALK_Y = 0.7

-- Sidewalk lines: fixed axis value plus the range walkers may use.
-- Walk lines down the middle of every flat street's sidewalks, with height.
local LINES: { { axis: string, at: number, from: number, to: number, y: number } } = {}
for _, road in CityPlan.ROADS do
	if road.kind ~= "street" or road.y0 ~= road.y1 then
		continue
	end
	for _, side in { -1, 1 } do
		local probe = if road.axis == "X"
			then Vector3.new((road.from + road.to) / 2, 0, road.at + side * (road.w / 2 + 5))
			else Vector3.new(road.at + side * (road.w / 2 + 5), 0, (road.from + road.to) / 2)
		if CityPlan.onLand(probe) then
			table.insert(LINES, {
				axis = road.axis,
				at = road.at + side * (road.w / 2 + 5),
				from = road.from + 20,
				to = road.to - 20,
				y = road.y0,
			})
		end
	end
end

local Pedestrians = {}

local rng = Random.new()

local function pointOn(
	line: { axis: string, at: number, from: number, to: number, y: number },
	t: number
): Vector3
	local along = line.from + (line.to - line.from) * t
	if line.axis == "X" then
		return Vector3.new(along, line.y + WALK_Y, line.at)
	end
	return Vector3.new(line.at, line.y + WALK_Y, along)
end

local function walker(index: number, folder: Instance)
	-- The first lines are the busy hand-picked ones; the rest are random sidewalks.
	local line = LINES[rng:NextInteger(1, #LINES)]
	local start = pointOn(line, rng:NextNumber())
	local npc = Npc.new(
		"civilian",
		"Pedestrian" .. index,
		CFrame.new(start + Vector3.new(0, 3, 0)),
		folder,
		rng
	)
	if not npc then
		return
	end
	npc.humanoid.WalkSpeed = rng:NextNumber(5.5, 8)
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
	local function busy(): boolean
		return (tonumber(npc.model:GetAttribute("BusyUntil")) or 0) > os.clock()
	end
	while npc.model.Parent do
		local goal = pointOn(line, rng:NextNumber())
		local deadline = os.clock() + 120
		while npc.model.Parent and os.clock() < deadline do
			local pos = npc.root.Position
			if Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Magnitude < 3 then
				break
			end
			while busy() do
				npc:stop()
				task.wait(0.5)
			end
			npc:moveToward(goal, os.clock())
			task.wait(0.4)
		end
		npc:stop()
		task.wait(rng:NextNumber(1.5, 6))
	end
end

function Pedestrians.start()
	local town = workspace:WaitForChild("Town")
	local folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = town
	for i = 1, COUNT do
		task.delay(i * 0.3, walker, i, folder)
	end
end

return Pedestrians
