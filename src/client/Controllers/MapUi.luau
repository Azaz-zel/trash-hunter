--!strict
-- Minimap (top right), full-screen map (tap the minimap or press M) and the
-- location card shown when entering a district. Everything is drawn from
-- shared data (CityPlan roads, Config districts, stores, contacts and
-- dumpsters), so no screenshots or image assets are needed.
--
-- Minimap: a radar that turns with the camera, so the way you face is always
-- up (the N badge on the ring shows north). It zooms out while you drive and
-- shows the GPS route, the distance to the waypoint, and a pointer on the
-- ring when the waypoint is off the radar.
--
-- Full map (north up): opens centred on you. Drag to move, scroll / pinch /
-- the + and - buttons to zoom, the target button to jump back to yourself.
-- Tap a pin to see what it is and route there with "Set GPS"; tap empty
-- ground to drop a waypoint (tap it again to clear). The "Go to" buttons
-- route straight to the nearest Hideout, open dumpster, store, quest or
-- mission contact, and the "Show" chips hide or show each kind of pin.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Districts = require(Shared:WaitForChild("Districts"))
local MapData = require(Shared:WaitForChild("MapData"))
local CityPlan = require(Shared:WaitForChild("CityPlan"))
local Quests = require(Shared:WaitForChild("Quests"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local B = MapData.BOUNDS

local MINI_SIZE = 168
local MINI_SCALE = 0.22 -- pixels per stud on the minimap while walking
local MINI_DRIVE = 0.55 -- minimap zoom factor while driving (sees further)
local ZOOM_MAX = 8 -- full map, relative to the whole-city view
local ZOOM_OPEN = 3 -- full map zoom when opened
local SIDE = 196 -- full map sidebar width
local STUD_M = 0.28 -- metres per stud, for distances
local TAP_SLOP = 7 -- pixels a press may move and still count as a tap
local PICK_RADIUS = 16 -- pixels around a pin that select it

local GPS_COLOR = Color3.fromRGB(255, 80, 120)
local DISTRICT_TINT = {
	downtown = Color3.fromRGB(110, 90, 150),
	midtown = Color3.fromRGB(120, 130, 150),
	southside = Color3.fromRGB(150, 120, 100),
	eastgate = Color3.fromRGB(110, 150, 110),
	beach = Color3.fromRGB(200, 180, 130),
	hills = Color3.fromRGB(90, 140, 100),
	industrial = Color3.fromRGB(160, 140, 100),
	oldport = Color3.fromRGB(120, 110, 140),
	docks = Color3.fromRGB(110, 130, 150),
}

-- Pin kinds: map colour, legend name, and the "Go to" button text.
type Kind = { color: Color3, name: string, go: string?, order: number }
local KINDS: { [string]: Kind } = {
	hideout = { color = C.accent, name = "Hideout", go = "Hideout", order = 1 },
	dumpster = {
		color = Color3.fromRGB(120, 230, 140),
		name = "Dumpster",
		go = "Dumpster",
		order = 2,
	},
	guarded = { color = Color3.fromRGB(255, 120, 110), name = "Guarded", order = 3 },
	store = { color = Color3.fromRGB(80, 170, 255), name = "Store", go = "Store", order = 4 },
	quest = { color = Color3.fromRGB(190, 120, 255), name = "Quest", go = "Quest", order = 5 },
	contact = { color = Color3.fromRGB(255, 170, 30), name = "Mission", go = "Mission", order = 6 },
	friend = { color = Color3.fromRGB(90, 200, 255), name = "Players", order = 7 },
}
local LOCKED_COLOR = Color3.fromRGB(150, 150, 156)
-- Screen direction of each compass point on a north-up map.
local COMPASS: { [string]: Vector2 } = {
	N = Vector2.new(0, -1),
	E = Vector2.new(1, 0),
	S = Vector2.new(0, 1),
	W = Vector2.new(-1, 0),
}

type Place = {
	kind: string,
	name: string,
	pos: Vector3,
	index: number?, -- dumpster index into Config.World.Dumpsters
}
-- A full-map overlay element: positioned from its world point every layout.
type Pin = {
	frame: GuiObject,
	label: TextLabel?,
	pos: Vector3,
	kind: string, -- a KINDS key, or "street" / "district" / "me" / "waypoint"
	place: Place?,
	minZoom: number,
	maxZoom: number,
	labelZoom: number,
}
type MiniCanvas = { world: Frame, scale: UIScale, dots: { Frame }, arrow: Frame, waypoint: Frame }

local MapUi = {}

-- ─── places ───────────────────────────────────────────────────────────────

local places: { Place } = {}
for i, pos in Config.World.HIDEOUTS do
	table.insert(
		places,
		{ kind = "hideout", name = if i == 1 then "Hideout" else "Harbor Lockup", pos = pos }
	)
end
for _, s in Config.Stores do
	table.insert(places, { kind = "store", name = s.name, pos = s.counter })
end
for _, g in Config.Quests.givers do
	table.insert(places, { kind = "quest", name = g.name, pos = g.pos })
end
for _, c in Config.Contacts do
	table.insert(places, { kind = "contact", name = c.name, pos = c.pos })
end
for i, d in Config.World.Dumpsters do
	local red = d.zone == "Red"
	table.insert(places, {
		kind = if red then "guarded" else "dumpster",
		name = if red then "Guarded dumpster" else "Dumpster",
		pos = d.pos,
		index = i,
	})
end

-- District id per dumpster, for permit locks.
local dumpsterDistrict: { string } = {}
for i, d in Config.World.Dumpsters do
	local district = Districts.at(d.pos)
	dumpsterDistrict[i] = if district then district.id else "town"
end

-- ─── state ────────────────────────────────────────────────────────────────

local gui: ScreenGui
local mini: MiniCanvas
local miniRotor: Frame
local miniZoom = 1
local compass: { [string]: Frame } = {}
local edgeDot: Frame
local streetLabel: TextLabel
local fullFrame: Frame
local card: CanvasGroup
local cardTitle: TextLabel
local cardSub: TextLabel
local cardStripe: Frame

-- Full map view: the base drawing (fullWorld) is made once at scale s0 and
-- zoomed with a UIScale; pins live in an unscaled overlay on top.
local view = { s0 = 0.2, zoom = 1, fit = 1, ox = 0, oy = 0, w = 0, h = 0 }
local fullWorld: Frame? = nil
local fullScale: UIScale? = nil
local overlay: Frame
local holder: Frame
local pins: { Pin } = {}
local mePin: Pin? = nil
local waypointPin: Pin? = nil
local selectRing: Frame
local shown: { [string]: boolean } = {}
for kind in KINDS do
	shown[kind] = true
end

-- Info card in the sidebar.
local infoTitle: TextLabel
local infoSub: TextLabel
local infoDist: TextLabel
local infoButton: TextButton
local selected: Place? = nil

-- Ready time per dumpster, indexed like Config.World.Dumpsters.
local cooling: { number } = {}
-- Player-set waypoint, with its world beacon.
local waypoint: Vector3? = nil
local waypointPart: Part? = nil
local waypointText: TextLabel? = nil
local routeFrom: Vector3? = nil

local friendDots: { [Player]: { mini: Frame, pin: Pin? } } = {}

-- ─── helpers ──────────────────────────────────────────────────────────────

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function myPos(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function distanceText(studs: number): string
	local m = studs * STUD_M
	if m >= 1000 then
		return string.format("%.1f km", m / 1000)
	end
	return `{math.floor(m / 5 + 0.5) * 5} m`
end

-- World (x, z) to canvas pixels at a scale. Origin is the map's north-west corner.
local function toPixel(scale: number, x: number, z: number): (number, number)
	return (x - B.x0) * scale, (B.z1 - z) * scale
end

-- Turns a screen-space vector by `deg` degrees clockwise (screen y is down).
local function turn(v: Vector2, deg: number): Vector2
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

local function uiScale(): number
	local s = gui and gui:FindFirstChildOfClass("UIScale")
	return if s then s.Scale else 1
end

local function dumpsterState(i: number): (boolean, boolean)
	local state = Store.get()
	local ready = (cooling[i] or 0) <= os.clock()
	local locked = state ~= nil and not Quests.permitted(state.permits, dumpsterDistrict[i])
	return ready, locked
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

-- A road or route piece between two world points.
local function segment(
	parent: Instance,
	scale: number,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3,
	z: number
): Frame
	local ax, ay = toPixel(scale, a.X, a.Z)
	local bx, by = toPixel(scale, b.X, b.Z)
	local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	return Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(len + width * 0.5, width),
		Rotation = math.deg(math.atan2(by - ay, bx - ax)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
end

local function dot(parent: Instance, color: Color3, size: number, zIndex: number): Frame
	return Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Parent = parent,
	}, { Ui.corner(size), Ui.stroke(1, C.ink) })
end

-- Player arrow: a cream disc with an accent nose (points up at Rotation 0).
local function arrowIcon(parent: Instance, zIndex: number): Frame
	local arrow = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		Parent = parent,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = C.cream,
		ZIndex = zIndex,
		Parent = arrow,
	}, { Ui.corner(7), Ui.stroke(2, C.ink) })
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(5, 10),
		BackgroundColor3 = C.accent,
		ZIndex = zIndex + 1,
		Parent = arrow,
	}, { Ui.corner(2) })
	return arrow
