--!strict
-- Townspeople walking the sidewalks so the streets never feel empty. Each one
-- strolls back and forth along a sidewalk line, stopping now and then (window
-- shopping, checking a phone). Each one will barter (see Barter.luau): the
-- walker stops while an offer is open.

local CollectionService = game:GetService("CollectionService")

local Npc = require(script.Parent.Parent.Npc)

local COUNT = 26
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
local LINES = {
	{ axis = "X", at = 22, from = -380, to = 400 }, -- Main St, north side
	{ axis = "X", at = -22, from = -400, to = 400 }, -- Main St, south side
	{ axis = "X", at = -218, from = -600, to = 600 }, -- Maple Ave, north side
	{ axis = "X", at = -262, from = -600, to = 600 }, -- Maple Ave, south side
	{ axis = "Z", at = 285, from = -185, to = -65 }, -- park path
	{ axis = "X", at = -125, from = 185, to = 385 }, -- park path
	{ axis = "X", at = 22, from = 680, to = 1220 }, -- Business District, Main St
	{ axis = "X", at = -98, from = 680, to = 1220 }, -- Commerce Ave
	{ axis = "X", at = -98, from = -1220, to = -660 }, -- Elm St (Eastside)
	{ axis = "X", at = -618, from = -600, to = 600 }, -- Hillcrest Dr
	{ axis = "X", at = 22, from = 1940, to = 2260 }, -- Port Haven, Main St
	{ axis = "X", at = -22, from = 1940, to = 2260 }, -- Port Haven, Main St
	{ axis = "X", at = 160, from = 1980, to = 2220 }, -- Harbor Park path
}

local Pedestrians = {}

local rng = Random.new()

local function pointOn(
	line: { axis: string, at: number, from: number, to: number },
	t: number
): Vector3
	local along = line.from + (line.to - line.from) * t
	if line.axis == "X" then
		return Vector3.new(along, WALK_Y, line.at)
	end
	return Vector3.new(line.at, WALK_Y, along)
end

local function walker(index: number, folder: Instance)
	local line = LINES[(index - 1) % #LINES + 1]
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
