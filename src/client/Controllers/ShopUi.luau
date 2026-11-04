--!strict
-- Store windows, separate from the Bag/Book window. A store counter opens
-- that store's stock; the Shop button (Shop Anywhere pass) opens every store;
-- the R$ button opens the Robux shop. The server re-checks the counter
-- distance (or the pass) on every purchase.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

type Mode = { kind: string, id: string? } -- kind: "store" | "anywhere" | "robux"

local ACCENT = {
	gear = Color3.fromRGB(230, 90, 60),
	cars = Color3.fromRGB(60, 140, 240),
	house = Color3.fromRGB(70, 190, 130),
	robux = Color3.fromRGB(80, 200, 120),
}
local SUBTITLE = {
	gear = "Tools and bigger backpacks",
	cars = "Faster cars with bigger trunks",
	house = "Homes on Sunset Ln",
	robux = "Convenience only. Robux never buys loot or luck.",
}

local ShopUi = {}

local gui: ScreenGui
local window: Frame
local stripe: Frame
local title: TextLabel
local subtitle: TextLabel
local cashLabel: TextLabel
local body: ScrollingFrame
local mode: Mode? = nil

-- ─── building blocks ──────────────────────────────────────────────────────

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	Ui.list(Enum.FillDirection.Vertical, 10).Parent = body
end

