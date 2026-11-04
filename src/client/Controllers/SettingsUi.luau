--!strict
-- Settings window (Settings button): music, effects and ambience volume
-- sliders, minimap rotation and low graphics. Loaded from the save on the
-- first state push; changes are sent back a moment after the last edit.
-- Low graphics also turns off shadows on this client.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)
local Settings = require(script.Parent.Parent.Settings)

local C = Ui.COLORS
local player = Players.LocalPlayer

local SettingsUi = {}

local gui: ScreenGui
local window: Frame
local refreshers: { () -> () } = {}
local saveToken = 0

local function save()
	saveToken += 1
	local mine = saveToken
	task.delay(1, function()
		if saveToken == mine then
			Store.action("saveSettings", Settings.get())
		end
	end)
end

local function slider(parent: Instance, order: number, label: string, key: string)
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.label(label, 15, {
		Size = UDim2.new(1, -60, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local pct = Ui.label("", 14, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.muted,
		Parent = row,
	})
	local track: TextButton = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = C.panelLight,
		Parent = row,
	}, { Ui.corner(7) })
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.accent,
		Parent = track,
	}, { Ui.corner(7) })
	local function show()
		local v = (Settings.get() :: any)[key] :: number
		fill.Size = UDim2.fromScale(v, 1)
		pct.Text = `{math.floor(v * 100 + 0.5)}%`
	end
	local dragging = false
	local function setFrom(x: number)
		local f = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		Settings.set(key, math.floor(f * 20 + 0.5) / 20)
		show()
		save()
	end
	track.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if
			dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch)
		then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(refreshers, show)
end

local function toggle(parent: Instance, order: number, label: string, key: string)
	local b = Ui.button("", "secondary", UDim2.new(1, 0, 0, 52), function()
		Settings.set(key, not (Settings.get() :: any)[key])
		save()
		for _, fn in refreshers do
			fn()
		end
	end)
	b.TextSize = 16
	b.LayoutOrder = order
	b.Parent = parent
	table.insert(refreshers, function()
		b.Text = `{label}: {if (Settings.get() :: any)[key] then "ON" else "OFF"}`
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Settings",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(420, 640) }).Parent = window
	Ui.padding(16).Parent = window
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = window
	Ui.label("⚙ Settings", 22, {
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = window,
	})
	slider(window, 1, "Music", "music")
	slider(window, 2, "Effects", "effects")
	slider(window, 3, "City ambience", "ambient")
	toggle(window, 4, "Radar turns with camera", "rotateMap")
	toggle(window, 5, "Low graphics (phones)", "low")
	local done = Ui.button("Done", "primary", UDim2.new(1, 0, 0, 52), function()
		window.Visible = false
	end)
	done.LayoutOrder = 6
	done.Parent = window
end

function SettingsUi.init()
	build()
	Ui.autoScale(gui)
end

function SettingsUi.start()
	local loaded = false
	Store.on("state", function(state)
		if not loaded and state and state.settings then
			loaded = true
			Settings.load(state.settings)
			for _, fn in refreshers do
				fn()
			end
		end
	end)
	Settings.changed(function(values)
		Lighting.GlobalShadows = not values.low
	end)
	Store.on("openSettings", function()
		window.Visible = not window.Visible
		if window.Visible then
			for _, fn in refreshers do
				fn()
			end
			Ui.pop(window, 0.92)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			window.Visible = false
		end
	end)
end

return SettingsUi
