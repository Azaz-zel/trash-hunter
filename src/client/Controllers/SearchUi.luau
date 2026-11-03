--!strict
-- The core moment, rummage style: a short dig, then pick one of the trash
-- bags (heavier usually means better; the Flashlight shows one bag's rarity),
-- then the reveal: lid shakes, rarity glow leaks out, lid pops, item card with
-- a 3D picture, plus what the other bags held. Presentation only; the server
-- already rolled everything.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local WEIGHT_TEXT = { "Light", "Medium", "Heavy" }

local SearchUi = {}

local gui: ScreenGui
local digFrame: Frame
local digFill: Frame
local digHint: TextLabel
local bagsFrame: Frame
local bagsRow: Frame
local bagsHint: TextLabel
local reveal: Frame
local skipLayer: TextButton

local closedLid: { [Model]: CFrame } = {}
local revealToken = 0
local digTween: Tween? = nil
local picking = false

local function lidOf(dumpster: Model): BasePart?
	return dumpster:FindFirstChild("Lid") :: BasePart?
end

local function bodyOf(dumpster: Model): BasePart?
	return dumpster:FindFirstChild("Body") :: BasePart?
end

local function hingeCFrame(dumpster: Model, angleDeg: number): CFrame?
	local lid = lidOf(dumpster)
	if not lid then
		return nil
	end
	local closed = closedLid[dumpster] or lid.CFrame
	closedLid[dumpster] = closed
	local half = lid.Size.Z / 2
	return closed
		* CFrame.new(0, 0, half)
		* CFrame.Angles(math.rad(angleDeg), 0, 0)
		* CFrame.new(0, 0, -half)
end

local function setLid(dumpster: Model, angleDeg: number, seconds: number)
	local lid = lidOf(dumpster)
	local target = hingeCFrame(dumpster, angleDeg)
	if lid and target then
		Ui.tween(lid, seconds, { CFrame = target }, Enum.EasingStyle.Back)
	end
end

local function closeDumpster(dumpster: Model)
	setLid(dumpster, 0, 0.25)
	local body = bodyOf(dumpster)
	local glow = body and body:FindFirstChild("Glow") :: PointLight?
	if glow then
		glow.Enabled = false
	end
end

local function cameraShake(strength: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		for _ = 1, 8 do
			humanoid.CameraOffset =
				Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function hideAll()
	if digTween then
		digTween:Cancel()
		digTween = nil
	end
	digFrame.Visible = false
	bagsFrame.Visible = false
	reveal.Visible = false
	skipLayer.Visible = false
end

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- 1. Rummaging: a short progress bar and trash flying out of the dumpster.
local function onSearchStarted(payload: { dumpster: Model, duration: number, depth: number })
	hideAll()
	revealToken += 1
	local token = revealToken
	digHint.Text = if payload.depth > 0
		then `Digging deeper ({payload.depth}/{Config.Search.MAX_DEEPER})...`
		else "Rummaging..."
	digFill.Size = UDim2.fromScale(0, 1)
	digFrame.Visible = true
	Ui.pop(digFrame, 0.9)
	digTween = TweenService:Create(
		digFill,
		TweenInfo.new(payload.duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	);
	(digTween :: Tween):Play()
	Store.play(Config.Sounds.RUMMAGE, 0.5)
	local body = bodyOf(payload.dumpster)
	local burst = body and body:FindFirstChild("Burst") :: ParticleEmitter?
	setLid(payload.dumpster, 35, 0.2)
	if burst then
		burst.Color = ColorSequence.new(Color3.fromRGB(110, 96, 70))
		task.spawn(function()
			while revealToken == token and digFrame.Visible do
				burst:Emit(4)
				task.wait(0.2)
			end
		end)
	end
end

-- A trash bag drawn with frames: dark sack, tied neck, weight bars.
local function bagCard(
	index: number,
	look: { weight: number, rarity: number? },
	count: number
): TextButton
	local card: TextButton = Ui.new("TextButton", {
		Name = "Bag" .. index,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1 / count, -10, 1, 0),
		LayoutOrder = index,
	}, { Ui.corner(14), Ui.stroke() })
	local scale = 0.62 + look.weight * 0.12
	local sack = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromScale(0.62 * scale, 0.5 * scale),
		BackgroundColor3 = Color3.fromRGB(28, 30, 34),
		Parent = card,
	}, { Ui.corner(40), Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.95 }) })
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.22, 0.22),
		BackgroundColor3 = Color3.fromRGB(28, 30, 34),
		Rotation = 45,
		Parent = sack,
	}, { Ui.corner(4) })
	-- Flashlight: this bag glows in its rarity color.
	if look.rarity then
		local rarity = Items.Rarities[look.rarity]
		local stroke = Ui.stroke(2, rarity.color)
		stroke.Parent = card
		Ui.label(rarity.name, 14, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.06),
			Size = UDim2.new(1, -8, 0, 18),
			TextColor3 = rarity.color,
			Parent = card,
		})
	end
	local bars = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromOffset(54, 8),
		BackgroundTransparency = 1,
		Parent = card,
	}, { Ui.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	for i = 1, 3 do
		Ui.new("Frame", {
			Size = UDim2.fromOffset(14, 8),
			BackgroundColor3 = if i <= look.weight then C.cream else C.panel,
			BackgroundTransparency = if i <= look.weight then 0 else 0.4,
			LayoutOrder = i,
			Parent = bars,
		}, { Ui.corner(3) })
	end
	Ui.label(WEIGHT_TEXT[look.weight], 15, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.new(1, -8, 0, 18),
		TextColor3 = C.muted,
		Parent = card,
	})
	return card