end

local function waypointIcon(parent: Instance, zIndex: number): Frame
	local wp = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(16, 20),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = zIndex,
		Parent = parent,
	})
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = GPS_COLOR,
		ZIndex = zIndex,
		Parent = wp,
	}, { Ui.corner(8), Ui.stroke(2, C.cream) })
	return wp
end

-- Land, sand, districts, the guarded yard, roads and the (empty) GPS route
-- layer, drawn into a frame at `scale` pixels per stud.
local function drawBase(parent: Instance, scale: number, routeWidth: number): Frame
	local world = Ui.new("Frame", {
		Name = "World",
		BackgroundColor3 = Color3.fromRGB(34, 74, 100), -- open water
		BorderSizePixel = 0,
		Size = UDim2.fromOffset((B.x1 - B.x0) * scale, (B.z1 - B.z0) * scale),
		Parent = parent,
	})
	world:SetAttribute("RouteWidth", routeWidth)
	world:SetAttribute("Scale", scale)
	for _, r in CityPlan.LAND do
		rect(world, scale, r.x0, r.x1, r.z0, r.z1, Color3.fromRGB(58, 70, 54), 0, 1)
	end
	-- Sand: strips from the shore to the winding coastal drive.
	for z = -1990, 2040, 60 do
		local edge = CityPlan.sandEdge(z + 30)
		rect(world, scale, -2250, edge, z, z + 60, Color3.fromRGB(214, 196, 150), 0, 1)
	end
	for _, d in Config.Districts do
		rect(world, scale, d.x0, d.x1, d.z0, d.z1, DISTRICT_TINT[d.id] or C.panelLight, 0.55, 1)
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
	-- Roads follow their curves: freeway amber, arterials white, others grey.
	for _, e in CityPlan.EDGES do
		local color = if e.kind == "freeway"
			then Color3.fromRGB(240, 180, 60)
			elseif e.kind == "arterial" then Color3.fromRGB(232, 234, 238)
			else Color3.fromRGB(176, 180, 186)
		local z = if e.kind == "freeway" then 4 else 3
		local wpx =
			math.max(if e.kind == "arterial" or e.kind == "freeway" then 2 else 1, e.w * scale)
		for k = 2, #e.points do
			segment(world, scale, e.points[k - 1], e.points[k], wpx, color, z)
		end
	end
	for _, n in CityPlan.NODES do
		if n.bulb then
			local px, py = toPixel(scale, n.pos.X, n.pos.Z)
			local r = math.max(3, CityPlan.BULB_R * 2 * scale)
			Ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(px, py),
				Size = UDim2.fromOffset(r, r),
				BackgroundColor3 = Color3.fromRGB(176, 180, 186),
				ZIndex = 3,
				Parent = world,
			}, { Ui.corner(r) })
		end
	end
	Ui.new("Frame", {
		Name = "Route",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = world,
	})
	return world
