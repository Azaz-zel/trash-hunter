--!strict
-- Always-on HUD: cash, backpack, suspicion bar, chase banner, Drop & Run,
-- toasts, big-find announcements and the BUSTED screen.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local SU = Config.Suspicion

local Hud = {}

local gui: ScreenGui
local cashLabel: TextLabel
local bagLabel: TextLabel
local suspicionFrame: Frame
local suspicionFill: Frame
local suspicionText: TextLabel
local chaseBanner: TextLabel
local dropButton: TextButton
local toastHolder: Frame
local announceLabel: TextLabel
local busted: Frame
local bustedBody: TextLabel
local homeButton: TextButton
local shopButton: TextButton

local function pill(name: string, caption: string, order: number): TextLabel
	local frame = Ui.panel({
		Name = name,
		Size = UDim2.fromOffset(124, 52),
		LayoutOrder = order,
	})
	Ui.label(string.upper(caption), 12, {
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -28, 0, 14),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local label = Ui.label("", 22, {
		Position = UDim2.fromOffset(14, 21),
		Size = UDim2.new(1, -28, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label.Parent = frame
	return label
end

local function toast(text: string, color: Color3?)
	local label = Ui.label(text, 20, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = Ui.PANEL_ALPHA,
		BackgroundColor3 = C.panel,
		TextColor3 = color or C.cream,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.corner(10).Parent = label
	Ui.stroke().Parent = label
	Ui.padding(10).Parent = label
	label.Parent = toastHolder
	Ui.pop(label, 0.7)
	local items = toastHolder:GetChildren()
	local labels = {}
	for _, child in items do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 3 then
		labels[1]:Destroy()
	end
	task.delay(2.6, function()
		if label.Parent then
			Ui.tween(label, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.3)
			label:Destroy()
		end
	end)
end

local lastCash: number? = nil
local lastBag: number? = nil

local function renderState()
	local state = Store.get()
	if not state then
		cashLabel.Text = "..."
		bagLabel.Text = "Bag ..."
		return
	end
	Ui.countMoney(cashLabel, state.cash)
	if lastCash and state.cash ~= lastCash then
		Ui.bump(cashLabel.Parent :: GuiObject)
	end
	if lastBag and #state.backpack ~= lastBag then
		Ui.bump(bagLabel.Parent :: GuiObject)
	end
	lastCash, lastBag = state.cash, #state.backpack
	homeButton.Visible = state.passes.homerun == true
	shopButton.Visible = state.passes.shopanywhere == true
	bagLabel.Text = `{#state.backpack}/{state.capacity}`
	bagLabel.TextColor3 = if #state.backpack >= state.capacity then C.accent else C.cream
end

local function renderSuspicion()
	local value = tonumber(player:GetAttribute("Suspicion")) or 0
	local chased = player:GetAttribute("Chased") == true
	local inRed = player:GetAttribute("InRedZone") == true
	local show = chased or value > 0 or inRed
	if show and not suspicionFrame.Visible then
		Ui.pop(suspicionFrame, 0.7)
	end
	suspicionFrame.Visible = show
	Ui.tween(suspicionFill, 0.15, { Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1) })
	if chased then
		suspicionFill.BackgroundColor3 = C.danger
		suspicionText.Text = "SPOTTED!"
	elseif value >= SU.WARN_HIGH then
		suspicionFill.BackgroundColor3 = C.danger
		suspicionText.Text = "Almost spotted!"
	elseif value >= SU.WARN_LOW then
		suspicionFill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
		suspicionText.Text = "The guard is getting suspicious"
	else
		suspicionFill.BackgroundColor3 = C.accent
		suspicionText.Text = if inRed then "Private property" else "Suspicion"
	end
	if chased and not dropButton.Visible then
		Ui.pop(dropButton, 0.6)
		Ui.pop(chaseBanner, 0.6)
	end
	chaseBanner.Visible = chased
	dropButton.Visible = chased
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local stats = Ui.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(300, 52),
		Parent = gui,
	}, { Ui.list(Enum.FillDirection.Horizontal, 10) })
	cashLabel = pill("Cash", "Cash", 1)
	cashLabel.Parent.Parent = stats
	cashLabel.TextColor3 = C.accent
	bagLabel = pill("Bag", "Backpack", 2)
	bagLabel.Parent.Parent = stats

	suspicionFrame = Ui.panel({
		Name = "Suspicion",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(0.6, 0, 0, 58),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(420, 58) }).Parent = suspicionFrame
	suspicionText = Ui.label("Suspicion", 18, {
		Position = UDim2.fromOffset(0, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = suspicionFrame,
	})
	local track = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Position = UDim2.new(0, 10, 0, 30),
		Size = UDim2.new(1, -20, 0, 18),
		Parent = suspicionFrame,
	}, { Ui.corner(6) })
	suspicionFill = Ui.new("Frame", {
		BackgroundColor3 = C.accent,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Ui.corner(6) })
	-- Tick marks at the two warning thresholds.
	for _, at in { SU.WARN_LOW, SU.WARN_HIGH } do
		Ui.new("Frame", {
			BackgroundColor3 = C.ink,
			BorderSizePixel = 0,
			Position = UDim2.new(at / 100, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 2,
			Parent = track,
		})
	end

	chaseBanner = Ui.label("RUN! Get back to the Hideout or lose the guard", 24, {
		Name = "ChaseBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.new(0.9, 0, 0, 40),
		TextColor3 = Color3.fromRGB(255, 120, 110),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Visible = false,
		Parent = gui,
	})

	dropButton = Ui.button(
		"DROP & RUN\nlose half your bag, stop the chase",
		"danger",
		UDim2.fromOffset(300, 72),
		function()
			Store.action("dropAndRun")
		end
	)
	dropButton.Name = "DropAndRun"
	dropButton.AnchorPoint = Vector2.new(0.5, 1)
	dropButton.Position = UDim2.new(0.5, 0, 1, -110)
	dropButton.TextSize = 18
	dropButton.Visible = false
	dropButton.Parent = gui

	toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.new(0.8, 0, 0, 200),
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(460, 200) }),
	})

	announceLabel = Ui.label("", 26, {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(0.9, 0, 0, 36),
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Visible = false,
		Parent = gui,
	})

	-- Side buttons. Keyboard: B for bag, C for collection book.
	local side = Ui.new("Frame", {
		Name = "Side",
		BackgroundTransparency = 1,
		-- Below the minimap (MapUi, 168px at top right).
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 196),
		Size = UDim2.fromOffset(72, 360),
		Parent = gui,
	}, { Ui.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
	local function sideButton(text: string, order: number, fn: () -> ()): TextButton
		local b = Ui.button(text, "secondary", UDim2.fromOffset(72, 52), fn)
		b.TextSize = 16
		b.LayoutOrder = order
		b.Parent = side
		return b
	end
	sideButton("Bag", 1, function()
		Store.emit("openPanel", "bag")
	end)
	-- Without the Shop Anywhere pass, buying happens at the store counters.
	shopButton = sideButton("Shop", 2, function()
		Store.emit("openPanel", "shop")
	end)
	shopButton.Visible = false
	sideButton("Book", 3, function()
		Store.emit("openPanel", "book")
	end)
	sideButton("Car", 4, function()
		Store.action("spawnCar")
	end)
	homeButton = sideButton("Home", 5, function()
		Store.action("homeRun")
	end)
	homeButton.Visible = false
	sideButton("R$", 6, function()
		Store.emit("openPanel", "robux")
	end)

	busted = Ui.new("Frame", {
		Name = "Busted",
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local card = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.86, 0, 0, 260),
		ZIndex = 21,
		Parent = busted,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 260) }).Parent = card
	Ui.padding(18).Parent = card
	Ui.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center).Parent = card
	Ui.label(
		"BUSTED!",
		48,
		{ TextColor3 = Color3.fromRGB(255, 110, 100), LayoutOrder = 1, ZIndex = 22, Parent = card }
	)
	bustedBody = Ui.label(
		"",
		20,
		{ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 80), ZIndex = 22, Parent = card }
	)
	local ok = Ui.button("Back to the Hideout", "primary", UDim2.new(1, 0, 0, 56), function()
		busted.Visible = false
	end)
	ok.LayoutOrder = 3
	ok.ZIndex = 22
	ok.Parent = card
