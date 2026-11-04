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
	sunset = Color3.fromRGB(170, 140, 110),
	route9 = Color3.fromRGB(70, 110, 70),
	oldport = Color3.fromRGB(120, 110, 140),
	docks = Color3.fromRGB(110, 130, 150),
}

type Canvas = { world: Frame, scale: number, dots: { Frame }, arrow: Frame, waypoint: Frame }

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
-- Player-set waypoint (click the full map), with its world marker.
local waypoint: Vector3? = nil
local waypointPart: Part? = nil
local waypointText: TextLabel? = nil
local edgeDot: Frame
local streetLabel: TextLabel

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
		if d.id == "docks" then
			-- The bay east of the quay.
			rect(world, scale, 2672, B.x1, B.z0, B.z1, Color3.fromRGB(40, 92, 130), 0.1, 2)
		end
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
	for i, hideout in Config.World.HIDEOUTS do
		marker(
			world,
			scale,
			hideout,
			C.accent,
			if labels then 14 else 10,
			if labels then (if i == 1 then "Hideout" else "Harbor Lockup") else nil,
			6,
			true
		)
	end
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
	local wp = Ui.new("Frame", {
		Name = "Waypoint",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(14, 18),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = world,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(255, 80, 120),
		ZIndex = 9,
		Parent = wp,
	}, { Ui.corner(7), Ui.stroke(2, C.cream) })
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
	-- Street names along named roads (full map only).
	if labels then
		for _, r in MapData.ROADS do
			if r.name then
				local mid = (r.from + r.to) / 2
				local x = if r.axis == "X" then mid else r.at
				local z = if r.axis == "X" then r.at else mid
				local px, py = toPixel(scale, x, z)
				Ui.label(r.name, 10, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(px, py),
					Size = UDim2.fromOffset(120, 12),
					Rotation = if r.axis == "Z" then 90 else 0,
					TextColor3 = Color3.fromRGB(60, 62, 66),
					ZIndex = 4,
					Parent = world,
				})
			end
		end
	end
	return { world = world, scale = scale, dots = dots, arrow = arrow, waypoint = wp }
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

local setWaypoint: (Vector3?) -> ()

local function nearestStreet(pos: Vector3): string?
	local best, bestDist = nil, MapData.ROAD_WIDTH / 2 + 14
	for _, r in MapData.ROADS do
		local along = if r.axis == "X" then pos.X else pos.Z
		local across = if r.axis == "X" then pos.Z else pos.X
		local dist = math.abs(across - r.at)
		if r.name and along >= r.from - 10 and along <= r.to + 10 and dist < bestDist then
			best, bestDist = r.name, dist
		end
	end
	return best
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
	}, { Ui.corner(MINI_SIZE / 2) })
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
	}, { Ui.corner(MINI_SIZE / 2), Ui.stroke(3, C.panel) })
	-- Compass letters sit on the ring.
	for _, c in { { "N", 0.5, 0 }, { "E", 1, 0.5 }, { "S", 0.5, 1 }, { "W", 0, 0.5 } } do
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(c[2], c[3]),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = if c[1] == "N" then C.accent else C.panel,
			ZIndex = 3,
			Parent = border,
		}, {
			Ui.corner(10),
			Ui.label(c[1], 12, {
				Size = UDim2.fromScale(1, 1),
				TextColor3 = if c[1] == "N" then C.ink else C.cream,
				ZIndex = 3,
			}),
		})
	end
	-- Waypoint pointer on the ring when the waypoint is off the minimap.
	edgeDot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(255, 80, 120),
		Visible = false,
		ZIndex = 4,
		Parent = border,
	}, { Ui.corner(6), Ui.stroke(2, C.cream) })
	-- Street and district under the minimap.
	local strip = Ui.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16 + MINI_SIZE + 8),
		Size = UDim2.fromOffset(MINI_SIZE + 24, 26),
		Parent = gui,
	})
	streetLabel = Ui.label("", 13, {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = strip,
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
	local legend = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 14),
		Size = UDim2.new(1, -200, 0, 26),
		BackgroundTransparency = 1,
		Parent = fullFrame,
	}, { Ui.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right) })
	local entries = {
		{ "Dumpster", Color3.fromRGB(120, 230, 140) },
		{ "Guarded", Color3.fromRGB(255, 120, 110) },
		{ "Locked", Color3.fromRGB(150, 150, 156) },
		{ "Store", Color3.fromRGB(80, 170, 255) },
		{ "Quest", Color3.fromRGB(190, 120, 255) },
		{ "Hideout", C.accent },
		{ "Waypoint", Color3.fromRGB(255, 80, 120) },
	}
	for i, entry in entries do
		local chip = Ui.new("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = legend,
		}, { Ui.list(Enum.FillDirection.Horizontal, 5) })
		Ui.new("Frame", {
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = entry[2],
			Parent = chip,
		}, { Ui.corner(5) })
		Ui.label(entry[1], 12, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			TextColor3 = C.muted,
			Parent = chip,
		})
	end
	Ui.label("Click the map to set a waypoint. Click it again to clear.", 12, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -2),
		Size = UDim2.new(0.7, 0, 0, 12),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = fullFrame,
	})
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
		full.world.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local w = full.world
			local f = (Vector2.new(input.Position.X, input.Position.Y) - w.AbsolutePosition)
				/ w.AbsoluteSize
			local spot = Vector3.new(B.x0 + f.X * (B.x1 - B.x0), 0, B.z1 - f.Y * (B.z1 - B.z0))
			-- Clicking near the current waypoint clears it.
			if waypoint and (waypoint - spot).Magnitude < 40 then
				setWaypoint(nil)
			else
				setWaypoint(spot)
			end
		end)
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