end

-- ─── minimap ──────────────────────────────────────────────────────────────

local function buildMini(miniFrame: CanvasGroup)
	-- The rotor is a zero-size frame at the radar centre: turning it turns the
	-- whole drawing around the player.
	miniRotor = Ui.new("Frame", {
		Name = "Rotor",
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = miniFrame,
	})
	local world = drawBase(miniRotor, MINI_SCALE, 3)
	local scale = Ui.new("UIScale", { Parent = world })
	local function pin(pos: Vector3, color: Color3, size: number, zIndex: number): Frame
		local f = dot(world, color, size, zIndex)
		local px, py = toPixel(MINI_SCALE, pos.X, pos.Z)
		f.Position = UDim2.fromOffset(px, py)
		return f
	end
	local dots: { Frame } = {}
	for _, p in places do
		if p.index then
			dots[p.index] = pin(p.pos, KINDS[p.kind].color, 5, 5)
		else
			local f = pin(p.pos, KINDS[p.kind].color, if p.kind == "hideout" then 11 else 9, 6)
			if p.kind == "contact" then
				Ui.label(
					"!",
					9,
					{ Size = UDim2.fromScale(1, 1), TextColor3 = C.ink, ZIndex = 7, Parent = f }
				)
			end
		end
	end
	local wp = waypointIcon(world, 9)
	local arrow = arrowIcon(world, 10)
	mini = { world = world, scale = scale, dots = dots, arrow = arrow, waypoint = wp }
end

-- ─── full map: view ───────────────────────────────────────────────────────

local function toScreen(pos: Vector3): (number, number)
	local k = view.s0 * view.zoom
	return (pos.X - B.x0) * k + view.ox, (B.z1 - pos.Z) * k + view.oy
end

local function fromScreen(px: number, py: number): Vector3
	local k = view.s0 * view.zoom
	return Vector3.new(B.x0 + (px - view.ox) / k, 0, B.z1 - (py - view.oy) / k)
end

local function clampView()
	local mw, mh = (B.x1 - B.x0) * view.s0 * view.zoom, (B.z1 - B.z0) * view.s0 * view.zoom
	view.ox = if mw <= view.w then (view.w - mw) / 2 else math.clamp(view.ox, view.w - mw, 0)
	view.oy = if mh <= view.h then (view.h - mh) / 2 else math.clamp(view.oy, view.h - mh, 0)
end

local function layoutFull()
	local world, scale = fullWorld, fullScale
	if not world or not scale then
		return
	end
	clampView()
	world.Position = UDim2.fromOffset(view.ox, view.oy)
	scale.Scale = view.zoom
	local z = view.zoom
	for _, p in pins do
		local on = z >= p.minZoom and z < p.maxZoom and (KINDS[p.kind] == nil or shown[p.kind])
		if p.kind == "waypoint" then
			on = on and waypoint ~= nil
		end
		p.frame.Visible = on
		if on then
			local x, y = toScreen(p.pos)
			p.frame.Position = UDim2.fromOffset(x, y)
			if p.label then
				p.label.Visible = z >= p.labelZoom or (selected ~= nil and p.place == selected)
			end
		end
	end
	local sel = selected
	selectRing.Visible = sel ~= nil
	if sel then
		local x, y = toScreen(sel.pos)
		selectRing.Position = UDim2.fromOffset(x, y)
	end
end

-- Zooms to `zoom`, keeping the world point under holder pixel (px, py) still.
local function zoomAt(zoom: number, px: number, py: number)
	local z = math.clamp(zoom, view.fit, ZOOM_MAX)
	view.ox = px - (px - view.ox) * z / view.zoom
	view.oy = py - (py - view.oy) * z / view.zoom
	view.zoom = z
	layoutFull()
end

