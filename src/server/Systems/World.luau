--!strict
-- Builds the town at server start so the whole map lives in git.
-- Reference: a small American town. Commercial strip on Main St with service
-- alleys behind it (where the dumpsters are), a strip mall with a rear
-- loading lane, a gas station, a motel, a park, apartments, a residential
-- grid along Maple Ave, and the Meridian Logistics yard (the private
-- property) north of Industrial Rd. Scale: about 1 stud = 0.3 m.
-- Layout uses a fixed random seed so every server builds the same town.

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Districts = require(ReplicatedStorage.Shared.Districts)
local CityPlan = require(ReplicatedStorage.Shared.CityPlan)
local CityDistricts = require(script.Parent.Parent.CityDistricts)
local Infill = require(script.Parent.Parent.Infill)
local Roads = require(script.Parent.Parent.Roads)
local Npc = require(script.Parent.Parent.Npc)

local W = Config.World
local FONT = Enum.Font.GothamBold
local POLICE_CAR_ASSET = 6418230807 -- Roblox-owned, so InsertService may load it
local M = Enum.Material

local ROAD_W = 34
local WALK_W = 10
local ROAD_TOP = 0.2
local WALK_TOP = 0.24 -- sidewalks sit flush with the street

local C = {
	asphalt = Color3.fromRGB(58, 60, 64),
	asphaltLight = Color3.fromRGB(78, 80, 84),
	concrete = Color3.fromRGB(176, 174, 168),
	concreteDark = Color3.fromRGB(140, 138, 132),
	lineYellow = Color3.fromRGB(226, 186, 52),
	lineWhite = Color3.fromRGB(232, 232, 228),
	metal = Color3.fromRGB(120, 124, 130),
	darkMetal = Color3.fromRGB(62, 64, 70),
	glass = Color3.fromRGB(70, 92, 110),
	trim = Color3.fromRGB(236, 234, 228),
	roof = Color3.fromRGB(70, 66, 64),
	roofBrown = Color3.fromRGB(96, 74, 60),
	brick = Color3.fromRGB(150, 82, 64),
	wood = Color3.fromRGB(120, 86, 58),
	fenceWood = Color3.fromRGB(166, 132, 96),
	dumpsterGreen = Color3.fromRGB(38, 82, 56),
	dumpsterBlue = Color3.fromRGB(36, 64, 110),
	lid = Color3.fromRGB(30, 32, 34),
	signRed = Color3.fromRGB(178, 30, 34),
	white = Color3.fromRGB(245, 245, 242),
	ink = Color3.fromRGB(22, 22, 26),
	leaf = Color3.fromRGB(62, 98, 50),
	trunk = Color3.fromRGB(88, 70, 56),
}

local SIDING = {
	Color3.fromRGB(214, 206, 186),
	Color3.fromRGB(176, 186, 190),
	Color3.fromRGB(226, 222, 212),
	Color3.fromRGB(150, 160, 146),
	Color3.fromRGB(196, 176, 150),
	Color3.fromRGB(128, 140, 158),
}

local CAR_COLORS = {
	Color3.fromRGB(150, 22, 28),
	Color3.fromRGB(34, 52, 94),
	Color3.fromRGB(196, 196, 198),
	Color3.fromRGB(30, 30, 32),
	Color3.fromRGB(240, 240, 238),
	Color3.fromRGB(70, 84, 72),
	Color3.fromRGB(110, 112, 118),
}

local World = {}

local rng = Random.new(1985)

