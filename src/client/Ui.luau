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

-- Buttons are never smaller than 48px tall so they work under a thumb.
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
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(48, 48) }),
	})
	button.Activated:Connect(onClick)
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

function Ui.money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

return Ui
