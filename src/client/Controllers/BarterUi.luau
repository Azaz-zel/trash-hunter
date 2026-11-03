--!strict
-- Trade card for pedestrian barter offers: what they want from your bag, and
-- what they give (cash, or an item shown in 3D). The server holds the offer.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer

local gui: ScreenGui
local card: Frame
local title: TextLabel
local wantView: ViewportFrame
local wantLabel: TextLabel
local giveView: ViewportFrame
local giveLabel: TextLabel
local verdict: TextLabel
local token = 0

local BarterUi = {}

local function side(x: number, heading: string): (ViewportFrame, TextLabel)
	Ui.label(heading, 13, {
		Position = UDim2.new(x, 8, 0, 46),
		Size = UDim2.new(0.5, -16, 0, 16),
		TextColor3 = C.muted,
		Parent = card,
	})
	local view: ViewportFrame = Ui.new("ViewportFrame", {
		Position = UDim2.new(x, 8, 0, 64),
		Size = UDim2.new(0.5, -16, 0, 92),
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.5,
		Parent = card,
	}, { Ui.corner(10) })
	local label = Ui.label("", 15, {
		Position = UDim2.new(x, 8, 0, 160),
		Size = UDim2.new(0.5, -16, 0, 36),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	return view, label
end

local function hide()
	token += 1
	card.Visible = false
end

local function answer(choice: string)
	hide()
	Store.action("barter", choice)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Barter",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7,
		Parent = player:WaitForChild("PlayerGui"),
	})
	card = Ui.panel({
		Name = "Offer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.9, 0, 0, 290),
		Visible = false,
		Parent = gui,
	})
	card.BackgroundTransparency = 0.05
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(460, 290) }).Parent = card
	title = Ui.label("", 18, {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	wantView, wantLabel = side(0, "THEY WANT")
	giveView, giveLabel = side(0.5, "YOU GET")
	verdict = Ui.label("", 13, {
		Position = UDim2.fromOffset(16, 198),
		Size = UDim2.new(1, -32, 0, 18),
		TextColor3 = C.muted,
		Parent = card,
	})
	local accept = Ui.button("Deal", "primary", UDim2.new(0.5, -22, 0, 48), function()
		answer("accept")
	end)
	accept.AnchorPoint = Vector2.new(0, 1)
	accept.Position = UDim2.new(0, 16, 1, -14)
	accept.Parent = card
	local decline = Ui.button("No thanks", "secondary", UDim2.new(0.5, -22, 0, 48), function()
		answer("decline")
	end)
	decline.AnchorPoint = Vector2.new(1, 1)
	decline.Position = UDim2.new(1, -16, 1, -14)
	decline.Parent = card
end

local function show(offer: any)
	token += 1
	local mine = token
	title.Text = `{offer.name} wants to trade`
	ItemModels.show(wantView, offer.wantId, offer.wantMutation)
	wantLabel.Text =
		`{Items.label(offer.wantId, offer.wantMutation)}\nPawn value {Ui.money(offer.wantValue)}`
	local gain: number
	if offer.giveId then
		ItemModels.show(giveView, offer.giveId, offer.giveMutation)
		giveLabel.Text =
			`{Items.label(offer.giveId, offer.giveMutation)}\nWorth {Ui.money(offer.giveValue)}`
		gain = offer.giveValue - offer.wantValue
	else
		giveView:ClearAllChildren()
		Ui.corner(10).Parent = giveView
		Ui.label(Ui.money(offer.cash), 30, {
			Size = UDim2.fromScale(1, 1),
			TextColor3 = C.accent,
			Parent = giveView,
		})
		giveLabel.Text = `{Ui.money(offer.cash)} cash`
		gain = offer.cash - offer.wantValue
	end
	verdict.Text = if gain > 0
		then `+{Ui.money(gain)} over the pawn counter`
		elseif gain < 0 then `{Ui.money(-gain)} less than the pawn counter`
		else "Same as the pawn counter"
	verdict.TextColor3 = if gain > 0 then C.safe elseif gain < 0 then C.danger else C.muted
	card.Visible = true
	Ui.pop(card, 0.94)
	task.delay(offer.seconds, function()
		if token == mine then
			hide()
		end
	end)
end

function BarterUi.init()
	build()
	Ui.autoScale(gui)
end

function BarterUi.start()
	Store.on("barterOffer", show)
end

return BarterUi