local function centerOn(pos: Vector3, zoom: number?)
	view.zoom = math.clamp(zoom or view.zoom, view.fit, ZOOM_MAX)
	local k = view.s0 * view.zoom
	view.ox = view.w / 2 - (pos.X - B.x0) * k
	view.oy = view.h / 2 - (B.z1 - pos.Z) * k
	layoutFull()
end

local function addPin(pin: Pin): Pin
	pin.frame.Parent = overlay
	table.insert(pins, pin)
	return pin
end

local function pinLabel(parent: GuiObject, text: string, size: number): TextLabel
	return Ui.label(text, size, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(150, size + 2),
		Font = Ui.FONT,
		TextColor3 = C.cream,
		TextStrokeTransparency = 0.2,
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
end

local function buildPins()
	-- District names: big, only when zoomed out.
	for _, d in Config.Districts do
		local label = Ui.label(string.upper(d.name), 15, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(180, 18),
			Font = Ui.FONT,
			TextColor3 = C.cream,
			TextTransparency = 0.15,
			TextStrokeTransparency = 0.4,
			ZIndex = 4,
		})
		addPin({
			frame = label,
			pos = Vector3.new((d.x0 + d.x1) / 2, 0, (d.z0 + d.z1) / 2),
			kind = "district",
			minZoom = 0,
			maxZoom = 2.6, -- street names take over from here
			labelZoom = 0,
		})
	end
	-- Street names on the longest piece of each named road, when zoomed in.
	local longest: { [string]: any } = {}
	for _, e in CityPlan.EDGES do
		if e.name and (longest[e.name] == nil or e.length > longest[e.name].length) then
			longest[e.name] = e
		end
	end
	for name, e in longest do
		local mid, t = CityPlan.pointAt(e, e.length / 2)
		local angle = math.deg(math.atan2(-t.Z, t.X))
		if angle > 90 then
			angle -= 180
		elseif angle < -90 then
			angle += 180
		end
		local label = Ui.label(name, 11, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(130, 13),
			Rotation = angle,
			TextColor3 = Color3.fromRGB(40, 42, 46),
			ZIndex = 4,
		})
		addPin({
			frame = label,
			pos = mid,
			kind = "street",
			minZoom = 2.6,
			maxZoom = math.huge,
			labelZoom = 0,
		})
	end
	-- Places.
	for _, p in places do
		local kind = KINDS[p.kind]
		local size = if p.index then 7 elseif p.kind == "hideout" then 16 else 13
		local f = dot(overlay, kind.color, size, if p.index then 5 else 6)
		local label: TextLabel? = nil
		if not p.index then
			label = pinLabel(f, p.name, 12)
		end
		if p.kind == "contact" then
			Ui.label(
				"!",
				11,
				{ Size = UDim2.fromScale(1, 1), TextColor3 = C.ink, ZIndex = 7, Parent = f }
			)
		end
		addPin({
			frame = f,
			label = label,
			pos = p.pos,
			kind = p.kind,
			place = p,
			minZoom = 0,
			maxZoom = math.huge,
			labelZoom = if p.kind == "hideout" then 0 else 2.2,
		})
	end
	waypointPin = addPin({
		frame = waypointIcon(overlay, 9),
		pos = Vector3.zero,
		kind = "waypoint",
		minZoom = 0,
		maxZoom = math.huge,
		labelZoom = 0,
	})
	mePin = addPin({
		frame = arrowIcon(overlay, 10),
		pos = Vector3.zero,
		kind = "me",
		minZoom = 0,
		maxZoom = math.huge,
		labelZoom = 0,
	})
end

-- ─── GPS ──────────────────────────────────────────────────────────────────

