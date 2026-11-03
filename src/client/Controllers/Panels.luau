--!strict
-- Bag panel (sell / display / upgrade) and the collection book.
-- Opened from the side buttons, the B / C keys, or the Hideout prompts.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local Panels = {}

local gui: ScreenGui
local window: Frame
local title: TextLabel
local body: ScrollingFrame
local current: string? = nil

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function section(text: string, order: number)
	Ui.label(text, 22, {
		TextColor3 = C.muted,
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
end

local function note(text: string, order: number)
	Ui.label(text, 18, {
		LayoutOrder = order,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
end

-- One item row: name in rarity color, rarity + value under it, actions right.
local function itemRow(
	entry: any,
	order: number,
	actions: { { text: string, style: string, enabled: boolean, fn: () -> () } }
)
	local item = Items.ById[entry.id]
	local rarity = Items.Rarities[item.rarity]
	local row = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = order,
		Parent = body,
	}, { Ui.corner(8) })
	Ui.label(Items.label(entry.id, entry.mutation), 20, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24 - 112 * #actions, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextColor3 = rarity.color,
		Parent = row,
	})
	Ui.label(`{rarity.name} · {Ui.money(Items.value(entry.id, entry.mutation))}`, 16, {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24 - 112 * #actions, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		Parent = row,
	})
	for i, action in actions do
		local button = Ui.button(action.text, action.style, UDim2.fromOffset(104, 48), action.fn)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8 - (i - 1) * 112, 0.5, 0)
		button.TextSize = 18
		Ui.setEnabled(button, action.enabled)
		button.Parent = row
	end
end

local function renderBag()
	local state = Store.get()
	title.Text = "Bag"
	clear()
	if not state then
		note("Loading your stuff...", 1)
		return
	end
	local inHideout = player:GetAttribute("InHideout") == true
	if not inHideout then
		note("Go to the Hideout to sell, display or upgrade.", 1)
	end

	section(`Backpack {#state.backpack}/{state.capacity}`, 2)
	if #state.backpack == 0 then
		note("Your backpack is empty. Search dumpsters to find stuff.", 3)
	end
	local total = 0
	for i, entry in state.backpack do
		total += Items.value(entry.id, entry.mutation)
		itemRow(entry, 10 + i, {
			{
				text = "Sell",
				style = "primary",
				enabled = inHideout,
				fn = function()
					Store.action("sell", entry.uid)
				end,
			},
			{
				text = "Display",
				style = "secondary",
				enabled = inHideout and #state.shelf < state.shelfSlots,
				fn = function()
					Store.action("display", entry.uid)
				end,
			},
		})
	end
	if #state.backpack > 0 then
		local sellAll = Ui.button(
			`Sell all for {Ui.money(total)}`,
			"primary",
			UDim2.new(1, 0, 0, 56),
			function()
				Store.action("sell", "all")
			end
		)
		sellAll.LayoutOrder = 100
		Ui.setEnabled(sellAll, inHideout)
		sellAll.Parent = body
	end

	section(`Display shelf {#state.shelf}/{state.shelfSlots}`, 200)
	if #state.shelf == 0 then
		note(
			"Display your best finds so other players can see them. Displayed items are kept, not sold.",
			201
		)
	end
	for i, entry in state.shelf do
		itemRow(entry, 210 + i, {
			{
				text = "Take back",
				style = "secondary",
				enabled = inHideout and #state.backpack < state.capacity,
				fn = function()
					Store.action("undisplay", entry.uid)
				end,
			},
		})
	end

	section("Backpack upgrade", 300)
	local upgrade = state.nextUpgrade
	if upgrade then
		local affordable = state.cash >= upgrade.price
		local buy = Ui.button(
			`{state.capacity} → {upgrade.capacity} slots for {Ui.money(upgrade.price)}`,
			"primary",
			UDim2.new(1, 0, 0, 56),
			function()
				Store.action("buyUpgrade")
			end
		)
		buy.LayoutOrder = 301
		Ui.setEnabled(buy, inHideout and affordable)
		buy.Parent = body
		if not affordable then
			note(`You need {Ui.money(upgrade.price - state.cash)} more.`, 302)
		end
	else
		note("Your backpack is maxed out.", 301)
	end
end

local function renderBook()
	local state = Store.get()
	clear()
	if not state then
		title.Text = "Collection"
		note("Loading your collection...", 1)
		return
	end
	local found = 0
	for _, item in Items.List do
		if state.collection[item.id] then
			found += 1
		end
	end
	title.Text = `Collection {found}/{#Items.List}`
	note("Every item you have ever found. Shiny and Golden versions count separately.", 1)

	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 84),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, item in Items.List do
		local rarity = Items.Rarities[item.rarity]
		local known = state.collection[item.id] == true
		local cell = Ui.new("Frame", {
			BackgroundColor3 = if known then C.panelLight else C.ink,
			LayoutOrder = i,
			Parent = grid,
		}, { Ui.corner(8), Ui.padding(8) })
		Ui.label(if known then item.name else "???", 18, {
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if known then rarity.color else C.muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = cell,
		})
		Ui.label(rarity.name, 16, {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.muted,
			Parent = cell,
		})
		local marks = {}
		for _, m in Items.Mutations do
			if state.collection[Items.collectionKey(item.id, m.id)] then
				table.insert(marks, m.name)
			end
		end
		if #marks > 0 then
			Ui.label(table.concat(marks, " + "), 16, {
				Position = UDim2.fromOffset(0, 48),
				Size = UDim2.new(1, 0, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.accent,
				Parent = cell,
			})
		end
	end
end

local function render()
	if current == "bag" then
		renderBag()
	elseif current == "book" then
		renderBook()
	end
end

local function open(which: string)
	if current == which then
		current = nil
		window.Visible = false
		return
	end
	current = which
	window.Visible = true
	body.CanvasPosition = Vector2.zero
	render()
end

local function close()
	current = nil
	window.Visible = false
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Panels",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.82),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 620) }).Parent = window
	title = Ui.label("", 30, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -140, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local closeButton = Ui.button("Close", "secondary", UDim2.fromOffset(104, 48), close)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.Parent = window
	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 68),
		Size = UDim2.new(1, -32, 1, -84),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })
	Ui.new("UIPadding", { PaddingRight = UDim.new(0, 12) }).Parent = body
end

function Panels.init()
	build()
end

function Panels.start()
	Store.on("openPanel", open)
	Store.on("state", render)
	player:GetAttributeChangedSignal("InHideout"):Connect(function()
		if current == "bag" then
			render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SellPrompt" or prompt.Name == "ShopPrompt" then
			if current ~= "bag" then
				open("bag")
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and current then
			close()
		end
	end)
end

return Panels
