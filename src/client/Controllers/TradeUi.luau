--!strict
-- Trading with other players (server: Systems/Trade). The Trade button lists
-- players close by; a request pops up for them with Accept / Decline. The
-- trade window shows your bag (tap items to offer them, up to the limit),
-- your cash offer, and what they offer. Ready, then Confirm on both sides.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local TC = Config.Trade

local TradeUi = {}

local gui: ScreenGui
local picker: Frame
local pickerList: Frame
local invite: Frame
local inviteText: TextLabel
local window: Frame
local titleLabel: TextLabel
local mineGrid: Frame
local theirsGrid: Frame
local cashBox: TextBox
local theirCash: TextLabel
local status: TextLabel
local readyButton: TextButton
local confirmButton: TextButton

local view: any = nil
local inviteToken = 0

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function tile(parent: Instance, entry: any, selected: boolean, onClick: (() -> ())?)
	local item = Items.ById[entry.id]
	if not item then
		return
	end
	local rarity = Items.Rarities[item.rarity]
	local b: TextButton = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = onClick ~= nil,
		BackgroundColor3 = if selected then Color3.fromRGB(60, 52, 20) else C.panelLight,
		BackgroundTransparency = if selected then 0.05 else 0.35,
		Parent = parent,
	}, { Ui.corner(8), Ui.stroke(if selected then 2 else 1, rarity.color) })
	Ui.label(Items.label(entry.id, entry.mutation), 12, {
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 1, -18),
		TextWrapped = true,
		Parent = b,
	})
	Ui.label(Ui.money(Items.value(entry.id, entry.mutation)), 11, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -2),
		Size = UDim2.new(1, -8, 0, 14),
		TextColor3 = rarity.color,
		Parent = b,
	})
	if onClick then
		b.Activated:Connect(onClick)
	end
end

local function grid(parent: Instance, order: number): Frame
	return Ui.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(84, 58),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function sendOffer(items: { string })
	local cash = math.max(0, math.floor(tonumber(cashBox.Text) or 0))
	task.spawn(Store.action, "tradeOffer", { items = items, cash = cash })
end

local function render()
	local v = view
	if not v then
		window.Visible = false
		return
	end
	titleLabel.Text = `🤝 Trading with {v.with}`
	local offered: { [string]: boolean } = {}
	local list = {}
	for _, e in v.mine.items do
		offered[e.uid] = true
		table.insert(list, e.uid)
	end
	clear(mineGrid)
	local state = Store.get()
	for _, entry in if state then state.backpack else {} do
		local on = offered[entry.uid] == true
		tile(mineGrid, entry, on, function()
			local picked = table.clone(list)
			if on then
				table.remove(picked, table.find(picked, entry.uid) :: number)
			elseif #picked < TC.MAX_ITEMS then
				table.insert(picked, entry.uid)
			else
				Store.emit("toast", { text = `Up to {TC.MAX_ITEMS} items.` })
				return
			end
			sendOffer(picked)
		end)
	end
	clear(theirsGrid)
	for _, entry in v.theirs.items do
		tile(theirsGrid, entry, true, nil)
	end
	theirCash.Text = `+ {Ui.money(v.theirs.cash)}`
	if not cashBox:IsFocused() then
		cashBox.Text = tostring(v.mine.cash)
	end
	readyButton.Text = if v.mine.ready then "Not ready" else "Ready"
	local both = v.mine.ready and v.theirs.ready
	Ui.setEnabled(confirmButton, both and not v.mine.confirmed)
	status.Text = if v.mine.confirmed
		then "Waiting for them to confirm..."
		elseif both then "Both ready. Check the offer and Confirm."
		elseif v.theirs.ready then `{v.with} is ready.`
		else "Pick what you give, then Ready."
	window.Visible = true
end

local function openPicker()
	clear(pickerList)
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local found = 0
	for _, other in Players:GetPlayers() do
		local root = other.Character
			and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			other ~= player
			and me
			and root
			and (root.Position - me.Position).Magnitude <= TC.RANGE
		then
			found += 1
			local b = Ui.button(other.DisplayName, "secondary", UDim2.new(1, 0, 0, 52), function()
				picker.Visible = false
				local ok, message = Store.action("tradeRequest", other.UserId)
				if ok and message then
					Store.emit("toast", { text = message })
				end
			end)
			b.TextSize = 16
			b.Parent = pickerList
		end
	end
	if found == 0 then
		Ui.label("Nobody close by. Stand next to a player to trade.", 15, {
			Size = UDim2.new(1, 0, 0, 44),
			TextColor3 = C.muted,
			Parent = pickerList,
		})
	end
	picker.Visible = true
	Ui.pop(picker, 0.92)
end

