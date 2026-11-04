--!strict
-- The city layout, shared by every system that needs to know where things
-- are. The server builds it, the client map draws it, traffic and walkers
-- move on it, and Config reads landmark positions from it. North is +Z.
--
-- Roads form a graph: nodes (intersections, bends, cul-de-sac bulbs) joined
-- by edges that carry a polyline, so streets can curve and climb. The layout
-- follows a real street hierarchy:
-- - A warped grid of arterials.
-- - Superblocks filled per district: a tight grid downtown, row streets in
--   Southside, crescents in Midtown, curving collectors with cul-de-sacs in
--   the suburbs.
-- - A winding coastal drive.
-- - Switchback roads up the terrain hills.
-- - A curving elevated freeway with a bridge to Port Haven island.
-- See docs/superpowers/specs/2026-11-05-city-rebuild-design.md.

export type Node = {
	id: number,
	pos: Vector3,
	edges: { Edge },
	bulb: boolean, -- cul-de-sac turning circle
	signal: boolean, -- traffic lights
	groups: { [number]: string }, -- signal phase group ("A"/"B") of each edge, by edge id
	gap: number, -- distance from the centre to where the street's own lane starts
}
export type Edge = {
	id: number,
	a: Node,
	b: Node,
	points: { Vector3 }, -- centre line, y = road base height (the surface is 0.72 above)
	w: number, -- asphalt width
	kind: string, -- "arterial" | "collector" | "street" | "court" | "freeway" | "hill"
	name: string?,
	length: number,
	tag: string?,
}
export type Rect = { x0: number, x1: number, z0: number, z1: number }
export type District = {
	id: string,
	name: string,
	tier: number,
	boost: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	city: string?, -- nil means the mainland ("maple")
	note: string?,
}

local WALK_W = 10
local SURFACE = 0.72 -- asphalt top above an edge's base height
local BULB_R = 26
local FREEWAY_Y = 36

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function smooth01(t: number): number
	local c = math.clamp(t, 0, 1)
	return c * c * (3 - 2 * c)
end

-- ─── terrain ──────────────────────────────────────────────────────────────

-- Vista Hills rise north of Hillside Ave; everything else is flat (y = 0).
local function hillY(x: number, z: number): number
	if z < 1170 then
		return 0
	end
	local rise = smooth01((z - 1190) / 430)
	local sides = smooth01((x + 2000) / 260) * smooth01((1720 - x) / 280)
	local roll = 9 * math.sin(x / 170) * math.sin(z / 130) * smooth01((z - 1450) / 250)
	return math.max(0, (58 * rise + roll) * sides)
end

-- The coast: Ocean Dr winds along it; sand lies west of the drive.
local function oceanX(z: number): number
	return -2085 + 38 * math.sin(z / 310) + 14 * math.sin(z / 97)
end
local OCEAN_W = 30
local function sandEdge(z: number): number
	return oceanX(z) - OCEAN_W / 2 - WALK_W
end

-- ─── curves ───────────────────────────────────────────────────────────────

local function polyLength(points: { Vector3 }): number
	local len = 0
	for i = 2, #points do
		len += (flat(points[i]) - flat(points[i - 1])).Magnitude
	end
	return len
end

