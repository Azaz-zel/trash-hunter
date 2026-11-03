--!strict
-- Minimap (top right), full-screen map (tap the minimap or press M) and the
-- location card shown when entering a district. Everything is drawn from
-- shared data (MapData roads, Config districts, stores and dumpsters), so no
-- screenshots or image assets are needed. North (+Z) is up.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Districts = require(Shared:WaitForChild("Districts"))
local MapData = require(Shared:WaitForChild("MapData"))
local Quests = require(Shared:WaitForChild("Quests"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local B = MapData.BOUNDS

local MINI_SIZE = 168
local MINI_SCALE = 0.22 -- pixels per stud on the minimap

local DISTRICT_TINT = {
	town = Color3.fromRGB(120, 130, 150),
	eastside = Color3.fromRGB(150, 120, 100),
	maple = Color3.fromRGB(110, 150, 110),
	hillcrest = Color3.fromRGB(110, 160, 140),
	business = Color3.fromRGB(110, 130, 180),
	industrial = Color3.fromRGB(160, 140, 100),
}

type Canvas = { world: Frame, scale: number, dots: { Frame }, arrow: Frame }

local MapUi = {}

local gui: ScreenGui
local mini: Canvas
local full: Canvas
local fullFrame: Frame
local card: CanvasGroup
local cardTitle: TextLabel
local cardSub: TextLabel
local cardStripe: Frame
-- Ready time per dumpster, indexed like Config.World.Dumpsters.
local cooling: { number } = {}

-- World (x, z) to canvas pixels. Origin is the map's north-west corner.
local function toPixel(scale: number, x: number, z: number): (number, number)
	return (x - B.x0) * scale, (B.z1 - z) * scale
end

local function rect(
	parent: Instance,
	scale: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	color: Color3,
	alpha: number,
	zIndex: number
): Frame
	local px, py = toPixel(scale, x0, z1)
	return Ui.new("Frame", {
		Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset((x1 - x0) * scale, (z1 - z0) * scale),
		BackgroundColor3 = color,
		BackgroundTransparency = alpha,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	})
end

local function marker(
	parent: Instance,
	scale: number,
	pos: Vector3,
	color: Color3,
	size: number,
	label: string?,
	zIndex: number,
	above: boolean?
): Frame
	local px, py = toPixel(scale, pos.X, pos.Z)
	local dot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(px, py),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	}, { Ui.corner(size), Ui.stroke(1, C.ink) })
	if label then
		Ui.label(label, 12, {
			AnchorPoint = Vector2.new(0.5, if above then 1 else 0),
			Position = UDim2.new(0.5, 0, if above then 0 else 1, if above then -2 else 2),
			Size = UDim2.fromOffset(140, 14),
			TextColor3 = C.cream,
			TextStrokeTransparency = 0.3,
			ZIndex = zIndex,
			Parent = dot,
		})
	end
	return dot
end