end

-- 2. Pick a bag.
local function onSearchBags(payload: {
	dumpster: Model,
	bags: { { weight: number, rarity: number? } },
	depth: number,
})
	hideAll()
	picking = false
	clearChildren(bagsRow)
	Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center).Parent = bagsRow
	bagsHint.Text = if payload.depth > 0
		then "Deeper bags, better odds. Pick one."
		else "Pick a bag. Heavier bags usually hold better stuff."
	for i, look in payload.bags do
		local card = bagCard(i, look, #payload.bags)
		card.Activated:Connect(function()
			if picking then
				return
			end
			picking = true
			Ui.bump(card)
			task.spawn(Store.action, "pickBag", i)
		end)
		card.Parent = bagsRow
	end
	bagsFrame.Visible = true
	Ui.pop(bagsFrame, 0.85)
end

local function itemPicture(
	parent: Instance,
	itemId: string,
	mutation: string?,
	size: UDim2,
	order: number?
): ViewportFrame
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		Size = size,
		BackgroundTransparency = 1,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	ItemModels.show(vp, itemId, mutation)
	return vp
end

-- 4. The card: picture, name, rarity, value, the bags you passed on, choices.
local function showRevealCard(payload: any)
	local rarity = Items.Rarities[payload.rarity]
	local item = Items.ById[payload.itemId]
	clearChildren(reveal)
	Ui.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = reveal
	local stroke = reveal:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = rarity.color
		stroke.Transparency = 0
		stroke.Thickness = if payload.rarity >= 3 then 2 else 1
		local old = stroke:FindFirstChildOfClass("UIGradient")
		if old then
			old:Destroy()
		end
		if payload.rarity >= 4 then
			local shine = Instance.new("UIGradient")
			shine.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarity.color),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, rarity.color),
			})
			shine.Parent = stroke
			TweenService:Create(
				shine,
				TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
				{ Rotation = 360 }
			):Play()
		end
	end

	local picture = itemPicture(reveal, item.id, payload.mutation, UDim2.new(1, 0, 0, 150), 1)
	task.spawn(function()
		local model = picture:FindFirstChildWhichIsA("Model")
		while model and model.Parent do
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(1.2), 0))
			task.wait(1 / 30)
		end
	end)
	Ui.label(
		string.upper(rarity.name),
		14,
		{ TextColor3 = rarity.color, LayoutOrder = 2, Parent = reveal }
	)
	Ui.label(Items.label(item.id, payload.mutation), 28, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = reveal,
	})
	if payload.mutation then
		local m = Items.MutationById[payload.mutation]
		Ui.label(
			`{m.name} · worth x{m.mult}`,
			15,
			{ TextColor3 = m.color, LayoutOrder = 4, Parent = reveal }
		)
	end
	Ui.label(
		Ui.money(payload.value),
		24,
		{ TextColor3 = C.accent, LayoutOrder = 5, Parent = reveal }
	)

	-- What the other bags held: near-misses make "one more" tempting.
	if payload.bags and #payload.bags > 1 then
		local missed = Ui.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 58),
			LayoutOrder = 6,
			Parent = reveal,
		}, { Ui.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
		Ui.label("Other bags", 13, {
			Size = UDim2.fromOffset(70, 58),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = missed,
		})
		for i, b in payload.bags do
			if i ~= payload.picked then
				local cell = Ui.new("Frame", {
					Size = UDim2.fromOffset(58, 58),
					BackgroundColor3 = C.panelLight,
					BackgroundTransparency = 0.3,
					LayoutOrder = i,
					Parent = missed,
				}, { Ui.corner(10), Ui.stroke(1, Items.Rarities[b.rarity].color) })
				itemPicture(cell, b.itemId, b.mutation, UDim2.fromScale(1, 1))
			end
		end
	end

	local function choose(choice: string)
		reveal.Visible = false
		task.spawn(function()
			local ok = Store.action("resolve", choice)
			if choice ~= "deeper" or not ok then
				closeDumpster(payload.dumpster)
			end
		end)
	end
	local keep = Ui.button(`Keep it`, "primary", UDim2.new(1, 0, 0, 52), function()
		choose("take")
	end)
	keep.LayoutOrder = 7
	keep.Parent = reveal
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 8,
		Parent = reveal,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	if payload.canDeeper then
		local red = payload.dumpster:GetAttribute("Zone") == "Red"
		local deeper = Ui.button(
			if red then "Dig deeper (risky)" else "Dig deeper",
			"secondary",
			UDim2.new(0.6, -4, 1, 0),
			function()
				choose("deeper")
			end
		)
		deeper.TextSize = 16
		deeper.Parent = row
	end
	local leave = Ui.button(
		"Leave it",
		"secondary",
		UDim2.new(if payload.canDeeper then 0.4 else 1, -4, 1, 0),
		function()
			choose("leave")
		end
	)
	leave.TextSize = 16
	leave.LayoutOrder = 2
	leave.Parent = row
	reveal.Visible = true
	Ui.pop(reveal, if payload.rarity >= 4 then 0.5 else 0.8)
end

-- 3. The reveal sequence in the world, then the card.
local function onSearchResult(payload: any)
	hideAll()
	revealToken += 1
	local token = revealToken
	local dumpster: Model = payload.dumpster
	local rarity = Items.Rarities[payload.rarity]
	local body = bodyOf(dumpster)
	local lid = lidOf(dumpster)
	local glow = body and body:FindFirstChild("Glow") :: PointLight?
	local burst = body and body:FindFirstChild("Burst") :: ParticleEmitter?

	skipLayer.Visible = true
	local skipped = false
	local skipConn = skipLayer.Activated:Connect(function()
		skipped = true
	end)
	local function pause(seconds: number)
		local untilT = os.clock() + seconds
		while os.clock() < untilT and not skipped and revealToken == token do
			task.wait()
		end
	end

	if lid then
		local closed = hingeCFrame(dumpster, 0) :: CFrame
		for i = 1, 4 do
			if skipped then
				break
			end
			lid.CFrame = closed * CFrame.Angles(math.rad(if i % 2 == 0 then 4 else -2), 0, 0)
			pause(0.06)
		end
	end
	if glow then
		glow.Color = rarity.color
		glow.Brightness = 0
		glow.Enabled = true
		Ui.tween(glow, 0.35, { Brightness = 1.5 + payload.rarity })
	end
	pause(0.3)
	setLid(dumpster, 105, 0.25)
	if burst then
		burst.Color = ColorSequence.new(rarity.color)
		burst:Emit(10 + payload.rarity * 8)
	end
	local sound = if payload.rarity >= 6
		then Config.Sounds.JACKPOT
		elseif payload.rarity >= 4 then Config.Sounds.EPIC
		elseif payload.rarity >= 3 then Config.Sounds.RARE
		else Config.Sounds.OPEN
	Store.play(sound, 0.7)
	if payload.rarity >= 4 then
		cameraShake(if payload.rarity >= 6 then 1.2 else 0.6)
	end
	pause(if payload.rarity >= 5 then 0.5 else 0.25)

	skipConn:Disconnect()
	skipLayer.Visible = false
	if revealToken == token then
		showRevealCard(payload)
	end
end

local function onCancelled(payload: { reason: string, dumpster: Model })
	hideAll()
	revealToken += 1
	closeDumpster(payload.dumpster)
	local messages = {
		moved = "You walked away from the dumpster.",
		spotted = "You've been spotted!",
	}
	local text = messages[payload.reason]
	if text then
		Store.emit("toast", { text = text })
	end
end

-- Hide the prompt and show a timer while a dumpster is picked clean for me.
local function onCooldown(payload: { dumpster: Model, seconds: number })
	local body = bodyOf(payload.dumpster)
	local prompt = body and body:FindFirstChild("SearchPrompt") :: ProximityPrompt?
	if not body or not prompt then
		return
	end
	prompt.Enabled = false
	local tag = Ui.new("BillboardGui", {
		Name = "CooldownTag",
		Size = UDim2.fromOffset(140, 30),
		StudsOffset = Vector3.new(0, 5, 0),
		MaxDistance = 60,
		Parent = body,
	})
	local label = Ui.label("", 16, {
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.4,
		TextColor3 = C.muted,
		Parent = tag,
	})
	local readyAt = os.clock() + payload.seconds
	task.spawn(function()
		while os.clock() < readyAt and tag.Parent do
			label.Text = `Empty · {math.ceil(readyAt - os.clock())}s`
			task.wait(1)
		end
		tag:Destroy()
		prompt.Enabled = true
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Search",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	digFrame = Ui.panel({
		Name = "Dig",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.new(0.8, 0, 0, 64),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(380, 64) }).Parent = digFrame
	digHint = Ui.label("", 16, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = digFrame,
	})
	local track = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Position = UDim2.new(0, 16, 0, 38),
		Size = UDim2.new(1, -32, 0, 10),
		Parent = digFrame,
	}, { Ui.corner(5) })
	digFill = Ui.new(
		"Frame",
		{ BackgroundColor3 = C.cream, Size = UDim2.fromScale(0, 1), Parent = track },
		{ Ui.corner(5) }
	)

	bagsFrame = Ui.panel({
		Name = "Bags",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.94, 0, 0, 230),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 230) }).Parent = bagsFrame
	bagsHint = Ui.label("", 16, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 20),
		TextColor3 = C.muted,
		Parent = bagsFrame,
	})
	bagsRow = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 1, -54),
		Parent = bagsFrame,
	})

	reveal = Ui.panel({
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.88, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(360, 640) }).Parent = reveal
	reveal.BackgroundTransparency = 0.04 -- modal card: nothing should show through
	bagsFrame.BackgroundTransparency = 0.06
	Ui.padding(16).Parent = reveal

	skipLayer = Ui.new("TextButton", {
		Name = "Skip",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
end

function SearchUi.init()
	build()
	Ui.autoScale(gui)
end

function SearchUi.start()
	Store.on("searchStarted", onSearchStarted)
	Store.on("searchBags", onSearchBags)
	Store.on("searchResult", onSearchResult)
	Store.on("searchCancelled", onCancelled)
	-- Covers the server auto-keeping an ignored find.
	Store.on("searchEnded", function(payload)
		hideAll()
		closeDumpster(payload.dumpster)
	end)
	Store.on("cooldown", onCooldown)
	-- Number keys pick bags on keyboard.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not bagsFrame.Visible then
			return
		end
		local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
		local index = table.find(keys, input.KeyCode)
		local card = index and bagsRow:FindFirstChild("Bag" .. index)
		if card and not picking then
			picking = true
			task.spawn(Store.action, "pickBag", index)
		end
	end)
end

return SearchUi