-- The shortest road route from `from` to the waypoint, drawn on both maps.
local function drawRoute(from: Vector3?)
	routeFrom = from
	local layers = {}
	for _, world in { mini and mini.world, fullWorld } do
		local layer = world and world:FindFirstChild("Route")
		if layer then
			layer:ClearAllChildren()
			table.insert(layers, layer)
		end
	end
	local wp = waypoint
	if not wp or not from then
		return
	end
	local nodes = CityPlan.route(from, wp)
	local points = { from }
	for k, n in nodes do
		local nextNode = nodes[k + 1]
		if nextNode then
			local e = CityPlan.edgeBetween(n, nextNode)
			if e then
				local pts = e.points
				local forward = e.a == n
				for q = 1, #pts do
					table.insert(points, pts[if forward then q else #pts - q + 1])
				end
			end
		else
			table.insert(points, n.pos)
		end
	end
	table.insert(points, wp)
	for _, layer in layers do
		local world = layer.Parent :: Frame
		local scale = world:GetAttribute("Scale") :: number
		local width = world:GetAttribute("RouteWidth") :: number
		for k = 2, #points do
			segment(layer, scale, points[k - 1], points[k], width, GPS_COLOR, 6)
		end
	end
end

local refreshInfo: () -> ()

local function setWaypoint(spot: Vector3?)
	waypoint = spot
	drawRoute(if spot then myPos() else nil)
	if waypointPart then
		waypointPart:Destroy()
		waypointPart, waypointText = nil, nil
	end
	mini.waypoint.Visible = spot ~= nil
	if spot then
		local px, py = toPixel(MINI_SCALE, spot.X, spot.Z)
		mini.waypoint.Position = UDim2.fromOffset(px, py)
	end
	local wpPin = waypointPin
	if wpPin then
		wpPin.pos = spot or Vector3.zero
	end
	layoutFull()
	refreshInfo()
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
	beacon.Color = GPS_COLOR
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

local function routeTo(place: Place)
	selected = place
	setWaypoint(place.pos)
end

-- ─── info card & quick routes ─────────────────────────────────────────────

local function describe(place: Place): string
	local d = Districts.at(place.pos)
	local area = if d then d.name else "Outskirts"
	local i = place.index
	if i then
		local ready, locked = dumpsterState(i)
		if locked then
			local m = Quests.missionFor(dumpsterDistrict[i])
			local who = if m then Config.Contacts[m.contact].name else "a contact"
			return `{area} · locked, get a permit from {who}`
		elseif place.kind == "guarded" then
			return `{area} · guarded yard, watch the patrols`
		end
		local stars = if d then string.rep("★", d.tier) else ""
		return `{area} {stars} · {if ready then "ready to search" else "searched, refilling"}`
	end
	local what = ({
		hideout = "sell loot, display, upgrades",
		store = "buy gear and cars",
		quest = "daily quest",
		contact = "district permit mission",
	})[place.kind] or ""
	return `{area} · {what}`
end

refreshInfo = function()
	if not infoTitle then
		return
	end
	local pos = myPos()
	local sel = selected
	if sel then
		infoTitle.Text = sel.name
		infoTitle.TextColor3 = if KINDS[sel.kind] then KINDS[sel.kind].color else GPS_COLOR
		infoSub.Text = describe(sel)
	elseif waypoint then
		infoTitle.Text = "Waypoint"
		infoTitle.TextColor3 = GPS_COLOR
		local d = Districts.at(waypoint :: Vector3)
		infoSub.Text = if d then d.name else "Outskirts"
	else
		infoTitle.Text = "Pick a place"
		infoTitle.TextColor3 = C.cream
		infoSub.Text = "Tap a pin, or use Go to below. Tap empty ground to drop a waypoint."
	end
	local target = if sel then sel.pos else waypoint
	infoDist.Text = if target and pos
		then `{distanceText((flat(target) - flat(pos)).Magnitude)} away`
		else ""
	local routed = waypoint ~= nil
		and target ~= nil
		and (flat(waypoint :: Vector3) - flat(target)).Magnitude < 1
	infoButton.Visible = target ~= nil
	infoButton.Text = if routed then "Clear GPS" else "Set GPS"
	infoButton.BackgroundColor3 = if routed then C.panelLight else GPS_COLOR
	layoutFull()
end

local function selectPlace(place: Place?)
	selected = place
	refreshInfo()
end

-- Nearest place of a kind (dumpsters: ready, unlocked and outside the yard).
local function nearest(kind: string): Place?
	local pos = myPos() or Config.World.SPAWN
	local best, bestD = nil, math.huge
	for _, p in places do
		if p.kind == kind then
			local i = p.index
			if i then
				local ready, locked = dumpsterState(i)
				if not ready or locked then
					continue
				end
			end
			local d = (flat(p.pos) - flat(pos)).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- ─── full map: build & input ──────────────────────────────────────────────

-- Small flat button (Ui.button has a 52px minimum, too big for the sidebar).
local function chip(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local b: TextButton = Ui.new("TextButton", {
		Size = UDim2.fromOffset(0, 32),
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Font = Ui.FONT,
		TextSize = 14,
		TextColor3 = C.cream,
		Text = text,
		Parent = parent,
	}, { Ui.corner(8), Ui.stroke(1, color) })
	b.Activated:Connect(onClick)
	return b
end

local function roundButton(text: string, order: number, onClick: () -> ()): TextButton
	local b: TextButton = Ui.new("TextButton", {
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Font = Ui.FONT,
		TextSize = 22,
		TextColor3 = C.cream,
		Text = text,
		LayoutOrder = order,
		ZIndex = 20,
	}, { Ui.corner(19), Ui.stroke() })
	b.Activated:Connect(onClick)
	return b
end

local function sectionTitle(parent: Instance, text: string, order: number)
	Ui.label(text, 12, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.muted,
		Font = Ui.FONT,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function openMap(open: boolean)
	fullFrame.Visible = open
	if open and fullWorld then
		local pos = myPos()
		if pos then
			centerOn(pos, math.max(view.zoom, ZOOM_OPEN))
		end
		refreshInfo()
	end
end

local function buildFull()
	fullFrame = Ui.panel({
		Name = "FullMap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.9),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	fullFrame.BackgroundTransparency = 0.04
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 760) }).Parent = fullFrame
	Ui.label("Map", 22, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.5, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = fullFrame,
	})
	local hint = if UserInputService.TouchEnabled
		then "Drag to move · pinch to zoom · tap a pin"
		else "Drag to move · scroll to zoom · click a pin · M to close"
	Ui.label(hint, 12, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0.6, -120, 0, 14),
		TextColor3 = C.muted,
		Parent = fullFrame,
	})
	local close = Ui.button("Close", "secondary", UDim2.fromOffset(72, 36), function()
		openMap(false)
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 8)
	close.TextSize = 15
	close.Parent = fullFrame

	-- Map area (left) clips the zoomed drawing.
	holder = Ui.new("Frame", {
		Name = "MapArea",
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -SIDE - 34, 1, -64),
		BackgroundColor3 = Color3.fromRGB(34, 74, 100),
		ClipsDescendants = true,
		Parent = fullFrame,
	}, { Ui.corner(10) })
	overlay = Ui.new("Frame", {
		Name = "Pins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 5,
		Parent = holder,
	})
	selectRing = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 8,
		Parent = overlay,
	}, { Ui.corner(13), Ui.new("UIStroke", { Thickness = 2, Color = C.cream }) })
	local zoomBar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(38, 130),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = holder,
	}, { Ui.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
	roundButton("+", 1, function()
		zoomAt(view.zoom * 1.5, view.w / 2, view.h / 2)
	end).Parent =
		zoomBar
	roundButton("−", 2, function()
		zoomAt(view.zoom / 1.5, view.w / 2, view.h / 2)
	end).Parent =
		zoomBar
	roundButton("◎", 3, function()
		local pos = myPos()
		if pos then
			centerOn(pos)
		end
	end).Parent =
		zoomBar

	-- Sidebar (right): selected place, quick routes, pin filters.
	local side = Ui.new("ScrollingFrame", {
		Name = "Sidebar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 52),
		Size = UDim2.new(0, SIDE, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = fullFrame,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })
	local info = Ui.new("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panelLight,
		BackgroundTransparency = 0.3,
		LayoutOrder = 1,
		Parent = side,
	}, { Ui.corner(10), Ui.padding(10), Ui.list(Enum.FillDirection.Vertical, 4) })
	infoTitle = Ui.label("", 17, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Ui.FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = info,
	})
	infoSub = Ui.label("", 13, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = info,
	})
	infoDist = Ui.label("", 13, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		Parent = info,
	})
	infoButton = chip(info, "Set GPS", GPS_COLOR, function()
		local target = if selected then (selected :: Place).pos else waypoint
		if waypoint and target and (flat(waypoint :: Vector3) - flat(target)).Magnitude < 1 then
			selected = nil
			setWaypoint(nil)
		elseif selected then
			routeTo(selected :: Place)
		end
	end)
	infoButton.Size = UDim2.new(1, 0, 0, 34)
	infoButton.LayoutOrder = 4

	sectionTitle(side, "GO TO", 2)
	local go = Ui.new("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = side,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -3, 0, 32),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for kindId, kind in KINDS do
		local label = kind.go
		if label then
			local b = chip(go, label, kind.color, function()
				local p = nearest(kindId)
				if p then
					routeTo(p)
					if fullWorld then
						centerOn(p.pos)
					end
				else
					selectPlace(nil)
					infoTitle.Text = `No {string.lower(kind.name)} to go to`
					infoSub.Text = if kindId == "dumpster"
						then "Every open dumpster nearby is refilling or locked. Try another district."
						else ""
				end
			end)
			b.LayoutOrder = kind.order
		end
	end
	local clear = chip(go, "Clear GPS", C.muted, function()
		selected = nil
		setWaypoint(nil)
	end)
	clear.LayoutOrder = 99

	sectionTitle(side, "SHOW", 4)
	local filters = Ui.new("Frame", {
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = side,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -3, 0, 28),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for kindId, kind in KINDS do
		local b: TextButton = Ui.new("TextButton", {
			BackgroundColor3 = C.panelLight,
			BackgroundTransparency = 0.4,
			Text = "",
			LayoutOrder = kind.order,
			Parent = filters,
		}, { Ui.corner(8) })
		local swatch = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = kind.color,
			Parent = b,
		}, { Ui.corner(5) })
		local text = Ui.label(kind.name, 13, {
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -26, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = b,
		})
		b.Activated:Connect(function()
			shown[kindId] = not shown[kindId]
			local on = shown[kindId]
			swatch.BackgroundTransparency = if on then 0 else 0.8
			text.TextTransparency = if on then 0 else 0.6
			for _, f in friendDots do
				f.mini.Visible = shown.friend
			end
			layoutFull()
		end)
	end
	Ui.label(
		"Pins are the same on the radar (top right). The radar turns with your camera: up is the way you face.",
		12,
		{
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 6,
			Parent = side,
		}
	)

	-- Pointer and touch: drag pans, a tap picks; wheel and pinch zoom.
	local press: { at: Vector2, ox: number, oy: number, moved: boolean, input: InputObject }? = nil
	local function localPos(input: InputObject): Vector2
		local s = uiScale()
		return (Vector2.new(input.Position.X, input.Position.Y) - holder.AbsolutePosition) / s
	end
	local function tap(at: Vector2)
		if at.X > view.w - 54 and at.Y > view.h - 146 then
			return -- on the zoom buttons
		end
		-- Nearest visible pin under the tap.
		local best, bestD = nil, PICK_RADIUS
		for _, p in pins do
			if p.place and p.frame.Visible then
				local x, y = toScreen(p.pos)
				local d = (Vector2.new(x, y) - at).Magnitude
				if d < bestD then
					best, bestD = p.place, d
				end
			end
		end
		if best then
			selectPlace(best)
			return
		end
		local wp = waypoint
		if wp then
			local x, y = toScreen(wp)
			if (Vector2.new(x, y) - at).Magnitude < PICK_RADIUS then
				selected = nil
				setWaypoint(nil)
				return
			end
		end
		selected = nil
		setWaypoint(fromScreen(at.X, at.Y))
	end
	overlay.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if
			(t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and not press
		then
			press =
				{ at = localPos(input), ox = view.ox, oy = view.oy, moved = false, input = input }
		end
	end)
	overlay.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local at = localPos(input)
			zoomAt(view.zoom * 1.25 ^ input.Position.Z, at.X, at.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local p = press
		if not p or not fullFrame.Visible then
			return
		end
		local t = input.UserInputType
		local mine = (
			t == Enum.UserInputType.MouseMovement
			and p.input.UserInputType == Enum.UserInputType.MouseButton1
		) or input == p.input
		if mine then
			local delta = localPos(input) - p.at
			if delta.Magnitude > TAP_SLOP then
				p.moved = true
			end
			if p.moved then
				view.ox, view.oy = p.ox + delta.X, p.oy + delta.Y
				layoutFull()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local p = press
		if not p then
			return
		end
		local t = input.UserInputType
		if
			input == p.input
			or (t == Enum.UserInputType.MouseButton1 and p.input.UserInputType == t)
		then
			press = nil
			if not p.moved and fullFrame.Visible then
				tap(p.at)
			end
		end
	end)
	local pinchFrom = 1
	UserInputService.TouchPinch:Connect(function(positions, scale, _velocity, state)
		if not fullFrame.Visible or #positions < 2 then
			return
		end
		local p = press
		if p then
			p.moved = true -- a pinch is never a tap
		end
		if state == Enum.UserInputState.Begin then
			pinchFrom = view.zoom
		end
		local s = uiScale()
		local mid = ((positions[1] + positions[2]) / 2 - holder.AbsolutePosition) / s
		zoomAt(pinchFrom * scale, mid.X, mid.Y)
	end)

	-- Draw once the area has a size; refit if the screen changes.
	local function measure()
		local size = holder.AbsoluteSize / uiScale()
		view.w, view.h = size.X, size.Y
		view.fit =
			math.min(1, view.w / ((B.x1 - B.x0) * view.s0), view.h / ((B.z1 - B.z0) * view.s0))
		layoutFull()
	end
	task.defer(function()
		local size = holder.AbsoluteSize / uiScale()
		local s0 = math.min(size.X / (B.x1 - B.x0), size.Y / (B.z1 - B.z0))
		view.s0 = if s0 > 0 then s0 else 0.15
		-- The drawing sits under the pins; its route line scales with the roads.
		local world = drawBase(holder, view.s0, math.max(1.4, 9 * view.s0))
		world.ZIndex = 1
		fullWorld = world
		fullScale = Ui.new("UIScale", { Parent = world })
		buildPins()
		measure()
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		if waypoint then
			drawRoute(myPos())
		end
	end)