-- Draws the whole town into a canvas frame at the given scale.
local function drawWorld(parent: Instance, scale: number, labels: boolean): Canvas
	local world = Ui.new("Frame", {
		Name = "World",
		BackgroundColor3 = Color3.fromRGB(58, 70, 54),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset((B.x1 - B.x0) * scale, (B.z1 - B.z0) * scale),
		Parent = parent,
	})
	for _, d in Config.Districts do
		rect(world, scale, d.x0, d.x1, d.z0, d.z1, DISTRICT_TINT[d.id] or C.panelLight, 0.55, 1)
		if labels then
			-- Top-left corner, so it never sits on the Hideout or store pins.
			local px, py = toPixel(scale, d.x0, d.z1)
			Ui.label(string.upper(d.name), 12, {
				Position = UDim2.fromOffset(px + 6, py + 4),
				Size = UDim2.fromOffset(200, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.cream,
				TextTransparency = 0.2,
				TextStrokeTransparency = 0.5,
				ZIndex = 4,
				Parent = world,
			})
		end
	end
	local rc, rs = Config.World.RED_CENTER, Config.World.RED_SIZE
	rect(
		world,
		scale,
		rc.X - rs.X / 2,
		rc.X + rs.X / 2,
		rc.Z - rs.Y / 2,
		rc.Z + rs.Y / 2,
		Color3.fromRGB(190, 50, 50),
		0.35,
		2
	)
	for _, r in MapData.ROADS do
		if r.axis == "X" then
			rect(
				world,
				scale,
				r.from,
				r.to,
				r.at - MapData.ROAD_WIDTH / 2,
				r.at + MapData.ROAD_WIDTH / 2,
				Color3.fromRGB(200, 202, 206),
				0.1,
				3
			)
		else
			rect(
				world,
				scale,
				r.at - MapData.ROAD_WIDTH / 2,
				r.at + MapData.ROAD_WIDTH / 2,
				r.from,
				r.to,
				Color3.fromRGB(200, 202, 206),
				0.1,
				3
			)
		end
	end
	marker(
		world,
		scale,
		Config.World.HIDEOUT_CENTER,
		C.accent,
		if labels then 14 else 10,
		if labels then "Hideout" else nil,
		6,
		true
	)
	for _, s in Config.Stores do
		marker(
			world,
			scale,
			s.counter,
			Color3.fromRGB(80, 170, 255),
			if labels then 12 else 8,
			if labels then s.name else nil,
			6
		)
	end
	for _, giver in Config.Quests.givers do
		marker(
			world,
			scale,
			giver.pos,
			Color3.fromRGB(190, 120, 255),
			if labels then 11 else 7,
			if labels then giver.name else nil,
			6
		)
	end
	-- From config, not workspace: streaming leaves far dumpsters unloaded.
	local dots: { Frame } = {}
	for i, d in Config.World.Dumpsters do
		local red = d.zone == "Red"
		dots[i] = marker(
			world,
			scale,
			d.pos,
			if red then Color3.fromRGB(255, 120, 110) else Color3.fromRGB(120, 230, 140),
			if labels then 7 else 5,
			nil,
			5
		)
	end
	local arrow = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = world,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = C.cream,
		ZIndex = 8,
		Parent = arrow,
	}, { Ui.corner(6), Ui.stroke(2, C.ink) })
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(4, 9),
		BackgroundColor3 = C.accent,
		ZIndex = 9,
		Parent = arrow,
	}, { Ui.corner(2) })
	return { world = world, scale = scale, dots = dots, arrow = arrow }
end

-- District id per dumpster, for permit locks.
local dumpsterDistrict: { string } = {}
for i, d in Config.World.Dumpsters do
	local district = Districts.at(d.pos)
	dumpsterDistrict[i] = if district then district.id else "town"
end

