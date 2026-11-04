--!strict
-- First five minutes: one marker in the world plus one sentence on screen,
-- driven by the server-side tutorial step (GDD FTUE).

local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local Guide = {}

local hint: TextLabel
local marker: BillboardGui
local markerText: TextLabel

local STEPS: { { text: string, path: { string }, label: string } } = {
	{
		text = "Search the dumpster next to the Hideout. Tap DIG (F) in the gold zone!",
		path = { "Dumpsters", "TutorialDumpster", "Body" },
		label = "SEARCH",
	},
	{
		text = "Sell your find at the yellow counter in the Hideout.",
		path = { "Hideout", "SellCounter" },
		label = "SELL",
	},
	{
		text = "Buy a bigger backpack inside Hank's Hardware, down the street.",
		path = { "Districts", "Stores", "hardwareStore", "hardwareCounter" },
		label = "UPGRADE",
	},
	{
		text = "Better loot waits behind the red fence. Stay out of the guard's light.",
		path = { "RedZone", "CompanySign" },
		label = "BETTER LOOT",
	},
}

local function find(path: { string }): BasePart?
	local node: Instance? = workspace:FindFirstChild("Town")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

local retrying = false

local function render()
	local state = Store.get()
	local step = state and STEPS[state.tutorial + 1]
	if not step then
		hint.Visible = false
		marker.Enabled = false
		return
	end
	if hint.Text ~= step.text then
		hint.Text = step.text
		Ui.pop(hint, 0.7)
	end
	hint.Visible = true
	local target = find(step.path)
	marker.Adornee = target
	marker.Enabled = target ~= nil
	markerText.Text = step.label .. "\n▼"
	-- With streaming on, the target may not have arrived yet: look again shortly.
	if not target and not retrying then
		retrying = true
		task.delay(1, function()
			retrying = false
			render()
		end)
	end
end

function Guide.init()
	local gui = Ui.new("ScreenGui", {
		Name = "Guide",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.autoScale(gui)
	hint = Ui.label("", 20, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 164),
		Size = UDim2.new(0.86, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = Ui.PANEL_ALPHA,
		BackgroundColor3 = C.panel,
		TextColor3 = C.accent,
		Visible = false,
		Parent = gui,
	})
	Ui.corner(10).Parent = hint
	Ui.stroke().Parent = hint
	Ui.padding(10).Parent = hint
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }).Parent = hint

	marker = Ui.new("BillboardGui", {
		Name = "GuideMarker",
		Size = UDim2.fromOffset(180, 90),
		StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		Enabled = false,
		-- BillboardGuis do not render inside a ScreenGui; PlayerGui is fine.
		Parent = player:WaitForChild("PlayerGui"),
	})
	markerText = Ui.label("", 30, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.accent,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Parent = marker,
	})
end

function Guide.start()
	-- The world marker bobs so the eye finds it.
	game:GetService("TweenService")
		:Create(
			marker,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ StudsOffset = Vector3.new(0, 8.2, 0) }
		)
		:Play()
	Store.on("state", render)
	render()
end

return Guide
