--!strict
-- Players panel (Players button): everyone on this server with their level,
-- title and house, and buttons to visit their house, trade (when close by)
-- and invite them to your crew. Crew invites pop up with Accept / Decline.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local PlayersUi = {}

local gui: ScreenGui
local window: Frame
local crewLabel: TextLabel
local list: ScrollingFrame
local invite: Frame
local inviteText: TextLabel
local inviteToken = 0

local function near(other: Player): boolean
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude <= Config.Trade.RANGE
end

local function small(text: string, style: string, fn: () -> ()): TextButton
	local b = Ui.button(text, style, UDim2.fromOffset(72, 52), fn)
	b.TextSize = 14
	return b
end

local function render()
	if not window.Visible then
		return
	end
	local myCrew = player:GetAttribute("Crew")
	crewLabel.Text = if myCrew
		then `Your crew: {player:GetAttribute("CrewNames") or ""}`
		else "No crew yet. Invite players to search together (better odds when close)."
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local any = false
	for i, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		any = true
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, -6, 0, 64),
			BackgroundColor3 = C.panelLight,
			BackgroundTransparency = 0.4,
			LayoutOrder = i,
			Parent = list,
		}, { Ui.corner(12) })
		local level = other:GetAttribute("Level") or 1
		local title = other:GetAttribute("Title") or ""
		Ui.label(other.DisplayName, 16, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -260, 0, 20),
			Font = Ui.FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = row,
		})
		Ui.label(`Lv {level} {title} · {other:GetAttribute("HouseName") or "no house here"}`, 12, {
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -260, 0, 18),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = row,
		})
		local buttons = Ui.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(240, 52),
			BackgroundTransparency = 1,
			Parent = row,
		}, { Ui.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
		local visit = small("Visit", "secondary", function()
			window.Visible = false
			Store.action("visitHouse", other.UserId)
		end)
		visit.LayoutOrder = 1
		visit.Parent = buttons
		local trade = small("Trade", "secondary", function()
			local ok, message = Store.action("tradeRequest", other.UserId)
			if ok and message then
				Store.emit("toast", { text = message })
			end
		end)
		trade.LayoutOrder = 2
		Ui.setEnabled(trade, near(other))
		trade.Parent = buttons
		local sameCrew = myCrew ~= nil and other:GetAttribute("Crew") == myCrew
		local crew = small(if sameCrew then "Crew ✓" else "Crew +", "primary", function()
			local ok, message = Store.action("crewInvite", other.UserId)
			if ok and message then
				Store.emit("toast", { text = message })
			end
		end)
		crew.LayoutOrder = 3
		Ui.setEnabled(crew, not sameCrew)
		crew.Parent = buttons
	end
	if not any then
		Ui.label("You're the only one here. Invite friends (Invite button).", 15, {
			Size = UDim2.new(1, -6, 0, 40),
			TextColor3 = C.muted,
			Parent = list,
		})
	end
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "PlayersPanel",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.8, 0),
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 560) }).Parent = window
	Ui.label("👥 Players", 22, {
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
	crewLabel = Ui.label("", 13, {
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -120, 0, 32),
		TextColor3 = Color3.fromRGB(120, 220, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local leave = Ui.button("Leave crew", "secondary", UDim2.fromOffset(96, 32), function()
		Store.action("crewLeave")
	end)
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -12, 0, 50)
	leave.TextSize = 13
	leave.Parent = window
	list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 108),
		Size = UDim2.new(1, -28, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })

	invite = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(340, 110),
		Visible = false,
		Parent = gui,
	})
	inviteText = Ui.label("", 17, {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = invite,
	})
	local yes = Ui.button("Join crew", "primary", UDim2.new(0.5, -18, 0, 52), function()
		invite.Visible = false
		Store.action("crewRespond", true)
	end)
	yes.Position = UDim2.new(0, 12, 1, -62)
	yes.Parent = invite
	local no = Ui.button("No thanks", "secondary", UDim2.new(0.5, -18, 0, 52), function()
		invite.Visible = false
		Store.action("crewRespond", false)
	end)
	no.AnchorPoint = Vector2.new(1, 0)
	no.Position = UDim2.new(1, -12, 1, -62)
	no.Parent = invite
end

function PlayersUi.init()
	build()
	Ui.autoScale(gui)
end

function PlayersUi.start()
	Store.on("openPlayers", function()
		window.Visible = not window.Visible
		if window.Visible then
			Ui.pop(window, 0.92)
			render()
		end
	end)
	Store.on("crewInvite", function(payload)
		inviteToken += 1
		local mine = inviteToken
		inviteText.Text = `{payload.from} invites you to their crew.`
		invite.Visible = true
		Ui.pop(invite, 0.9)
		task.delay(20, function()
			if inviteToken == mine then
				invite.Visible = false
			end
		end)
	end)
	for _, attr in { "Crew", "CrewNames" } do
		player:GetAttributeChangedSignal(attr):Connect(render)
	end
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			window.Visible = false
		end
	end)
end

return PlayersUi