local function section(text: string, order: number)
	Ui.label(string.upper(text), 12, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
end

-- One product: a coloured icon tile, name and detail, and a price button.
local function product(
	order: number,
	tile: { color: Color3, text: string },
	name: string,
	detail: string,
	buttonText: string,
	enabled: boolean,
	fn: () -> ()
)
	local card = Ui.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(34, 37, 43),
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = order,
		Parent = body,
	}, { Ui.corner(14), Ui.stroke(1, C.panelLight) })
	local icon = Ui.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = tile.color,
		Parent = card,
	}, { Ui.corner(12) })
	Ui.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		Parent = icon,
	})
	Ui.label(tile.text, 20, { Size = UDim2.fromScale(1, 1), TextColor3 = C.ink, Parent = icon })
	Ui.label(name, 17, {
		Position = UDim2.fromOffset(80, 14),
		Size = UDim2.new(1, -220, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = card,
	})
	Ui.label(detail, 13, {
		Position = UDim2.fromOffset(80, 38),
		Size = UDim2.new(1, -220, 0, 30),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local button = Ui.button(buttonText, "primary", UDim2.fromOffset(122, 46), fn)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	button.TextSize = 16
	Ui.setEnabled(button, enabled)
	button.Parent = card
end

local function initials(name: string): string
	local out = ""
	for word in name:gmatch("%a+") do
		out ..= word:sub(1, 1)
	end
	return out:sub(1, 2):upper()
end

-- ─── stock per store kind ─────────────────────────────────────────────────

local function cityOf(storeId: string?): string?
	local store = storeId and Config.Stores[storeId]
	return if store then store.city or "maple" else nil
end

local function renderGear(state: any, city: string?, order: number): number
	section("Tools", order)
	local tools = {}
	for id, t in Config.Tools do
		if city == nil or (t.city or "maple") == city then
			table.insert(tools, { id = id, t = t })
		end
	end
	table.sort(tools, function(a, b)
		return a.t.order < b.t.order
	end)
	for i, entry in tools do
		local owned = state.tools[entry.id] == true
		product(
			order + i,
			{ color = ACCENT.gear, text = initials(entry.t.name) },
			entry.t.name,
			entry.t.desc,
			if owned then "Owned" else Ui.money(entry.t.price),
			not owned and state.cash >= entry.t.price,
			function()
				Store.action("buyTool", entry.id)
			end
		)
	end
	order += #tools + 2
	section("Backpack", order)
	local up = state.nextUpgrade
	if up then
		product(
			order + 1,
			{ color = Color3.fromRGB(240, 190, 70), text = tostring(up.capacity) },
			"Bigger backpack",
			`{state.capacity} to {up.capacity} slots`,
			Ui.money(up.price),
			state.cash >= up.price,
			function()
				Store.action("buyUpgrade")
			end
		)
	else
		product(
			order + 1,
			{ color = Color3.fromRGB(240, 190, 70), text = tostring(state.capacity) },
			"Backpack maxed out",
			`{state.capacity} slots`,
			"Owned",
			false,
			function() end
		)
	end
	return order + 3
end

local function renderCars(state: any, city: string?, order: number): number
	section("Cars", order)
	local i = 0
	for _, car in Config.Cars do
		local owned = state.ownedCars[car.id] == true
		-- A dealer sells its own city's cars; owned cars can be picked anywhere.
		if city and (car.city or "maple") ~= city and not owned then
			continue
		end
		i += 1
		local driving = state.car == car.id
		product(
			order + i,
			{ color = car.color, text = tostring(car.trunk) },
			car.name,
			`Trunk {car.trunk} · {math.floor(car.top * 0.6)} mph · {car.nitro}s nitro`,
			if driving then "Selected" elseif owned then "Use" else Ui.money(car.price),
			not driving and (owned or state.cash >= car.price),
			function()
				Store.action("buyCar", car.id)
			end
		)
	end
	return order + i + 2
end

local function renderHouses(state: any, order: number): number
	section("Homes", order)
	for i, house in Config.Houses do
		local owned = state.houseLevel >= i
		local isNext = state.houseLevel + 1 == i
		product(
			order + i,
			{ color = ACCENT.house, text = tostring(house.slots) },
			house.name,
			`{house.slots} pedestals to show off your finds`,
			if owned then "Owned" elseif isNext then Ui.money(house.price) else "Locked",
			isNext and state.cash >= house.price,
			function()
				Store.action("buyHouse")
			end
		)
	end
	return order + #Config.Houses + 2
end

local function renderRobux(state: any, order: number): number
	section("Game passes", order)
	local i = 0
	for key, pass in Config.Robux.Passes do
		i += 1
		local owned = state.passes[key] == true
		product(
			order + i,
			{ color = ACCENT.robux, text = "R$" },
			pass.name,
			pass.desc,
			if owned then "Owned" elseif pass.id == 0 then "Coming soon" else `R$ {pass.price}`,
			not owned and pass.id ~= 0,
			function()
				Store.action("robux", key)
			end
		)
	end
	order += i + 2
	section("Cash packs", order)
	local k = 0
	for key, p in Config.Robux.Products do
		k += 1
		product(
			order + k,
			{ color = Color3.fromRGB(240, 190, 70), text = "$" },
			p.name,
			`Adds {Ui.money(p.cash)} cash`,
			if p.id == 0 then "Coming soon" else `R$ {p.price}`,
			p.id ~= 0,
			function()
				Store.action("robux", key)
			end
		)
	end
	return order + k + 2
end

-- ─── window ───────────────────────────────────────────────────────────────

function ShopUi.render()
	local m = mode
	local state = Store.get()
	if not m or not state then
		return
	end
	local scroll = body.CanvasPosition
	clear()
	cashLabel.Text = Ui.money(state.cash)
	local accent, heading, sub
	if m.kind == "robux" then
		accent, heading, sub = ACCENT.robux, "Robux Shop", SUBTITLE.robux
		renderRobux(state, 1)
	elseif m.kind == "anywhere" then
		accent, heading, sub = C.accent, "Shop Anywhere", "Every store, wherever you are"
		local order = renderGear(state, nil, 1)
		order = renderCars(state, nil, order)
		renderHouses(state, order)
	else
		local store = Config.Stores[m.id or ""]
		if not store then
			return
		end
		accent, heading, sub =
			ACCENT[store.sells] or C.accent, store.name, SUBTITLE[store.sells] or ""
		local city = cityOf(m.id)
		if store.sells == "gear" then
			renderGear(state, city, 1)
		elseif store.sells == "cars" then
			renderCars(state, city, 1)
		else
			renderHouses(state, 1)
		end
	end
	stripe.BackgroundColor3 = accent
	title.Text = heading
	subtitle.Text = sub
	body.CanvasPosition = scroll
end

local function close()
	mode = nil
	window.Visible = false
end

local function open(m: Mode)
	mode = m
	window.Visible = true
	Ui.pop(window, 0.92)
	ShopUi.render()
	task.defer(function()
		body.CanvasPosition = Vector2.zero
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.03
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 640) }).Parent = window
	stripe = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = C.accent,
		BorderSizePixel = 0,
		Parent = window,
	}, { Ui.corner(3) })
	title = Ui.label("", 24, {
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.new(1, -220, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = window,
	})
	subtitle = Ui.label("", 13, {
		Position = UDim2.fromOffset(20, 48),
		Size = UDim2.new(1, -220, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local cashPill = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 20),
		Size = UDim2.fromOffset(110, 36),
		BackgroundColor3 = Color3.fromRGB(34, 37, 43),
		Parent = window,
	}, { Ui.corner(18), Ui.stroke(1, C.panelLight) })
	cashLabel =
		Ui.label("", 17, { Size = UDim2.fromScale(1, 1), TextColor3 = C.accent, Parent = cashPill })
	local closeButton = Ui.button("Close", "secondary", UDim2.fromOffset(72, 40), close)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 18)
	closeButton.TextSize = 15
	closeButton.Parent = window
	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 80),
		Size = UDim2.new(1, -32, 1, -96),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }).Parent =
		body
end

function ShopUi.init()
	build()
	Ui.autoScale(gui)
end

function ShopUi.start()
	Store.on("openShop", function(m: Mode)
		if mode and window.Visible and mode.kind == m.kind and mode.id == m.id then
			close()
		else
			open(m)
		end
	end)
	Store.on("state", ShopUi.render)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= "StorePrompt" then
			return
		end
		local id = prompt.Parent and prompt.Parent:GetAttribute("Store")
		if typeof(id) == "string" and Config.Stores[id] then
			open({ kind = "store", id = id })
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and mode then
			close()
		end
	end)
	-- A store window closes once you walk away from its counter.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local m = mode
			local state = Store.get()
			if m and m.kind == "store" and not (state and state.passes.shopanywhere) then
				local store = Config.Stores[m.id or ""]
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if
					not store
					or not root
					or (root.Position - store.counter).Magnitude > store.range + 8
				then
					close()
				end
			end
		end
	end)
end

return ShopUi
