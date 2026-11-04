--!strict
-- Client-only life: a police
-- cruiser patrolling past the Meridian yard, light bars that flash when the
-- yard alarm is up, day/night ambience and chase music. Cars are clones of
-- server-prepared templates moved with one tween on an anchored root.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local rng = Random.new()

local ROAD_TOP = 0.2
local CRUISER_SPEED = 22
local ROAD_END = 1230

local Ambience = {}

local folder: Folder

local function play(tween: Tween)
	tween:Play()
	tween.Completed:Wait()
end

-- Weld every part to the primary part and anchor only that one.
local function makeMovable(model: Model): (BasePart, number)
	local root = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	model.PrimaryPart = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
	root.Anchored = true
	root.CanCollide = false
	local cf, size = model:GetBoundingBox()
	local lift = model:GetPivot().Y - (cf.Y - size.Y / 2)
	return root, lift
end

local function drive(model: Model, lane: { z: number, dir: number }, speed: number)
	local root, lift = makeMovable(model)
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(lane.dir, 0, 0)).Rotation
	local info = TweenInfo.new(ROAD_END * 2 / speed, Enum.EasingStyle.Linear)
	-- Root CFrame offset from the pivot, so the tween moves the pivot along the lane.
	local rootOffset = model:GetPivot():ToObjectSpace(root.CFrame)
	local y = ROAD_TOP + lift
	while model.Parent do
		local from = CFrame.new(-ROAD_END * lane.dir, y, lane.z) * facing
		local to = CFrame.new(ROAD_END * lane.dir, y, lane.z) * facing
		root.CFrame = from * rootOffset
		play(TweenService:Create(root, info, { CFrame = to * rootOffset }))
		task.wait(rng:NextNumber(2, 7))
	end
end

-- Red/blue flashers on a police car, active while the yard alarm is up.
local function lightBar(model: Model, attachToRoot: boolean)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local cf, size = model:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = "LightBarAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = cf * CFrame.new(0, size.Y / 2 + 0.5, 0)
	if attachToRoot then
		anchor.Anchored = false
		anchor.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = anchor
		w.Parent = anchor
	else
		anchor.Anchored = true
	end
	anchor.Parent = model
	local red = Instance.new("PointLight")
	red.Color = Color3.fromRGB(255, 40, 40)
	red.Range = 24
	red.Brightness = 0
	red.Parent = anchor
	local blue = Instance.new("PointLight")
	blue.Color = Color3.fromRGB(40, 90, 255)
	blue.Range = 24
	blue.Brightness = 0
	blue.Parent = anchor
	task.spawn(function()
		local phase = false
		while model.Parent do
			if workspace:GetAttribute("Alarm") == true then
				phase = not phase
				red.Brightness = if phase then 4 else 0
				blue.Brightness = if phase then 0 else 4
				task.wait(0.3)
			else
				red.Brightness, blue.Brightness = 0, 0
				workspace:GetAttributeChangedSignal("Alarm"):Wait()
			end
		end
	end)
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
		local templates = ReplicatedStorage:WaitForChild("VehicleTemplates", 60)
		if not templates then
			return
		end
		-- Civilian traffic lives in Traffic.luau; only the yard cruiser runs here.
		local police = templates:FindFirstChild("PoliceCar")
		if police and police:IsA("Model") then
			local cruiser = police:Clone()
			cruiser.Name = "Cruiser"
			cruiser.Parent = folder
			lightBar(cruiser, true)
			task.delay(3, drive, cruiser, { z = 308, dir = -1 }, CRUISER_SPEED)
		end
		local town = workspace:WaitForChild("Town")
		local gate = town:WaitForChild("GateCruiser", 30)
		if gate and gate:IsA("Model") then
			lightBar(gate, false)
		end
	end)
end

return Ambience