local function modal(name: string, size: UDim2, max: Vector2): Frame
	local f = Ui.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
		Parent = gui,
	})
	f.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = max }).Parent = f
	return f
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Trade",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Who to trade with.
	picker = modal("Picker", UDim2.new(0.8, 0, 0, 0), Vector2.new(360, 480))
	picker.AutomaticSize = Enum.AutomaticSize.Y
	Ui.padding(14).Parent = picker
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = picker
	Ui.label(
		"🤝 Trade with...",
		20,
		{ Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, Parent = picker }
	)
	pickerList = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = picker,
	}, { Ui.list(Enum.FillDirection.Vertical, 6) })
	local cancelPick = Ui.button("Cancel", "secondary", UDim2.new(1, 0, 0, 52), function()
		picker.Visible = false
	end)
	cancelPick.LayoutOrder = 2
	cancelPick.Parent = picker

	-- Incoming request.
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
	local yes = Ui.button("Accept", "primary", UDim2.new(0.5, -18, 0, 52), function()
		invite.Visible = false
		Store.action("tradeRespond", true)
	end)
	yes.Position = UDim2.new(0, 12, 1, -62)
	yes.Parent = invite
	local no = Ui.button("Decline", "secondary", UDim2.new(0.5, -18, 0, 52), function()
		invite.Visible = false
		Store.action("tradeRespond", false)
	end)
	no.AnchorPoint = Vector2.new(1, 0)
	no.Position = UDim2.new(1, -12, 1, -62)
	no.Parent = invite

	-- The trade itself.
	window = modal("TradeWindow", UDim2.new(0.94, 0, 0, 0), Vector2.new(560, 640))
	window.AutomaticSize = Enum.AutomaticSize.Y
	Ui.padding(14).Parent = window
	Ui.list(Enum.FillDirection.Vertical, 8).Parent = window
	titleLabel =
		Ui.label("", 20, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 0, Parent = window })
	Ui.label(`YOU GIVE (tap items, up to {TC.MAX_ITEMS})`, 12, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		Font = Ui.FONT,
		LayoutOrder = 1,
		Parent = window,
	})
	mineGrid = grid(window, 2)
	local cashRow = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = window,
	})
	Ui.label("Cash $", 15, {
		Size = UDim2.fromOffset(60, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cashRow,
	})
	cashBox = Ui.new("TextBox", {
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(0, 140, 1, 0),
		BackgroundColor3 = C.panelLight,
		TextColor3 = C.cream,
		Font = Ui.FONT,
		TextSize = 16,
		Text = "0",
		ClearTextOnFocus = false,
		Parent = cashRow,
	}, { Ui.corner(8) })
	cashBox.FocusLost:Connect(function()
		local v = view
		if not v then
			return
		end
		local list = {}
		for _, e in v.mine.items do
			table.insert(list, e.uid)
		end
		sendOffer(list)
	end)
	Ui.label("THEY GIVE", 12, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		Font = Ui.FONT,
		LayoutOrder = 4,
		Parent = window,
	})
	theirsGrid = grid(window, 5)
	theirsGrid.Size = UDim2.new(1, 0, 0, 70)
	theirCash = Ui.label("", 16, {
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.accent,
		LayoutOrder = 6,
		Parent = window,
	})
	status = Ui.label("", 14, {
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = C.muted,
		LayoutOrder = 7,
		Parent = window,
	})
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 8,
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	readyButton = Ui.button("Ready", "secondary", UDim2.new(0.33, -6, 1, 0), function()
		local v = view
		Store.action("tradeReady", not (v and v.mine.ready))
	end)
	readyButton.TextSize = 16
	readyButton.Parent = row
	confirmButton = Ui.button("Confirm", "primary", UDim2.new(0.33, -6, 1, 0), function()
		Store.action("tradeConfirm")
	end)
	confirmButton.TextSize = 16
	confirmButton.LayoutOrder = 2
	confirmButton.Parent = row
	local cancel = Ui.button("Cancel", "danger", UDim2.new(0.33, -6, 1, 0), function()
		Store.action("tradeCancel")
	end)
	cancel.TextSize = 16
	cancel.LayoutOrder = 3
	cancel.Parent = row
end

function TradeUi.init()
	build()
	Ui.autoScale(gui)
end

function TradeUi.start()
	Store.on("openTrade", function()
		if view then
			return
		end
		openPicker()
	end)
	Store.on("tradeInvite", function(payload)
		inviteToken += 1
		local mine = inviteToken
		inviteText.Text = `{payload.from} wants to trade with you.`
		invite.Visible = true
		Ui.pop(invite, 0.9)
		task.delay(payload.seconds or TC.REQUEST_SECONDS, function()
			if inviteToken == mine then
				invite.Visible = false
			end
		end)
	end)
	Store.on("tradeOpen", function(payload)
		view = payload
		render()
		Ui.pop(window, 0.92)
	end)
	Store.on("tradeUpdate", function(payload)
		view = payload
		render()
	end)
	Store.on("state", function()
		if view then
			render()
		end
	end)
	Store.on("tradeClosed", function(payload)
		view = nil
		window.Visible = false
		local done = payload.reason == "done"
		Store.emit("toast", {
			text = if done then "Trade complete!" else `Trade closed: {payload.reason}`,
			color = if done then C.safe else nil,
		})
	end)
end

return TradeUi