-- ─── primitives ────────────────────────────────────────────────────────────

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Box with its bottom-center at `cf`: easier to place things on the ground.
local function box(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return part(parent, {
		Name = name,
		Size = size,
		CFrame = cf * CFrame.new(0, size.Y / 2, 0),
		Color = color,
		Material = material or M.SmoothPlastic,
	})
end

-- WedgePart is tall at +Z and slopes down toward -Z.
local function wedge(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or M.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function sign(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	bg: Color3,
	fg: Color3,
	transparentBg: boolean?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.6
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg
	label.BackgroundTransparency = if transparentBg then 1 else 0
	label.TextColor3 = fg
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = target
end

local function light(target: BasePart, kind: string, props: { [string]: any })
	local l = Instance.new(kind)
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = target
end

-- Window: dark glass pane with a light trim frame, on the front (-Z) of `cf`.
local function window(parent: Instance, cf: CFrame, w: number, h: number)
	box(parent, "WindowTrim", cf, Vector3.new(w + 0.8, h + 0.8, 0.3), C.trim)
	local pane = box(
		parent,
		"Window",
		cf * CFrame.new(0, 0.4, -0.12),
		Vector3.new(w, h, 0.2),
		C.glass,
		M.Glass
	)
	pane.Reflectance = 0.15
	pane.Transparency = 0.15
	box(parent, "Mullion", cf * CFrame.new(0, 0.4, -0.25), Vector3.new(0.25, h, 0.1), C.trim)
end

-- ─── trees & street props ──────────────────────────────────────────────────

-- True when a point is within `margin` studs of the asphalt.
local function onRoad(pos: Vector3, margin: number): boolean
	return CityPlan.clearance(pos) < margin
end

-- Tree kinds give the town some variety; weights favour broadleaf trees.
local TREE_KINDS = {
	{ kind = "oak", weight = 40 },
	{ kind = "pine", weight = 22 },
	{ kind = "birch", weight = 14 },
	{ kind = "autumn", weight = 14 },
	{ kind = "bush", weight = 10 },
}
local AUTUMN = {
	Color3.fromRGB(196, 96, 36),
	Color3.fromRGB(214, 150, 40),
	Color3.fromRGB(170, 52, 36),
	Color3.fromRGB(190, 170, 60),
}

local function pickTreeKind(): string
	local total = 0
	for _, k in TREE_KINDS do
		total += k.weight
	end
	local roll = rng:NextNumber() * total
	for _, k in TREE_KINDS do
		roll -= k.weight
		if roll <= 0 then
			return k.kind
		end
	end
	return "oak"
end

-- kind: nil picks one at random. Trees never grow on the asphalt.
local function tree(parent: Instance, pos: Vector3, scale: number?, leaves: number?, kind: string?)
	-- Street trees stand at the outer sidewalk edge (2 studs in); nearer ones go.
	if onRoad(pos, WALK_W - 3) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Tree"
	local s = (scale or 1) * rng:NextNumber(0.85, 1.2)
	local which = kind or pickTreeKind()
	local function trunk(h: number, w: number, color: Color3)
		part(model, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, w, w),
			CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = M.Wood,
		})
	end
	local function blob(offset: Vector3, size: Vector3, color: Color3)
		part(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = size,
			Position = pos + offset,
			Color = color,
			Material = M.Grass,
			CanCollide = false,
			CastShadow = true,
		})
	end
	if which == "palm" then
		-- Leaning segmented trunk with a crown of drooping fronds.
		local lean = Vector3.new(rng:NextNumber(-0.25, 0.25), 1, rng:NextNumber(-0.25, 0.25)).Unit
		local seg = 3.2 * s
		local top = pos
		for i = 0, 6 do
			local a = pos + lean * (i * seg)
			local b2 = pos + lean * ((i + 1) * seg)
			part(model, {
				Name = "Trunk",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(seg + 0.2, (1.5 - i * 0.08) * s, (1.5 - i * 0.08) * s),
				CFrame = CFrame.lookAt((a + b2) / 2, b2) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(150, 120, 86),
				Material = M.Wood,
			})
			top = b2
		end
		for i = 1, 7 do
			local yaw = i / 7 * math.pi * 2
			local dir = Vector3.new(math.cos(yaw), -0.45, math.sin(yaw)).Unit
			local tip = top + dir * 9 * s
			part(model, {
				Name = "Leaves",
				Size = Vector3.new(3 * s, 0.3, (tip - top).Magnitude),
				CFrame = CFrame.lookAt((top + tip) / 2, tip),
				Color = Color3.fromRGB(70, 130, 60),
				Material = M.Grass,
				CanCollide = false,
			})
		end
	elseif which == "pine" then
		-- Stacked tiers read as a conifer.
		local h = 6 * s
		trunk(h + 4 * s, 1.3 * s, Color3.fromRGB(80, 62, 48))
		local green = Color3.fromRGB(40, 72, 48):Lerp(Color3.fromRGB(58, 88, 56), rng:NextNumber())
		for t = 0, 4 do
			local d = (11 - t * 2) * s
			part(model, {
				Name = "Leaves",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3.4 * s, d, d),
				CFrame = CFrame.new(pos + Vector3.new(0, h + t * 3 * s, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = green,
				Material = M.Grass,
				CanCollide = false,
			})
		end
	elseif which == "birch" then
		local h = 15 * s
		trunk(h, 1 * s, Color3.fromRGB(226, 222, 212))
		local green = Color3.fromRGB(120, 156, 70)
			:Lerp(Color3.fromRGB(150, 170, 80), rng:NextNumber())
		for i = 1, 4 do
			local r = rng:NextNumber(5, 7) * s
			blob(
				Vector3.new(
					rng:NextNumber(-2.5, 2.5) * s,
					h - 2 * s + i * 1.6 * s,
					rng:NextNumber(-2.5, 2.5) * s
				),
				Vector3.new(r, r * 1.2, r),
				green
			)
		end
	elseif which == "bush" then
		local green = C.leaf:Lerp(Color3.fromRGB(90, 120, 60), rng:NextNumber())
		for _ = 1, 3 do
			local r = rng:NextNumber(4, 6) * s
			blob(
				Vector3.new(rng:NextNumber(-2, 2) * s, r * 0.3, rng:NextNumber(-2, 2) * s),
				Vector3.new(r, r * 0.7, r),
				green
			)
		end
	else
		local trunkH = 12 * s
		trunk(trunkH, 1.6 * s, C.trunk)
		local leafColor = if which == "autumn"
			then AUTUMN[rng:NextInteger(1, #AUTUMN)]
			else C.leaf:Lerp(Color3.fromRGB(96, 120, 60), rng:NextNumber(0, 0.6))
		for i = 1, leaves or 4 do
			local r = rng:NextNumber(7, 10) * s
			local offset = if i == 1
				then Vector3.new(0, trunkH + 2 * s, 0)
				else Vector3.new(
					rng:NextNumber(-4, 4) * s,
					trunkH + rng:NextNumber(-1, 4) * s,
					rng:NextNumber(-4, 4) * s
				)
			blob(offset, Vector3.new(r, r * 0.85, r), leafColor)
		end
	end
	model.Parent = parent
end

-- lit = false: the lamp glows but casts no light (cheaper on phones).
local function streetLight(parent: Instance, pos: Vector3, yaw: number, lit: boolean?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	part(parent, {
		Name = "LightPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(22, 0.8, 0.8),
		CFrame = cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.metal,
		Material = M.Metal,
	})
	box(
		parent,
		"LightArm",
		cf * CFrame.new(0, 21.6, -3.5),
		Vector3.new(0.4, 0.4, 7),
		C.metal,
		M.Metal
	)
	local head = box(
		parent,
		"LampHead",
		cf * CFrame.new(0, 21.2, -7),
		Vector3.new(1.4, 0.6, 2.6),
		Color3.fromRGB(255, 238, 200),
		M.Neon
	)
	if lit ~= false then
		light(head, "SpotLight", {
			Face = Enum.NormalId.Bottom,
			Angle = 110,
			Range = 45,
			Brightness = 2.2,
			Color = Color3.fromRGB(255, 214, 160),
			Shadows = false,
		})
	end
	CollectionService:AddTag(head, "StreetLight")
end

local function hydrant(parent: Instance, pos: Vector3)
	local red = Color3.fromRGB(176, 38, 32)
	part(parent, {
		Name = "Hydrant",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 1.1, 1.1),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = red,
		Material = M.Metal,
	})
	part(parent, {
		Name = "HydrantCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Position = pos + Vector3.new(0, 2.4, 0),
		Color = red,
		Material = M.Metal,
	})
end

local function stopSign(parent: Instance, pos: Vector3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	box(parent, "SignPost", cf, Vector3.new(0.3, 8, 0.3), C.metal, M.Metal)
	local plate = box(
		parent,
		"StopSign",
		cf * CFrame.new(0, 7, -0.2),
		Vector3.new(2.6, 2.6, 0.12),
		C.signRed,
		M.Metal
	)
	sign(plate, Enum.NormalId.Front, "STOP", C.signRed, C.white)
end

local function trafficLight(parent: Instance, pos: Vector3, yaw: number, group: string?)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	box(parent, "SignalPole", cf, Vector3.new(0.9, 20, 0.9), C.darkMetal, M.Metal)
	box(
		parent,
		"SignalArm",
		cf * CFrame.new(0, 19, -9),
		Vector3.new(0.5, 0.5, 18),
		C.darkMetal,
		M.Metal
	)
	-- Local -X faces the drivers arriving at the junction: the lamps sit on
	-- that face of the housing, with a black backplate behind for contrast.
	local housing = box(
		parent,
		"SignalHead",
		cf * CFrame.new(0, 14.6, -14),
		Vector3.new(1.2, 4.6, 1.6),
		Color3.fromRGB(40, 40, 30),
		M.Metal
	)
	box(
		parent,
		"SignalBackplate",
		housing.CFrame * CFrame.new(0.65, -2.8, 0), -- box() takes the bottom centre
		Vector3.new(0.12, 5.6, 2.6),
		C.ink,
		M.SmoothPlastic
	)
	local signal = Instance.new("Model")
	signal.Name = "TrafficSignal"
	for i, name in { "Red", "Yellow", "Green" } do
		local y = 1.4 - (i - 1) * 1.4
		part(signal, {
			Name = name,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = housing.CFrame * CFrame.new(-0.5, y, 0),
			Color = C.ink,
			CanCollide = false,
		})
		-- Visor over each lamp so it reads as a real signal head.
		box(
			parent,
			"SignalVisor",
			housing.CFrame * CFrame.new(-0.95, y + 0.56, 0),
			Vector3.new(0.7, 0.1, 1.3),
			Color3.fromRGB(40, 40, 30),
			M.Metal
		)
	end
	signal:SetAttribute("Group", group or "A")
	signal.Parent = parent
	CollectionService:AddTag(signal, "TrafficSignal")
end

local function bench(parent: Instance, cf: CFrame)
	box(
		parent,
		"BenchSeat",
		cf * CFrame.new(0, 1.6, 0),
		Vector3.new(6, 0.3, 1.6),
		C.wood,
		M.WoodPlanks
	)
	box(
		parent,
		"BenchBack",
		cf * CFrame.new(0, 2.2, 0.8),
		Vector3.new(6, 1.6, 0.25),
		C.wood,
		M.WoodPlanks
	)
	for _, x in { -2.6, 2.6 } do
		box(
			parent,
			"BenchLeg",
			cf * CFrame.new(x, 0, 0),
			Vector3.new(0.3, 1.6, 1.4),
			C.darkMetal,
			M.Metal
		)
	end
end

local function trashCan(parent: Instance, pos: Vector3, color: Color3)
	box(parent, "TrashCan", CFrame.new(pos), Vector3.new(2.4, 3.6, 2.4), color, M.Plastic)
	box(
		parent,
		"TrashCanLid",
		CFrame.new(pos + Vector3.new(0, 3.6, 0)),
		Vector3.new(2.6, 0.3, 2.6),
		color:Lerp(C.ink, 0.3),
		M.Plastic
	)
end

local function utilityPole(parent: Instance, pos: Vector3): Vector3
	local wood = Color3.fromRGB(90, 72, 56)
	part(parent, {
		Name = "UtilityPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 1.1, 1.1),
		CFrame = CFrame.new(pos + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = wood,
		Material = M.Wood,
	})
	box(
		parent,
		"CrossArm",
		CFrame.new(pos + Vector3.new(0, 27.5, 0)),
		Vector3.new(0.6, 0.6, 7),
		wood,
		M.Wood
	)
	return pos + Vector3.new(0, 28, 0)
end

local function wire(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2 - Vector3.new(0, 1.5, 0)
	for _, seg in { { a, mid }, { mid, b } } do
		local from, to = seg[1], seg[2]
		part(parent, {
			Name = "Wire",
			Size = Vector3.new(0.12, 0.12, (to - from).Magnitude),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = C.ink,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

local function parkingLot(
	parent: Instance,
	center: Vector3,
	size: Vector2,
	rows: { number }
): { CFrame }
	part(parent, {
		Name = "ParkingLot",
		Size = Vector3.new(size.X, ROAD_TOP, size.Y),
		CFrame = CFrame.new(center + Vector3.new(0, ROAD_TOP / 2, 0)),
		Color = C.asphaltLight,
		Material = M.Asphalt,
	})
	local stalls = {}
	for _, rowZ in rows do
		local x = center.X - size.X / 2 + 8
		while x < center.X + size.X / 2 - 8 do
			part(parent, {
				Name = "Stripe",
				Size = Vector3.new(0.3, 0.02, 16),
				CFrame = CFrame.new(x, ROAD_TOP + 0.01, rowZ),
				Color = C.lineWhite,
				CanCollide = false,
			})
			table.insert(stalls, CFrame.new(x + 5, ROAD_TOP, rowZ))
			x += 10
		end
	end
	return stalls
end

-- ─── buildings ─────────────────────────────────────────────────────────────

-- Shop in a row, front (-Z of cf) facing the street.
local function storefront(
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	wall: Color3,
	material: Enum.Material,
	name: string,
	awning: Color3
)
	local model = Instance.new("Model")
	model.Name = "Shop"
	local height = math.max(h, 22) -- two storeys: shop below, apartment above
	box(model, "Walls", cf, Vector3.new(w, height, d), wall, material)
	local front = cf * CFrame.new(0, 0, -d / 2 - 0.1)
	local trim = wall:Lerp(Color3.fromRGB(240, 236, 226), 0.55)
	-- Pilasters at both edges and a cornice on top.
	for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
		box(
			model,
			"Pilaster",
			front * CFrame.new(x, 0, -0.3),
			Vector3.new(1.4, height, 0.8),
			trim,
			material
		)
	end
	box(
		model,
		"Cornice",
		front * CFrame.new(0, height, -0.4),
		Vector3.new(w + 0.8, 1.2, 1.4),
		trim,
		M.Concrete
	)
	box(
		model,
		"Parapet",
		cf * CFrame.new(0, height + 1.2, -d / 2 + 0.6),
		Vector3.new(w, 1.6, 1.2),
		wall,
		material
	)
	-- Ground floor: lit display windows either side of a recessed door.
	box(
		model,
		"Bulkhead",
		front * CFrame.new(0, 0, -0.15),
		Vector3.new(w - 3, 1.6, 0.4),
		trim,
		M.Concrete
	)
	local glass = box(
		model,
		"Display",
		front * CFrame.new(0, 1.6, 0),
		Vector3.new(w - 3, 7.4, 0.25),
		C.glass,
		M.Glass
	)
	glass.Transparency = 0.35
	glass.Reflectance = 0.25
	box(
		model,
		"Door",
		front * CFrame.new(w / 4, 0, 0.8),
		Vector3.new(4, 8.6, 0.3),
		C.darkMetal,
		M.Metal
	)
	local inside = box(
		model,
		"Interior",
		front * CFrame.new(0, 0.6, 2.5),
		Vector3.new(w - 5, 9, 0.2),
		Color3.fromRGB(236, 226, 204)
	)
	light(inside, "SurfaceLight", {
		Face = Enum.NormalId.Front,
		Range = 12,
		Brightness = 1,
		Color = Color3.fromRGB(255, 232, 200),
	})
	for i = 0, 2 do
		box(
			model,
			"ShelfUnit",
			front * CFrame.new(-w / 2 + 4 + i * ((w - 8) / 2), 0.4, 2),
			Vector3.new(2.5, 5, 1),
			Color3.fromRGB(150 + i * 20, 110, 90)
		)
	end
	-- Striped canvas awning and a sign band.
	local stripes = math.max(4, math.floor((w - 2) / 3))
	local stripeW = (w - 2) / stripes
	for i = 0, stripes - 1 do
		wedge(
			model,
			"Awning",
			front
				* CFrame.new(-w / 2 + 1 + stripeW * (i + 0.5), 10.4, -2)
				* CFrame.Angles(0, math.rad(180), 0),
			Vector3.new(stripeW, 1.8, 4),
			if i % 2 == 0 then awning else Color3.fromRGB(240, 236, 226),
			M.Fabric
		)
	end
	local board = box(
		model,
		"SignBoard",
		front * CFrame.new(0, 11.6, -0.2),
		Vector3.new(w - 4, 2.6, 0.4),
		C.ink
	)
	sign(board, Enum.NormalId.Front, name, C.ink, Color3.fromRGB(250, 240, 220))
	-- Projecting blade sign, readable from down the street.
	box(
		model,
		"BladeArm",
		front * CFrame.new(-w / 2 + 2.5, 15.5, -1.2),
		Vector3.new(0.2, 0.2, 2.6),
		C.darkMetal,
		M.Metal
	)
	local blade = box(
		model,
		"BladeSign",
		front * CFrame.new(-w / 2 + 2.5, 13.2, -2.2),
		Vector3.new(0.3, 4, 2.4),
		awning
	)
	sign(blade, Enum.NormalId.Left, name, awning, C.white)
	sign(blade, Enum.NormalId.Right, name, awning, C.white)
	-- Upper floor: a row of sash windows.
	local count = math.max(2, math.floor(w / 9))
	for i = 1, count do
		local x = -w / 2 + i * (w / (count + 1))
		window(model, front * CFrame.new(x, 14, -0.1), 3.6, 4.4)
	end
	box(
		model,
		"BackDoor",
		cf * CFrame.new(-w / 4, 0, d / 2 + 0.1),
		Vector3.new(4, 8, 0.2),
		C.darkMetal,
		M.Metal
	)
	box(
		model,
		"RoofAC",
		cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), height, rng:NextNumber(0, d / 4)),
		Vector3.new(6, 3, 5),
		C.concrete,
		M.Metal
	)
	model.Parent = parent
end

local function gableRoof(
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	rise: number,
	color: Color3
)
	local half = d / 2 + 1
	wedge(
		parent,
		"Roof",
		cf * CFrame.new(0, rise / 2, -half / 2),
		Vector3.new(w + 2, rise, half),
		color,
		M.Slate
	)
	wedge(
		parent,
		"Roof",
		cf * CFrame.new(0, rise / 2, half / 2) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(w + 2, rise, half),
		color,
		M.Slate
	)
end

-- A house on its lot. `cf` is the house front-center on the ground; front faces -Z.
local function house(parent: Instance, cf: CFrame, toCurb: number, twoStory: boolean)
	local model = Instance.new("Model")
	model.Name = "House"
	local siding = SIDING[rng:NextInteger(1, #SIDING)]
	local brick = rng:NextNumber() < 0.3
	local wallMat = if brick then M.Brick else M.WoodPlanks
	local wallColor = if brick then C.brick:Lerp(siding, 0.15) else siding
	local w = if twoStory then 34 else 40
	local d = if twoStory then 28 else 30
	local h = if twoStory then 22 else 12
	local body = cf * CFrame.new(0, 0, d / 2)

	box(model, "Foundation", body, Vector3.new(w + 0.4, 1.2, d + 0.4), C.concreteDark, M.Concrete)
	box(model, "Walls", body * CFrame.new(0, 1.2, 0), Vector3.new(w, h, d), wallColor, wallMat)
	gableRoof(
		model,
		body * CFrame.new(0, 1.2 + h, 0),
		w,
		d,
		if twoStory then 8 else 7,
		if rng:NextNumber() < 0.5 then C.roof else C.roofBrown
	)

	local front = cf * CFrame.new(0, 1.2, -0.1)
	local doorX = if twoStory then 0 else -6
	local doorColor = if rng:NextNumber() < 0.5
		then Color3.fromRGB(86, 40, 36)
		else Color3.fromRGB(40, 54, 70)
	box(
		model,
		"Door",
		front * CFrame.new(doorX, 0, -0.1),
		Vector3.new(3.6, 8, 0.3),
		doorColor,
		M.Wood
	)
	box(
		model,
		"Porch",
		cf * CFrame.new(doorX, 0, -3),
		Vector3.new(10, 1.2, 6),
		C.concrete,
		M.Concrete
	)
	for _, x in if twoStory then { -10, 10 } else { -14, 4 } do
		window(model, front * CFrame.new(x, 3, -0.15), 5, 5)
	end
	if twoStory then
		for _, x in { -10, 0, 10 } do
			window(model, front * CFrame.new(x, 13, -0.15), 4.5, 5)
		end
	end
	if rng:NextNumber() < 0.5 then
		box(
			model,
			"Chimney",
			body * CFrame.new(w / 2 - 4, 1.2 + h, d / 4),
			Vector3.new(3, 9, 3),
			C.brick,
			M.Brick
		)
	end

	-- Attached garage and driveway on the right.
	local garageX = w / 2 + 11
	local garage = cf * CFrame.new(garageX, 0, d / 2 - 2)
	box(
		model,
		"Garage",
		garage * CFrame.new(0, 1.2, 0),
		Vector3.new(22, 11, d - 4),
		wallColor,
		wallMat
	)
	gableRoof(model, garage * CFrame.new(0, 12.2, 0), 22, d - 4, 5, C.roof)
	box(model, "GarageDoor", cf * CFrame.new(garageX, 1.2, 1.9), Vector3.new(16, 8.5, 0.3), C.trim)
	local driveLen = toCurb + 2
	part(model, {
		Name = "Driveway",
		Size = Vector3.new(18, 0.3, driveLen),
		CFrame = cf * CFrame.new(garageX, 0.15, 2 - driveLen / 2),
		Color = C.concrete,
		Material = M.Concrete,
	})
	part(model, {
		Name = "Walkway",
		Size = Vector3.new(4, 0.3, toCurb - 6),
		CFrame = cf * CFrame.new(doorX, 0.15, -6 - (toCurb - 6) / 2),
		Color = C.concrete,
		Material = M.Concrete,
	})
	local curb = cf * CFrame.new(0, 0, -toCurb + 2)
	box(model, "MailPost", curb * CFrame.new(-4, 0, 0), Vector3.new(0.4, 3.6, 0.4), C.wood, M.Wood)
	box(
		model,
		"Mailbox",
		curb * CFrame.new(-4, 3.6, 0),
		Vector3.new(1.2, 1.2, 2),
		C.darkMetal,
		M.Metal
	)
	if rng:NextNumber() < 0.7 then
		local binColor = if rng:NextNumber() < 0.5
			then Color3.fromRGB(40, 70, 46)
			else Color3.fromRGB(44, 46, 52)
		trashCan(model, (curb * CFrame.new(garageX + 11, 0, 0)).Position, binColor)
	end
	local back = cf * CFrame.new(0, 0, d + 22)
	box(
		model,
		"Fence",
		back * CFrame.new(garageX / 2, 0, 0),
		Vector3.new(w + 30, 6, 0.4),
		C.fenceWood,
		M.WoodPlanks
	)
	if rng:NextNumber() < 0.8 then
		tree(model, (cf * CFrame.new(-w / 2 - 6, 0, -toCurb / 2)).Position, 1)
	end
	model.Parent = parent
end

local function dumpster(
	parent: Instance,
	spec: {
		pos: Vector3,
		zone: string,
		tutorial: boolean?,
		yaw: number?,
		pad: string?,
	}
): Model
	local model = Instance.new("Model")
	model.Name = if spec.tutorial then "TutorialDumpster" else "Dumpster"
	local private = spec.zone == "Red"
	local base = CFrame.new(spec.pos + Vector3.new(0, ROAD_TOP, 0))
		* CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
	local steel = if private then C.dumpsterBlue else C.dumpsterGreen

	-- Concrete pad, and a three-sided block pen when the spec asks for one.
	-- The dumpster's open front is local -Z; the pen closes the back and sides.
	box(
		model,
		"Pad",
		base * CFrame.new(0, -0.15, 1),
		Vector3.new(12, 0.3, 10),
		C.concreteDark,
		M.Concrete
	)
	if spec.pad == "enclosure" then
		local block = Color3.fromRGB(176, 170, 160)
		box(
			model,
			"PenBack",
			base * CFrame.new(0, 0, 4.4),
			Vector3.new(12, 6.5, 0.8),
			block,
			M.Brick
		)
		for _, x in { -5.6, 5.6 } do
			box(
				model,
				"PenSide",
				base * CFrame.new(x, 0, 0.5),
				Vector3.new(0.8, 6.5, 8.6),
				block,
				M.Brick
			)
		end
		box(
			model,
			"PenGate",
			base * CFrame.new(-5.9, 0, -4.6) * CFrame.Angles(0, math.rad(-70), 0),
			Vector3.new(0.3, 5.5, 5),
			C.metal,
			M.CorrodedMetal
		)
	end

	local body =
		box(model, "Body", base * CFrame.new(0, 0.6, 0), Vector3.new(8, 5, 6), steel, M.Metal)
	box(model, "Lid", base * CFrame.new(0, 5.6, 0), Vector3.new(8.2, 0.35, 6.2), C.lid, M.Plastic)
	for _, x in { -3, 3 } do
		box(
			model,
			"Sleeve",
			base * CFrame.new(x, 2.6, -3.1),
			Vector3.new(1.4, 0.8, 0.6),
			steel:Lerp(C.ink, 0.3),
			M.Metal
		)
	end
	box(
		model,
		"Rim",
		base * CFrame.new(0, 5.3, 0),
		Vector3.new(8.3, 0.3, 6.3),
		steel:Lerp(C.ink, 0.25),
		M.Metal
	)
	for _, x in { -3.2, 3.2 } do
		for _, z in { -2.4, 2.4 } do
			box(
				model,
				"Caster",
				base * CFrame.new(x, 0, z),
				Vector3.new(0.6, 0.6, 0.6),
				C.ink,
				M.Metal
			)
		end
	end
	local plate = box(
		model,
		"Label",
		base * CFrame.new(0, 2.6, -3.05),
		Vector3.new(4, 1.2, 0.05),
		Color3.fromRGB(230, 230, 225)
	)
	sign(
		plate,
		Enum.NormalId.Front,
		if private then "MERIDIAN" else "WASTE CO.",
		Color3.fromRGB(230, 230, 225),
		C.ink
	)
	for i = 1, rng:NextInteger(1, 3) do
		local bag = part(model, {
			Name = "TrashBag",
			Size = Vector3.new(2.2, 2, 2.2),
			CFrame = base * CFrame.new(5 + rng:NextNumber(-0.5, 1), 1, (i - 2) * 2.3),
			Color = Color3.fromRGB(24, 26, 30),
			Material = M.Plastic,
			CanCollide = false,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bag
	end

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Enabled = false
	glow.Range = 16
	glow.Brightness = 0
	glow.Parent = body

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Speed = NumberRange.new(14, 24)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.Lifetime = NumberRange.new(0.6, 1.1)
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Acceleration = Vector3.new(0, -30, 0)
	burst.LightEmission = 0.5
	burst.Parent = body

	local flies = Instance.new("ParticleEmitter")
	flies.Name = "Flies"
	flies.Rate = 2
	flies.Lifetime = NumberRange.new(2, 3)
	flies.Speed = NumberRange.new(1, 2)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.RotSpeed = NumberRange.new(-200, 200)
	flies.Size = NumberSequence.new(0.12)
	flies.Color = ColorSequence.new(C.ink)
	flies.Acceleration = Vector3.new(0, 0.6, 0)
	flies.Drag = 2
	flies.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SearchPrompt"
	prompt.ActionText = "Search"
	local district = Districts.at(spec.pos)
	local tier = if district then district.tier else 1
	prompt.ObjectText = (if private then "Private dumpster" else "Dumpster") .. ` · Tier {tier}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Search.RANGE - 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.PrimaryPart = body
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Zone", spec.zone)
	model:SetAttribute("District", if district then district.name else "Town Center")
	model:SetAttribute("DistrictId", if district then district.id else "town")
	model:SetAttribute("City", if district and district.city then district.city else "maple")
	model:SetAttribute("Tier", tier)
	model:SetAttribute("DistrictBoost", if district then district.boost else 0)
	model:SetAttribute("Tutorial", spec.tutorial == true)
	if spec.heavy then
		-- Heavy-duty bin: hazard stripes, a chained lid and a two-player tag.
		model:SetAttribute("Heavy", true)
		for _, y in { 1.2, 4.2 } do
			box(
				model,
				"HazardStripe",
				base * CFrame.new(0, 0.6 + y, 0),
				Vector3.new(8.2, 0.5, 6.2),
				Color3.fromRGB(240, 196, 30),
				M.SmoothPlastic
			)
		end
		box(
			model,
			"Chain",
			base * CFrame.new(0, 5.6, -3.1),
			Vector3.new(0.4, 1.2, 0.4),
			C.darkMetal,
			M.DiamondPlate
		)
		local tag = Instance.new("BillboardGui")
		tag.Name = "HeavyTag"
		tag.Size = UDim2.fromOffset(170, 40)
		tag.StudsOffset = Vector3.new(0, 5, 0)
		tag.MaxDistance = 70
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(240, 196, 30)
		label.TextStrokeTransparency = 0.3
		label.Text = "HEAVY BIN\n2 players · better loot"
		label.Parent = tag
		tag.Parent = body
	end
	model.Parent = parent
	CollectionService:AddTag(model, "Dumpster")
	return model
end

-- ─── districts ─────────────────────────────────────────────────────────────

local function buildHideout(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Hideout"
	folder.Parent = parent
	local c = W.HIDEOUT_CENTER
	local w, d, h = 64, 52, 18
	local base = CFrame.new(c.X, ROAD_TOP, c.Z)
	part(folder, {
		Name = "Apron",
		Size = Vector3.new(w + 20, ROAD_TOP, 30),
		CFrame = CFrame.new(c.X, ROAD_TOP / 2, c.Z - d / 2 - 13),
		Color = C.concreteDark,
		Material = M.Concrete,
	})
	box(folder, "Floor", base, Vector3.new(w, 0.5, d), Color3.fromRGB(150, 146, 138), M.Concrete)

	local wallColor = Color3.fromRGB(176, 168, 150)
	box(
		folder,
		"WallBack",
		base * CFrame.new(0, 0, d / 2 - 0.5),
		Vector3.new(w, h, 1),
		wallColor,
		M.Concrete
	)
	box(
		folder,
		"WallLeft",
		base * CFrame.new(-w / 2 + 0.5, 0, 0),
		Vector3.new(1, h, d),
		wallColor,
		M.Concrete
	)
	box(
		folder,
		"WallRight",
		base * CFrame.new(w / 2 - 0.5, 0, 0),
		Vector3.new(1, h, d),
		wallColor,
		M.Concrete
	)
	local front = base * CFrame.new(0, 0, -d / 2 + 0.5)
	for _, x in { -27, 0, 27 } do
		box(
			folder,
			"FrontPier",
			front * CFrame.new(x, 0, 0),
			Vector3.new(10, h, 1),
			wallColor,
			M.Concrete
		)
	end
	box(
		folder,
		"FrontHeader",
		front * CFrame.new(0, 12, 0),
		Vector3.new(w, h - 12, 1),
		wallColor,
		M.Concrete
	)
	for _, x in { -13.5, 13.5 } do
		box(
			folder,
			"RollUpDoor",
			front * CFrame.new(x, 10, 0.6),
			Vector3.new(16, 2, 0.4),
			C.metal,
			M.CorrodedMetal
		)
	end
	box(
		folder,
		"Roof",
		base * CFrame.new(0, h, 0),
		Vector3.new(w + 2, 0.8, d + 2),
		Color3.fromRGB(110, 112, 114),
		M.CorrodedMetal
	)
	local facade = box(
		folder,
		"HideoutSign",
		front * CFrame.new(0, h - 4.5, -0.7),
		Vector3.new(40, 4, 0.4),
		Color3.fromRGB(28, 30, 34)
	)
	sign(
		facade,
		Enum.NormalId.Front,
		"RUSTY'S SALVAGE & PAWN",
		Color3.fromRGB(28, 30, 34),
		Color3.fromRGB(240, 196, 70)
	)
	for _, x in { -18, 0, 18 } do
		local tube = box(
			folder,
			"ShopLight",
			base * CFrame.new(x, h - 1.2, 4),
			Vector3.new(8, 0.3, 1),
			Color3.fromRGB(240, 246, 255),
			M.Neon
		)
		light(tube, "SurfaceLight", {
			Face = Enum.NormalId.Bottom,
			Range = 22,
			Brightness = 1.4,
			Angle = 120,
			Color = Color3.fromRGB(230, 240, 255),
		})
	end

	local counter = box(
		folder,
		"SellCounter",
		CFrame.new(W.SELL_POINT + Vector3.new(0, ROAD_TOP + 0.5, 0)),
		Vector3.new(10, 3.6, 3),
		Color3.fromRGB(84, 60, 44),
		M.Wood
	)
	local case = box(
		folder,
		"DisplayCase",
		CFrame.new(W.SELL_POINT + Vector3.new(0, ROAD_TOP + 4.1, 0)),
		Vector3.new(10, 1.4, 3),
		C.glass,
		M.Glass
	)
	case.Transparency = 0.5
	local sellSign = box(
		folder,
		"SellSign",
		CFrame.new(W.SELL_POINT + Vector3.new(0, ROAD_TOP + 9, 3)),
		Vector3.new(10, 2.6, 0.3),
		Color3.fromRGB(240, 196, 70)
	)
	sign(sellSign, Enum.NormalId.Front, "WE BUY JUNK", Color3.fromRGB(240, 196, 70), C.ink)
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell & Display"
	sellPrompt.ObjectText = "Pawn Counter"
	sellPrompt.HoldDuration = 0
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = counter

	-- Hideout dressing: OPEN sign, pegboard, TV, floor lines, a tow truck out front.
	local openSign = box(
		folder,
		"OpenSign",
		front * CFrame.new(20, 9, -0.7),
		Vector3.new(6, 2, 0.3),
		Color3.fromRGB(255, 70, 90),
		M.Neon
	)
	sign(openSign, Enum.NormalId.Front, "OPEN", Color3.fromRGB(255, 70, 90), C.white, true)
	light(
		openSign,
		"PointLight",
		{ Range = 12, Brightness = 1.2, Color = Color3.fromRGB(255, 90, 110) }
	)
	box(
		folder,
		"Pegboard",
		base * CFrame.new(18, 3.5, d / 2 - 1.2),
		Vector3.new(16, 7, 0.3),
		Color3.fromRGB(196, 168, 120),
		M.WoodPlanks
	)
	for i = 0, 5 do
		box(
			folder,
			"HangingTool",
			base * CFrame.new(11 + i * 2.6, 6.5, d / 2 - 1.5),
			Vector3.new(0.4, 2.4, 0.2),
			C.metal,
			M.Metal
		)
	end
	local tv =
		box(folder, "TV", base * CFrame.new(-8, 8, d / 2 - 1.2), Vector3.new(7, 4, 0.4), C.ink)
	local screen = box(
		folder,
		"Screen",
		base * CFrame.new(-8, 8.3, d / 2 - 1.45),
		Vector3.new(6.4, 3.4, 0.05),
		Color3.fromRGB(70, 130, 190),
		M.Neon
	)
	screen.Transparency = 0.2
	tv.Name = "TV"
	for _, x in { -13.5, 13.5 } do
		part(folder, {
			Name = "FloorLine",
			Size = Vector3.new(0.4, 0.02, d - 6),
			CFrame = base * CFrame.new(x - 8, 0.52, 0),
			Color = Color3.fromRGB(230, 190, 50),
			CanCollide = false,
		})
	end
	-- Fenced parking out front, where player cars arrive.
	local lot = base * CFrame.new(0, 0, -d / 2 - 22)
	for _, x in { -42, 42 } do
		box(
			folder,
			"LotFence",
			lot * CFrame.new(x, 0, 0),
			Vector3.new(0.4, 4, 28),
			C.metal,
			M.DiamondPlate
		)
	end
	for i = -3, 3 do
		part(folder, {
			Name = "LotStripe",
			Size = Vector3.new(0.3, 0.02, 12),
			CFrame = lot * CFrame.new(i * 11, 0.22, 6),
			Color = C.lineWhite,
			CanCollide = false,
		})
	end
	local tow = lot * CFrame.new(-30, 0, -4)
	box(
		folder,
		"TowCab",
		tow * CFrame.new(0, 1.2, -5),
		Vector3.new(7, 6, 7),
		Color3.fromRGB(196, 150, 40),
		M.Metal
	)
	box(
		folder,
		"TowBed",
		tow * CFrame.new(0, 1.2, 4),
		Vector3.new(7, 2, 12),
		Color3.fromRGB(60, 62, 66),
		M.DiamondPlate
	)
	box(
		folder,
		"TowBoom",
		tow * CFrame.new(0, 3.2, 9) * CFrame.Angles(math.rad(-25), 0, 0),
		Vector3.new(0.8, 0.8, 7),
		C.darkMetal,
		M.Metal
	)
	for _, z in { -5, 6 } do
		for _, x in { -3.6, 3.6 } do
			part(folder, {
				Name = "TowWheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 2.6, 2.6),
				CFrame = tow * CFrame.new(x, 1.3, z),
				Color = C.ink,
				Material = M.Rubber,
			})
		end
	end

	-- Display shelves along the side walls: one per player (Economy assigns them).
	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	shelves.Parent = folder
	local spots = {}
	for i = 0, 3 do
		table.insert(spots, { x = -w / 2 + 3, z = -14 + i * 9, yaw = -90 })
		table.insert(spots, { x = w / 2 - 3, z = -14 + i * 9, yaw = 90 })
	end
	for i, spot in spots do
		local model = Instance.new("Model")
		model.Name = "Shelf" .. i
		local cf = base * CFrame.new(spot.x, 0.5, spot.z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
		local back = box(
			model,
			"Back",
			cf * CFrame.new(0, 0, 0.9),
			Vector3.new(7, 7, 0.3),
			C.darkMetal,
			M.Metal
		)
		local board = box(
			model,
			"Board",
			cf * CFrame.new(0, 2.6, 0),
			Vector3.new(7, 0.3, 2),
			C.metal,
			M.Metal
		)
		box(
			model,
			"LowerBoard",
			cf * CFrame.new(0, 0.6, 0),
			Vector3.new(7, 0.3, 2),
			C.metal,
			M.Metal
		)
		for _, x in { -3.4, 3.4 } do
			box(
				model,
				"Upright",
				cf * CFrame.new(x, 0, 0),
				Vector3.new(0.3, 7, 2),
				C.darkMetal,
				M.Metal
			)
		end
		for k, x in { -2.3, 0, 2.3 } do
			local slot = Instance.new("Attachment")
			slot.Name = "Slot" .. k
			slot.Position = Vector3.new(x, 1.1, 0)
			slot.Parent = board
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = "OwnerTag"
		tag.Size = UDim2.fromOffset(200, 34)
		tag.StudsOffset = Vector3.new(0, 4.6, 0)
		tag.MaxDistance = 60
		tag.Enabled = false
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextScaled = true
		label.TextColor3 = C.white
		label.TextStrokeTransparency = 0.4
		label.Parent = tag
		tag.Parent = back
		model.PrimaryPart = board
		model.Parent = shelves
	end

	box(
		folder,
		"Workbench",
		base * CFrame.new(10, 0.5, 20),
		Vector3.new(12, 3.4, 3.5),
		C.wood,
		M.WoodPlanks
	)
	for i = 0, 3 do
		part(folder, {
			Name = "Tire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 3.6, 3.6),
			CFrame = base * CFrame.new(-22, 1.2 + i * 1.2, 20) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.ink,
			Material = M.Rubber,
		})
	end
	local couch = Color3.fromRGB(92, 70, 56)
	box(
		folder,
		"CouchSeat",
		base * CFrame.new(-8, 0.5, 21),
		Vector3.new(9, 2, 3.4),
		couch,
		M.Fabric
	)
	box(
		folder,
		"CouchBack",
		base * CFrame.new(-8, 0.5, 22.8),
		Vector3.new(9, 4, 1),
		couch,
		M.Fabric
	)
	for _, x in { 26, 28.5 } do
		part(folder, {
			Name = "OilDrum",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 2.4, 2.4),
			CFrame = base * CFrame.new(x, 2.5, -18) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(40, 70, 110),
			Material = M.Metal,
		})
	end

	-- Scrapyard behind the shop.
	local yard = base * CFrame.new(0, 0, d / 2 + 30)
	part(folder, {
		Name = "YardGround",
		Size = Vector3.new(80, 0.3, 56),
		CFrame = yard * CFrame.new(0, 0.15, 0),
		Color = Color3.fromRGB(110, 100, 86),
		Material = M.Ground,
	})
	for _, side in { -1, 1 } do
		box(
			folder,
			"YardFence",
			yard * CFrame.new(side * 40, 0, 0),
			Vector3.new(0.4, 9, 56),
			C.metal,
			M.CorrodedMetal
		)
	end
	box(
		folder,
		"YardFence",
		yard * CFrame.new(0, 0, 28),
		Vector3.new(80, 9, 0.4),
		C.metal,
		M.CorrodedMetal
	)
	for _ = 1, 9 do
		local pile = yard
			* CFrame.new(rng:NextNumber(-34, 34), 0, rng:NextNumber(-20, 22))
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local tilt =
			CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
		local size = Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(2, 5), rng:NextNumber(4, 8))
		box(
			folder,
			"Scrap",
			pile * tilt,
			size,
			C.metal:Lerp(Color3.fromRGB(120, 70, 40), rng:NextNumber(0.2, 0.8)),
			M.CorrodedMetal
		)
	end

	-- Exactly one spawn, at the Hideout. The Baseplate template's own
	-- SpawnLocation sits at the origin (Downtown, tier 4): reuse it, and drop
	-- any others so nobody starts across the city.
	local spawn: SpawnLocation? = nil
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			if spawn then
				d:Destroy()
			else
				spawn = d
			end
		end
	end
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Parent = workspace
	end
	local sp = spawn :: SpawnLocation
	sp.Anchored = true
	sp.Size = Vector3.new(8, 0.2, 8)
	sp.Position = W.SPAWN + Vector3.new(0, ROAD_TOP + 0.6, 0)
	sp.Neutral = true
	sp.Duration = 0
	sp.Transparency = 1
	sp.CanCollide = false
	local decal = sp:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

local function buildMeridianYard(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "RedZone"
	folder.Parent = parent
	-- Laid out around its original design point, then shifted into place.
	local rc = CityPlan.YARD_ORIGIN
	local hx, hz = W.RED_SIZE.X / 2, W.RED_SIZE.Y / 2
	part(folder, {
		Name = "Floor",
		Size = Vector3.new(W.RED_SIZE.X, ROAD_TOP, W.RED_SIZE.Y),
		CFrame = CFrame.new(rc.X, ROAD_TOP / 2, rc.Z),
		Color = Color3.fromRGB(92, 92, 92),
		Material = M.Concrete,
	})
	part(folder, {
		Name = "WarningLine",
		Size = Vector3.new(W.RED_SIZE.X - 4, 0.02, 1.2),
		CFrame = CFrame.new(rc.X, ROAD_TOP + 0.01, rc.Z - hz + 3),
		Color = C.signRed,
		CanCollide = false,
	})
	part(folder, {
		Name = "Driveway",
		Size = Vector3.new(28, ROAD_TOP, 30),
		CFrame = CFrame.new(0, ROAD_TOP / 2, rc.Z - hz - 15),
		Color = C.asphaltLight,
		Material = M.Asphalt,
	})

	-- Chain-link fence with barbed wire: gate at the south, truck gate east, a cut west.
	local fenceH = 12
	local function fenceRun(a: Vector3, b: Vector3, gap: NumberRange?)
		local alongX = math.abs(b.X - a.X) > math.abs(b.Z - a.Z)
		local lo = if alongX then math.min(a.X, b.X) else math.min(a.Z, b.Z)
		local hi = if alongX then math.max(a.X, b.X) else math.max(a.Z, b.Z)
		-- The fence runs lo..hi with an opening for the gate, if any.
		local runs = if gap then { { lo, gap.Min }, { gap.Max, hi } } else { { lo, hi } }
		for _, s in runs do
			local len = s[2] - s[1]
			local mid = (s[1] + s[2]) / 2
			local pos = if alongX
				then Vector3.new(mid, ROAD_TOP, a.Z)
				else Vector3.new(a.X, ROAD_TOP, mid)
			local size = if alongX
				then Vector3.new(len, fenceH, 0.15)
				else Vector3.new(0.15, fenceH, len)
			local mesh = box(
				folder,
				"ChainLink",
				CFrame.new(pos),
				size,
				Color3.fromRGB(150, 156, 160),
				M.DiamondPlate
			)
			mesh.Transparency = 0.6
			mesh.CastShadow = false
			local railSize = if alongX
				then Vector3.new(len, 0.3, 0.3)
				else Vector3.new(0.3, 0.3, len)
			box(
				folder,
				"TopRail",
				CFrame.new(pos + Vector3.new(0, fenceH, 0)),
				railSize,
				C.metal,
				M.Metal
			)
			for k = 1, 2 do
				local wireSize = if alongX
					then Vector3.new(len, 0.08, 0.08)
					else Vector3.new(0.08, 0.08, len)
				box(
					folder,
					"BarbedWire",
					CFrame.new(pos + Vector3.new(0, fenceH + 0.4 + k * 0.5, 0)),
					wireSize,
					C.ink,
					M.Metal
				)
			end
			for p = s[1], s[2], 12 do
				local postPos = if alongX
					then Vector3.new(p, ROAD_TOP, a.Z)
					else Vector3.new(a.X, ROAD_TOP, p)
				box(
					folder,
					"FencePost",
					CFrame.new(postPos),
					Vector3.new(0.5, fenceH + 1.6, 0.5),
					C.metal,
					M.Metal
				)
			end
		end
	end
	local x0, x1, z0, z1 = rc.X - hx, rc.X + hx, rc.Z - hz, rc.Z + hz
	fenceRun(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), NumberRange.new(-14, 14))
	fenceRun(Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), nil)
	fenceRun(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), NumberRange.new(424, 444))
	fenceRun(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), NumberRange.new(518, 528))

	box(
		folder,
		"BarrierPost",
		CFrame.new(-16, ROAD_TOP, z0),
		Vector3.new(1.4, 4, 1.4),
		Color3.fromRGB(230, 190, 40),
		M.Metal
	)
	box(
		folder,
		"BarrierArm",
		CFrame.new(-4, ROAD_TOP + 3.6, z0),
		Vector3.new(24, 0.5, 0.5),
		C.white
	)
	local booth = CFrame.new(-26, ROAD_TOP, z0 + 10)
	box(
		folder,
		"GuardBooth",
		booth,
		Vector3.new(10, 10, 10),
		Color3.fromRGB(200, 200, 196),
		M.Concrete
	)
	window(folder, booth * CFrame.new(0, 4, -5.15), 7, 4)
	box(
		folder,
		"BoothRoof",
		booth * CFrame.new(0, 10, 0),
		Vector3.new(12, 0.8, 12),
		C.darkMetal,
		M.Metal
	)
	for _, x in { -60, 60, -160, 160 } do
		local board = box(
			folder,
			"KeepOut",
			CFrame.new(x, ROAD_TOP + 4, z0 - 0.4),
			Vector3.new(14, 6, 0.2),
			C.white
		)
		sign(
			board,
			Enum.NormalId.Front,
			"PRIVATE PROPERTY\nNO TRESPASSING\nVIOLATORS WILL BE PROSECUTED",
			C.white,
			C.signRed
		)
	end
	local navy = Color3.fromRGB(34, 54, 86)
	local entry = box(
		folder,
		"CompanySign",
		CFrame.new(32, ROAD_TOP, z0 - 6),
		Vector3.new(26, 7, 1.2),
		navy,
		M.Concrete
	)
	sign(entry, Enum.NormalId.Front, "MERIDIAN LOGISTICS\nDISTRIBUTION CENTER", navy, C.white)

	for _, wx in { -115, 115 } do
		local base = CFrame.new(wx, ROAD_TOP, 440)
		box(
			folder,
			"Warehouse",
			base,
			Vector3.new(150, 38, 80),
			Color3.fromRGB(196, 196, 192),
			M.Concrete
		)
		box(
			folder,
			"WarehouseBand",
			base * CFrame.new(0, 32, 0),
			Vector3.new(150.4, 2, 80.4),
			navy,
			M.Concrete
		)
		local wsign = box(
			folder,
			"WarehouseSign",
			base * CFrame.new(0, 24, -40.3),
			Vector3.new(60, 7, 0.3),
			Color3.fromRGB(196, 196, 192)
		)
		sign(wsign, Enum.NormalId.Front, "MERIDIAN", Color3.fromRGB(196, 196, 192), navy, true)
		for i = 0, 7 do
			local dx = -63 + i * 18
			box(
				folder,
				"DockDoor",
				base * CFrame.new(dx, 4, 40.2),
				Vector3.new(10, 11, 0.3),
				C.metal,
				M.CorrodedMetal
			)
			box(
				folder,
				"DockBumper",
				base * CFrame.new(dx, 0, 41.2),
				Vector3.new(12, 4, 2),
				C.ink,
				M.Rubber
			)
			local lamp = box(
				folder,
				"DockLight",
				base * CFrame.new(dx, 17, 40.6),
				Vector3.new(1.2, 0.8, 1),
				Color3.fromRGB(255, 230, 180),
				M.Neon
			)
			light(lamp, "SpotLight", {
				Face = Enum.NormalId.Back,
				Angle = 90,
				Range = 26,
				Brightness = 1.5,
				Color = Color3.fromRGB(255, 220, 170),
			})
			CollectionService:AddTag(lamp, "StreetLight")
		end
		for _, rx in { -50, 0, 50 } do
			box(
				folder,
				"RoofUnit",
				base * CFrame.new(rx, 38, 10),
				Vector3.new(10, 4, 8),
				C.concrete,
				M.Metal
			)
		end
	end

	local function trailer(cf: CFrame, color: Color3)
		box(folder, "Trailer", cf * CFrame.new(0, 4, 0), Vector3.new(8.5, 12, 44), color, M.Metal)
		for _, z in { 14, 18 } do
			for _, x in { -3.4, 3.4 } do
				part(folder, {
					Name = "TrailerWheel",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1.4, 3.6, 3.6),
					CFrame = cf * CFrame.new(x, 1.8, z),
					Color = C.ink,
					Material = M.Rubber,
				})
			end
		end
		box(
			folder,
			"LandingGear",
			cf * CFrame.new(0, 0, -16),
			Vector3.new(6, 4, 0.6),
			C.darkMetal,
			M.Metal
		)
	end
	trailer(CFrame.new(-178, ROAD_TOP, 506), C.white)
	trailer(CFrame.new(-106, ROAD_TOP, 506), Color3.fromRGB(200, 200, 205))
	trailer(CFrame.new(124, ROAD_TOP, 506), C.white)
	local containerColors = {
		Color3.fromRGB(150, 50, 40),
		Color3.fromRGB(40, 90, 140),
		Color3.fromRGB(60, 110, 70),
		Color3.fromRGB(180, 120, 40),
	}
	for row = 0, 2 do
		for level = 0, rng:NextInteger(0, 2) do
			local cf = CFrame.new(-30 + row * 10, ROAD_TOP + level * 9, 548)
				* CFrame.Angles(0, math.rad(90), 0)
			box(
				folder,
				"Container",
				cf,
				Vector3.new(40, 9, 8.5),
				containerColors[rng:NextInteger(1, #containerColors)],
				M.CorrodedMetal
			)
		end
	end
	for row = 0, 1 do
		for level = 0, 1 do
			box(
				folder,
				"Container",
				CFrame.new(64, ROAD_TOP + level * 9, 548 + row * 10),
				Vector3.new(40, 9, 8.5),
				containerColors[rng:NextInteger(1, #containerColors)],
				M.CorrodedMetal
			)
		end
	end
	for i = 0, 5 do
		box(
			folder,
			"Pallet",
			CFrame.new(-206 + (i % 3) * 5, ROAD_TOP + math.floor(i / 3) * 1.2, 470),
			Vector3.new(4, 1.2, 4),
			C.wood,
			M.WoodPlanks
		)
	end
	local fork = CFrame.new(20, ROAD_TOP, 506) * CFrame.Angles(0, math.rad(30), 0)
	box(folder, "Forklift", fork, Vector3.new(4.4, 4, 7), Color3.fromRGB(230, 170, 30), M.Metal)
	box(
		folder,
		"ForkMast",
		fork * CFrame.new(0, 0, -4),
		Vector3.new(3.6, 9, 0.6),
		C.darkMetal,
		M.Metal
	)
	box(
		folder,
		"ForkCage",
		fork * CFrame.new(0, 4, 0.5),
		Vector3.new(4.2, 4, 4),
		C.darkMetal,
		M.Metal
	)

	-- Floodlight towers: the yard is lit at night, so trespassing feels exposed.
	for _, p in
		{
			Vector3.new(-200, 0, 360),
			Vector3.new(200, 0, 360),
			Vector3.new(-200, 0, 560),
			Vector3.new(200, 0, 560),
			Vector3.new(0, 0, 500),
		}
	do
		box(
			folder,
			"FloodTower",
			CFrame.new(p + Vector3.new(0, ROAD_TOP, 0)),
			Vector3.new(1.2, 34, 1.2),
			C.metal,
			M.Metal
		)
		local bank = box(
			folder,
			"Floodlight",
			CFrame.new(p + Vector3.new(0, 34, 0)),
			Vector3.new(5, 2, 2),
			Color3.fromRGB(255, 246, 220),
			M.Neon
		)
		light(bank, "SpotLight", {
			Face = Enum.NormalId.Bottom,
			Angle = 120,
			Range = 60,
			Brightness = 2.4,
			Color = Color3.fromRGB(255, 244, 220),
		})
		CollectionService:AddTag(bank, "StreetLight")
	end
	for _, p in { Vector3.new(-40, 0, 362), Vector3.new(40, 0, 362), Vector3.new(0, 0, 590) } do
		box(
			folder,
			"CameraPole",
			CFrame.new(p + Vector3.new(0, ROAD_TOP, 0)),
			Vector3.new(0.5, 14, 0.5),
			C.metal,
			M.Metal
		)
		box(
			folder,
			"Camera",
			CFrame.new(p + Vector3.new(0, 14, -0.8)) * CFrame.Angles(math.rad(-20), 0, 0),
			Vector3.new(1, 1, 2.2),
			C.white
		)
	end
	local offset = CityPlan.YARD_OFFSET
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			child.CFrame += offset
		elseif child:IsA("Model") then
			child:PivotTo(child:GetPivot() + offset)
		end
	end
end

-- ─── vehicles (Roblox-owned police car mesh, also recolored for civilians) ─

local function sanitize(model: Model)
	for _, d in model:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Constraint")
			or d:IsA("Sound")
			or d:IsA("Trail")
			or d:IsA("RemoteEvent")
			or d:IsA("BindableEvent")
			or d:IsA("Seat")
			or d:IsA("VehicleSeat")
			or d:IsA("ProximityPrompt")
		then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = d.Size.Magnitude > 8
		end
	end
end

local function civilianize(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			if d.Material == M.Neon or string.find(string.lower(d.Name), "light") then
				d:Destroy()
			elseif
				d.BrickColor == BrickColor.new("Institutional white")
				or d.BrickColor == BrickColor.new("Lily white")
			then
				d.Color = color
			end
		end
	end
end

local function fallbackCar(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Car"
	local root = part(model, {
		Name = "Body",
		Size = Vector3.new(7.6, 3, 17),
		CFrame = CFrame.new(0, 2.4, 0),
		Color = color,
	})
	part(model, {
		Name = "Cabin",
		Size = Vector3.new(7, 2.8, 8),
		CFrame = CFrame.new(0, 5.2, 1),
		Color = C.glass,
		Material = M.Glass,
	})
	for _, x in { -3.3, 3.3 } do
		for _, z in { -5.4, 5.4 } do
			part(model, {
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 3, 3),
				CFrame = CFrame.new(x, 1.5, z),
				Color = C.ink,
				Material = M.Rubber,
			})
		end
	end
	model.PrimaryPart = root
	return model
end

local function loadVehicles(town: Instance, stalls: { CFrame })
	local ok, container = pcall(InsertService.LoadAsset, InsertService, POLICE_CAR_ASSET)
	local police: Model? = nil
	if ok then
		local found = (container :: Instance):FindFirstChildWhichIsA("Model")
		if found then
			sanitize(found)
			police = found
		end
	else
		warn("[World] could not load the police car, using simple cars: " .. tostring(container))
	end

	local templates = ReplicatedStorage:FindFirstChild("VehicleTemplates") or Instance.new("Folder")
	templates.Name = "VehicleTemplates"
	local function civilian(color: Color3): Model
		if police then
			local m = police:Clone()
			civilianize(m, color)
			m.Name = "Car"
			return m
		end
		return fallbackCar(color)
	end
	if police then
		local p = police:Clone()
		p.Name = "PoliceCar"
		p.Parent = templates
	end
	for i, color in CAR_COLORS do
		local m = civilian(color)
		m.Name = "Car" .. i
		m.Parent = templates
	end
	templates.Parent = ReplicatedStorage

	-- Height from a model's pivot to the bottom of its bounding box.
	local function lift(m: Model): number
		local cf, size = m:GetBoundingBox()
		return m:GetPivot().Y - (cf.Y - size.Y / 2)
	end

	local parked = Instance.new("Folder")
	parked.Name = "ParkedCars"
	parked.Parent = town
	for _, cf in stalls do
		if rng:NextNumber() < 0.45 then
			local m = civilian(CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
			local flip = CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0)
			m:PivotTo(CFrame.new(cf.X, ROAD_TOP + lift(m), cf.Z) * flip)
			m.Parent = parked
		end
	end
	if police then
		local cruiser = police:Clone()
		cruiser.Name = "GateCruiser"
		local hz = W.RED_SIZE.Y / 2
		cruiser:PivotTo(
			CFrame.new(W.RED_CENTER.X - 62, ROAD_TOP + lift(cruiser), W.RED_CENTER.Z - hz + 20)
				* CFrame.Angles(0, math.rad(60), 0)
		)
		cruiser.Parent = town
	end
end

-- ─── lighting & terrain ────────────────────────────────────────────────────

local function setupEnvironment()
	local terrain = workspace.Terrain
	-- Ground is a mowed-lawn Part, not terrain: terrain grass grows tall blades
	-- (decoration) that poke through roads and cannot be turned off by script.
	terrain:Clear()
	local lawn = workspace:WaitForChild("Town"):FindFirstChild("Ground") or Instance.new("Folder")
	lawn.Name = "Ground"
	lawn.Parent = workspace:WaitForChild("Town")
	-- Parts are capped at 2048 studs, so big areas are laid in tiles.
	local function tiles(r: any, y: number, h: number, props: { [string]: any })
		local step = 1600
		local x = r.x0
		while x < r.x1 do
			local x2 = math.min(x + step, r.x1)
			local z = r.z0
			while z < r.z1 do
				local z2 = math.min(z + step, r.z1)
				local p = Instance.new("Part")
				p.Anchored = true
				p.TopSurface = Enum.SurfaceType.Smooth
				p.Size = Vector3.new(x2 - x, h, z2 - z)
				p.Position = Vector3.new((x + x2) / 2, y, (z + z2) / 2)
				for k2, v in props do
					(p :: any)[k2] = v
				end
				p.Parent = lawn
				z = z2
			end
			x = x2
		end
	end
	for _, r in CityPlan.LAND do
		tiles(
			r,
			-1.02,
			2,
			{ Name = "Lawn", Color = Color3.fromRGB(92, 124, 64), Material = M.Grass }
		)
	end
	for _, r in CityPlan.WATER do
		tiles(r, -1.6, 1, {
			Name = "Sea",
			CanCollide = false,
			Color = Color3.fromRGB(30, 84, 108),
			Material = M.Glass,
			Transparency = 0.15,
			Reflectance = 0.2,
		})
		tiles(r, -9, 1, { Name = "Seabed", Color = Color3.fromRGB(80, 90, 70), Material = M.Sand })
	end
	-- Sand from the shoreline up to the coastal drive's sidewalk.
	for z = -1990, 2040, 30 do
		local edge = math.min(CityPlan.sandEdge(z), CityPlan.sandEdge(z + 30))
		local sand = Instance.new("Part")
		sand.Name = "Sand"
		sand.Anchored = true
		sand.TopSurface = Enum.SurfaceType.Smooth
		sand.Size = Vector3.new(edge + 2250 + 1, 1.1, 30.5)
		sand.Position = Vector3.new((-2250 + edge) / 2, -0.5, z + 15)
		sand.Color = Color3.fromRGB(226, 206, 160)
		sand.Material = M.Sand
		sand.Parent = lawn
	end
	-- Vista Hills: smooth terrain rising north of Hillside Ave.
	task.spawn(function()
		local res = 4
		local x0, x1, z0, z1 = -2000, 1700, 1168, 2048
		local yTop = 80
		local ny = yTop // res
		for cx = x0, x1 - 1, 256 do
			local cx1 = math.min(cx + 256, x1)
			local nx = (cx1 - cx) // res
			local nz = (z1 - z0) // res
			local mats, occ = {}, {}
			for ix = 1, nx do
				mats[ix], occ[ix] = {}, {}
				for iy = 1, ny do
					mats[ix][iy], occ[ix][iy] = {}, {}
				end
				local x = cx + (ix - 0.5) * res
				for iz = 1, nz do
					local z = z0 + (iz - 0.5) * res
					local h = CityPlan.hillY(x, z)
					for iy = 1, ny do
						local bottom = (iy - 1) * res
						local o = math.clamp((h - bottom) / res, 0, 1)
						occ[ix][iy][iz] = o
						mats[ix][iy][iz] = if o <= 0
							then Enum.Material.Air
							elseif h - bottom < 6 then Enum.Material.LeafyGrass
							else Enum.Material.Ground
					end
				end
			end
			local region = Region3.new(
				Vector3.new(cx, 0, z0),
				Vector3.new(cx + nx * res, ny * res, z0 + nz * res)
			)
			terrain:WriteVoxels(region, res, mats, occ)
			task.wait()
		end
	end)
	local patchRng = Random.new(7)
	local placed = 0
	while placed < 160 do
		local size = patchRng:NextNumber(60, 180)
		local pos =
			Vector3.new(patchRng:NextNumber(-2200, 2650), 0, patchRng:NextNumber(-1950, 1200))
		if CityPlan.onLand(pos) then
			placed += 1
			local patch = Instance.new("Part")
			patch.Name = "LawnPatch"
			patch.Anchored = true
			patch.CanCollide = false
			patch.CastShadow = false
			patch.Size = Vector3.new(size, 0.04, size * patchRng:NextNumber(0.5, 1))
			patch.CFrame = CFrame.new(pos) * CFrame.Angles(0, patchRng:NextNumber(0, 6.28), 0)
			patch.Color = Color3.fromRGB(92, 124, 64):Lerp(
				if patchRng:NextNumber() < 0.5
					then Color3.fromRGB(70, 104, 50)
					else Color3.fromRGB(122, 140, 76),
				patchRng:NextNumber(0.3, 0.7)
			)
			patch.Material = M.Grass
			patch.Parent = lawn
		end
	end
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.5
		clouds.Density = 0.55
		clouds.Parent = terrain
	end

	Lighting.ClockTime = Config.DayCycle.START
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 136)

	local air = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	air.Density = 0.3
	air.Offset = 0.25
	air.Color = Color3.fromRGB(199, 206, 214)
	air.Decay = Color3.fromRGB(106, 112, 125)
	air.Glare = 0.2
	air.Haze = 1.2
	air.Parent = Lighting

	local grade = (
		Lighting:FindFirstChild("TrashHunterGrade") or Instance.new("ColorCorrectionEffect")
	) :: ColorCorrectionEffect
	grade.Name = "TrashHunterGrade"
	grade.Saturation = 0.02
	grade.Contrast = 0.08
	grade.TintColor = Color3.fromRGB(255, 250, 244)
	grade.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
end

-- ─── entry points ──────────────────────────────────────────────────────────

-- By store id.
local STORE_LOOK = {
	hardware = {
		w = 50,
		wall = Color3.fromRGB(150, 70, 52),
		material = M.Brick,
		awning = Color3.fromRGB(176, 40, 32),
		action = "Shop gear",
	},
	motors = {
		w = 60,
		wall = Color3.fromRGB(196, 200, 206),
		material = M.Concrete,
		awning = Color3.fromRGB(30, 80, 160),
		action = "Browse cars",
	},
	harbor = {
		w = 50,
		wall = Color3.fromRGB(70, 96, 110),
		material = M.WoodPlanks,
		awning = Color3.fromRGB(30, 60, 90),
		action = "Shop gear",
	},
	bayside = {
		w = 60,
		wall = Color3.fromRGB(230, 226, 214),
		material = M.Concrete,
		awning = Color3.fromRGB(32, 120, 128),
		action = "Browse cars",
	},
	realty = {
		w = 50,
		wall = Color3.fromRGB(226, 218, 200),
		material = M.Plaster,
		awning = Color3.fromRGB(40, 92, 70),
		action = "Browse homes",
	},
}

-- Walk-in stores: a room with a glass front and a doorway, shelves or a
-- showroom inside, and the counter (with its prompt) at the back.
local function buildStores(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Stores"
	folder.Parent = parent
	for id, store in Config.Stores do
		local look = STORE_LOOK[id]
		local lot = CityPlan.STORE_LOTS[id]
		local model = Instance.new("Model")
		model.Name = id .. "Store"
		local w, d, h = look.w, 46, 18
		local front = lot * CFrame.new(0, 0, 4) -- front wall line
		local body = front * CFrame.new(0, 0, d / 2)
		local floorColor = if store.sells == "cars"
			then Color3.fromRGB(220, 220, 224)
			else Color3.fromRGB(150, 116, 84)
		box(
			model,
			"Floor",
			body,
			Vector3.new(w, 0.4, d),
			floorColor,
			if store.sells == "cars" then M.Marble else M.WoodPlanks
		)
		box(
			model,
			"WallBack",
			body * CFrame.new(0, 0.4, d / 2 - 0.5),
			Vector3.new(w, h, 1),
			look.wall,
			look.material
		)
		for _, sx in { -1, 1 } do
			box(
				model,
				"WallSide",
				body * CFrame.new(sx * (w / 2 - 0.5), 0.4, 0),
				Vector3.new(1, h, d),
				look.wall,
				look.material
			)
			-- Glass storefront either side of the doorway, on a low wall.
			local seg = (w - 10) / 2
			local x = sx * (5 + seg / 2)
			box(
				model,
				"WallFront",
				front * CFrame.new(x, 0.4, 0.5),
				Vector3.new(seg, 3, 1),
				look.wall,
				look.material
			)
			local glass = box(
				model,
				"ShopWindow",
				front * CFrame.new(x, 3.4, 0.5),
				Vector3.new(seg, h - 7, 0.4),
				C.glass,
				M.Glass
			)
			glass.Transparency = 0.55
			box(
				model,
				"WallFront",
				front * CFrame.new(x, h - 3.6, 0.5),
				Vector3.new(seg, 4, 1),
				look.wall,
				look.material
			)
		end
		box(
			model,
			"Lintel",
			front * CFrame.new(0, 10.4, 0.5),
			Vector3.new(10, h - 10, 1),
			look.wall,
			look.material
		)
		box(
			model,
			"Roof",
			body * CFrame.new(0, h + 0.4, 0),
			Vector3.new(w + 1, 1, d + 1),
			C.roof,
			M.Concrete
		)
		-- Sign band and awning over the entrance.
		local band = box(
			model,
			"SignBand",
			front * CFrame.new(0, h - 4.6, -0.3),
			Vector3.new(w, 4, 0.4),
			look.awning
		)
		sign(band, Enum.NormalId.Front, string.upper(store.name), look.awning, C.white)
		box(
			model,
			"Awning",
			front * CFrame.new(0, 10.6, -3),
			Vector3.new(16, 0.5, 6),
			look.awning,
			M.Fabric
		)
		for _, z in { d * 0.3, d * 0.7 } do
			local lamp = box(
				model,
				"CeilingLight",
				front * CFrame.new(0, h - 0.4, z),
				Vector3.new(w - 10, 0.3, 2),
				Color3.fromRGB(255, 248, 230),
				M.Neon
			)
			light(
				lamp,
				"SurfaceLight",
				{ Face = Enum.NormalId.Bottom, Range = 20, Brightness = 1.4, Angle = 120 }
			)
		end
		if store.sells == "cars" then
			-- Showroom: two cars on display.
			for _, x in { -w / 4, w / 4 } do
				local car = front * CFrame.new(x, 0.4, 14)
				box(
					model,
					"ShowCarBody",
					car * CFrame.new(0, 0.8, 0),
					Vector3.new(6.4, 2.4, 13),
					CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)],
					M.SmoothPlastic
				)
				box(
					model,
					"ShowCarCabin",
					car * CFrame.new(0, 3.2, 1),
					Vector3.new(5.8, 2, 6.5),
					Color3.fromRGB(40, 50, 60),
					M.Glass
				)
				box(
					model,
					"Turntable",
					car,
					Vector3.new(16, 0.4, 16),
					Color3.fromRGB(60, 62, 70),
					M.DiamondPlate
				)
			end
		else
			-- Two aisles of shelves stocked with boxes.
			for _, x in { -w / 4, w / 4 } do
				local shelf = front * CFrame.new(x, 0.4, 16)
				box(model, "Shelf", shelf, Vector3.new(3, 7, 14), C.darkMetal, M.Metal)
				for row = 0, 2 do
					for k2 = -2, 2 do
						box(
							model,
							"Stock",
							shelf * CFrame.new(0, 1 + row * 2.2, k2 * 2.6),
							Vector3.new(3.4, 1.6, 2),
							Color3.fromHSV(rng:NextNumber(), 0.5, 0.85),
							M.SmoothPlastic
						)
					end
				end
			end
		end
		-- The counter, with the prompt that opens the store's window.
		local counterCf = lot * CFrame.new(0, 0.4, 32)
		local counter = box(
			model,
			id .. "Counter",
			counterCf,
			Vector3.new(12, 3.6, 2.6),
			Color3.fromRGB(86, 62, 46),
			M.WoodPlanks
		)
		counter:SetAttribute("Store", id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StorePrompt"
		prompt.ActionText = look.action
		prompt.ObjectText = store.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = store.range - 2
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		box(
			model,
			"Register",
			counterCf * CFrame.new(3, 3.6, 0),
			Vector3.new(2, 1.4, 1.6),
			C.darkMetal,
			M.Metal
		)
		model.Parent = folder
	end
end

local kit = {
	trafficLight = trafficLight,
	stopSign = stopSign,
	house = house,
	onRoad = onRoad,
	part = part,
	box = box,
	wedge = wedge,
	sign = sign,
	light = light,
	window = window,
	tree = tree,
	streetLight = streetLight,
	hydrant = hydrant,
	bench = bench,
	trashCan = trashCan,
	gableRoof = gableRoof,
	storefront = storefront,
	parkingLot = parkingLot,
	utilityPole = utilityPole,
	wire = wire,
	C = C,
	M = M,
	SIDING = SIDING,
	rng = rng,
	ROAD_TOP = ROAD_TOP,
	WALK_TOP = WALK_TOP,
	ROAD_W = ROAD_W,
	WALK_W = WALK_W,
}

local stalls: { CFrame } = {}
CityDistricts.extendKit(kit)

-- Housing builds homes with the same parts and palette as the rest of town.
World.kit = kit

function World.init()
	local old = workspace:FindFirstChild("Town")
	if old then
		old:Destroy()
	end
	local town = Instance.new("Folder")
	town.Name = "Town"

	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = town
	Roads.build(kit, streets)

	local districts = Instance.new("Folder")
	districts.Name = "Districts"
	districts.Parent = town
	buildHideout(town)
	buildMeridianYard(town)
	buildStores(districts)
	CityDistricts.build(districts, kit)

	local dumpsters = Instance.new("Folder")
	dumpsters.Name = "Dumpsters"
	dumpsters.Parent = town
	for _, spec in W.Dumpsters do
		dumpster(dumpsters, spec)
	end

	town.Parent = workspace
	setupEnvironment()
	local built = Infill.build(kit, town)
	print(`[World] infill built {built} buildings`)
	game:GetService("StarterPlayer").CharacterWalkSpeed = Config.Player.WALK_SPEED
end

local function setLights(on: boolean)
	for _, head in CollectionService:GetTagged("StreetLight") do
		if head:IsA("BasePart") then
			head.Material = if on then M.Neon else M.SmoothPlastic
			local l = head:FindFirstChildWhichIsA("Light")
			if l then
				l.Enabled = on
			end
		end
	end
	workspace:SetAttribute("Night", on)
end

local function updateHotDistrict()
	local candidates = {}
	for _, d in Config.Districts do
		if d.id ~= "town" and d.tier > 0 then
			table.insert(candidates, d.name)
		end
	end
	local day = math.floor(DateTime.now().UnixTimestamp / 86400)
	workspace:SetAttribute("HotDistrict", candidates[day % #candidates + 1])
end

-- A clerk stands behind every sell counter and store counter (the side
-- away from the customer, which is local +Z of the counter).
local function spawnClerks(town: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Clerks"
	folder.Parent = town
	local clerkRng = Random.new(11)
	local counters = {}
	for _, d in town:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "SellCounter" or d:GetAttribute("Store")) then
			table.insert(counters, d)
		end
	end
	for _, counter in counters do
		local isSell = counter.Name == "SellCounter"
		local behind = counter.CFrame * CFrame.new(0, 0, counter.Size.Z / 2 + 2)
		local stand = Vector3.new(behind.X, counter.Position.Y - counter.Size.Y / 2 + 3, behind.Z)
		local npc = Npc.new(
			"civilian",
			if isSell then "PawnClerk" else "StoreClerk",
			CFrame.lookAt(stand, Vector3.new(counter.Position.X, stand.Y, counter.Position.Z)),
			folder,
			clerkRng
		)
		if npc then
			npc.root.Anchored = true
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(140, 26)
			tag.StudsOffset = Vector3.new(0, 2.6, 0)
			tag.MaxDistance = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.BuilderSansBold
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(240, 196, 70)
			label.TextStrokeTransparency = 0.3
			label.Text = if isSell then "Pawn Clerk" else "Clerk"
			label.Parent = tag
			tag.Parent = npc.head
		end
		task.wait()
	end
end

function World.start()
	task.spawn(spawnClerks, workspace:WaitForChild("Town"))
	task.spawn(loadVehicles, workspace:WaitForChild("Town"), stalls)
	updateHotDistrict()
	task.spawn(function()
		while true do
			task.wait(60)
			updateHotDistrict()
		end
	end)

	local D = Config.DayCycle
	local STEP = 0.5
	local clock = D.START
	local lightsOn: boolean? = nil
	task.spawn(function()
		while true do
			local night = clock >= D.LIGHTS_ON or clock < D.LIGHTS_OFF
			if night ~= lightsOn then
				lightsOn = night
				setLights(night)
				Lighting.OutdoorAmbient = if night
					then Color3.fromRGB(70, 76, 104)
					else Color3.fromRGB(128, 128, 136)
			end
			task.wait(STEP)
			clock = (clock + 24 * STEP / D.DAY_LENGTH * (if night then D.NIGHT_SPEED else 1)) % 24
			Lighting.ClockTime = clock
		end
	end)

	-- Signal lamps are lit by each client (Controllers/Traffic) on the shared
	-- CityPlan.signalState clock, so they switch exactly when cars react.
end

return World