end

-- ─── build ────────────────────────────────────────────────────────────────

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Map",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Minimap: a round radar window centred on the player.
	local miniFrame: CanvasGroup = Ui.new("CanvasGroup", {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		BackgroundColor3 = Color3.fromRGB(34, 74, 100),
		Parent = gui,
	}, { Ui.corner(MINI_SIZE / 2) })
	buildMini(miniFrame)
	local miniButton = Ui.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = miniFrame,
	})
	miniButton.Activated:Connect(function()
		openMap(not fullFrame.Visible)
	end)
	local border = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		Parent = gui,
	}, { Ui.corner(MINI_SIZE / 2), Ui.stroke(3, C.panel) })
	-- Compass badges ride the ring as the radar turns.
	for _, c in { "N", "E", "S", "W" } do
		compass[c] = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if c == "N" then 22 else 16, if c == "N" then 22 else 16),
			BackgroundColor3 = if c == "N" then C.accent else C.panel,
			ZIndex = 3,
			Parent = border,
		}, {
			Ui.corner(11),
			Ui.label(c, if c == "N" then 13 else 10, {
				Size = UDim2.fromScale(1, 1),
				TextColor3 = if c == "N" then C.ink else C.cream,
				Font = Ui.FONT,
				ZIndex = 3,
			}),
		})
	end
	-- Waypoint pointer on the ring when the waypoint is off the radar.
	edgeDot = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = GPS_COLOR,
		Visible = false,
		ZIndex = 4,
		Parent = border,
	}, { Ui.corner(6), Ui.stroke(2, C.cream) })
	-- "M" key badge for keyboard players.
	if not UserInputService.TouchEnabled then
		Ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.fromOffset(34, 18),
			BackgroundColor3 = C.panel,
			ZIndex = 5,
			Parent = border,
		}, {
			Ui.corner(6),
			Ui.label("M map", 10, { Size = UDim2.fromScale(1, 1), Font = Ui.FONT, ZIndex = 5 }),
		})
	end
	-- Street, district and GPS distance under the radar.
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
		RichText = true,
		Parent = strip,
	})

	buildFull()

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

