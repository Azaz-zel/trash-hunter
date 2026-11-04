--!strict
-- One window with tabs Bag, Trunk (only at your opened car trunk) and Book. Items are shown as
-- picture cards (3D item models in ViewportFrames). Tap a card to select it;
-- the action bar at the bottom shows what you can do with it right now.
-- Opened from the side buttons, the B / C keys, or the Hideout and car prompts.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local TABS = { "bag", "trunk", "book" }
local TAB_NAMES = { bag = "Bag", trunk = "Trunk", book = "Book" }

type Action = { text: string, style: string, enabled: boolean, fn: () -> () }

local Panels = {}

local gui: ScreenGui
local window: Frame
local tabButtons: { [string]: TextButton } = {}
local body: ScrollingFrame
local actionBar: Frame
local current: string? = nil
-- The trunk tab exists only while you stand at your opened car trunk.
local trunkOpen = false
local trunkCar: Model? = nil
local selected: { uid: string, from: string }? = nil

-- ─── building blocks ───────────────────────────────────────────────────────

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function heading(text: string, order: number, right: string?)
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = order,
		Parent = body,
	})
	Ui.label(string.upper(text), 13, {
		Size = UDim2.new(0.6, 0, 1, 0),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	if right then
		Ui.label(right, 13, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
end

local function note(text: string, order: number)
	Ui.label(text, 15, {
		LayoutOrder = order,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
end

local function grid(order: number, cellHeight: number): Frame
	local columns = if window.AbsoluteSize.X > 480 then 4 else 3
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -8, 0, cellHeight),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

type CardOpts = { silhouette: boolean?, caption: string?, selectable: { uid: string, from: string }? }

-- Picture card for an item. `silhouette` hides it (collection book).
local function pill(
	parent: Instance,
	text: string,
	bg: Color3,
	fg: Color3,
	pos: UDim2,
	anchor: Vector2
)
	local frame = Ui.new("Frame", {
		AnchorPoint = anchor,
		Position = pos,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		BackgroundColor3 = bg,
		ZIndex = 3,
		Parent = parent,
	}, {
		Ui.corner(9),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
	})
	Ui.label(text, 11, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		TextColor3 = fg,
		ZIndex = 3,
		Parent = frame,
	})
	return frame
end

local function itemCard(
	parent: Instance,
	order: number,
	itemId: string,
	mutation: string?,
	opts: CardOpts
): TextButton
	local item = Items.ById[itemId]
	local rarity = Items.Rarities[item.rarity]
	local sel = opts.selectable
	local hidden = opts.silhouette == true
	local isSelected = selected ~= nil
		and sel ~= nil
		and selected.uid == sel.uid
		and selected.from == sel.from
	local card: TextButton = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = sel ~= nil,
		BackgroundColor3 = if hidden
			then Color3.fromRGB(24, 26, 30)
			else Color3.fromRGB(34, 37, 43),
		BackgroundTransparency = 0,
		LayoutOrder = order,
		ClipsDescendants = true,
		Parent = parent,
	}, { Ui.corner(12) })
	-- Rarity glow rising from the bottom of the card.
	if not hidden then
		local glow = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.75),
			BackgroundColor3 = rarity.color,
			BorderSizePixel = 0,
			Parent = card,
		}, { Ui.corner(12) })
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, if item.rarity >= 4 then 0.55 else 0.75),
			}),
			Parent = glow,
		})
	end
	local strokeColor = if isSelected then C.cream elseif hidden then C.panelLight else rarity.color
	local stroke = Ui.stroke(if isSelected then 2.5 else 1, strokeColor)
	stroke.Transparency = if isSelected then 0 elseif hidden then 0.4 else 0.35
	stroke.Parent = card
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 1, -72),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = card,
	})
	ItemModels.show(vp, itemId, mutation, hidden)
	pill(
		card,
		string.upper(rarity.name),
		if hidden then C.panelLight else rarity.color,
		if hidden then C.muted else C.ink,
		UDim2.fromOffset(7, 7),
		Vector2.zero
	)
	if mutation and not hidden then
		local m = Items.MutationById[mutation]
		if m then
			pill(
				card,
				string.upper(m.name),
				m.color,
				C.ink,
				UDim2.new(1, -7, 0, 7),
				Vector2.new(1, 0)
			)
		end
	end
	Ui.label(if hidden then "???" else (Items.ById[itemId] :: any).name, 14, {
		Position = UDim2.new(0, 9, 1, -44),
		Size = UDim2.new(1, -18, 0, 18),
		TextColor3 = if hidden then C.muted else C.cream,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = card,
	})
	Ui.label(
		opts.caption
			or (if hidden then "Not found yet" else Ui.money(Items.value(itemId, mutation))),
		14,
		{
			Position = UDim2.new(0, 9, 1, -24),
			Size = UDim2.new(1, -18, 0, 16),
			TextColor3 = if hidden then C.muted else C.accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Parent = card,
		}
	)
	if sel then
		card.Activated:Connect(function()
			selected = if isSelected then nil else { uid = sel.uid, from = sel.from }
			Panels.render()
		end)
	end
	return card
