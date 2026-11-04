--!strict
-- Wanted stars (server: Systems/Wanted). Top centre while the city police
-- are after you: the stars, a bar that fills as they lose track of you, and
-- a red/blue flashing frame. Toasts tell you what you did and how it ended.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local MAX = Config.Wanted.MAX_STARS
local RED = Color3.fromRGB(255, 60, 60)
local BLUE = Color3.fromRGB(60, 120, 255)
local STAR_ON = Color3.fromRGB(255, 210, 60)
local STAR_OFF = Color3.fromRGB(90, 90, 96)

local WantedUi = {}

local gui: ScreenGui
local panel: Frame
local stroke: UIStroke
local starLabels: { TextLabel } = {}
local fill: Frame
local hint: TextLabel

local function render()
	local n = tonumber(player:GetAttribute("Wanted")) or 0
	local wasVisible = panel.Visible
	panel.Visible = n > 0
	if n > 0 and not wasVisible then
		Ui.pop(panel, 0.7)
	end
	for i, label in starLabels do
		label.TextColor3 = if i <= n then STAR_ON else STAR_OFF
	end
	-- Stay clear of the yard's suspicion bar and chase banner.
	local yard = player:GetAttribute("Chased") == true or player:GetAttribute("InRedZone") == true
	panel.Position = UDim2.new(0.5, 0, 0, if yard then 132 else 16)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Wanted",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	panel = Ui.panel({
		Name = "WantedPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(220, 66),
		Visible = false,
		Parent = gui,
	})
	stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Thickness = 2
	stroke.Transparency = 0
	Ui.label("WANTED", 13, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Ui.FONT,
		TextColor3 = RED,
		Parent = panel,
	})
	local row = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	for i = 1, MAX do
		starLabels[i] = Ui.label("★", 28, {
			Size = UDim2.fromOffset(30, 30),
			Font = Ui.FONT,
			TextColor3 = STAR_OFF,
			LayoutOrder = i,
			Parent = row,
		})
	end
	local track = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 5),
		BackgroundColor3 = C.panelLight,
		Parent = panel,
	}, { Ui.corner(3) })
	fill = Ui.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.safe,
		Parent = track,
	}, { Ui.corner(3) })
	hint = Ui.label("Lose the cops or reach a Hideout", 12, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(260, 14),
		TextColor3 = C.cream,
		TextStrokeTransparency = 0.4,
		Parent = panel,
	})
end

function WantedUi.init()
	build()
	Ui.autoScale(gui)
end

function WantedUi.start()
	for _, attr in { "Wanted", "Chased", "InRedZone" } do
		player:GetAttributeChangedSignal(attr):Connect(render)
	end
	render()
	Store.on("crime", function(payload)
		Store.emit("toast", { text = `{payload.text} · the police are watching`, color = RED })
	end)
	Store.on("wanted", function(payload)
		local n = payload.stars or 0
		if n > 0 then
			Store.emit("toast", {
				text = `{payload.crime or "Wanted"} · {string.rep("★", n)}`,
				color = RED,
			})
		elseif payload.reason == "lost" then
			Store.emit("toast", { text = "You lost the cops.", color = C.safe })
		elseif payload.reason == "lawyer" then
			Store.emit(
				"toast",
				{ text = "Your lawyer made it go away. Clean record.", color = C.safe }
			)
		elseif payload.reason == "safe" then
			Store.emit("toast", { text = "Safe at the Hideout. The heat is off.", color = C.safe })
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		local flash = math.floor(os.clock() * 3) % 2 == 0
		stroke.Color = if flash then RED else BLUE
		local search = tonumber(player:GetAttribute("WantedSearch")) or 0
		fill.Size = UDim2.fromScale(search, 1)
		hint.Text = if search > 0.05
			then "Losing them... stay out of sight"
			else "Lose the cops or reach a Hideout"
	end)
end

return WantedUi