local function refreshDots()
	for i, f in mini.dots do
		local ready, locked = dumpsterState(i)
		f.BackgroundTransparency = if ready and not locked then 0 else 0.75
		f.BackgroundColor3 = if locked
			then LOCKED_COLOR
			elseif Config.World.Dumpsters[i].zone == "Red" then KINDS.guarded.color
			else KINDS.dumpster.color
	end
	if not fullFrame.Visible then
		return
	end
	for _, p in pins do
		local place = p.place
		local i = place and place.index
		if i then
			local f = mini.dots[i]
			if f then
				p.frame.BackgroundTransparency = f.BackgroundTransparency
				p.frame.BackgroundColor3 = f.BackgroundColor3
			end
		end
	end
end

local function nearestStreet(pos: Vector3): string?
	local best, bestDist = nil, 26
	for _, e in CityPlan.EDGES do
		if e.name then
			for k = 2, #e.points do
				local a = flat(e.points[k - 1])
				local b = flat(e.points[k])
				local p = flat(pos)
				local ab = b - a
				local t = if ab.Magnitude > 0
					then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
					else 0
				local d = (p - (a + ab * t)).Magnitude - e.w / 2
				if d < bestDist then
					best, bestDist = e.name, d
				end
			end
		end
	end
	return best
end