end

-- Placeholder card for a free backpack slot.
local function emptySlot(parent: Instance, order: number)
	Ui.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 26, 30),
		BackgroundTransparency = 0.3,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Ui.corner(12),
		Ui.stroke(1, C.panelLight),
		Ui.label("Empty", 13, { Size = UDim2.fromScale(1, 1), TextColor3 = C.panelLight }),
	})
end

-- A row of stat tiles: { label, value, fill (0..1) or nil, colour }.
local function statTiles(order: number, tiles: { { any } })
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = order,
		Parent = body,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8) })
	for i, t in tiles do
		local tile = Ui.new("Frame", {
			Size = UDim2.new(1 / #tiles, -8 * (#tiles - 1) / #tiles, 1, 0),
			BackgroundColor3 = Color3.fromRGB(34, 37, 43),
			LayoutOrder = i,
			Parent = row,
		}, { Ui.corner(12), Ui.stroke(1, C.panelLight) })
		Ui.label(string.upper(t[1]), 11, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 14),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = tile,
		})
		Ui.label(t[2], 19, {
			Position = UDim2.fromOffset(12, 23),
			Size = UDim2.new(1, -24, 0, 22),
			TextColor3 = t[4] or C.cream,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = tile,
		})
		if t[3] then
			local track = Ui.new("Frame", {
				Position = UDim2.new(0, 12, 1, -12),
				Size = UDim2.new(1, -24, 0, 5),
				BackgroundColor3 = C.panelLight,
				Parent = tile,
			}, { Ui.corner(3) })
			Ui.new("Frame", {
				Size = UDim2.fromScale(math.clamp(t[3], 0, 1), 1),
				BackgroundColor3 = t[4] or C.safe,
				Parent = track,
			}, { Ui.corner(3) })
		end
	end
end
local function find(list: { any }, uid: string): any
	for _, e in list do
		if e.uid == uid then
			return e
		end
	end
	return nil
end

local function actions(buttons: { Action }, label: string?)
	clear(actionBar)
	actionBar.Visible = #buttons > 0
	if #buttons == 0 then
		return
	end
	Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right).Parent = actionBar
	if label then
		Ui.label(label, 15, {
			Size = UDim2.new(1, -#buttons * 118, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			LayoutOrder = 0,
			Parent = actionBar,
		})
	end
	for i, b in buttons do
		local button = Ui.button(b.text, b.style, UDim2.new(0, 110, 1, 0), b.fn)
		button.TextSize = 16
		button.LayoutOrder = i
		Ui.setEnabled(button, b.enabled)
		button.Parent = actionBar
	end
end

-- ─── tabs ──────────────────────────────────────────────────────────────────

local function byValue(list: { any }): { any }
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		return Items.value(a.id, a.mutation) > Items.value(b.id, b.mutation)
	end)
	return sorted
end

