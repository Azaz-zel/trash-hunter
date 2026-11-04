--!strict
-- Client side of the weather (server: Systems/Weather). While it rains,
-- streaks of rain fall around the camera and the rain sound plays (when
-- Config.Sounds.RAIN is set). While the streets are wet, roads turn dark and
-- glossy so the neon and headlights shine on them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WeatherFx = {}

local WET_NAMES = { Road = true, Junction = true }
local WET_TINT = 0.62 -- wet asphalt colour, as a share of the dry colour
local WET_REFLECT = 0.22

local cloud: Part
local emitter: ParticleEmitter
local rainSound: Sound?
-- Dry look of every part we made wet, to put back.
local dryLook: { [BasePart]: { color: Color3, material: Enum.Material, reflectance: number } } = {}
local wet = false

local function setWet(on: boolean)
	if on == wet then
		return
	end
	wet = on
	local town = workspace:FindFirstChild("Town")
	local streets = town and town:FindFirstChild("Streets")
	if not streets then
		return
	end
	task.spawn(function()
		local n = 0
		if on then
			for _, d in streets:GetDescendants() do
				if d:IsA("BasePart") and WET_NAMES[d.Name] and not dryLook[d] then
					dryLook[d] =
						{ color = d.Color, material = d.Material, reflectance = d.Reflectance }
					local c = d.Color
					d.Color = Color3.new(c.R * WET_TINT, c.G * WET_TINT, c.B * WET_TINT)
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = WET_REFLECT
					n += 1
					if n % 400 == 0 then
						task.wait()
					end
				end
			end
		else
			for part, look in dryLook do
				part.Color = look.color
				part.Material = look.material
				part.Reflectance = look.reflectance
				n += 1
				if n % 400 == 0 then
					task.wait()
				end
			end
			table.clear(dryLook)
		end
	end)
end

local function setRain(on: boolean)
	emitter.Enabled = on
	local s = rainSound
	if s then
		if on and not s.IsPlaying then
			s.Volume = 0
			s:Play()
		end
		TweenService:Create(s, TweenInfo.new(4), { Volume = if on then 0.5 else 0 }):Play()
	end
end

function WeatherFx.init()
	-- An invisible sheet above the camera that sheds the rain.
	cloud = Instance.new("Part")
	cloud.Name = "RainCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(140, 1, 140)
	cloud.Parent = workspace
	emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Rate = 700
	emitter.Lifetime = NumberRange.new(0.7, 0.9)
	emitter.Speed = NumberRange.new(95, 115)
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Size = NumberSequence.new(0.18)
	emitter.Squash = NumberSequence.new(2.6) -- long thin streaks
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 215, 235))
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.LightEmission = 0.25
	emitter.LightInfluence = 0.6
	emitter.Enabled = false
	emitter.Parent = cloud
	if Config.Sounds.RAIN ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Rain"
		s.SoundId = Config.Sounds.RAIN
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		rainSound = s
	end
end

function WeatherFx.start()
	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function()
		if emitter.Enabled then
			-- Lead the camera a little so rain is already falling where it moves.
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local lead = if root then root.AssemblyLinearVelocity * 0.5 else Vector3.zero
			local p = camera.CFrame.Position + Vector3.new(lead.X, 0, lead.Z)
			cloud.CFrame = CFrame.new(p.X, p.Y + 45, p.Z)
		end
	end)
	local function update()
		setRain(workspace:GetAttribute("Weather") == "Rain")
		setWet(workspace:GetAttribute("Wet") == true)
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(update)
	workspace:GetAttributeChangedSignal("Wet"):Connect(update)
	task.defer(update)
end

return WeatherFx
