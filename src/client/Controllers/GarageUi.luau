--!strict
-- Garage (Garage button or V): the cars you own, with Spawn and Use, the
-- Custom Paint palette and underglow switch for pass owners, and a route to
-- Maple Motors for players who do not own a car yet.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local PALETTE = {
	"c0392b",
	"e67e22",
	"f1c40f",
	"27ae60",
	"16a085",
	"2980b9",
	"8e44ad",
	"ff4fd8",
	"00f0ff",
	"ecf0f1",
	"7f8c8d",
	"1b1b1f",
}

local GarageUi = {}

local gui: ScreenGui
local window: Frame
local body: ScrollingFrame

local function close()
	window.Visible = false
end

local function owns(state: any, car: any): boolean
	if car.pass then
		return state.passes[car.pass] == true
	end
	return state.ownedCars[car.id] == true
end

local function render()
	local state = Store.get()
	if not window.Visible or not state then
		return
	end
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local any = false
	for _, car in Config.Cars do
		if not owns(state, car) then
			continue
		end
		any = true
		local current = state.car == car.id
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, -6, 0, 64),
			BackgroundColor3 = C.panelLight,
			BackgroundTransparency = if current then 0.1 else 0.4,
			LayoutOrder = nextOrder(),
			Parent = body,
		}, { Ui.corner(12), Ui.stroke(1, if current then C.accent else C.hairline) })
		Ui.new("Frame", {
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = car.color,
			Parent = row,
		}, { Ui.corner(10) })
		Ui.label(car.name, 17, {
			Position = UDim2.fromOffset(60, 10),
			Size = UDim2.new(1, -200, 0, 22),
			Font = Ui.FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Ui.label(`{math.floor(car.top * 0.6)} mph · trunk {car.trunk} · {car.nitro}s nitro`, 13, {
			Position = UDim2.fromOffset(60, 34),
			Size = UDim2.new(1, -200, 0, 18),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local b = Ui.button(
			if current then "Spawn" else "Use",
			if current then "primary" else "secondary",
			UDim2.fromOffset(110, 44),
			function()
				if current then
					Store.action("spawnCar")
					close()
				else
					Store.action("selectCar", car.id)
				end
			end
		)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -10, 0.5, 0)
		b.TextSize = 16
		b.Parent = row
	end
	if not any then
		Ui.label("You don't own a car yet. Maple Motors sells the Old Sedan for $450.", 16, {
			Size = UDim2.new(1, -6, 0, 44),
			TextColor3 = C.muted,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
		local go = Ui.button("GPS to Maple Motors", "primary", UDim2.new(1, -6, 0, 52), function()
			Store.emit(
				"routeTo",
				{ pos = Config.Stores.motors.counter, name = Config.Stores.motors.name }
			)
			close()
		end)
		go.LayoutOrder = nextOrder()
		go.Parent = body
		return
	end
	-- Looks: Custom Paint pass (colour, underglow); Neon Runner (underglow).
	local paintPass = state.passes.paint == true
	local glowPass = paintPass or state.passes.neon == true
	Ui.label("LOOKS", 12, {
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	if paintPass then
		local grid = Ui.new("Frame", {
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = body,
		}, {
			Ui.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(38, 38),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for i, hex in PALETTE do
			local swatch: TextButton = Ui.new("TextButton", {
				Text = "",
				BackgroundColor3 = Color3.fromHex(hex),
				LayoutOrder = i,
				Parent = grid,
			}, { Ui.corner(19), Ui.stroke(2, if state.paint == hex then C.cream else C.panel) })
			swatch.Activated:Connect(function()
				Store.action("setPaint", { paint = hex })
			end)
		end
		local reset = Ui.button("Factory colour", "secondary", UDim2.new(1, -6, 0, 52), function()
			Store.action("setPaint", { paint = false })
		end)
		reset.TextSize = 15
		reset.LayoutOrder = nextOrder()
		reset.Parent = body
	else
		Ui.label("Custom Paint pass: any colour for any car.", 14, {
			Size = UDim2.new(1, -6, 0, 20),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
	end
	if glowPass then
		local glow = Ui.button(
			if state.underglow then "Underglow: ON" else "Underglow: OFF",
			"secondary",
			UDim2.new(1, -6, 0, 52),
			function()
				Store.action("setPaint", { underglow = not state.underglow })
			end
		)
		glow.TextSize = 15
		glow.LayoutOrder = nextOrder()
		glow.Parent = body
	end
end

local function open()
	window.Visible = true
	Ui.pop(window, 0.92)
	render()
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Garage",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.8, 0),
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }).Parent = window
	Ui.label("🚗 Garage", 22, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -120, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local x = Ui.button("Close", "secondary", UDim2.fromOffset(72, 36), close)
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 10)
	x.TextSize = 15
	x.Parent = window
	body = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -28, 1, -68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })
end

function GarageUi.init()
	build()
	Ui.autoScale(gui)
end

function GarageUi.start()
	Store.on("openGarage", function()
		if window.Visible then
			close()
		else
			open()
		end
	end)
	Store.on("state", render)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			Store.emit("openGarage", nil)
		elseif input.KeyCode == Enum.KeyCode.Escape and window.Visible then
			close()
		end
	end)
end

return GarageUi