-- Other players: blue dots on the radar and the full map.
local function updateFriends()
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local entry = friendDots[other]
		if not entry then
			local m = dot(mini.world, KINDS.friend.color, 8, 8)
			local pin: Pin? = nil
			if fullWorld then
				local f = dot(overlay, KINDS.friend.color, 10, 8)
				local label = pinLabel(f, other.DisplayName, 12)
				pin = addPin({
					frame = f,
					label = label,
					pos = Vector3.zero,
					kind = "friend",
					minZoom = 0,
					maxZoom = math.huge,
					labelZoom = 1.5,
				})
			end
			entry = { mini = m, pin = pin }
			friendDots[other] = entry
		end
		local e = entry :: { mini: Frame, pin: Pin? }
		e.mini.Visible = root ~= nil and shown.friend
		if root then
			local px, py = toPixel(MINI_SCALE, root.Position.X, root.Position.Z)
			e.mini.Position = UDim2.fromOffset(px, py)
			if e.pin then
				e.pin.pos = root.Position
			end
		end
	end
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
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			openMap(not fullFrame.Visible)
		elseif input.KeyCode == Enum.KeyCode.Escape and fullFrame.Visible then
			openMap(false)
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		local entry = friendDots[other]
		if entry then
			entry.mini:Destroy()
			local pin = entry.pin
			if pin then
				pin.frame:Destroy()
				local k = table.find(pins, pin)
				if k then
					table.remove(pins, k)
				end
			end
			friendDots[other] = nil
		end
	end)

	local camera = workspace.CurrentCamera
	local lastDistrict: string? = nil
	local wasRed = false
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local pos = root.Position
		-- Radar: turn with the camera, zoom out while driving.
		local look = camera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, look.Z)) -- 0 = north, 90 = east
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		local driving = humanoid ~= nil and humanoid.SeatPart ~= nil
		miniZoom += ((if driving then MINI_DRIVE else 1) - miniZoom) * math.min(1, dt * 3)
		mini.scale.Scale = miniZoom
		local px, py = toPixel(MINI_SCALE, pos.X, pos.Z)
		mini.world.Position = UDim2.fromOffset(-px * miniZoom, -py * miniZoom)
		mini.arrow.Position = UDim2.fromOffset(px, py)
		mini.arrow.Rotation = heading
		miniRotor.Rotation = -heading
		local ring = MINI_SIZE / 2
		for name, dir in COMPASS do
			local v = turn(dir, -heading) * ring
			compass[name].Position = UDim2.new(0.5, v.X, 0.5, v.Y)
		end
		local me = mePin
		if me and fullFrame.Visible then
			me.pos = pos
			me.frame.Rotation = heading
			local x, y = toScreen(pos)
			me.frame.Position = UDim2.fromOffset(x, y)
		end

		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0

		local here = Districts.at(pos)
		local street = nearestStreet(pos)
		local area = if here then here.name else "Outskirts"
		local where = if street then `{street} · {area}` else area
		local wp = waypoint
		if wp then
			local offsetWorld = Vector3.new(wp.X - pos.X, 0, wp.Z - pos.Z)
			local dist = offsetWorld.Magnitude
			if dist < 18 then
				selected = nil
				setWaypoint(nil)
				streetLabel.Text = where
			else
				-- Re-route once the player has moved well away from the last start.
				local from = routeFrom
				if from == nil or (flat(from) - flat(pos)).Magnitude > 60 then
					drawRoute(pos)
				end
				streetLabel.Text =
					`<font color="#FF5078"><b>GPS {distanceText(dist)}</b></font>  {where}`
				if waypointText then
					waypointText.Text = distanceText(dist)
				end
				-- Ring pointer: the waypoint's direction on the turned radar.
				local offset = turn(
					Vector2.new(offsetWorld.X, -offsetWorld.Z) * MINI_SCALE * miniZoom,
					-heading
				)
				local radius = MINI_SIZE / 2 - 10
				edgeDot.Visible = offset.Magnitude > radius
				if edgeDot.Visible then
					local edge = offset.Unit * radius
					edgeDot.Position = UDim2.new(0.5, edge.X, 0.5, edge.Y)
				end
			end
		else
			streetLabel.Text = where
		end
		refreshDots()
		updateFriends()
		if fullFrame.Visible then
			layoutFull()
			if selected or waypoint then
				refreshInfo()
			end
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
		local d = here
		if d and d.id ~= lastDistrict then
			lastDistrict = d.id
			local state = Store.get()
			local m = Quests.missionFor(d.id)
			if red then
				return -- the private-property card already showed
			elseif d.tier == 0 then
				showCard(d.name, d.note or "", Color3.fromRGB(196, 120, 60))
			elseif m and state and not Quests.permitted(state.permits, d.id) then
				showCard(
					d.name,
					`Locked · find {Config.Contacts[m.contact].name} for a permit`,
					LOCKED_COLOR
				)
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
