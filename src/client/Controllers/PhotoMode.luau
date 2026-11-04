--!strict
-- Photo mode (P, or the button in Settings): hides every HUD, adds a soft
-- depth-of-field and lets the camera pull much further back, so players can
-- take screenshots of their finds, house and car. P again (or the small
-- button) brings everything back.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local player = Players.LocalPlayer

local PhotoMode = {}

local gui: ScreenGui
local on = false
local hidden: { ScreenGui } = {}
local blur: DepthOfFieldEffect? = nil
local savedZoom = 0

local function set(enable: boolean)
	if enable == on then
		return
	end
	on = enable
	local pg = player:WaitForChild("PlayerGui")
	if on then
		table.clear(hidden)
		for _, g in pg:GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		local dof = Instance.new("DepthOfFieldEffect")
		dof.FarIntensity = 0.35
		dof.FocusDistance = 18
		dof.InFocusRadius = 22
		dof.NearIntensity = 0.2
		dof.Parent = Lighting
		blur = dof
		savedZoom = player.CameraMaxZoomDistance
		player.CameraMaxZoomDistance = 220
	else
		for _, g in hidden do
			g.Enabled = true
		end
		table.clear(hidden)
		if blur then
			blur:Destroy()
			blur = nil
		end
		player.CameraMaxZoomDistance = savedZoom
	end
	gui.Enabled = on
end

function PhotoMode.init()
	gui = Ui.new("ScreenGui", {
		Name = "PhotoMode",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local exit = Ui.button(
		"📸 Exit photo mode (P)",
		"secondary",
		UDim2.fromOffset(200, 40),
		function()
			set(false)
		end
	)
	exit.AnchorPoint = Vector2.new(0.5, 0)
	exit.Position = UDim2.new(0.5, 0, 0, 10)
	exit.TextSize = 14
	exit.BackgroundTransparency = 0.6
	exit.Parent = gui
end

function PhotoMode.start()
	Store.on("photoMode", function()
		set(not on)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P then
			set(not on)
		end
	end)
end

return PhotoMode