local function renderBag(state: any)
	local inHideout = player:GetAttribute("InHideout") == true
	local atHome = player:GetAttribute("InOwnHouse") == true
	local total = 0
	for _, e in state.backpack do
		total += Items.value(e.id, e.mutation)
	end
	local items = byValue(state.backpack)
	local fill = #state.backpack / math.max(state.capacity, 1)
	local best = items[1]
	statTiles(1, {
		{
			"Backpack",
			`{#state.backpack} / {state.capacity}`,
			fill,
			if fill >= 1 then C.danger elseif fill >= 0.75 then C.accent else C.safe,
		},
		{ "Worth", Ui.money(total), nil, C.accent },
		{
			"Best find",
			if best then Items.label(best.id, best.mutation) else "Nothing yet",
			nil,
			if best then Items.Rarities[Items.ById[best.id].rarity].color else C.muted,
		},
	})
	if #state.backpack == 0 then
		note("Search dumpsters to fill your backpack. Heavier bags usually hold better stuff.", 2)
	end
	local g = grid(3, 176)
	for i, e in items do
		itemCard(g, i, e.id, e.mutation, { selectable = { uid = e.uid, from = "backpack" } })
	end
	for i = #items + 1, state.capacity do
		emptySlot(g, i)
	end

	-- House storage (the chest in your house); the best of it is on show.
	if atHome then
		heading("House storage", 14, `{#state.home}/{state.storage} · ♥ {state.likes}`)
		if #state.home == 0 then
			note(
				"Store finds here to keep them safe. Your most valuable ones stand on the pedestals.",
				15
			)
		end
		local h = grid(16, 176)
		for i, e in state.home do
			itemCard(h, i, e.id, e.mutation, { selectable = { uid = e.uid, from = "home" } })
		end
	end
	if not inHideout and not atHome then
		note("Sell at the Hideout. Keep things in your house's storage (Sunset Ln).", 13)
	end

	local sel = selected
	local bagEntry = sel and sel.from == "backpack" and find(state.backpack, sel.uid)
	local homeEntry = sel and sel.from == "home" and find(state.home, sel.uid)
	if bagEntry then
		local e = bagEntry
		local buttons: { Action } = {}
		if inHideout then
			table.insert(buttons, {
				text = "Sell",
				style = "primary",
				enabled = true,
				fn = function()
					selected = nil
					Store.action("sell", e.uid)
				end,
			})
		end
		if atHome then
			table.insert(buttons, {
				text = "Store",
				style = "secondary",
				enabled = #state.home < state.storage,
				fn = function()
					selected = nil
					Store.action("homeDisplay", e.uid)
				end,
			})
		end
		if trunkOpen then
			table.insert(buttons, {
				text = "To trunk",
				style = "secondary",
				enabled = #state.trunk < state.trunkCapacity,
				fn = function()
					selected = nil
					Store.action("toTrunk", e.uid)
				end,
			})
		end
		actions(
			buttons,
			`{Items.label(e.id, e.mutation)} · {Ui.money(Items.value(e.id, e.mutation))}`
		)
		if #buttons == 0 then
			actions({}, nil)
		end
	elseif homeEntry then
		local e = homeEntry
		actions({
			{
				text = "Take back",
				style = "secondary",
				enabled = #state.backpack < state.capacity,
				fn = function()
					selected = nil
					Store.action("homeTake", e.uid)
				end,
			},
		}, Items.label(e.id, e.mutation))
	else
		selected = nil
		local buttons: { Action } = {}
		if inHideout and #state.backpack > 0 then
			table.insert(buttons, {
				text = "Sell all",
				style = "primary",
				enabled = true,
				fn = function()
					Store.action("sell", "all")
				end,
			})
		end
		if trunkOpen and #state.backpack > 0 then
			table.insert(buttons, {
				text = "Stash all",
				style = "secondary",
				enabled = true,
				fn = function()
					Store.action("toTrunk", "all")
				end,
			})
		end
		actions(buttons, if #buttons > 0 then "Tap an item for options" else nil)
	end
end

local function renderTrunk(state: any)
	local total = 0
	for _, e in state.trunk do
		total += Items.value(e.id, e.mutation)
	end
	local fill = #state.trunk / math.max(state.trunkCapacity, 1)
	statTiles(1, {
		{
			"Trunk",
			`{#state.trunk} / {state.trunkCapacity}`,
			fill,
			if fill >= 1 then C.danger elseif fill >= 0.75 then C.accent else C.safe,
		},
		{ "Worth", Ui.money(total), nil, C.accent },
	})
	note("Safe from the guards. Park within reach of a hideout to sell the whole trunk.", 2)
	local g = grid(4, 176)
	local items = byValue(state.trunk)
	for i, e in items do
		itemCard(g, i, e.id, e.mutation, { selectable = { uid = e.uid, from = "trunk" } })
	end
	for i = #items + 1, state.trunkCapacity do
		emptySlot(g, i)
	end
	local sel = selected
	local entry = sel and sel.from == "trunk" and find(state.trunk, sel.uid)
	if entry then
		local e = entry
		actions({
			{
				text = "To backpack",
				style = "secondary",
				enabled = #state.backpack < state.capacity,
				fn = function()
					selected = nil
					Store.action("fromTrunk", e.uid)
				end,
			},
		}, Items.label(e.id, e.mutation))
	else
		selected = nil
		actions({
			{
				text = "Stash all",
				style = "secondary",
				enabled = #state.backpack > 0,
				fn = function()
					Store.action("toTrunk", "all")
				end,
			},
			{
				text = "Sell trunk",
				style = "primary",
				enabled = #state.trunk > 0 and player:GetAttribute("InHideout") == true,
				fn = function()
					Store.action("sellTrunk")
				end,
			},
		}, nil)
	end
end

-- Row in the shop: name, description, and one action button on the right.

local function renderBook(state: any)
	actions({}, nil)
	local found = 0
	for _, item in Items.List do
		if state.collection[item.id] then
			found += 1
		end
	end
	-- Milestone track: each reward as a node along one bar.
	local track = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Color3.fromRGB(34, 37, 43),
		LayoutOrder = 1,
		Parent = body,
	}, { Ui.corner(12), Ui.stroke(1, C.panelLight) })
	Ui.label("COLLECTION", 11, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(0.5, 0, 0, 14),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = track,
	})
	Ui.label(`{found} / {#Items.List} found`, 20, {
		Position = UDim2.fromOffset(14, 25),
		Size = UDim2.new(0.6, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = track,
	})
	local last = Config.Milestones[#Config.Milestones].found
	local bar = Ui.new("Frame", {
		Position = UDim2.new(0, 14, 1, -30),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = C.panelLight,
		Parent = track,
	}, { Ui.corner(3) })
	Ui.new("Frame", {
		Size = UDim2.fromScale(math.clamp(found / last, 0, 1), 1),
		BackgroundColor3 = C.accent,
		Parent = bar,
	}, { Ui.corner(3) })
	for _, m in Config.Milestones do
		local done = found >= m.found
		local x = m.found / last
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = if done then C.accent else Color3.fromRGB(34, 37, 43),
			Parent = bar,
		}, { Ui.corner(7), Ui.stroke(2, if done then C.accent else C.panelLight) })
		Ui.label(Ui.money(m.cash), 11, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 0, -6),
			Size = UDim2.fromOffset(60, 12),
			TextColor3 = if done then C.accent else C.muted,
			Parent = bar,
		})
	end
	note("Shiny and Golden versions are tracked too.", 2)

	local cities = {}
	for id, city in Config.Cities do
		table.insert(cities, { id = id, name = city.name, order = city.order })
	end
	table.sort(cities, function(a, b)
		return a.order < b.order
	end)
	local order = 3
	for _, city in cities do
		local list, have = {}, 0
		for _, item in Items.List do
			if (item.city or "maple") == city.id then
				table.insert(list, item)
				if state.collection[item.id] then
					have += 1
				end
			end
		end
		heading(city.name, order, `{have}/{#list} · {math.floor(have / #list * 100)}%`)
		local g = grid(order + 1, 176)
		order += 2
		for i, item in list do
			local marks = {}
			for _, m in Items.Mutations do
				if state.collection[Items.collectionKey(item.id, m.id)] then
					table.insert(marks, m.name)
				end
			end
			itemCard(g, i, item.id, nil, {
				silhouette = not state.collection[item.id],
				caption = if #marks > 0 then "Also " .. table.concat(marks, " + ") else nil,
			})
		end
	end
