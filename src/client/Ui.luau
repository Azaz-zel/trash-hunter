--!strict
-- Tiny UI kit. Identity motif: comic-panel look, thick ink outline on every
-- panel and button, one rounded display font (Fredoka One) to match the
-- cartoon trash world. Yellow is the single accent, used for primary actions.

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.FONT = Enum.Font.FredokaOne
Ui.COLORS = table.freeze({
	panel = Color3.fromRGB(24, 28, 44),
	panelLight = Color3.fromRGB(44, 50, 74),
	ink = Color3.fromRGB(12, 13, 22),
	cream = Color3.fromRGB(250, 244, 228),
	muted = Color3.fromRGB(190, 194, 212),
	accent = Color3.fromRGB(255, 200, 48),
	danger = Color3.fromRGB(196, 36, 36),
	safe = Color3.fromRGB(88, 204, 96),
})

local C = Ui.COLORS

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function Ui.corner(px: number): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, px) })
end

function Ui.stroke(px: number?, color: Color3?): UIStroke
	return Ui.new("UIStroke", {
		Thickness = px or 3,
		Color = color or C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new(
		"UIPadding",
		{ PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u }
	)
end

function Ui.list(
	direction: Enum.FillDirection,
	gap: number,
	align: Enum.HorizontalAlignment?
): UIListLayout
	return Ui.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if direction == Enum.FillDirection.Horizontal
			then Enum.VerticalAlignment.Center
			else Enum.VerticalAlignment.Top,
	})
end

function Ui.label(text: string, textSize: number, props: { [string]: any }?): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		Text = text,
		TextSize = textSize,
		TextColor3 = C.cream,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, textSize + 6),
	}
	for k, v in props or {} do
		base[k] = v
	end
	return Ui.new("TextLabel", base)
end

local STYLES = {
	primary = { bg = C.accent, fg = C.ink },
	secondary = { bg = C.panelLight, fg = C.cream },
	danger = { bg = C.danger, fg = Color3.new(1, 1, 1) },
}

-- Animation vocabulary: every UI motion uses one of these so the game feels coherent.
Ui.FAST = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Ui.SETTLE = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Ui.BOUNCY = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("PopScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return Ui.new("UIScale", { Name = "PopScale", Parent = gui })
end

local live: { [UIScale]: Tween } = {}
local function scaleTo(scale: UIScale, value: number, info: TweenInfo)
	local previous = live[scale]
	if previous then
		previous:Cancel()
	end
	local t = TweenService:Create(scale, info, { Scale = value })
	live[scale] = t
	t.Completed:Once(function()
		if live[scale] == t then
			live[scale] = nil
		end
	end)
	t:Play()
end

-- Entrance pop: grow from `from` to full size with a little overshoot.
function Ui.pop(gui: GuiObject, from: number?)
	local scale = scaleOf(gui)
	scale.Scale = from or 0.85
	scaleTo(scale, 1, Ui.BOUNCY)
end

-- Attention bump: 1.1x and back, for a value that just changed.
function Ui.bump(gui: GuiObject)
	local scale = scaleOf(gui)
	scaleTo(scale, 1.12, Ui.FAST)
	task.delay(0.09, scaleTo, scale, 1, Ui.SETTLE)
end

-- Buttons are never smaller than 52px before scaling (44px on the smallest phones).
function Ui.button(text: string, style: string, size: UDim2, onClick: () -> ()): TextButton
	local s = STYLES[style] or STYLES.secondary
	local button: TextButton = Ui.new("TextButton", {
		Size = size,
		BackgroundColor3 = s.bg,
		TextColor3 = s.fg,
		Font = Ui.FONT,
		TextSize = 20,
		TextWrapped = true,
		Text = text,
		AutoButtonColor = true,
	}, {
		Ui.corner(8),
		Ui.stroke(3),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(52, 52) }),
	})
	-- Press feedback: squish on press, spring back on release.
	local scale = scaleOf(button)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			scaleTo(scale, 0.92, Ui.FAST)
		end
	end)
	local function release()
		scaleTo(scale, 1, Ui.SETTLE)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	return button
end

function Ui.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.55
	button.TextTransparency = if enabled then 0 else 0.45
end

function Ui.panel(props: { [string]: any }?): Frame
	local base: { [string]: any } = { BackgroundColor3 = C.panel, BackgroundTransparency = 0.05 }
	for k, v in props or {} do
		base[k] = v
	end
	return Ui.new("Frame", base, { Ui.corner(10), Ui.stroke(3) })
end

function Ui.tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Shrinks a whole ScreenGui on short screens (landscape phones) so panels fit,
-- never below 0.85 so 52px buttons stay at least 44px.
function Ui.autoScale(gui: ScreenGui)
	local scale: UIScale = Ui.new("UIScale", { Name = "ScreenScale", Parent = gui })
	local camera = workspace.CurrentCamera
	local function update()
		local height = camera.ViewportSize.Y
		scale.Scale = math.clamp(height / 640, 0.85, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

-- Counts a money label up (or down) to a new value instead of snapping.
local counters: { [TextLabel]: NumberValue } = {}
function Ui.countMoney(label: TextLabel, value: number)
	local holder = counters[label]
	if not holder then
		local nv = Instance.new("NumberValue")
		nv.Value = value
		nv.Changed:Connect(function(v)
			label.Text = Ui.money(v)
		end)
		counters[label] = nv
		label.Text = Ui.money(value)
		label.Destroying:Once(function()
			counters[label] = nil
			nv:Destroy()
		end)
		return
	end
	local nv = holder :: NumberValue
	TweenService:Create(
		nv,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = value }
	):Play()
end

function Ui.money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

return Ui