local function refreshDots(canvas: Canvas)
	local now = os.clock()
	local state = Store.get()
	for i, dot in canvas.dots do
		local ready = (cooling[i] or 0) <= now
		local locked = state ~= nil and not Quests.permitted(state.stats, dumpsterDistrict[i])
		dot.BackgroundTransparency = if ready and not locked then 0 else 0.75
		if locked then
			dot.BackgroundColor3 = Color3.fromRGB(150, 150, 156)
		elseif Config.World.Dumpsters[i].zone == "Red" then
			dot.BackgroundColor3 = Color3.fromRGB(255, 120, 110)
		else
			dot.BackgroundColor3 = Color3.fromRGB(120, 230, 140)
		end
	end
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Map",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Minimap: a clipped, rounded window that scrolls with the player.
	local miniFrame: CanvasGroup = Ui.new("CanvasGroup", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		BackgroundColor3 = C.panel,
		Parent = gui,
	}, { Ui.corner(16) })
	local miniButton = Ui.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = miniFrame,
	})
	miniButton.Activated:Connect(function()
		fullFrame.Visible = not fullFrame.Visible
	end)
	mini = drawWorld(miniFrame, MINI_SCALE, false)
	local border = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke() })
	Ui.label("N", 12, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(16, 14),
		TextColor3 = C.cream,
		TextStrokeTransparency = 0.3,
		Parent = border,
	})

	-- Full map: fits the whole town on screen, with labels.
	fullFrame = Ui.panel({
		Name = "FullMap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.88),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	fullFrame.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(900, 720) }).Parent = fullFrame
	local holder: CanvasGroup = Ui.new("CanvasGroup", {
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1,
		Parent = fullFrame,
	}, { Ui.corner(12) })
	Ui.label("Map", 22, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(0.5, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = fullFrame,
	})
	Ui.label(
		"Green: ready · Gray: permit needed · Red: guarded · Blue: store · Purple: quests",
		13,
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -96, 0, 18),
			Size = UDim2.new(0.6, -96, 0, 18),
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = fullFrame,
		}
	)
	local close = Ui.button("Close", "secondary", UDim2.fromOffset(72, 36), function()
		fullFrame.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.TextSize = 15
	close.Parent = fullFrame
	task.defer(function()
		-- AbsoluteSize includes the screen UIScale; offsets inside do not.
		local uiScale = gui:FindFirstChildOfClass("UIScale")
		local avail = holder.AbsoluteSize / (if uiScale then uiScale.Scale else 1)
		local scale = math.min(avail.X / (B.x1 - B.x0), avail.Y / (B.z1 - B.z0))
		full = drawWorld(holder, if scale > 0 then scale else 0.25, true)
		full.world.AnchorPoint = Vector2.new(0.5, 0.5)
		full.world.Position = UDim2.fromScale(0.5, 0.5)
	end)

	-- Location card left of the minimap (the side buttons sit below it).
	card = Ui.new("CanvasGroup", {
		Name = "LocationCard",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16 - MINI_SIZE - 10, 0, 16),
		Size = UDim2.fromOffset(230, 58),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.12,
		GroupTransparency = 1,
		Parent = gui,
	}, { Ui.corner(12) })
	cardStripe = Ui.new("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = C.accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	cardTitle = Ui.label("", 18, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -22, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Font = Ui.FONT,
		Parent = card,
	})
	cardSub = Ui.label("", 13, {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -22, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
end

local cardToken = 0
local function showCard(title: string, sub: string, stripe: Color3)
	cardTitle.Text = title
	cardSub.Text = sub
	cardStripe.BackgroundColor3 = stripe
	cardToken += 1
	local mine = cardToken
	Ui.tween(card, 0.3, { GroupTransparency = 0 })
	task.delay(4, function()
		if cardToken == mine then
			Ui.tween(card, 0.6, { GroupTransparency = 1 })
		end
	end)
end

function MapUi.init()
	build()
	Ui.autoScale(gui)
end

function MapUi.start()
	Store.on("cooldown", function(payload)
		local model = payload.dumpster
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local at, best, bestDist = model:GetPivot().Position, nil, math.huge
		for i, d in Config.World.Dumpsters do
			local dist = (Vector3.new(d.pos.X, at.Y, d.pos.Z) - at).Magnitude
			if dist < bestDist then
				best, bestDist = i, dist
			end
		end
		if best then
			cooling[best] = os.clock() + payload.seconds
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			fullFrame.Visible = not fullFrame.Visible
		end
	end)

	local camera = workspace.CurrentCamera
	local lastDistrict: string? = nil
	local wasRed = false
	local acc = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local pos = root.Position
		-- Rotate the arrow with the camera heading (north-up map).
		local look = camera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, look.Z))
		for _, canvas in { mini, full } do
			if canvas then
				local px, py = toPixel(canvas.scale, pos.X, pos.Z)
				canvas.arrow.Position = UDim2.fromOffset(px, py)
				canvas.arrow.Rotation = heading -- map up is +Z, clockwise is +X
			end
		end
		local px, py = toPixel(mini.scale, pos.X, pos.Z)
		mini.world.Position = UDim2.fromOffset(MINI_SIZE / 2 - px, MINI_SIZE / 2 - py)
		refreshDots(mini)
		if full and fullFrame.Visible then
			refreshDots(full)
		end

		-- Location card: district change, and entering the guarded yard.
		local red = player:GetAttribute("InRedZone") == true
		if red and not wasRed then
			showCard(
				"PRIVATE PROPERTY",
				"Meridian Logistics yard · guards on patrol",
				Color3.fromRGB(220, 60, 60)
			)
		end
		wasRed = red
		local d = Districts.at(pos)
		if d and d.id ~= lastDistrict then
			lastDistrict = d.id
			local state = Store.get()
			local gate = Config.Gates[d.id]
			if red then
				return -- the private-property card already showed
			elseif d.tier == 0 then
				showCard(d.name, "Homes for sale at Maple Realty", Color3.fromRGB(196, 120, 60))
			elseif gate and state and not Quests.permitted(state.stats, d.id) then
				showCard(d.name, `Permit needed: {gate.text}`, Color3.fromRGB(150, 150, 156))
			else
				local stars = string.rep("★", d.tier)
					.. string.rep("☆", Districts.MAX_TIER - d.tier)
				local hot = workspace:GetAttribute("HotDistrict") == d.name
				showCard(
					d.name,
					`Loot {stars}{if hot then "  ·  HOT TODAY" else ""}`,
					if hot then Color3.fromRGB(255, 140, 40) else C.accent
				)
			end
		end
	end)
end

return MapUi
