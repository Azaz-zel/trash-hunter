--!strict
-- Server weather. Spells of clear sky and rain come and go (Config.Weather);
-- the sky darkens and thickens for rain on every client. workspace attributes:
--   Weather = "Clear" | "Rain"
--   Wet     = true while it rains and for a minute after (shiny roads)
-- The client draws the rain itself (Controllers/WeatherFx).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local WC = Config.Weather
local FADE = TweenInfo.new(20, Enum.EasingStyle.Sine)
local DRY_AFTER = 60

local Weather = {}

local rng = Random.new()

type Look = {
	density: number,
	haze: number,
	color: Color3,
	cover: number,
	cloudDensity: number,
	brightness: number,
}
local clear: Look? = nil
local RAIN_LOOK = {
	density = 0.42,
	haze = 2.6,
	color = Color3.fromRGB(150, 158, 170),
	cover = 0.88,
	cloudDensity = 0.85,
	brightness = 1.6,
}

local function apply(look: Look)
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air then
		TweenService
			:Create(air, FADE, { Density = look.density, Haze = look.haze, Color = look.color })
			:Play()
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		TweenService:Create(clouds, FADE, { Cover = look.cover, Density = look.cloudDensity })
			:Play()
	end
	TweenService:Create(Lighting, FADE, { Brightness = look.brightness }):Play()
end

local function capture(): Look
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	return {
		density = if air then air.Density else 0.3,
		haze = if air then air.Haze else 1,
		color = if air then air.Color else Color3.fromRGB(199, 206, 214),
		cover = if clouds then clouds.Cover else 0.5,
		cloudDensity = if clouds then clouds.Density else 0.55,
		brightness = Lighting.Brightness,
	}
end

function Weather.start()
	workspace:SetAttribute("Weather", "Clear")
	workspace:SetAttribute("Wet", false)
	task.spawn(function()
		task.wait(5) -- World has set up the sky by now
		clear = capture()
		while true do
			task.wait(rng:NextNumber(WC.MIN_SPELL, WC.MAX_SPELL))
			local rain = rng:NextNumber() < WC.RAIN_CHANCE
			if rain and workspace:GetAttribute("Weather") ~= "Rain" then
				workspace:SetAttribute("Weather", "Rain")
				workspace:SetAttribute("Wet", true)
				apply(RAIN_LOOK)
			elseif not rain and workspace:GetAttribute("Weather") == "Rain" then
				workspace:SetAttribute("Weather", "Clear")
				apply(clear :: Look)
				task.delay(DRY_AFTER, function()
					if workspace:GetAttribute("Weather") == "Clear" then
						workspace:SetAttribute("Wet", false)
					end
				end)
			end
		end
	end)
end

return Weather
