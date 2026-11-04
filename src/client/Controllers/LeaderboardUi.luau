--!strict
-- Top panel (Top button): the global leaderboards the server publishes as
-- JSON in ReplicatedStorage.Leaderboards (see Systems/Leaderboards). Tabs
-- switch boards; your own name is highlighted.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local ORDER = { "earned", "collection", "xp", "likes", "combo" }
local NAMES = {
	earned = "Richest",
	collection = "Collectors",
	xp = "Level",
	likes = "House",
	combo = "Combo",
}

local LeaderboardUi = {}

local gui: ScreenGui
local window: Frame
local list: Frame
local tabs: { [string]: TextButton } = {}
local current = "earned"

local function render()
	if not window.Visible then
		return
	end
	for id, tab in tabs do
		tab.BackgroundTransparency = if id == current then 0 else 0.6
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
	local value = folder and folder:FindFirstChild(current)
	local rows = {}
	if value and value:IsA("StringValue") and value.Value ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok and typeof(decoded) == "table" then
			rows = decoded
		end
	end
	if #rows == 0 then
		Ui.label("Updating... check back in a minute.", 15, {
			Size = UDim2.new(1, 0, 0, 30),
			TextColor3 = C.muted,
			Parent = list,
		})
		return
	end
	for i, row in rows do
		local me = row.name == player.DisplayName or row.name == player.Name
		local medal = ({ "🥇", "🥈", "🥉" })[i] or `{i}.`
		local line = Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = if me then Color3.fromRGB(70, 60, 20) else C.panelLight,
			BackgroundTransparency = if me then 0.2 else 0.55,
			LayoutOrder = i,
			Parent = list,
		}, { Ui.corner(8) })
		Ui.label(`{medal}  {row.name}`, 16, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0.65, -10, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = line,
		})
		Ui.label(tostring(row.value), 16, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0.35, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.accent,
			Font = Ui.FONT,
			Parent = line,
		})
	end
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Top",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 520),
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 520) }).Parent = window
	Ui.label("🏆 Leaderboards", 22, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -120, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local x = Ui.button("Close", "secondary", UDim2.fromOffset(72, 36), function()
		window.Visible = false
	end)
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 10)
	x.TextSize = 15
	x.Parent = window
	local bar = Ui.new("Frame", {
		Position = UDim2.fromOffset(14, 54),
		Size = UDim2.new(1, -28, 0, 34),
		BackgroundTransparency = 1,
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6) })
	for i, id in ORDER do
		local tab: TextButton = Ui.new("TextButton", {
			Size = UDim2.new(0.2, -5, 1, 0),
			BackgroundColor3 = C.accent,
			BackgroundTransparency = 0.6,
			Font = Ui.FONT,
			TextSize = 14,
			TextColor3 = C.cream,
			Text = NAMES[id],
			LayoutOrder = i,
			Parent = bar,
		}, { Ui.corner(8) })
		tab.Activated:Connect(function()
			current = id
			render()
		end)
		tabs[id] = tab
	end
	list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 98),
		Size = UDim2.new(1, -28, 1, -110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Vertical, 6) })
end

function LeaderboardUi.init()
	build()
	Ui.autoScale(gui)
end

function LeaderboardUi.start()
	Store.on("openTop", function()
		window.Visible = not window.Visible
		if window.Visible then
			Ui.pop(window, 0.92)
			render()
		end
	end)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Leaderboards", 60)
		if folder then
			folder.DescendantAdded:Connect(render)
			for _, v in folder:GetChildren() do
				if v:IsA("StringValue") then
					v.Changed:Connect(render)
				end
			end
			folder.ChildAdded:Connect(function(v)
				if v:IsA("StringValue") then
					v.Changed:Connect(render)
				end
			end)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			window.Visible = false
		end
	end)
end

return LeaderboardUi