end

local function onBusted(payload: { count: number, value: number })
	if payload.count > 0 then
		bustedBody.Text =
			`The guard took {payload.count} item(s) worth {Ui.money(payload.value)}. You kept your best find.\nCash, trunk, shelf and upgrades are safe.`
	else
		bustedBody.Text = "You lost nothing this time.\nCash, trunk, shelf and upgrades are safe."
	end
	busted.Visible = true
	Ui.pop(busted:FindFirstChildWhichIsA("Frame") :: Frame, 0.6)
	Store.play(Config.Sounds.WHISTLE, 0.8)
end

local announceToken = 0
local function onAnnounce(
	payload: { name: string, itemId: string, mutation: string?, rarity: number }
)
	local rarity = Items.Rarities[payload.rarity]
	announceToken += 1
	local token = announceToken
	announceLabel.Text =
		`{payload.name} found a {string.upper(Items.label(payload.itemId, payload.mutation))}!`
	announceLabel.TextColor3 = rarity.color
	announceLabel.Visible = true
	Ui.pop(announceLabel, 0.6)
	task.delay(5, function()
		if announceToken == token then
			announceLabel.Visible = false
		end
	end)
end

function Hud.init()
	build()
	Ui.autoScale(gui)
end

function Hud.start()
	Store.on("state", renderState)
	Store.on("toast", function(payload)
		toast(payload.text, payload.color)
	end)
	Store.on("sold", function(payload)
		Store.play(Config.Sounds.CASH, 0.5)
		toast(`Sold {payload.count} item(s) for {Ui.money(payload.amount)}`, C.accent)
	end)
	Store.on("upgraded", function(payload)
		Store.play(Config.Sounds.CASH, 0.5)
		toast(`Backpack upgraded to {payload.capacity} slots!`, C.safe)
	end)
	Store.on("dropped", function(payload)
		toast(`You dropped {payload.count} item(s) and got away.`)
	end)
	Store.on("chase", function(payload)
		if payload.on then
			toast("You've been spotted! Run!", Color3.fromRGB(255, 120, 110))
		elseif payload.reason == "safe" or payload.reason == "lost" then
			toast("You got away!", C.safe)
		end
		renderSuspicion()
	end)
	Store.on("busted", onBusted)
	Store.on("announce", onAnnounce)
	Store.on("bought", function(payload)
		Store.play(Config.Sounds.CASH, 0.5)
		toast(`Bought {payload.name}!`, C.safe)
	end)
	Store.on("milestone", function(payload)
		Store.play(Config.Sounds.RARE, 0.6)
		toast(`Collection reward: {payload.found} items found, +{Ui.money(payload.cash)}`, C.accent)
	end)
	for _, attr in { "Suspicion", "Chased", "InRedZone" } do
		player:GetAttributeChangedSignal(attr):Connect(renderSuspicion)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			Store.emit("openPanel", "bag")
		elseif input.KeyCode == Enum.KeyCode.C then
			Store.emit("openPanel", "book")
		elseif input.KeyCode == Enum.KeyCode.G and dropButton.Visible then
			Store.action("dropAndRun")
		end
	end)
	renderState()
	renderSuspicion()
end

return Hud