end
function Panels.render()
	if not current then
		return
	end
	for _, tab in TABS do
		local b = tabButtons[tab]
		local on = tab == current
		b.BackgroundColor3 = if on then C.cream else C.panelLight
		b.TextColor3 = if on then C.ink else C.cream
		b.BackgroundTransparency = if on then 0 else 0.4
	end
	local scroll = body.CanvasPosition
	clear(body)
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = body
	local state = Store.get()
	if not state then
		note("Loading your stuff...", 1)
		actions({}, nil)
		return
	end
	if current == "bag" then
		renderBag(state)
	elseif current == "trunk" then
		renderTrunk(state)
	else
		renderBook(state)
	end
	body.CanvasPosition = scroll
end

local function open(which: string)
	if which == "trunk" and not trunkOpen then
		which = "bag" -- the trunk is opened at the car, not from a menu
	end
	if current == which and window.Visible then
		current = nil
		window.Visible = false
		return
	end
	local switched = current ~= which
	if switched then
		selected = nil
	end
	current = which
	tabButtons.trunk.Visible = trunkOpen
	window.Visible = true
	Ui.pop(window, 0.92)
	Panels.render()
	if switched then
		-- After the layout has sized the new content.
		task.defer(function()
			body.CanvasPosition = Vector2.zero
		end)
	end
