--!strict
-- The core moment: dig bar with the Perfect Dig sweet spot, then the reveal
-- (lid shakes, rarity glow leaks out, lid pops, item card). Everything here is
-- local presentation; the server already decided the result.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local SearchUi = {}

local gui: ScreenGui
local digFrame: Frame
local sweet: Frame
local marker: Frame
local digHint: TextLabel
local digButton: TextButton
local reveal: Frame
local skipLayer: TextButton

local digging: {
	startedAt: number,
	duration: number,
	tapped: boolean,
	tween: Tween?,
	dumpster: Model,
}? =
	nil
local closedLid: { [Model]: CFrame } = {}
local revealToken = 0

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

local function stopDigBar()
	if digging and digging.tween then
		digging.tween:Cancel()
	end
	digging = nil
	digFrame.Visible = false
end

local function tapDig()
	local current = digging
	if not current or current.tapped then
		return
	end
	current.tapped = true
	Ui.setEnabled(digButton, false)
	task.spawn(function()
		local ok, perfect = Store.action("digTap")
		if ok and perfect then
			digHint.Text = "PERFECT DIG!"
			digHint.TextColor3 = C.accent
			Ui.bump(digHint)
		elseif ok then
			digHint.Text = "Missed the sweet spot"
			digHint.TextColor3 = C.muted
		end
	end)
end

local function onSearchStarted(payload: {
	dumpster: Model,
	duration: number,
	sweetStart: number,
	sweetEnd: number,
	depth: number,
})
	stopDigBar()
	reveal.Visible = false
	local dumpster = payload.dumpster
	sweet.Position = UDim2.fromScale(payload.sweetStart, 0)
	sweet.Size = UDim2.fromScale(payload.sweetEnd - payload.sweetStart, 1)
	marker.Position = UDim2.fromScale(0, 0)
	digHint.Text = if payload.depth > 0
		then `Digging deeper ({payload.depth}/{Config.Search.MAX_DEEPER})... tap DIG in the yellow zone`
		else "Tap DIG in the yellow zone for a Perfect Dig"
	digHint.TextColor3 = C.cream
	Ui.setEnabled(digButton, true)
	digFrame.Visible = true

	local startedAt = os.clock()
	local state = {
		startedAt = startedAt,
		duration = payload.duration,
		tapped = false,
		tween = nil :: Tween?,
		dumpster = dumpster,
	}
	digging = state
	local body = bodyOf(dumpster)
	local burst = body and body:FindFirstChild("Burst") :: ParticleEmitter?
	if burst then
		burst.Color = ColorSequence.new(Color3.fromRGB(150, 120, 80))
	end
	Store.play(Config.Sounds.RUMMAGE, 0.5)
	Ui.pop(digFrame, 0.9)
	-- Marker sweep is one linear tween; dirt puffs are a slow side loop.
	local sweep = TweenService:Create(
		marker,
		TweenInfo.new(payload.duration, Enum.EasingStyle.Linear),
		{ Position = UDim2.fromScale(1, 0) }
	)
	state.tween = sweep
	sweep.Completed:Once(function(status)
		if status == Enum.PlaybackState.Completed and digging == state then
			stopDigBar()
		end
	end)
	sweep:Play()
	task.spawn(function()
		while digging == state do
			if burst then
				burst:Emit(3)
			end
			task.wait(0.25)
		end
	end)
end

