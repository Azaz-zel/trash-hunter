--!strict
-- Client-only life: light bars on the yard's gate cruiser that flash when
-- the alarm is up, day/night ambience, chase music (yard chase or city
-- wanted stars), and the city itself: a traffic hum that swells on busy
-- streets and a crowd murmur near people (Config.Sounds CITY_HUM / CROWD,
-- silent until set). Traffic lives in Traffic.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Settings = require(script.Parent.Parent.Settings)

local player = Players.LocalPlayer

local Ambience = {}

local folder: Folder

-- Weld every part to the primary part and anchor only that one.

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

local function loopSound(id: string, group: string?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.SoundGroup = Settings.group(group or "Ambient")
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return s
end

local function setupAudio()
	local day = loopSound(Config.Sounds.DAY_AMBIENCE)
	local night = loopSound(Config.Sounds.NIGHT_AMBIENCE)
	local chase = loopSound(Config.Sounds.CHASE_MUSIC, "Music")
	local FADE = TweenInfo.new(1.2)

	local function mix()
		local chased = player:GetAttribute("Chased") == true
			or (tonumber(player:GetAttribute("Wanted")) or 0) > 0
		local isNight = workspace:GetAttribute("Night") == true
		TweenService:Create(chase, FADE, { Volume = if chased then 0.45 else 0 }):Play()
		TweenService:Create(day, FADE, { Volume = if chased or isNight then 0 else 0.3 }):Play()
		TweenService:Create(night, FADE, { Volume = if chased or not isNight then 0 else 0.3 })
			:Play()
	end
	player:GetAttributeChangedSignal("Chased"):Connect(mix)
	player:GetAttributeChangedSignal("Wanted"):Connect(mix)
	workspace:GetAttributeChangedSignal("Night"):Connect(mix)
	mix()
end

-- City hum and crowd murmur, louder the more cars and people are around.
local function setupCityAudio()
	local hum = if Config.Sounds.CITY_HUM ~= "" then loopSound(Config.Sounds.CITY_HUM) else nil
	local crowd = if Config.Sounds.CROWD ~= "" then loopSound(Config.Sounds.CROWD) else nil
	if not hum and not crowd then
		return
	end
	local FADE = TweenInfo.new(1.5)
	task.spawn(function()
		while true do
			task.wait(0.75)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local pos = root.Position
			local function countNear(container: Instance?, radius: number): number
				local n = 0
				for _, m in if container then container:GetChildren() else {} do
					local p = if m:IsA("Model") then m:GetPivot().Position else nil
					if p and (p - pos).Magnitude < radius then
						n += 1
					end
				end
				return n
			end
			local town = workspace:FindFirstChild("Town")
			local cars = countNear(workspace:FindFirstChild("Traffic"), 160)
			local people = countNear(town and town:FindFirstChild("Pedestrians"), 45)
			if hum then
				TweenService:Create(hum, FADE, { Volume = math.min(0.35, 0.06 + cars * 0.025) })
					:Play()
			end
			if crowd then
				TweenService:Create(crowd, FADE, { Volume = math.min(0.4, people * 0.05) }):Play()
			end
		end
	end)
end

function Ambience.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientAmbience"
	folder.Parent = workspace
end

function Ambience.start()
	setupAudio()
	setupCityAudio()

	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("VehicleTemplates", 60)
		if not templates then
			return
		end
		-- Traffic (and its patrol cruisers) lives in Traffic.luau.
		local town = workspace:WaitForChild("Town")
		local gate = town:WaitForChild("GateCruiser", 30)
		if gate and gate:IsA("Model") then
			lightBar(gate, false)
		end
	end)
end

return Ambience