end

local function close()
	trunkOpen, trunkCar = false, nil
	current = nil
	selected = nil
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
		Size = UDim2.fromScale(0.94, 0.86),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(620, 680) }).Parent = window
	window.BackgroundTransparency = 0.03

	-- Segmented tabs.
	local tabs = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -96, 0, 46),
		Parent = window,
	}, {
		Ui.corner(12),
		Ui.padding(4),
		Ui.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center),
	})
	for i, tab in TABS do
		local b: TextButton = Ui.new("TextButton", {
			Text = TAB_NAMES[tab],
			Font = Ui.FONT,
			TextSize = 16,
			TextColor3 = C.cream,
			BackgroundColor3 = C.panelLight,
			BackgroundTransparency = 0.4,
			AutoButtonColor = true,
			Size = UDim2.new(1 / #TABS, -4, 1, 0),
			LayoutOrder = i,
			Parent = tabs,
		}, { Ui.corner(9) })
		b.Activated:Connect(function()
			if current ~= tab then
				open(tab)
			end
		end)
		tabButtons[tab] = b
	end
	local closeButton = Ui.button("Close", "secondary", UDim2.fromOffset(72, 46), close)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 12)
	closeButton.TextSize = 15
	closeButton.Parent = window

	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 1, -146),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }).Parent =
		body

	actionBar = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.new(1, -32, 0, 50),
		Visible = false,
		Parent = window,
	})
end

function Panels.init()
	build()
	Ui.autoScale(gui)
end

function Panels.start()
	Store.on("openPanel", open)
	Store.on("state", Panels.render)
	for _, attr in { "InHideout", "InOwnHouse" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if current then
				Panels.render()
			end
		end)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SellPrompt" or prompt.Name == "StoragePrompt" then
			open("bag")
		elseif prompt.Name == "TrunkPrompt" then
			local car = prompt:FindFirstAncestorWhichIsA("Model")
			while car and car.Parent and car.Parent.Name ~= "PlayerCars" do
				car = car:FindFirstAncestorWhichIsA("Model")
			end
			if car and car:GetAttribute("Owner") == player.UserId then
				trunkOpen, trunkCar = true, car
				open("trunk")
			end
		end
	end)
	-- The trunk closes once the player walks away from the car.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if trunkOpen then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local car = trunkCar
				if
					not root
					or not car
					or not car.Parent
					or (car:GetPivot().Position - root.Position).Magnitude > 22
				then
					close()
				end
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