local function showRevealCard(payload: any)
	local rarity = Items.Rarities[payload.rarity]
	local item = Items.ById[payload.itemId]
	for _, child in reveal:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local stroke = reveal:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = rarity.color
		stroke.Thickness = if payload.rarity >= 3 then 2 else 1
		stroke.Transparency = 0
		local old = stroke:FindFirstChildOfClass("UIGradient")
		if old then
			old:Destroy()
		end
		-- Epic and up: a light sweeps around the card edge.
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

	Ui.label(
		string.upper(rarity.name),
		22,
		{ TextColor3 = rarity.color, LayoutOrder = 1, Parent = reveal }
	)
	Ui.label(Items.label(item.id, payload.mutation), 34, {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = reveal,
	})
	local tags = {}
	if payload.mutation then
		local m = Items.MutationById[payload.mutation]
		table.insert(tags, `{m.name} x{m.mult}`)
	end
	if payload.perfect then
		table.insert(tags, "Perfect Dig")
	end
	if #tags > 0 then
		Ui.label(
			table.concat(tags, "  ·  "),
			18,
			{ TextColor3 = C.accent, LayoutOrder = 3, Parent = reveal }
		)
	end
	Ui.label(
		"Worth " .. Ui.money(payload.value),
		26,
		{ TextColor3 = C.accent, LayoutOrder = 4, Parent = reveal }
	)

	local function choose(choice: string)
		reveal.Visible = false
		task.spawn(function()
			local ok = Store.action("resolve", choice)
			if choice ~= "deeper" or not ok then
				closeDumpster(payload.dumpster)
			end
		end)
	end

	local keep = Ui.button("Keep it", "primary", UDim2.new(1, 0, 0, 56), function()
		choose("take")
	end)
	keep.LayoutOrder = 5
	keep.Parent = reveal

	if payload.canDeeper then
		local red = payload.dumpster:GetAttribute("Zone") == "Red"
		local note = if red
			then "throw it back for better odds, more suspicion"
			else "throw it back for better odds"
		local deeper = Ui.button(
			`Dig deeper ({payload.depth + 1}/{Config.Search.MAX_DEEPER})\n{note}`,
			"secondary",
			UDim2.new(1, 0, 0, 64),
			function()
				choose("deeper")
			end
		)
		deeper.TextSize = 18
		deeper.LayoutOrder = 6
		deeper.Parent = reveal
	end

	local leave = Ui.button("Leave it", "secondary", UDim2.new(1, 0, 0, 48), function()
		choose("leave")
	end)
	leave.LayoutOrder = 7
	leave.TextSize = 18
	leave.Parent = reveal

	reveal.Visible = true
	Ui.pop(reveal, if payload.rarity >= 4 then 0.5 else 0.8)
end

local function onSearchResult(payload: any)
	stopDigBar()
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

	-- 1. Lid rattles.
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
	-- 2. Rarity glow leaks out before the item shows.
	if glow then
		glow.Color = rarity.color
		glow.Brightness = 0
		glow.Enabled = true
		Ui.tween(glow, 0.35, { Brightness = 1.5 + payload.rarity })
	end
	pause(0.35)
	-- 3. Lid pops open, burst in rarity color.
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
	pause(if payload.rarity >= 5 then 0.6 else 0.3)

	skipConn:Disconnect()
	skipLayer.Visible = false
	if revealToken == token then
		showRevealCard(payload)
	end
end

local function onCancelled(payload: { reason: string, dumpster: Model })
	stopDigBar()
	reveal.Visible = false
	skipLayer.Visible = false
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
		Size = UDim2.fromOffset(140, 36),
		StudsOffset = Vector3.new(0, 4.5, 0),
		MaxDistance = 60,
		Parent = body,
	})
	local label = Ui.label("", 20, {
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.2,
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
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.92, 0, 0, 120),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(520, 120) }).Parent = digFrame
	digHint = Ui.label(
		"",
		18,
		{ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Parent = digFrame }
	)
	local track = Ui.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Position = UDim2.new(0, 12, 0, 50),
		Size = UDim2.new(1, -150, 0, 30),
		Parent = digFrame,
	}, { Ui.corner(6), Ui.stroke() })
	sweet = Ui.new("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = track })
	marker = Ui.new("Frame", {
		BackgroundColor3 = C.cream,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = 3,
		Parent = track,
	}, { Ui.stroke() })
	digButton = Ui.button("DIG!", "primary", UDim2.fromOffset(120, 64), tapDig)
	digButton.AnchorPoint = Vector2.new(1, 0)
	digButton.Position = UDim2.new(1, -12, 0, 36)
	digButton.TextSize = 26
	digButton.Parent = digFrame

	reveal = Ui.panel({
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.86, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(380, 600) }).Parent = reveal
	Ui.padding(16).Parent = reveal
	Ui.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = reveal

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
	Store.on("searchResult", onSearchResult)
	Store.on("searchCancelled", onCancelled)
	-- Covers the server auto-keeping an ignored find.
	Store.on("searchEnded", function(payload)
		reveal.Visible = false
		closeDumpster(payload.dumpster)
	end)
	Store.on("cooldown", onCooldown)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
			tapDig()
		end
	end)
end

return SearchUi
