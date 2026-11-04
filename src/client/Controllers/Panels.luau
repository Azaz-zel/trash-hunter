--!strict
-- One window with four tabs: Bag, Trunk, Shop, Book. Items are shown as
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

local TABS = { "bag", "trunk", "shop", "book" }
-- What the shop tab lists: "gear", "cars" or "robux" at a store counter or
-- the R$ button; nil (everything) only with the Shop Anywhere pass.
local storeFilter: string? = nil
-- City of the store counter that opened the shop (nil: every city).
local storeCity: string? = nil
local STORE_TAB = { gear = "Hardware", cars = "Motors", house = "Realty" }
local TAB_NAMES = { bag = "Bag", trunk = "Trunk", shop = "Shop", book = "Book" }

type Action = { text: string, style: string, enabled: boolean, fn: () -> () }

local Panels = {}

local gui: ScreenGui
local window: Frame
local tabButtons: { [string]: TextButton } = {}
local body: ScrollingFrame
local actionBar: Frame
local current: string? = nil
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
	local isSelected = selected ~= nil
		and sel ~= nil
		and selected.uid == sel.uid
		and selected.from == sel.from
	local card: TextButton = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = sel ~= nil,
		BackgroundColor3 = if opts.silhouette then C.panel else C.panelLight,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(12) })
	local strokeColor = if isSelected then C.cream elseif opts.silhouette then nil else rarity.color
	local stroke = Ui.stroke(if isSelected then 2 else 1, strokeColor)
	if not isSelected and not opts.silhouette then
		stroke.Transparency = 0.55
	end
	stroke.Parent = card
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -48),
		BackgroundTransparency = 1,
		Parent = card,
	})
	ItemModels.show(vp, itemId, mutation, opts.silhouette)
	Ui.label(if opts.silhouette then "???" else Items.label(itemId, mutation), 14, {
		Position = UDim2.new(0, 8, 1, -42),
		Size = UDim2.new(1, -16, 0, 18),
		TextColor3 = if opts.silhouette then C.muted else C.cream,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	Ui.label(opts.caption or rarity.name, 13, {
		Position = UDim2.new(0, 8, 1, -23),
		Size = UDim2.new(1, -16, 0, 16),
		TextColor3 = if opts.silhouette
			then C.muted
			elseif opts.caption then C.accent
			else rarity.color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	if sel then
		card.Activated:Connect(function()
			selected = if isSelected then nil else { uid = sel.uid, from = sel.from }
			Panels.render()
		end)
	end
	return card
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

local function renderBag(state: any)
	local inHideout = player:GetAttribute("InHideout") == true
	local total = 0
	for _, e in state.backpack do
		total += Items.value(e.id, e.mutation)
	end
	heading("Backpack", 1, `{#state.backpack}/{state.capacity} · {Ui.money(total)}`)
	if #state.backpack == 0 then
		note("Your backpack is empty. Search dumpsters to find stuff.", 2)
	end
	local g = grid(3, 150)
	for i, e in state.backpack do
		itemCard(g, i, e.id, e.mutation, {
			selectable = { uid = e.uid, from = "backpack" },
			caption = Ui.money(Items.value(e.id, e.mutation)),
		})
	end
	heading("Display shelf", 10, `{#state.shelf}/{state.shelfSlots}`)
	if #state.shelf == 0 then
		note(
			"Display your best finds at the Hideout. Other players can see them; they are kept, not sold.",
			11
		)
	end
	local s = grid(12, 150)
	for i, e in state.shelf do
		itemCard(s, i, e.id, e.mutation, { selectable = { uid = e.uid, from = "shelf" } })
	end
	local atHome = player:GetAttribute("InOwnHouse") == true
	local homeSlots = if state.houseLevel > 0 then Config.Houses[state.houseLevel].slots else 0
	if state.houseLevel > 0 then
		heading("House pedestals", 14, `{#state.home}/{homeSlots} · ♥ {state.likes}`)
		if not atHome then
			note("Stand inside your house on Sunset Lane to change the pedestals.", 15)
		end
		local h = grid(16, 150)
		for i, e in state.home do
			itemCard(h, i, e.id, e.mutation, { selectable = { uid = e.uid, from = "home" } })
		end
	end
	if not inHideout then
		note("Selling and displaying work at the Hideout.", 13)
	end

	local sel = selected
	local bagEntry = sel and sel.from == "backpack" and find(state.backpack, sel.uid)
	local shelfEntry = sel and sel.from == "shelf" and find(state.shelf, sel.uid)
	local homeEntry = sel and sel.from == "home" and find(state.home, sel.uid)
	if bagEntry then
		local e = bagEntry
		actions({
			{
				text = "Sell",
				style = "primary",
				enabled = inHideout,
				fn = function()
					selected = nil
					Store.action("sell", e.uid)
				end,
			},
			if atHome
				then {
					text = "Pedestal",
					style = "secondary",
					enabled = #state.home < homeSlots,
					fn = function()
						selected = nil
						Store.action("homeDisplay", e.uid)
					end,
				}
				else {
					text = "Display",
					style = "secondary",
					enabled = inHideout and #state.shelf < state.shelfSlots,
					fn = function()
						selected = nil
						Store.action("display", e.uid)
					end,
				},
			{
				text = "To trunk",
				style = "secondary",
				enabled = true,
				fn = function()
					selected = nil
					Store.action("toTrunk", e.uid)
				end,
			},
		}, `{Items.label(e.id, e.mutation)} · {Ui.money(Items.value(e.id, e.mutation))}`)
	elseif homeEntry then
		local e = homeEntry
		actions({
			{
				text = "Take back",
				style = "secondary",
				enabled = atHome and #state.backpack < state.capacity,
				fn = function()
					selected = nil
					Store.action("homeTake", e.uid)
				end,
			},
		}, Items.label(e.id, e.mutation))
	elseif shelfEntry then
		local e = shelfEntry
		actions({
			{
				text = "Take back",
				style = "secondary",
				enabled = inHideout and #state.backpack < state.capacity,
				fn = function()
					selected = nil
					Store.action("undisplay", e.uid)
				end,
			},
		}, Items.label(e.id, e.mutation))
	else
		selected = nil
		if #state.backpack > 0 then
			actions({
				{
					text = "Sell all",
					style = "primary",
					enabled = inHideout,
					fn = function()
						Store.action("sell", "all")
					end,
				},
				{
					text = "Stash all",
					style = "secondary",
					enabled = true,
					fn = function()
						Store.action("toTrunk", "all")
					end,
				},
			}, "Tap an item for options")
		else
			actions({}, nil)
		end
	end
end

local function renderTrunk(state: any)
	local total = 0
	for _, e in state.trunk do
		total += Items.value(e.id, e.mutation)
	end
	heading("Trunk", 1, `{#state.trunk}/{state.trunkCapacity} · {Ui.money(total)}`)
	note(
		"Items in your trunk are safe from the guards. Stand next to your car to load or unload; park at the Hideout to sell from the trunk.",
		2
	)
	if #state.trunk == 0 then
		note("Your trunk is empty.", 3)
	end
	local g = grid(4, 150)
	for i, e in state.trunk do
		itemCard(g, i, e.id, e.mutation, {
			selectable = { uid = e.uid, from = "trunk" },
			caption = Ui.money(Items.value(e.id, e.mutation)),
		})
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
local function shopRow(
	order: number,
	name: string,
	desc: string,
	buttonText: string,
	style: string,
	enabled: boolean,
	fn: () -> ()
)
	local row = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = order,
		Parent = body,
	}, { Ui.corner(12), Ui.stroke() })
	Ui.label(name, 17, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -150, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT,
		Parent = row,
	})
	Ui.label(desc, 14, {
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -150, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = row,
	})
	local button = Ui.button(buttonText, style, UDim2.fromOffset(124, 44), fn)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.TextSize = 16
	Ui.setEnabled(button, enabled)
	button.Parent = row
end

local function renderGear(state: any, atCounter: boolean)
	local tools = {}
	for id, t in Config.Tools do
		table.insert(tools, { id = id, t = t })
	end
	table.sort(tools, function(a, b)
		return a.t.order < b.t.order
	end)
	for i, entry in tools do
		if storeCity and (entry.t.city or "maple") ~= storeCity then
			continue
		end
		local owned = state.tools[entry.id] == true
		local text = if owned then "Owned" else Ui.money(entry.t.price)
		local can = not owned and atCounter and state.cash >= entry.t.price
		shopRow(2 + i, entry.t.name, entry.t.desc, text, "primary", can, function()
			Store.action("buyTool", entry.id)
		end)
	end

	heading("Backpack", 20, `{state.capacity} slots`)
	local up = state.nextUpgrade
	if up then
		local can = atCounter and state.cash >= up.price
		shopRow(
			21,
			"Bigger backpack",
			`{state.capacity} to {up.capacity} slots`,
			Ui.money(up.price),
			"primary",
			can,
			function()
				Store.action("buyUpgrade")
			end
		)
	else
		note("Your backpack is maxed out.", 21)
	end
end

local function renderCars(state: any, atCounter: boolean)
	heading("Cars", 30, Ui.money(state.cash))
	for i, car in Config.Cars do
		local owned = state.ownedCars[car.id] == true
		-- A dealer sells its own city's cars; owned cars can be picked anywhere.
		if storeCity and (car.city or "maple") ~= storeCity and not owned then
			continue
		end
		local driving = state.car == car.id
		local text = if driving then "Selected" elseif owned then "Use" else Ui.money(car.price)
		local can = not driving and atCounter and (owned or state.cash >= car.price)
		shopRow(
			30 + i,
			car.name,
			`Trunk holds {car.trunk} items`,
			text,
			if owned then "secondary" else "primary",
			can,
			function()
				Store.action("buyCar", car.id)
			end
		)
	end
end

local function renderRobux(state: any)
	heading("Robux", 50, "Convenience only")
	local order = 51
	for key, pass in Config.Robux.Passes do
		local owned = state.passes[key] == true
		local text = if owned
			then "Owned"
			elseif pass.id == 0 then "Coming soon"
			else `R$ {pass.price}`
		shopRow(order, pass.name, pass.desc, text, "primary", not owned and pass.id ~= 0, function()
			Store.action("robux", key)
		end)
		order += 1
	end
	for key, product in Config.Robux.Products do
		local text = if product.id == 0 then "Coming soon" else `R$ {product.price}`
		shopRow(
			order,
			product.name,
			`Adds {Ui.money(product.cash)} cash`,
			text,
			"primary",
			product.id ~= 0,
			function()
				Store.action("robux", key)
			end
		)
		order += 1
	end
end

local function renderHouses(state: any)
	heading("Sunset Lane homes", 2, Ui.money(state.cash))
	note("Show off your best finds on pedestals. Visitors can like your house.", 3)
	for i, house in Config.Houses do
		local owned = state.houseLevel >= i
		local isNext = state.houseLevel + 1 == i
		local text = if owned then "Owned" elseif isNext then Ui.money(house.price) else "Locked"
		shopRow(
			3 + i,
			house.name,
			`{house.slots} pedestals`,
			text,
			"primary",
			isNext and state.cash >= house.price,
			function()
				Store.action("buyHouse")
			end
		)
	end
end

local function renderShop(state: any)
	-- The server re-checks the store distance on every purchase.
	local atCounter = storeFilter ~= nil or state.passes.shopanywhere == true
	local function shows(kind: string): boolean
		return storeFilter == nil or storeFilter == kind
	end
	actions({}, nil)

	if shows("gear") then
		renderGear(state, atCounter)
	end
	if shows("cars") then
		renderCars(state, atCounter)
	end
	if storeFilter == "house" then
		renderHouses(state)
	end
	if shows("robux") then
		renderRobux(state)
	end
end

local function renderBook(state: any)
	actions({}, nil)
	local found = 0
	for _, item in Items.List do
		if state.collection[item.id] then
			found += 1
		end
	end
	local nextReward = nil
	for _, m in Config.Milestones do
		if found < m.found then
			nextReward = m
			break
		end
	end
	heading("Collection", 1, `{found}/{#Items.List} found`)
	if nextReward then
		note(
			`Find {nextReward.found - found} more to earn {Ui.money(nextReward.cash)}. Shiny and Golden versions are tracked too.`,
			2
		)
	else
		note("Every item found. Hunt for Shiny and Golden versions.", 2)
	end
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
		heading(city.name, order, `{have}/{#list}`)
		local g = grid(order + 1, 150)
		order += 2
		for i, item in list do
			local known = state.collection[item.id] == true
			local marks = {}
			for _, m in Items.Mutations do
				if state.collection[Items.collectionKey(item.id, m.id)] then
					table.insert(marks, m.name)
				end
			end
			itemCard(g, i, item.id, nil, {
				silhouette = not known,
				caption = if #marks > 0 then table.concat(marks, " + ") else nil,
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
	elseif current == "shop" then
		renderShop(state)
	else
		renderBook(state)
	end
	body.CanvasPosition = scroll
end

local function open(which: string, filter: string?)
	if which == "robux" then
		which, filter = "shop", "robux"
	end
	if current == which and window.Visible and storeFilter == filter then
		current = nil
		window.Visible = false
		return
	end
	local switched = current ~= which
	if switched then
		selected = nil
	end
	current = which
	storeFilter = filter
	storeCity = nil
	local state = Store.get()
	local anywhere = state ~= nil and state.passes.shopanywhere == true
	tabButtons.shop.Visible = anywhere or which == "shop"
	tabButtons.shop.Text = if filter == "robux"
		then "R$"
		elseif filter then STORE_TAB[filter] or TAB_NAMES.shop
		else TAB_NAMES.shop
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
				open(tab, if tab == "shop" then storeFilter else nil)
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
		if prompt.Name == "SellPrompt" then
			open("bag")
		elseif prompt.Name == "StorePrompt" then
			local store = Config.Stores[prompt.Parent and prompt.Parent:GetAttribute("Store") or ""]
			if store then
				open("shop", store.sells)
				storeCity = store.city or "maple"
				Panels.render()
			end
		elseif prompt.Name == "TrunkPrompt" then
			local car = prompt:FindFirstAncestorWhichIsA("Model")
			while car and car.Parent and car.Parent.Name ~= "PlayerCars" do
				car = car:FindFirstAncestorWhichIsA("Model")
			end
			if car and car:GetAttribute("Owner") == player.UserId then
				open("trunk")
			end
		end
	end)
	-- A store view closes once the player walks away from that counter.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local state = Store.get()
			if
				current == "shop"
				and (storeFilter == "gear" or storeFilter == "cars" or storeFilter == "house")
				and not (state and state.passes.shopanywhere)
			then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local near = false
				for _, store in Config.Stores do
					if
						root
						and store.sells == storeFilter
						and (root.Position - store.counter).Magnitude <= store.range + 6
					then
						near = true
					end
				end
				if not near then
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