setWaypoint = function(spot: Vector3?)
	waypoint = spot
	if waypointPart then
		waypointPart:Destroy()
		waypointPart, waypointText = nil, nil
	end
	for _, canvas in { mini, full } do
		if canvas then
			canvas.waypoint.Visible = spot ~= nil
			if spot then
				local px, py = toPixel(canvas.scale, spot.X, spot.Z)
				canvas.waypoint.Position = UDim2.fromOffset(px, py)
			end
		end
	end
	if not spot then
		edgeDot.Visible = false
		return
	end
	-- A tall beacon in the world, visible through buildings.
	local beacon = Instance.new("Part")
	beacon.Name = "WaypointBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 80, 120)
	beacon.Transparency = 0.35
	beacon.Size = Vector3.new(3, 120, 3)
	beacon.Position = spot + Vector3.new(0, 60, 0)
	local tag = Instance.new("BillboardGui")
	tag.AlwaysOnTop = true
	tag.Size = UDim2.fromOffset(160, 36)
	tag.StudsOffset = Vector3.new(0, -30, 0)
	tag.LightInfluence = 0
	local label = Ui.label("", 20, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 150, 170),
		TextStrokeTransparency = 0.2,
		Parent = tag,
	})
	tag.Parent = beacon
	beacon.Parent = workspace
	waypointPart, waypointText = beacon, label
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

		local here = Districts.at(pos)
		local street = nearestStreet(pos)
		local area = if here then here.name else "Outskirts"
		streetLabel.Text = if street then `{street} · {area}` else area

		local wp = waypoint
		if wp then
			local flat = Vector3.new(wp.X - pos.X, 0, wp.Z - pos.Z)
			local dist = flat.Magnitude
			if dist < 18 then
				setWaypoint(nil)
			else
				if waypointText then
					waypointText.Text = `{math.floor(dist)} studs`
				end
				-- Pixel offset on the minimap (north-up: +Z is up, +X is right).
				local offset = Vector2.new(flat.X, -flat.Z) * mini.scale
				local radius = MINI_SIZE / 2 - 10
				edgeDot.Visible = offset.Magnitude > radius
				if edgeDot.Visible then
					local edge = offset.Unit * radius
					edgeDot.Position = UDim2.new(0.5, edge.X, 0.5, edge.Y)
				end
			end
		end
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
				showCard(d.name, d.note or "", Color3.fromRGB(196, 120, 60))
			elseif gate and state and not Quests.permitted(state.stats, d.id) then
				showCard(d.name, `Permit needed: {gate.text}`, Color3.fromRGB(150, 150, 156))
			else
				local stars = string.rep("★", d.tier)
					.. string.rep("☆", Districts.MAX_TIER - d.tier)
				local hot = workspace:GetAttribute("HotDistrict") == d.name
				showCard(
					if d.city == "port" then `{d.name} · Port Haven` else d.name,
					`Loot {stars}{if hot then "  ·  HOT TODAY" else ""}`,
					if hot then Color3.fromRGB(255, 140, 40) else C.accent
				)
			end
		end
	end)
end

return MapUi
