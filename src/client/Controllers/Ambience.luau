--!strict
-- Client-only life: raccoons hopping between dumpsters (and scattering when
-- someone walks up), cars on the two streets, swaying trees, day/night
-- ambience and chase music. All local and tween-driven: one anchored root per
-- moving thing, so the server pays nothing and the client pays one C-side tween.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Raccoon = require(Shared:WaitForChild("Raccoon"))

local player = Players.LocalPlayer
local rng = Random.new()

local RACCOON_COUNT = 4
local RACCOON_Y = 0.2
local SCARE_RADIUS = 9
local HOP_UP = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOP_DOWN = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FLEE_UP = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLEE_DOWN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local DIG = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true)

local CAR_SPEED = 24
local ROAD_END = 195
local LANES = {
	{ z = 43, dir = -1 },
	{ z = 49, dir = 1 },
	{ z = -39, dir = -1 },
	{ z = -33, dir = 1 },
}
local CAR_COLORS = {
	Color3.fromRGB(230, 70, 60),
	Color3.fromRGB(60, 140, 230),
	Color3.fromRGB(250, 200, 50),
}

local Ambience = {}

local folder: Folder

local function play(tween: Tween)
	tween:Play()
	tween.Completed:Wait()
end

local function threatNear(pos: Vector3): Vector3?
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
			if offset.Magnitude < SCARE_RADIUS then
				return if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(1, 0, 0)
			end
		end
	end
	return nil
end

-- One hop of at most `step` studs toward `target`. Returns true on arrival.
local function hop(
	root: BasePart,
	target: Vector3,
	step: number,
	up: TweenInfo,
	down: TweenInfo
): boolean
	local from = root.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 0.6 then
		return true
	end
	local dir = flat.Unit
	local to = from + dir * math.min(step, dist)
	local mid = from:Lerp(to, 0.5) + Vector3.new(0, 0.8, 0)
	local facing = CFrame.lookAt(Vector3.zero, dir).Rotation
	play(TweenService:Create(root, up, { CFrame = CFrame.new(mid) * facing }))
	play(TweenService:Create(root, down, { CFrame = CFrame.new(to) * facing }))
	return dist <= step
end

local function dumpsterSpots(): { Vector3 }
	local spots = {}
	local town = workspace:FindFirstChild("Town")
	local dumpsters = town and town:FindFirstChild("Dumpsters")
	if dumpsters then
		for _, d in dumpsters:GetChildren() do
			if d:IsA("Model") and d:GetAttribute("Zone") == "Green" then
				table.insert(spots, d:GetPivot().Position)
			end
		end
	end
	return spots
end