-- Point at arc-length fraction f (0..1), plus the segment it falls on.
local function pointAtFrac(points: { Vector3 }, f: number): (Vector3, number)
	local total = polyLength(points)
	local target = math.clamp(f, 0, 1) * total
	for i = 2, #points do
		local seg = (flat(points[i]) - flat(points[i - 1])).Magnitude
		if target <= seg or i == #points then
			local t = if seg > 0 then math.clamp(target / seg, 0, 1) else 0
			return points[i - 1]:Lerp(points[i], t), i - 1
		end
		target -= seg
	end
	return points[#points], #points - 1
end

-- The part of a polyline between fractions f0 < f1.
local function subPoly(points: { Vector3 }, f0: number, f1: number): { Vector3 }
	local p0, s0 = pointAtFrac(points, f0)
	local p1, s1 = pointAtFrac(points, f1)
	local out = { p0 }
	for i = s0 + 1, s1 do
		if (flat(points[i]) - flat(out[#out])).Magnitude > 0.5 then
			table.insert(out, points[i])
		end
	end
	if (flat(p1) - flat(out[#out])).Magnitude > 0.5 or #out == 1 then
		table.insert(out, p1)
	end
	return out
end

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: number): { Vector3 }
	local out = {}
	for i = 0, n do
		local t = i / n
		local u = 1 - t
		table.insert(
			out,
			p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
		)
	end
	return out
end

-- Catmull-Rom spline through control points, sampled about every `step` studs.
local function spline(ctrl: { Vector3 }, step: number): { Vector3 }
	local out = { ctrl[1] }
	for i = 1, #ctrl - 1 do
		local p0 = ctrl[math.max(i - 1, 1)]
		local p1, p2 = ctrl[i], ctrl[i + 1]
		local p3 = ctrl[math.min(i + 2, #ctrl)]
		local n = math.max(2, math.floor((p2 - p1).Magnitude / step))
		for k = 1, n do
			local t = k / n
			local t2, t3 = t * t, t * t * t
			table.insert(
				out,
				(
					p1 * 2
					+ (p2 - p0) * t
					+ (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2
					+ (p1 * 3 - p0 - p2 * 3 + p3) * t3
				) * 0.5
			)
		end
	end
	return out
end

-- Drapes a polyline over the hills (y = terrain height).
local function drape(points: { Vector3 }): { Vector3 }
	local out = {}
	for _, p in points do
		table.insert(out, v3(p.X, hillY(p.X, p.Z), p.Z))
	end
	return out
end

-- ─── districts, land, water ───────────────────────────────────────────────

-- First match wins (Downtown sits inside Midtown).
local DISTRICTS: { District } = {
	{
		id = "downtown",
		name = "Downtown",
		tier = 4,
		boost = 1.2,
		x0 = -500,
		x1 = 600,
		z0 = -400,
		z1 = 400,
	},
	{
		id = "hills",
		name = "Vista Hills",
		tier = 3,
		boost = 0.8,
		x0 = -2000,
		x1 = 1700,
		z0 = 1185,
		z1 = 2050,
	},
	{
		id = "beach",
		name = "Westshore",
		tier = 2,
		boost = 0.35,
		x0 = -2250,
		x1 = -1700,
		z0 = -2000,
		z1 = 1185,
	},
	{
		id = "industrial",
		name = "Industrial Park",
		tier = 5,
		boost = 1.6,
		x0 = 1100,
		x1 = 1800,
		z0 = -2000,
		z1 = 1185,
	},
	{
		id = "southside",
		name = "Southside",
		tier = 1,
		boost = 0,
		x0 = -1700,
		x1 = -500,
		z0 = -2000,
		z1 = -900,
	},
	{
		id = "eastgate",
		name = "Eastgate",
		tier = 1,
		boost = 0.2,
		x0 = -500,
		x1 = 1100,
		z0 = -2000,
		z1 = -900,
	},
	{
		id = "midtown",
		name = "Midtown",
		tier = 2,
		boost = 0.45,
		x0 = -1700,
		x1 = 1100,
		z0 = -900,
		z1 = 1185,
	},
	{
		id = "oldport",
		name = "Old Port",
		city = "port",
		tier = 3,
		boost = 0.7,
		x0 = 1990,
		x1 = 2470,
		z0 = -1300,
		z1 = 1300,
	},
	{
		id = "docks",
		name = "The Docks",
		city = "port",
		tier = 5,
		boost = 1.4,
		x0 = 2470,
		x1 = 2720,
		z0 = -1300,
		z1 = 1300,
	},
}

local LAND: { Rect } = {
	{ x0 = -2250, x1 = 1800, z0 = -2000, z1 = 2050 },
	{ x0 = 2000, x1 = 2680, z0 = -1300, z1 = 1300 },
}
local WATER: { Rect } = {
	{ x0 = -2900, x1 = -2250, z0 = -2400, z1 = 2500 },
	{ x0 = -2250, x1 = 1800, z0 = -2400, z1 = -2000 },
	{ x0 = -2250, x1 = 1800, z0 = 2050, z1 = 2500 },
	{ x0 = 1800, x1 = 2000, z0 = -2400, z1 = 2500 },
	{ x0 = 2000, x1 = 2680, z0 = -2400, z1 = -1300 },
	{ x0 = 2000, x1 = 2680, z0 = 1300, z1 = 2500 },
	{ x0 = 2680, x1 = 3200, z0 = -2400, z1 = 2500 },
}

local function inRect(r: Rect, x: number, z: number): boolean
	return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1
end

local function district(pos: Vector3): District?
	for _, d in DISTRICTS do
		if inRect(d :: any, pos.X, pos.Z) then
			return d
		end
	end
	return nil
end

-- Buildable land (not sea, not the sand).
local function onLand(pos: Vector3): boolean
	for _, r in LAND do
		if inRect(r, pos.X, pos.Z) then
			return not (pos.X < 0 and pos.X < sandEdge(pos.Z))
		end
	end
	return false
end

-- ─── landmarks (reserved land) ────────────────────────────────────────────

local HIDEOUT = v3(-800, 0, -1270) -- faces south onto Palm St (z = -1350)
local LOCKUP = v3(2200, 0, 75) -- Harbor Lockup, faces south onto Wharf Rd
local YARD_ORIGIN = v3(0, 0, 465) -- the Meridian yard was designed around this point
local RED_CENTER = v3(1400, 0, 600)
local YARD_OFFSET = RED_CENTER - YARD_ORIGIN
local PLAZA: Rect = { x0 = 262, x1 = 398, z0 = 156, z1 = 244 } -- Downtown civic plaza
local PARK: Rect = { x0 = -770, x1 = -535, z0 = 232, z1 = 368 } -- Midtown park

local RESERVED: { Rect } = {
	PLAZA,
	PARK,
	{ x0 = HIDEOUT.X - 100, x1 = HIDEOUT.X + 100, z0 = HIDEOUT.Z - 53, z1 = HIDEOUT.Z + 90 },
	{ x0 = LOCKUP.X - 50, x1 = LOCKUP.X + 50, z0 = LOCKUP.Z - 50, z1 = LOCKUP.Z + 40 },
	{
		x0 = RED_CENTER.X - 250,
		x1 = RED_CENTER.X + 250,
		z0 = RED_CENTER.Z - 160,
		z1 = RED_CENTER.Z + 160,
	},
}

local function reserved(pos: Vector3, pad: number?): boolean
	local p = pad or 0
	for _, r in RESERVED do
		if pos.X >= r.x0 - p and pos.X <= r.x1 + p and pos.Z >= r.z0 - p and pos.Z <= r.z1 + p then
			return true
		end
	end
	return false
end

-- ─── graph ────────────────────────────────────────────────────────────────

local NODES: { Node } = {}
local EDGES: { Edge } = {}

local function newNode(pos: Vector3): Node
	for _, n in NODES do
		if (flat(n.pos) - flat(pos)).Magnitude < 3 and math.abs(n.pos.Y - pos.Y) < 2 then
			return n
		end
	end
	local n: Node = {
		id = #NODES + 1,
		pos = pos,
		edges = {},
		bulb = false,
		signal = false,
		groups = {},
		gap = 0,
	}
	table.insert(NODES, n)
	return n
end

local WIDTH = { arterial = 34, collector = 30, street = 28, court = 24, freeway = 30, hill = 28 }

type Base = {
	a: Node,
	b: Node,
	points: { Vector3 },
	w: number,
	kind: string,
	name: string?,
	splits: { { f: number, node: Node } },
	length: number,
}
local BASE: { [string]: Base } = {}
local BASE_ORDER: { string } = {}
local LOCAL: { { a: Node, b: Node, points: { Vector3 }, kind: string, name: string?, tag: string? } } =
	{}

local function addBase(
	key: string,
	a: Node,
	b: Node,
	points: { Vector3 },
	kind: string,
	name: string?,
	w: number?
)
	points[1] = a.pos
	points[#points] = b.pos
	BASE[key] = {
		a = a,
		b = b,
		points = points,
		w = w or WIDTH[kind],
		kind = kind,
		name = name,
		splits = {},
		length = polyLength(points),
	}
	table.insert(BASE_ORDER, key)
end

-- A node at fraction f along a base edge (reuses a split within 12 studs).
local function splitAt(key: string, f: number): Node
	local b = BASE[key]
	assert(b, "no base edge " .. key)
	if f * b.length < 12 then
		return b.a
	end
	if (1 - f) * b.length < 12 then
		return b.b
	end
	for _, s in b.splits do
		if math.abs(s.f - f) * b.length < 12 then
			return s.node
		end
	end
	local pos = pointAtFrac(b.points, f)
	local n = newNode(pos)
	table.insert(b.splits, { f = f, node = n })
	return n
end

local function addLocal(
	a: Node,
	b: Node,
	points: { Vector3 },
	kind: string,
	name: string?,
	tag: string?
)
	points[1] = a.pos
	points[#points] = b.pos
	table.insert(LOCAL, { a = a, b = b, points = points, kind = kind, name = name, tag = tag })
end

-- ─── arterial lattice ─────────────────────────────────────────────────────

local XS = { -1700, -1100, -500, 60, 600, 1100, 1700 }
local ZS = { -1800, -1350, -900, -400, 0, 400, 800, 1150 }
local ROW_NAMES = {
	"Southern Ave",
	"Palm St",
	"Mission St",
	"Grand Ave",
	"Main St",
	"Neon Blvd",
	"Sunset Blvd",
	"Hillside Ave",
}
local COL_NAMES =
	{ "Bay Rd", "Union St", "Center St", "Broadway", "Lake St", "Foundry Rd", "Harbor Rd" }
-- Columns that stop short, which makes T-junctions and bigger superblocks.
local COL_SPAN = { { 1, 8 }, { 1, 8 }, { 1, 8 }, { 2, 8 }, { 1, 7 }, { 1, 8 }, { 1, 8 } }

-- Nodes kept exactly on the grid, so landmarks that are built square stay square.
local LOCKED = {}
for _, k in
	{
		"2,2",
		"3,2",
		"2,5",
		"2,6",
		"3,4",
		"4,4",
		"5,4",
		"3,5",
		"4,5",
		"5,5",
		"3,6",
		"4,6",
		"5,6",
		"6,6",
		"7,6",
		"6,7",
		"7,7",
		"3,8",
		"6,8",
		"1,3",
		"1,4",
	}
do
	LOCKED[k] = true
end

local function jitter(i: number, j: number): (number, number)
	if LOCKED[i .. "," .. j] then
		return 0, 0
	end
	local a = math.sin(i * 12.9898 + j * 78.233) * 43758.5453
	local b = math.sin(i * 39.346 + j * 11.135) * 24634.6345
	return ((a - math.floor(a)) - 0.5) * 90, ((b - math.floor(b)) - 0.5) * 70
end

local L: { { Node } } = {}
for i, x in XS do
	L[i] = {}
	for j, z in ZS do
		local dx, dz = jitter(i, j)
		L[i][j] = newNode(v3(x + dx, 0, z + dz))
	end
end
for j = 1, #ZS do
	for i = 1, #XS - 1 do
		local a, b = L[i][j], L[i + 1][j]
		addBase(
			`R:{i}:{j}`,
			a,
			b,
			{ a.pos, b.pos },
			"arterial",
			ROW_NAMES[j],
			if j == 5 then 40 elseif j == 8 then 30 else 34
		)
	end
end
for i = 1, #XS do
	for j = COL_SPAN[i][1], COL_SPAN[i][2] - 1 do
		local a, b = L[i][j], L[i][j + 1]
		addBase(
			`C:{i}:{j}`,
			a,
			b,
			{ a.pos, b.pos },
			"arterial",
			COL_NAMES[i],
			if i == 4 then 40 else 34
		)
	end
end

-- Ocean Dr: winds along the coast; each row runs out to it.
local O: { Node } = {}
for j, z in ZS do
	local zz = L[1][j].pos.Z
	O[j] = newNode(v3(oceanX(zz), 0, zz))
	local _ = z
end
for j = 1, #ZS - 1 do
	local pts = {}
	local z0, z1 = O[j].pos.Z, O[j + 1].pos.Z
	local n = math.max(2, math.floor((z1 - z0) / 28))
	for k = 0, n do
		local z = z0 + (z1 - z0) * k / n
		table.insert(pts, v3(oceanX(z), 0, z))
	end
	addBase(`O:{j}`, O[j], O[j + 1], pts, "arterial", "Ocean Dr", OCEAN_W)
	addBase(`OC:{j}`, O[j], L[1][j], { O[j].pos, L[1][j].pos }, "arterial", ROW_NAMES[j], 30)
end
addBase(
	`OC:{#ZS}`,
	O[#ZS],
	L[1][#ZS],
	{ O[#ZS].pos, L[1][#ZS].pos },
	"arterial",
	ROW_NAMES[#ZS],
	30
)

-- ─── Port Haven island ────────────────────────────────────────────────────

local ISLAND_Z = { -1100, -900, -300, 0, 300, 900, 1100 }
local function bayX(z: number): number
	return 2100 + 22 * math.sin(z / 210)
end
local AN: { [number]: Node } = {}
local PI: { [number]: Node } = {}
local BA: { [number]: Node } = {}
for _, z in ISLAND_Z do
	AN[z] = newNode(v3(2350, 0, z))
	PI[z] = newNode(v3(2580, 0, z))
	BA[z] = newNode(v3(bayX(z), 0, z))
end
AN[-650] = newNode(v3(2350, 0, -650)) -- where the freeway comes down
local anchorZ = { -1100, -900, -650, -300, 0, 300, 900, 1100 }
for k = 1, #anchorZ - 1 do
	local a, b = AN[anchorZ[k]], AN[anchorZ[k + 1]]
	addBase(`AN:{k}`, a, b, { a.pos, b.pos }, "arterial", "Anchor Ave")
end
for k = 1, #ISLAND_Z - 1 do
	local z0, z1 = ISLAND_Z[k], ISLAND_Z[k + 1]
	addBase(`PI:{k}`, PI[z0], PI[z1], { PI[z0].pos, PI[z1].pos }, "street", "Pier Rd")
	local pts = {}
	local n = math.max(2, math.floor((z1 - z0) / 30))
	for s = 0, n do
		local z = z0 + (z1 - z0) * s / n
		table.insert(pts, v3(bayX(z), 0, z))
	end
	addBase(`BA:{k}`, BA[z0], BA[z1], pts, "street", "Bay St")
end
for _, z in { -900, -300, 0, 300, 900 } do
	local name = if z == 0 then "Wharf Rd" else nil
	addBase(`IW:{z}`, BA[z], AN[z], { BA[z].pos, AN[z].pos }, "street", name)
	addBase(`IE:{z}`, AN[z], PI[z], { AN[z].pos, PI[z].pos }, "street", name)
end

-- ─── Vista Hills: switchbacks, a ridge road and courts ───────────────────

local VTOP = newNode(v3(-500, hillY(-500, 1760), 1760))
addBase(
	"VISTA",
	L[3][8],
	VTOP,
	drape(spline({
		L[3][8].pos,
		v3(-500, 0, 1235),
		v3(-330, 0, 1300),
		v3(-760, 0, 1410),
		v3(-320, 0, 1520),
		v3(-660, 0, 1640),
		VTOP.pos,
	}, 14)),
	"hill",
	"Vista Dr"
)
local CREST = {
	newNode(v3(-1550, hillY(-1550, 1700), 1700)),
	newNode(v3(-1100, hillY(-1100, 1720), 1720)),
	VTOP,
	newNode(v3(-150, hillY(-150, 1800), 1800)),
	newNode(v3(350, hillY(350, 1740), 1740)),
	newNode(v3(800, hillY(800, 1770), 1770)),
}
for k = 1, #CREST - 1 do
	local a, b = CREST[k], CREST[k + 1]
	local mid = (a.pos + b.pos) / 2 + v3(0, 0, if k % 2 == 0 then 60 else -55)
	addBase(`CR:{k}`, a, b, drape(spline({ a.pos, mid, b.pos }, 14)), "hill", "Crest Rd")
end
addBase(
	"CANYON",
	L[6][8],
	CREST[#CREST],
	drape(spline({
		L[6][8].pos,
		v3(1080, 0, 1240),
		v3(860, 0, 1330),
		v3(1150, 0, 1450),
		v3(880, 0, 1580),
		v3(1020, 0, 1680),
		CREST[#CREST].pos,
	}, 14)),
	"hill",
	"Canyon Rd"
)
-- Courts off the ridge, ending in turning circles with villas around them.
for _, c in
	{
		{ 1, v3(-1600, 0, 1960), v3(-1500, 0, 1850) },
		{ 1, v3(-1700, 0, 1480), v3(-1650, 0, 1590) },
		{ 2, v3(-1150, 0, 1960), v3(-1050, 0, 1860) },
		{ 2, v3(-1000, 0, 1500), v3(-1100, 0, 1600) },
		{ 4, v3(-200, 0, 1990), v3(-100, 0, 1900) },
		{ 5, v3(400, 0, 1560), v3(300, 0, 1640) },
		{ 5, v3(420, 0, 1960), v3(330, 0, 1860) },
	}
do
	local from = CREST[c[1]]
	local endPos = v3(c[2].X, hillY(c[2].X, c[2].Z), c[2].Z)
	local bulb = newNode(endPos)
	bulb.bulb = true
	addLocal(from, bulb, drape(spline({ from.pos, c[3], endPos }, 14)), "court", nil, "hills")
end

-- ─── landmarks on the arterials (reserved before the side streets) ────────

-- Lot frame beside a base edge at fraction f: origin at the sidewalk's outer
-- edge, +Z pointing away from the road. side 1 = right of the edge's direction.
local function baseFrame(key: string, f: number, side: number, setback: number?): CFrame
	local b = BASE[key]
	assert(b, "no base edge " .. key)
	local p, seg = pointAtFrac(b.points, f)
	local d = flat(b.points[seg + 1]) - flat(b.points[seg])
	local t = if d.Magnitude > 0 then d.Unit else Vector3.xAxis
	local out = Vector3.new(-t.Z, 0, t.X) * side
	local origin = p + out * (b.w / 2 + WALK_W + (setback or 0))
	return CFrame.lookAt(origin, origin + out) * CFrame.Angles(0, math.pi, 0)
end

local function spotOn(key: string, f: number, side: number): Vector3
	return (baseFrame(key, f, side, -5)).Position
end

-- Walk-in store lots (the counter stands 32 studs in from the sidewalk).
local STORE_LOTS = {
	hardware = baseFrame("R:1:2", 0.5, -1),
	motors = baseFrame("R:3:3", 0.45, -1),
	realty = baseFrame("R:5:1", 0.22, -1),
	harbor = baseFrame("AN:6", 0.65, 1),
	bayside = baseFrame("AN:4", 0.5, 1),
}
local STORE_COUNTER_DEPTH = 32
for _, cf in STORE_LOTS do
	local c = (cf * CFrame.new(0, 0, 25)).Position
	table.insert(RESERVED, { x0 = c.X - 40, x1 = c.X + 40, z0 = c.Z - 40, z1 = c.Z + 40 })
end

-- Daily quest givers.
local GIVERS = {
	earl = { pos = spotOn("R:2:2", 0.82, -1), yaw = 0 },
	rosa = { pos = spotOn("R:2:4", 0.5, 1), yaw = 0 },
	zed = { pos = spotOn("R:3:5", 0.45, -1), yaw = 0 },
	lola = { pos = spotOn("O:4", 0.5, 1), yaw = 0 },
	vic = { pos = spotOn("C:6:5", 0.5, -1), yaw = 0 },
	pete = { pos = spotOn("IW:0", 0.25, -1), yaw = 0 },
}
-- Mission contacts who hand out district permit missions.
local CONTACTS = {
	marcus = spotOn("C:2:2", 0.6, 1),
	kai = spotOn("C:1:4", 0.5, 1),
	nova = spotOn("C:3:3", 0.8, 1),
	victoria = spotOn("R:3:8", 0.15, -1),
	tony = spotOn("C:6:3", 0.35, -1),
	joe = spotOn("C:7:2", 0.6, -1),
	mae = spotOn("IW:300", 0.5, -1),
}

-- ─── superblocks ──────────────────────────────────────────────────────────

type SidePart = { key: string, rev: boolean }
type Side = { SidePart }

local function sideLength(side: Side): number
	local len = 0
	for _, s in side do
		len += BASE[s.key].length
	end
	return len
end

-- Position at fraction u along a side, and the base edge + fraction there.
local function sideAt(side: Side, u: number): (Vector3, string, number)
	local target = math.clamp(u, 0, 1) * sideLength(side)
	for k, s in side do
		local b = BASE[s.key]
		if target <= b.length or k == #side then
			local f = math.clamp(target / b.length, 0, 1)
			if s.rev then
				f = 1 - f
			end
			return (pointAtFrac(b.points, f)), s.key, f
		end
		target -= b.length
	end
	error("empty side")
end

local function sideNode(side: Side, u: number): Node
	local _, key, f = sideAt(side, u)
	return splitAt(key, f)
end

type Cell = {
	south: Side,
	north: Side,
	west: Side,
	east: Side,
	sw: Vector3,
	se: Vector3,
	nw: Vector3,
	ne: Vector3,
}

local function bilin(c: Cell, u: number, v: number): Vector3
	local s = c.sw:Lerp(c.se, u)
	local n = c.nw:Lerp(c.ne, u)
	return s:Lerp(n, v)
end

-- The freeway leaves Bay Rd here and climbs; streets must not run under its low ends.
local FREEWAY_LOW: { Vector3 } = {}

-- A street is dropped if it would cut through reserved land, the sea or a ramp.
local function streetBlocked(points: { Vector3 }): boolean
	local len = polyLength(points)
	local n = math.max(2, math.floor(len / 10))
	for k = 1, n - 1 do
		local p = pointAtFrac(points, k / n)
		if reserved(p, 30) or not onLand(p) then
			return true
		end
		for _, q in FREEWAY_LOW do
			if (flat(p) - flat(q)).Magnitude < 30 then
				return true
			end
		end
	end
	return false
end

local STREET_NAMES = {
	"Oak St",
	"Pine St",
	"Cedar St",
	"Elm St",
	"Maple Ave",
	"Walnut St",
	"Birch Ln",
	"Willow Way",
	"Ash St",
	"Cherry Ln",
	"Spruce St",
	"Hazel Ave",
	"Juniper Way",
	"Laurel St",
	"Magnolia Ave",
	"Poplar St",
	"Aspen Ct",
	"Sycamore Rd",
	"Redwood Dr",
	"Chestnut St",
}
local nameIndex = 0
local function nextName(): string
	nameIndex += 1
	return STREET_NAMES[(nameIndex - 1) % #STREET_NAMES + 1]
end

-- A regular grid of nu x nv blocks.
local function gridCell(c: Cell, nu: number, nv: number, kind: string)
	local interior: { [string]: Node } = {}
	local function inner(k: number, l: number): Node
		local key = k .. "," .. l
		if not interior[key] then
			interior[key] = newNode(bilin(c, k / nu, l / nv))
		end
		return interior[key]
	end
	for k = 1, nu - 1 do
		local u = k / nu
		local pts = { (sideAt(c.south, u)) }
		for l = 1, nv - 1 do
			table.insert(pts, bilin(c, u, l / nv))
		end
		table.insert(pts, (sideAt(c.north, u)))
		if not streetBlocked(pts) then
			local chain = { sideNode(c.south, u) }
			for l = 1, nv - 1 do
				table.insert(chain, inner(k, l))
			end
			table.insert(chain, sideNode(c.north, u))
			local name = nextName()
			for s = 1, #chain - 1 do
				addLocal(chain[s], chain[s + 1], { chain[s].pos, chain[s + 1].pos }, kind, name)
			end
		end
	end
	for l = 1, nv - 1 do
		local v = l / nv
		local pts = { (sideAt(c.west, v)) }
		for k = 1, nu - 1 do
			table.insert(pts, bilin(c, k / nu, v))
		end
		table.insert(pts, (sideAt(c.east, v)))
		if not streetBlocked(pts) then
			local chain = { sideNode(c.west, v) }
			for k = 1, nu - 1 do
				table.insert(chain, inner(k, l))
			end
			table.insert(chain, sideNode(c.east, v))
			local name = nextName()
			for s = 1, #chain - 1 do
				addLocal(chain[s], chain[s + 1], { chain[s].pos, chain[s + 1].pos }, kind, name)
			end
		end
	end
end

-- Concentric crescents around the south-west and north-east corners.
local function crescentCell(c: Cell)
	local arcs = {
		{ c.south, 0.3, c.west, 0.3, bilin(c, 0.3, 0.13), bilin(c, 0.13, 0.3) },
		{ c.south, 0.64, c.west, 0.64, bilin(c, 0.64, 0.28), bilin(c, 0.28, 0.64) },
		{ c.north, 0.45, c.east, 0.45, bilin(c, 0.45, 0.8), bilin(c, 0.8, 0.45) },
	}
	for _, a in arcs do
		local p0 = sideAt(a[1], a[2])
		local p3 = sideAt(a[3], a[4])
		local pts = bezier(p0, a[5], a[6], p3, 18)
		if not streetBlocked(pts) then
			local n0, n1 = sideNode(a[1], a[2]), sideNode(a[3], a[4])
			addLocal(n0, n1, pts, "street", nextName())
		end
	end
end

-- A curving collector across the superblock with cul-de-sacs off it.
local function suburbCell(c: Cell, branches: number)
	local p0 = sideAt(c.west, 0.5)
	local p3 = sideAt(c.east, 0.5)
	local curve = bezier(p0, bilin(c, 0.36, 0.12), bilin(c, 0.64, 0.88), p3, 48)
	if streetBlocked(curve) then
		return
	end
	local ts = {}
	for k = 1, branches do
		table.insert(ts, k / (branches + 1))
	end
	local nodes = { sideNode(c.west, 0.5) }
	for _, t in ts do
		table.insert(nodes, newNode((pointAtFrac(curve, t))))
	end
	table.insert(nodes, sideNode(c.east, 0.5))
	local fs = { 0 }
	for _, t in ts do
		table.insert(fs, t)
	end
	table.insert(fs, 1)
	local name = nextName()
	for k = 1, #nodes - 1 do
		addLocal(nodes[k], nodes[k + 1], subPoly(curve, fs[k], fs[k + 1]), "collector", name)
	end
	for k, t in ts do
		local from = nodes[k + 1]
		local north = k % 2 == 1
		local endPos = bilin(c, t, if north then 0.86 else 0.14)
		local mid = from.pos:Lerp(endPos, 0.5)
		local tangent = (
			(pointAtFrac(curve, math.min(1, t + 0.02)))
			- (pointAtFrac(curve, math.max(0, t - 0.02)))
		)
		local bend = if tangent.Magnitude > 0 then tangent.Unit * 35 else Vector3.zero
		local pts = bezier(from.pos, mid + bend, mid - bend, endPos, 14)
		if not streetBlocked(pts) then
			local bulb = newNode(endPos)
			bulb.bulb = true
			local courtName = (nextName():gsub(" %a+$", " Ct"))
			addLocal(from, bulb, pts, "court", courtName)
		end
	end
end

-- Sunset Ln: the cul-de-sac where players buy homes.
local SUNSET: { a: Node, b: Node }? = nil
local function sunsetCell(c: Cell)
	local from = sideNode(c.south, 0.5)
	local endPos = bilin(c, 0.5, 0.86)
	local bulb = newNode(endPos)
	bulb.bulb = true
	addLocal(from, bulb, { from.pos, endPos }, "court", "Sunset Ln", "sunset")
	SUNSET = { a = from, b = bulb }
end

-- Cross streets between Ocean Dr and Bay Rd.
local function beachCell(c: Cell)
	for _, v in { 0.34, 0.67 } do
		local p0, p1 = sideAt(c.west, v), sideAt(c.east, v)
		local mid = p0:Lerp(p1, 0.5) + v3(0, 0, 18)
		local pts = bezier(p0, p0:Lerp(mid, 0.6), p1:Lerp(mid, 0.6), p1, 10)
		if not streetBlocked(pts) then
			addLocal(sideNode(c.west, v), sideNode(c.east, v), pts, "street", nextName())
		end
	end
end

local function mainCell(i0: number, i1: number, j0: number, j1: number): Cell
	local south, north, west, east = {}, {}, {}, {}
	for i = i0, i1 - 1 do
		table.insert(south, { key = `R:{i}:{j0}`, rev = false })
		table.insert(north, { key = `R:{i}:{j1}`, rev = false })
	end
	for j = j0, j1 - 1 do
		table.insert(west, { key = `C:{i0}:{j}`, rev = false })
		table.insert(east, { key = `C:{i1}:{j}`, rev = false })
	end
	return {
		south = south,
		north = north,
		west = west,
		east = east,
		sw = L[i0][j0].pos,
		se = L[i1][j0].pos,
		nw = L[i0][j1].pos,
		ne = L[i1][j1].pos,
	}
end

-- The freeway: from Bay Rd up over Midtown and the channel, down onto the island.
local fwStart = splitAt("C:1:3", 0.5)
local fwCtrl = {
	fwStart.pos,
	v3(-1500, 18, fwStart.pos.Z + 8),
	v3(-1250, FREEWAY_Y, -630),
	v3(-700, FREEWAY_Y, -580),
	v3(0, FREEWAY_Y, -690),
	v3(650, FREEWAY_Y, -600),
	v3(1250, FREEWAY_Y, -690),
	v3(1750, FREEWAY_Y, -650),
	v3(2060, FREEWAY_Y, -650),
	v3(2240, 16, -650),
	AN[-650].pos,
}
local fwPoints = spline(fwCtrl, 22)
for _, p in fwPoints do
	if p.Y < 12 then
		table.insert(FREEWAY_LOW, p)
	end
end
addBase("FWY", fwStart, AN[-650], fwPoints, "freeway", "Harbor Fwy")

-- Superblock styles.
local CELLS = {
	{ 1, 2, 1, 2, "rows" },
	{ 2, 3, 1, 2, "rows" },
	{ 3, 5, 1, 2, "suburb", 3 },
	{ 5, 6, 1, 2, "sunset" },
	{ 6, 7, 1, 2, "industrial" },
	{ 1, 2, 2, 3, "rows" },
	{ 2, 3, 2, 3, "rows" },
	{ 3, 4, 2, 3, "suburb", 2 },
	{ 4, 5, 2, 3, "suburb", 2 },
	{ 5, 6, 2, 3, "suburb", 2 },
	{ 6, 7, 2, 3, "industrial" },
	{ 1, 2, 3, 4, "grid2" },
	{ 2, 3, 3, 4, "crescent" },
	{ 3, 4, 3, 4, "grid2" },
	{ 4, 5, 3, 4, "grid2" },
	{ 5, 6, 3, 4, "crescent" },
	{ 6, 7, 3, 4, "industrial" },
	{ 1, 2, 4, 5, "grid2" },
	{ 2, 3, 4, 5, "grid2" },
	{ 3, 4, 4, 5, "downtown" },
	{ 4, 5, 4, 5, "downtown" },
	{ 5, 6, 4, 5, "crescent" },
	{ 6, 7, 4, 5, "industrial" },
	{ 1, 2, 5, 6, "crescent" },
	{ 2, 3, 5, 6, "grid2" },
	{ 3, 4, 5, 6, "downtown" },
	{ 4, 5, 5, 6, "downtown" },
	{ 5, 6, 5, 6, "grid2" },
	{ 6, 7, 5, 6, "industrial" },
	{ 1, 2, 6, 7, "grid2" },
	{ 2, 3, 6, 7, "crescent" },
	{ 3, 4, 6, 7, "grid2" },
	{ 4, 5, 6, 7, "grid2" },
	{ 5, 6, 6, 7, "grid2" },
	{ 6, 7, 6, 7, "yard" },
	{ 1, 2, 7, 8, "suburb", 2 },
	{ 2, 3, 7, 8, "suburb", 2 },
	{ 3, 4, 7, 8, "suburb", 2 },
	{ 4, 6, 7, 8, "suburb", 3 },
	{ 6, 7, 7, 8, "industrial" },
}
for _, spec in CELLS do
	local c = mainCell(spec[1], spec[2], spec[3], spec[4])
	local style = spec[5]
	if style == "rows" or style == "downtown" then
		gridCell(c, 3, 3, "street")
	elseif style == "grid2" then
		gridCell(c, 2, 2, "street")
	elseif style == "industrial" then
		gridCell(c, 2, 1, "street")
	elseif style == "crescent" then
		crescentCell(c)
	elseif style == "suburb" then
		suburbCell(c, spec[6] or 2)
	elseif style == "sunset" then
		sunsetCell(c)
	end
end
for j = 1, #ZS - 1 do
	beachCell({
		south = { { key = `OC:{j}`, rev = false } },
		north = { { key = `OC:{j + 1}`, rev = false } },
		west = { { key = `O:{j}`, rev = false } },
		east = { { key = `C:1:{j}`, rev = false } },
		sw = O[j].pos,
		se = L[1][j].pos,
		nw = O[j + 1].pos,
		ne = L[1][j + 1].pos,
	})
end

-- ─── finalize: split base edges, wire the graph ───────────────────────────

local function addEdge(
	a: Node,
	b: Node,
	points: { Vector3 },
	w: number,
	kind: string,
	name: string?,
	tag: string?
)
	if a == b or #points < 2 then
		return
	end
	local e: Edge = {
		id = #EDGES + 1,
		a = a,
		b = b,
		points = points,
		w = w,
		kind = kind,
		name = name,
		length = polyLength(points),
		tag = tag,
	}
	table.insert(EDGES, e)
	table.insert(a.edges, e)
	table.insert(b.edges, e)
end

for _, key in BASE_ORDER do
	local b = BASE[key]
	table.sort(b.splits, function(x, y)
		return x.f < y.f
	end)
	local chain = { { f = 0, node = b.a } }
	for _, s in b.splits do
		table.insert(chain, s)
	end
	table.insert(chain, { f = 1, node = b.b })
	for k = 1, #chain - 1 do
		local pts = subPoly(b.points, chain[k].f, chain[k + 1].f)
		pts[1] = chain[k].node.pos
		pts[#pts] = chain[k + 1].node.pos
		addEdge(chain[k].node, chain[k + 1].node, pts, b.w, b.kind, b.name)
	end
end
for _, l in LOCAL do
	addEdge(l.a, l.b, l.points, WIDTH[l.kind], l.kind, l.name, l.tag)
end

-- Unit direction an edge leaves `node` in (flattened).
local function leaving(e: Edge, node: Node): Vector3
	local pts = e.points
	local from, to =
		if e.a == node then pts[1] else pts[#pts], if e.a == node then pts[2] else pts[#pts - 1]
	local d = flat(to) - flat(from)
	return if d.Magnitude > 0 then d.Unit else Vector3.xAxis
end

for _, n in NODES do
	local maxW, wide = 0, 0
	for _, e in n.edges do
		maxW = math.max(maxW, e.w)
		if e.w >= 30 and e.kind ~= "freeway" then
			wide += 1
		end
	end
	local straight = #n.edges == 2 and leaving(n.edges[1], n):Dot(leaving(n.edges[2], n)) < -0.97
	if n.bulb then
		n.gap = 0
	elseif #n.edges >= 3 or (#n.edges == 2 and not straight) then
		n.gap = maxW / 2 + 4
	end
	n.signal = #n.edges >= 4 and wide >= 3 and n.pos.Y < 1
end

-- Signal phase groups. The two approaches that line up best (the straight
-- through road) share a phase, and so does anything parallel to them; every
-- other approach gets the other phase. Grouping by compass direction alone
-- put three legs of a skewed crossing on one phase, so two crossing streams
-- had green at once. Group "A" is the more east-west road.
for _, n in NODES do
	if not n.signal then
		continue
	end
	local bi, bj, best = 1, 2, math.huge
	for i = 1, #n.edges do
		for j = i + 1, #n.edges do
			local d = leaving(n.edges[i], n):Dot(leaving(n.edges[j], n))
			if d < best then
				bi, bj, best = i, j, d
			end
		end
	end
	local axis = leaving(n.edges[bi], n)
	local main = if math.abs(axis.X) >= math.abs(axis.Z) then "A" else "B"
	local cross = if main == "A" then "B" else "A"
	for k, e in n.edges do
		local par = k == bi or k == bj or math.abs(leaving(e, n):Dot(axis)) > 0.9
		n.groups[e.id] = if par then main else cross
	end
end

-- ─── lots and frames ──────────────────────────────────────────────────────

-- Point and unit tangent at distance s along an edge (from `a`).
local function pointAt(e: Edge, s: number): (Vector3, Vector3)
	local f = if e.length > 0 then s / e.length else 0
	local p, seg = pointAtFrac(e.points, f)
	local d = flat(e.points[seg + 1]) - flat(e.points[seg])
	return p, if d.Magnitude > 0 then d.Unit else Vector3.xAxis
end

-- Lot frame beside an edge: origin at the sidewalk's outer edge, +Z pointing
-- away from the road, y = the edge's base height. side 1 = right of a->b.
local function frameAt(e: Edge, s: number, side: number, setback: number?): CFrame
	local p, t = pointAt(e, s)
	local right = Vector3.new(-t.Z, 0, t.X)
	local out = right * side
	local origin = p + out * (e.w / 2 + WALK_W + (setback or 0))
	return CFrame.lookAt(origin, origin + out) * CFrame.Angles(0, math.pi, 0) -- lookAt points -Z at the target; we want +Z away
end

local function findEdge(predicate: (Edge) -> boolean): Edge
	for _, e in EDGES do
		if predicate(e) then
			return e
		end
	end
	error("edge not found")
end

-- Player house lots along Sunset Ln.
local LOTS: { CFrame } = {}
local sunsetEdge = findEdge(function(e)
	return e.tag == "sunset"
end)
for s = 50, sunsetEdge.length - BULB_R - 40, 70 do
	for _, side in { 1, -1 } do
		table.insert(LOTS, frameAt(sunsetEdge, s, side, 4))
	end
end
local _ = SUNSET

for _, cf in LOTS do
	local c = (cf * CFrame.new(0, 0, 40)).Position
	table.insert(RESERVED, { x0 = c.X - 34, x1 = c.X + 34, z0 = c.Z - 40, z1 = c.Z + 40 })
end

-- ─── dumpsters ────────────────────────────────────────────────────────────

export type DumpsterSpot = {
	pos: Vector3,
	zone: string,
	yaw: number,
	pad: string,
	tutorial: boolean?,
	heavy: boolean?,
}

local function buildDumpsters(): { DumpsterSpot }
	local list: { DumpsterSpot } = {
		{
			pos = HIDEOUT + v3(-44, 0, -12),
			zone = "Green",
			yaw = 90,
			pad = "wall",
			tutorial = true,
		},
	}
	for _, d in
		{
			{ -150, 486, 0, "wall" },
			{ -80, 486, 0, "wall" },
			{ 80, 486, 0, "wall" },
			{ 150, 486, 0, "wall" },
			{ -36, 340, 90, "wall" },
			{ -214, 590, 90, "enclosure" },
		}
	do
		table.insert(
			list,
			{ pos = v3(d[1], 0, d[2]) + YARD_OFFSET, zone = "Red", yaw = d[3], pad = d[4] }
		)
	end
	local heavyIn: { [string]: boolean } = {}
	for _, e in EDGES do
		if e.kind == "freeway" or e.length < 110 or (e.id * 37) % 100 >= 34 then
			continue
		end
		local side = if e.id % 2 == 0 then 1 else -1
		local s = e.length * (0.35 + ((e.id * 13) % 30) / 100)
		local frame = frameAt(e, s, side, 7)
		local pos = frame.Position
		local d = district(pos)
		if not d or d.tier == 0 or not onLand(pos) or reserved(pos, 25) then
			continue
		end
		-- The open front (local -Z of the dumpster) faces the street.
		local look = (frame * CFrame.new(0, 0, -1)).Position - pos
		local yaw = math.deg(math.atan2(-look.X, -look.Z))
		local spot: DumpsterSpot = { pos = pos, zone = "Green", yaw = yaw, pad = "enclosure" }
		if
			not heavyIn[d.id] and (d.id == "industrial" or d.id == "docks" or d.id == "downtown")
		then
			heavyIn[d.id] = true
			spot.heavy = true
		end
		table.insert(list, spot)
	end
	return list
end

-- ─── people ───────────────────────────────────────────────────────────────

-- Places where people hang around: bus stops on the arterials, food carts
-- downtown and on the beach, benches in the plaza and the park.
export type Hangout = { kind: string, cf: CFrame, label: string? }
local HANGOUTS: { Hangout } = {}
for _, e in EDGES do
	local d = district((pointAt(e, e.length / 2)))
	if e.kind == "arterial" and e.length > 180 and e.id % 3 == 0 and e.points[1].Y < 1 then
		local cf = frameAt(e, e.length * 0.5, if e.id % 2 == 0 then 1 else -1, -4)
		if onLand(cf.Position) and not reserved(cf.Position, 10) then
			table.insert(HANGOUTS, { kind = "busstop", cf = cf })
		end
	elseif
		d
		and (d.id == "downtown" or d.id == "beach")
		and e.kind == "street"
		and e.id % 2 == 0
	then
		local cf = frameAt(e, e.length * 0.3, 1, -6)
		if onLand(cf.Position) and not reserved(cf.Position, 10) then
			table.insert(HANGOUTS, { kind = "foodcart", cf = cf })
		end
	end
end
for _, r in { PLAZA, PARK } do
	for k = 0, 3 do
		local x = r.x0 + 20 + k * (r.x1 - r.x0 - 40) / 3
		table.insert(HANGOUTS, { kind = "bench", cf = CFrame.new(x, 0.3, r.z0 + 14) })
	end
end

-- Street vendors: food carts and stands on the curb with the vendor beside
-- them, like a big American downtown (hot dog and halal carts, a taco stand,
-- a neon noodle bar). The streets around the Hideout get them first, so the
-- first blocks a new player walks are busy; the rest spread over the city.
-- The stall sits between the curb and the walking line (frame origin on the
-- curb, +Z toward the shops), so walkers pass in front of it.
local VENDOR_KINDS =
	{ "hotdog", "tacos", "halal", "pretzel", "coffee", "news", "icecream", "noodles" }
local VENDOR_NAMES = {
	hotdog = "Hot Dogs",
	tacos = "Tacos",
	halal = "Halal Food",
	pretzel = "Pretzels",
	coffee = "Coffee",
	news = "Newsstand",
	icecream = "Ice Cream",
	noodles = "Noodle Bar",
}
local VENDOR_AREAS = {
	downtown = true,
	midtown = true,
	southside = true,
	eastgate = true,
	beach = true,
	oldport = true,
}
local MAX_VENDORS = 48
local VENDOR_NEAR = 520 -- studs from the Hideout
local NEAR_VENDORS = 20 -- of MAX_VENDORS, placed around the Hideout first
do
	local count = 0
	local function addVendor(e: Edge, f: number, side: number)
		if count >= MAX_VENDORS then
			return
		end
		local cf = frameAt(e, e.length * f, side, -WALK_W)
		if not onLand(cf.Position) or reserved(cf.Position, 12) then
			return
		end
		count += 1
		local label = VENDOR_KINDS[(e.id + count) % #VENDOR_KINDS + 1]
		table.insert(HANGOUTS, { kind = "vendor", cf = cf, label = label })
	end
	local near, far = {}, {}
	for _, e in EDGES do
		if
			e.kind == "freeway"
			or e.kind == "court"
			or e.kind == "hill"
			or e.length < 110
			or e.points[1].Y > 1
		then
			continue
		end
		local mid = pointAt(e, e.length / 2)
		local d = district(mid)
		if not d or not VENDOR_AREAS[d.id] then
			continue
		end
		if (flat(mid) - flat(HIDEOUT)).Magnitude < VENDOR_NEAR then
			table.insert(near, e)
		else
			table.insert(far, e)
		end
	end
	local function fromHideout(e: Edge): number
		return (flat((pointAt(e, e.length / 2))) - flat(HIDEOUT)).Magnitude
	end
	table.sort(near, function(a, b)
		return fromHideout(a) < fromHideout(b)
	end)
	for k, e in near do
		if count >= NEAR_VENDORS then
			break
		end
		addVendor(e, 0.66, -1)
		if k <= 8 then
			addVendor(e, 0.36, 1)
		end
	end
	-- Spread the rest evenly over the remaining streets.
	local step = math.max(1, math.ceil(#far / math.max(1, MAX_VENDORS - count)))
	for k = 1, #far, step do
		addVendor(far[k], 0.66, -1)
	end
end

-- Sidewalk paths for walkers: both sides of every street, trimmed at corners.
local SIDEWALKS: { { Vector3 } } = {}
for _, e in EDGES do
	if e.kind == "freeway" or e.length < 50 then
		continue
	end
	for _, side in { -1, 1 } do
		local path = {}
		local s0 = e.a.gap + 8
		local s1 = e.length - e.b.gap - 8
		local s = s0
		while s <= s1 do
			local p, t = pointAt(e, s)
			local right = Vector3.new(-t.Z, 0, t.X)
			table.insert(path, p + right * side * (e.w / 2 + WALK_W / 2) + v3(0, SURFACE, 0))
			s += 16
		end
		if #path >= 3 and onLand(path[1]) and onLand(path[#path]) then
			table.insert(SIDEWALKS, path)
		end
	end
end

-- ─── module ───────────────────────────────────────────────────────────────

local CityPlan = {}

CityPlan.WALK_W = WALK_W
CityPlan.SURFACE = SURFACE
CityPlan.BULB_R = BULB_R
CityPlan.NODES = NODES
CityPlan.EDGES = EDGES
CityPlan.DISTRICTS = DISTRICTS
CityPlan.LAND = LAND
CityPlan.WATER = WATER
CityPlan.PLAZA = PLAZA
CityPlan.PARK = PARK
CityPlan.BOUNDS = { x0 = -2700, x1 = 2900, z0 = -2150, z1 = 2150 }
CityPlan.HIDEOUT = HIDEOUT
CityPlan.LOCKUP = LOCKUP
CityPlan.RED_CENTER = RED_CENTER
CityPlan.YARD_ORIGIN = YARD_ORIGIN
CityPlan.YARD_OFFSET = YARD_OFFSET
CityPlan.STORE_LOTS = STORE_LOTS
CityPlan.LOTS = LOTS
CityPlan.HANGOUTS = HANGOUTS
CityPlan.VENDOR_NAMES = VENDOR_NAMES
CityPlan.SIDEWALKS = SIDEWALKS
CityPlan.CONTACTS = CONTACTS
CityPlan.GIVERS = GIVERS
CityPlan.hillY = hillY
CityPlan.groundY = hillY
CityPlan.oceanX = oceanX
CityPlan.sandEdge = sandEdge
CityPlan.district = district
CityPlan.onLand = onLand
CityPlan.reserved = reserved
CityPlan.pointAt = pointAt
CityPlan.frameAt = frameAt
CityPlan.leaving = leaving
CityPlan.polyLength = polyLength

function CityPlan.storeCounter(id: string): Vector3
	local p = (STORE_LOTS[id] * CFrame.new(0, 0, STORE_COUNTER_DEPTH)).Position
	return Vector3.new(p.X, 0, p.Z)
end

-- Nearest node (by flat distance) to a position.
function CityPlan.nearestNode(pos: Vector3): Node
	local best, bestD = NODES[1], math.huge
	for _, n in NODES do
		if #n.edges > 0 then
			local d = (flat(n.pos) - flat(pos)).Magnitude
			if d < bestD then
				best, bestD = n, d
			end
		end
	end
	return best
end

-- Shortest road route (list of nodes) between two positions.
function CityPlan.route(from: Vector3, to: Vector3): { Node }
	local start, goal = CityPlan.nearestNode(from), CityPlan.nearestNode(to)
	local dist: { [Node]: number } = { [start] = 0 }
	local prev: { [Node]: Node } = {}
	local open: { Node } = { start }
	local closed: { [Node]: boolean } = {}
	while #open > 0 do
		local bi = 1
		for k = 2, #open do
			if dist[open[k]] < dist[open[bi]] then
				bi = k
			end
		end
		local n = table.remove(open, bi) :: Node
		if n == goal then
			break
		end
		closed[n] = true
		for _, e in n.edges do
			local m = if e.a == n then e.b else e.a
			if not closed[m] then
				local d = dist[n] + e.length
				if dist[m] == nil or d < dist[m] then
					if dist[m] == nil then
						table.insert(open, m)
					end
					dist[m] = d
					prev[m] = n
				end
			end
		end
	end
	local path = { goal }
	local cur = goal
	while prev[cur] do
		cur = prev[cur]
		table.insert(path, 1, cur)
	end
	return path
end

-- The edge joining two adjacent nodes.
function CityPlan.edgeBetween(a: Node, b: Node): Edge?
	for _, e in a.edges do
		if e.b == b or e.a == b then
			return e
		end
	end
	return nil
end

-- ─── traffic signals ──────────────────────────────────────────────────────
-- One clock drives every signal in the city (the lamps, client traffic and
-- the walkers at crosswalks): group A green, amber, a short all-red so the
-- junction clears, then the same for group B.
local SIGNAL_GREEN, SIGNAL_AMBER, SIGNAL_CLEAR = 12, 3, 2
local SIGNAL_HALF = SIGNAL_GREEN + SIGNAL_AMBER + SIGNAL_CLEAR
CityPlan.SIGNAL_CYCLE = SIGNAL_HALF * 2

-- "green" | "amber" | "red" for a phase group at time t (use the server
-- clock), and the seconds that state still lasts.
function CityPlan.signalState(group: string, t: number): (string, number)
	local c = t % (SIGNAL_HALF * 2)
	local active = if c < SIGNAL_HALF then "A" else "B"
	local k = c % SIGNAL_HALF
	if group ~= active then
		return "red", SIGNAL_HALF - k
	elseif k < SIGNAL_GREEN then
		return "green", SIGNAL_GREEN - k
	elseif k < SIGNAL_GREEN + SIGNAL_AMBER then
		return "amber", SIGNAL_GREEN + SIGNAL_AMBER - k
	end
	return "red", SIGNAL_HALF * 2 - k
end

-- Phase group of the traffic arriving at signal node `n` along edge `e`.
function CityPlan.signalGroup(n: Node, e: Edge): string
	return n.groups[e.id] or "A"
end

-- A person crossing at `n` while walking along `dir` may go when the traffic
-- running beside them (parallel to `dir`) has green.
function CityPlan.crossingGroup(n: Node, dir: Vector3): string
	local best, bestDot = nil :: Edge?, -1
	for _, e in n.edges do
		local d = math.abs(leaving(e, n):Dot(flat(dir).Unit))
		if d > bestDot then
			best, bestDot = e, d
		end
	end
	return if best then CityPlan.signalGroup(n, best) else "A"
end

-- Spatial index of road segments (100-stud cells) for fast "how far from the
-- asphalt is this point" queries (trees, props, lot checks).
local CELL = 100
local BULBS = {}
for _, n in NODES do
	if n.bulb then
		table.insert(BULBS, n)
	end
end
local segGrid: { [string]: { { a: Vector3, b: Vector3, half: number } } } = {}
for _, e in EDGES do
	for k = 2, #e.points do
		local a, b = flat(e.points[k - 1]), flat(e.points[k])
		local seg = { a = a, b = b, half = e.w / 2 }
		local x0, x1 =
			math.floor(math.min(a.X, b.X) / CELL) - 1, math.floor(math.max(a.X, b.X) / CELL) + 1
		local z0, z1 =
			math.floor(math.min(a.Z, b.Z) / CELL) - 1, math.floor(math.max(a.Z, b.Z) / CELL) + 1
		for gx = x0, x1 do
			for gz = z0, z1 do
				local key = gx .. "," .. gz
				segGrid[key] = segGrid[key] or {}
				table.insert(segGrid[key], seg)
			end
		end
	end
end

-- Distance from a point to the nearest asphalt edge (negative on the asphalt).
function CityPlan.clearance(pos: Vector3): number
	local p = flat(pos)
	local list = segGrid[math.floor(p.X / CELL) .. "," .. math.floor(p.Z / CELL)]
	local best = math.huge
	for _, seg in list or {} do
		local ab = seg.b - seg.a
		local t = if ab.Magnitude > 0 then math.clamp((p - seg.a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		local d = (p - (seg.a + ab * t)).Magnitude - seg.half
		if d < best then
			best = d
		end
	end
	for _, n in BULBS do
		local d = (p - flat(n.pos)).Magnitude - BULB_R
		if d < best then
			best = d
		end
	end
	return best
end

CityPlan.DUMPSTERS = buildDumpsters()

-- Guard patrol points of the yard (designed around YARD_ORIGIN).
local guard = {}
for _, p in
	{
		{ 0, 358 },
		{ -120, 364 },
		{ 120, 364 },
		{ -212, 384 },
		{ 212, 384 },
		{ 0, 440 },
		{ -214, 446 },
		{ 214, 446 },
		{ -160, 512 },
		{ -60, 516 },
		{ 60, 516 },
		{ 160, 512 },
		{ 0, 562 },
		{ -200, 576 },
		{ 200, 576 },
	}
do
	table.insert(guard, v3(p[1], 0, p[2]) + YARD_OFFSET)
end
CityPlan.GUARD_POINTS = guard

function CityPlan.selfCheck()
	assert(#CityPlan.DUMPSTERS > 60, `only {#CityPlan.DUMPSTERS} dumpsters`)
	for _, d in CityPlan.DUMPSTERS do
		assert(onLand(d.pos), `dumpster in the water at {d.pos}`)
	end
	assert(#LOTS >= 8, `only {#LOTS} house lots`)
	-- Every road can be reached from the Hideout.
	local seen = {}
	local queue = { CityPlan.nearestNode(HIDEOUT) }
	seen[queue[1]] = true
	while #queue > 0 do
		local n = table.remove(queue) :: Node
		for _, e in n.edges do
			local m = if e.a == n then e.b else e.a
			if not seen[m] then
				seen[m] = true
				table.insert(queue, m)
			end
		end
	end
	for _, n in NODES do
		assert(#n.edges == 0 or seen[n], `road node {n.id} at {n.pos} is cut off`)
	end
	local _ = CityPlan.route(HIDEOUT, LOCKUP)
end

return CityPlan