local function runRaccoon(model: Model)
	local root = model.PrimaryPart :: BasePart
	while model.Parent do
		local spots = dumpsterSpots()
		if #spots == 0 then
			task.wait(2)
			continue
		end
		local center = spots[rng:NextInteger(1, #spots)]
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(4.5, 7)
		local target = Vector3.new(
			center.X + math.cos(angle) * radius,
			RACCOON_Y,
			center.Z + math.sin(angle) * radius
		)

		local arrived = false
		while not arrived and model.Parent do
			local away = threatNear(root.Position)
			if away then
				local fleeTo = root.Position + away * 14
				for _ = 1, 6 do
					if hop(root, fleeTo, 2.4, FLEE_UP, FLEE_DOWN) then
						break
					end
				end
				break
			end
			arrived = hop(root, target, 2.2, HOP_UP, HOP_DOWN)
		end

		if arrived then
			-- Rummage: face the dumpster and nod into the trash a few times.
			local look = Vector3.new(center.X, RACCOON_Y, center.Z)
			root.CFrame = CFrame.lookAt(root.Position, look)
			for _ = 1, rng:NextInteger(2, 4) do
				play(
					TweenService:Create(
						root,
						DIG,
						{ CFrame = root.CFrame * CFrame.Angles(math.rad(-25), 0, 0) }
					)
				)
				task.wait(rng:NextNumber(0.2, 0.6))
			end
		end
		task.wait(rng:NextNumber(1, 4))
	end
end

local function weld(root: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function buildCar(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Car"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	local function piece(
		name: string,
		size: Vector3,
		offset: Vector3,
		c: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.CFrame = CFrame.new(offset)
		weld(root, p)
		p.Parent = model
		return p
	end
	-- Faces -Z.
	piece("Body", Vector3.new(4.4, 2, 9), Vector3.new(0, 1.9, 0), color)
	piece(
		"Cabin",
		Vector3.new(4, 1.8, 4.6),
		Vector3.new(0, 3.8, 0.6),
		Color3.fromRGB(170, 220, 250),
		Enum.Material.Glass
	)
	for _, x in { -1.6, 1.6 } do
		piece(
			"Headlight",
			Vector3.new(0.9, 0.6, 0.2),
			Vector3.new(x, 2.2, -4.55),
			Color3.fromRGB(255, 245, 200),
			Enum.Material.Neon
		)
		for _, z in { -2.8, 2.8 } do
			piece(
				"Wheel",
				Vector3.new(0.8, 1.8, 1.8),
				Vector3.new(x * 1.4, 0.9, z),
				Color3.fromRGB(30, 30, 36),
				nil,
				Enum.PartType.Cylinder
			)
		end
	end
	return model
end

local function runCar(model: Model, lane: { z: number, dir: number })
	local root = model.PrimaryPart :: BasePart
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(lane.dir, 0, 0)).Rotation
	local info = TweenInfo.new(ROAD_END * 2 / CAR_SPEED, Enum.EasingStyle.Linear)
	while model.Parent do
		root.CFrame = CFrame.new(-ROAD_END * lane.dir, 0.2, lane.z) * facing
		play(
			TweenService:Create(
				root,
				info,
				{ CFrame = CFrame.new(ROAD_END * lane.dir, 0.2, lane.z) * facing }
			)
		)
		task.wait(rng:NextNumber(3, 9))
	end
end

local function swayTrees(town: Instance)
	local decor = town:WaitForChild("Decor", 10)
	if not decor then
		return
	end
	for _, leaves in decor:GetChildren() do
		if leaves.Name == "Leaves" and leaves:IsA("BasePart") then
			local base = leaves.CFrame
			local info = TweenInfo.new(
				rng:NextNumber(2.4, 3.6),
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			TweenService:Create(leaves, info, {
				CFrame = base
					* CFrame.new(0, 0.25, 0)
					* CFrame.Angles(math.rad(3), 0, math.rad(rng:NextNumber(-3, 3))),
			}):Play()
		end
	end
end

local function loopSound(id: string): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return s
end

local function setupAudio()
	local day = loopSound(Config.Sounds.DAY_AMBIENCE)
	local night = loopSound(Config.Sounds.NIGHT_AMBIENCE)
	local chase = loopSound(Config.Sounds.CHASE_MUSIC)
	local FADE = TweenInfo.new(1.2)

	local function mix()
		local chased = player:GetAttribute("Chased") == true
		local isNight = workspace:GetAttribute("Night") == true
		TweenService:Create(chase, FADE, { Volume = if chased then 0.45 else 0 }):Play()
		TweenService:Create(day, FADE, { Volume = if chased or isNight then 0 else 0.3 }):Play()
		TweenService:Create(night, FADE, { Volume = if chased or not isNight then 0 else 0.3 })
			:Play()
	end
	player:GetAttributeChangedSignal("Chased"):Connect(mix)
	workspace:GetAttributeChangedSignal("Night"):Connect(mix)
	mix()
end

function Ambience.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientAmbience"
	folder.Parent = workspace
end

function Ambience.start()
	setupAudio()

	task.spawn(function()
		local town = workspace:WaitForChild("Town")
		swayTrees(town)

		for i = 1, RACCOON_COUNT do
			local raccoon = Raccoon.build(0.9, true)
			raccoon:PivotTo(CFrame.new(rng:NextNumber(-60, 60), RACCOON_Y, rng:NextNumber(-40, 40)))
			raccoon.Parent = folder
			task.delay(i * 0.7, runRaccoon, raccoon)
		end

		for i, lane in LANES do
			if i > #CAR_COLORS then
				break
			end
			local car = buildCar(CAR_COLORS[i])
			car.Parent = folder
			task.delay(i * 4, runCar, car, lane)
		end
	end)
end

return Ambience
