--!strict
-- The city layout, shared by every system that needs to know where things
-- are: the server builds it, the client map draws it, traffic and walkers
-- move on it, Config reads landmark positions from it. North is +Z.
-- See docs/superpowers/specs/2026-11-05-city-rebuild-design.md.

export type Road = {
	axis: string, -- "X" runs east-west at z = at; "Z" runs north-south at x = at
	at: number,
	from: number,
	to: number,
	w: number, -- asphalt width
	y0: number, -- deck height at `from`
	y1: number, -- deck height at `to`
	kind: string, -- "street" (curbs, sidewalks) or "freeway" (barriers, pillars)
	name: string?,
}
export type Rect = { x0: number, x1: number, z0: number, z1: number }
export type District = {
	id: string,
	name: string,
	tier: number, -- 0: no dumpsters
	boost: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	city: string?, -- nil means Maple (mainland)
	note: string?,
}

local WALK_W = 10
local ART = 34 -- arterial width
local LOC = 24 -- local street width
local HILL_Y = 40
local FREEWAY_Y = 36

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- ─── roads ────────────────────────────────────────────────────────────────

local ROADS: { Road } = {}

local function street(
	axis: string,
	at: number,
	from: number,
	to: number,
	w: number,
	name: string?,
	y: number?
)
	table.insert(ROADS, {
		axis = axis,
		at = at,
		from = from,
		to = to,
		w = w,
		y0 = y or 0,
		y1 = y or 0,
		kind = "street",
		name = name,
	})
end

local function sloped(
	axis: string,
	at: number,
	from: number,
	to: number,
	w: number,
	y0: number,
	y1: number,
	kind: string,
	name: string?
)
	table.insert(ROADS, {
		axis = axis,
		at = at,
		from = from,
		to = to,
		w = w,
		y0 = y0,
		y1 = y1,
		kind = kind,
		name = name,
	})
end

-- Mainland arterials.
for _, r in
	{
		{ -1800, "Southern Ave" },
		{ -1350, "Palm St" },
		{ -900, "Mission St" },
		{ -400, "Grand Ave" },
		{ 0, "Main St" },
		{ 400, "Neon Blvd" },
		{ 800, "Sunset Blvd" },
		{ 1150, "Hillside Ave" },
	}
do
	street("X", r[1], -2100, 1700, ART, r[2])
end
for _, r in
	{
		{ -2100, "Ocean Dr" },
		{ -1700, "Bay Rd" },
		{ -1100, "Union St" },
		{ -500, "Center St" },
		{ 60, "Broadway" },
		{ 600, "Lake St" },
		{ 1100, "Foundry Rd" },
		{ 1700, "Harbor Rd" },
	}
do
	street("Z", r[1], -1800, 1150, ART, r[2])
end
-- Local streets make the blocks small and dense.
for _, z in { -1575, -1125 } do
	street("X", z, -2100, 1700, LOC)
end
for _, z in { -200, 200, 600, 975 } do
	street("X", z, -2100, 1100, LOC)
end
for _, x in { -1900, -1400, -800, -220, 330, 850 } do
	street("Z", x, -1800, 1150, LOC)
end
-- Foundry Ln stops short of the Meridian yard.
street("Z", 1400, -1800, 400, LOC, "Foundry Ln")
street("Z", 1400, 800, 1150, LOC)

-- Vista Hills: a ramp up to the plateau, then a small loop of streets on top.
sloped("Z", -500, 1150, 1450, ART, 0, HILL_Y, "street", "Vista Dr")
street("X", 1450, -1600, 800, LOC, "Crest Rd", HILL_Y)
street("X", 1750, -1600, 800, LOC, "Summit Rd", HILL_Y)
for _, x in { -1600, -1100, 60, 600, 800 } do
	street("Z", x, 1450, 1750, LOC, nil, HILL_Y)
end
street("Z", -500, 1450, 1950, LOC, nil, HILL_Y)

-- Freeway: up from Bay Rd, across the city and the channel bridge, down onto the island.
sloped("X", -650, -1700, -1350, 30, 0, FREEWAY_Y, "freeway", "Harbor Fwy")
sloped("X", -650, -1350, 2050, 30, FREEWAY_Y, FREEWAY_Y, "freeway", "Harbor Fwy")
sloped("X", -650, 2050, 2350, 30, FREEWAY_Y, 0, "freeway", "Harbor Fwy")

-- Port Haven island.
street("Z", 2100, -1100, 1100, LOC, "Bay St")
street("Z", 2350, -1100, 1100, ART, "Anchor Ave")
street("Z", 2580, -1100, 1100, LOC, "Pier Rd")
for _, z in { -900, -300, 0, 300, 900 } do
	street("X", z, 2100, 2580, LOC, if z == 0 then "Wharf Rd" else nil)
end

-- ─── districts, land and water ────────────────────────────────────────────

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
		x0 = -1750,
		x1 = 900,
		z0 = 1200,
		z1 = 2050,
	},
	{
		id = "beach",
		name = "Westshore",
		tier = 2,
		boost = 0.35,
		x0 = -2300,
		x1 = -1700,
		z0 = -2000,
		z1 = 1200,
	},
	{
		id = "industrial",
		name = "Industrial Park",
		tier = 5,
		boost = 1.6,
		x0 = 1100,
		x1 = 1800,
		z0 = -2000,
		z1 = 1200,
	},
	{
		id = "southside",
		name = "Southside",
		tier = 1,
		boost = 0,
		x0 = -1700,
		x1 = -300,
		z0 = -2000,
		z1 = -900,
	},
	{
		id = "eastgate",
		name = "Eastgate",
		tier = 1,
		boost = 0.2,
		x0 = -300,
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
		z1 = 1200,
	},
	{
		id = "oldport",
		name = "Old Port",
		city = "port",
		tier = 3,
		boost = 0.7,
		x0 = 1990,
		x1 = 2350,
		z0 = -1300,
		z1 = 1300,
	},
	{
		id = "docks",
		name = "The Docks",
		city = "port",
		tier = 5,
		boost = 1.4,
		x0 = 2350,
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
	{ x0 = -2900, x1 = -2250, z0 = -2400, z1 = 2400 },
	{ x0 = 1800, x1 = 2000, z0 = -2400, z1 = 2400 },
	{ x0 = 2000, x1 = 2680, z0 = -2400, z1 = -1300 },
	{ x0 = 2000, x1 = 2680, z0 = 1300, z1 = 2400 },
	{ x0 = 2680, x1 = 3200, z0 = -2400, z1 = 2400 },
}
-- Sand between the ocean and Ocean Dr's sidewalk.
local BEACH: Rect = { x0 = -2250, x1 = -2127, z0 = -1950, z1 = 1950 }
-- The hills plateau, with the Vista Dr gorge cut through its southern edge.
local PLATEAU = {
	height = HILL_Y,
	x0 = -1750,
	x1 = 900,
	z0 = 1250,
	z1 = 2050,
	gorge = { x0 = -525, x1 = -475, z1 = 1450 },
}

-- ─── landmarks ────────────────────────────────────────────────────────────

local HIDEOUT = v3(-950, 0, -1040) -- faces south onto the z = -1125 street
local LOCKUP = v3(2200, 0, 75) -- Harbor Lockup, faces south onto Wharf Rd
-- The Meridian yard was designed around (0, 0, 465); its builder and guard
-- points are shifted by this offset.
local YARD_ORIGIN = v3(0, 0, 465)
local RED_CENTER = v3(1400, 0, 600)
local YARD_OFFSET = RED_CENTER - YARD_ORIGIN

local function roadNamed(axis: string, at: number): Road
	for _, r in ROADS do
		if r.axis == axis and r.at == at and r.kind == "street" then
			return r
		end
	end
	error(`no {axis} road at {at}`)
end

-- Lot frame on a road side: origin at the sidewalk edge, +Z pointing away
-- from the road, at the road's height.
local function lotFrame(road: Road, along: number, side: number): CFrame
	local edge = road.w / 2 + WALK_W
	local y = road.y0
		+ (road.y1 - road.y0) * math.clamp((along - road.from) / (road.to - road.from), 0, 1)
	if road.axis == "X" then
		return CFrame.new(along, y, road.at + side * edge)
			* CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
	end
	return CFrame.new(road.at + side * edge, y, along)
		* CFrame.Angles(0, math.rad(if side > 0 then 90 else -90), 0)
end

-- Store lots: the building is entered from the street; the counter is inside.
local STORE_LOTS = {
	hardware = lotFrame(roadNamed("X", -1125), -1250, 1),
	motors = lotFrame(roadNamed("X", -1125), -650, 1),
	realty = lotFrame(roadNamed("X", -1350), 470, -1),
	harbor = lotFrame(roadNamed("Z", 2350), 200, -1),
	bayside = lotFrame(roadNamed("Z", 2350), -150, -1),
}
local STORE_COUNTER_DEPTH = 32

-- Player house lots on Sunset Ln (the z = -1575 street in Eastgate).
local LOTS: { CFrame } = {}
for _, x in { 122, 192, 262, 387, 457, 527 } do
	for _, side in { 1, -1 } do
		table.insert(LOTS, lotFrame(roadNamed("X", -1575), x, side) * CFrame.new(0, 0, 4))
	end
end

local PLAZA: Rect = { x0 = 87, x1 = 308, z0 = 27, z1 = 178 } -- Downtown civic plaza
local PARK: Rect = { x0 = -1078, x1 = -822, z0 = 622, z1 = 778 } -- Midtown park

-- Land kept free of infill buildings.
local RESERVED: { Rect } = {
	PLAZA,
	PARK,
	{ x0 = HIDEOUT.X - 80, x1 = HIDEOUT.X + 80, z0 = HIDEOUT.Z - 70, z1 = HIDEOUT.Z + 60 },
	{ x0 = LOCKUP.X - 50, x1 = LOCKUP.X + 50, z0 = LOCKUP.Z - 60, z1 = LOCKUP.Z + 40 },
	{
		x0 = RED_CENTER.X - 270,
		x1 = RED_CENTER.X + 270,
		z0 = RED_CENTER.Z - 175,
		z1 = RED_CENTER.Z + 175,
	},
	BEACH,
}
for _, cf in STORE_LOTS do
	local c = (cf * CFrame.new(0, 0, 30)).Position
	table.insert(RESERVED, { x0 = c.X - 42, x1 = c.X + 42, z0 = c.Z - 42, z1 = c.Z + 42 })
end
for _, cf in LOTS do
	local c = (cf * CFrame.new(0, 0, 40)).Position
	table.insert(RESERVED, { x0 = c.X - 36, x1 = c.X + 36, z0 = c.Z - 42, z1 = c.Z + 42 })
end

local function inRect(r: Rect, x: number, z: number): boolean
	return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1
end

-- ─── helpers ──────────────────────────────────────────────────────────────

local CityPlan = {}

CityPlan.WALK_W = WALK_W
CityPlan.ROADS = ROADS
CityPlan.DISTRICTS = DISTRICTS
CityPlan.LAND = LAND
CityPlan.WATER = WATER
CityPlan.BEACH = BEACH
CityPlan.PLATEAU = PLATEAU
CityPlan.PLAZA = PLAZA
CityPlan.PARK = PARK
CityPlan.BOUNDS = { x0 = -2700, x1 = 2900, z0 = -2050, z1 = 2100 }
CityPlan.HIDEOUT = HIDEOUT
CityPlan.LOCKUP = LOCKUP
CityPlan.RED_CENTER = RED_CENTER
CityPlan.YARD_ORIGIN = YARD_ORIGIN
CityPlan.YARD_OFFSET = YARD_OFFSET
CityPlan.STORE_LOTS = STORE_LOTS
CityPlan.LOTS = LOTS
CityPlan.lotFrame = lotFrame

function CityPlan.storeCounter(id: string): Vector3
	local p = (STORE_LOTS[id] * CFrame.new(0, 0, STORE_COUNTER_DEPTH)).Position
	return Vector3.new(p.X, 0, p.Z)
end

function CityPlan.roadY(road: Road, along: number): number
	local t = math.clamp((along - road.from) / (road.to - road.from), 0, 1)
	return road.y0 + (road.y1 - road.y0) * t
end

function CityPlan.district(pos: Vector3): District?
	for _, d in DISTRICTS do
		if inRect(d :: any, pos.X, pos.Z) then
			return d
		end
	end
	return nil
end

function CityPlan.onLand(pos: Vector3): boolean
	for _, r in LAND do
		if inRect(r, pos.X, pos.Z) then
			return not inRect(BEACH, pos.X, pos.Z)
		end
	end
	return false
end

function CityPlan.reserved(pos: Vector3, pad: number?): boolean
	local p = pad or 0
	for _, r in RESERVED do
		if pos.X >= r.x0 - p and pos.X <= r.x1 + p and pos.Z >= r.z0 - p and pos.Z <= r.z1 + p then
			return true
		end
	end
	return false
end

-- Ground height of the plateau (hills) or 0.
function CityPlan.groundY(pos: Vector3): number
	local p = PLATEAU
	if pos.X >= p.x0 and pos.X <= p.x1 and pos.Z >= p.z0 and pos.Z <= p.z1 then
		local g = p.gorge
		if pos.X > g.x0 and pos.X < g.x1 and pos.Z < g.z1 then
			return 0
		end
		return p.height
	end
	return 0
end

-- Where perpendicular roads meet this one at the same height, sorted.
function CityPlan.crossings(road: Road): { number }
	local out = {}
	for _, other in ROADS do
		if
			other.axis ~= road.axis
			and other.at >= road.from - 1
			and other.at <= road.to + 1
			and road.at >= other.from - 1
			and road.at <= other.to + 1
			and math.abs(CityPlan.roadY(road, other.at) - CityPlan.roadY(other, road.at)) < 1
		then
			table.insert(out, other.at)
		end
	end
	table.sort(out)
	return out
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
		-- Next to the Hideout, for the first search.
		{
			pos = HIDEOUT + v3(-36, 0, -10),
			zone = "Green",
			yaw = 90,
			pad = "wall",
			tutorial = true,
		},
	}
	-- Meridian yard: by the dock doors, the guard booth and the back fence.
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
	-- One spot on some street segments, in a gap between the buildings.
	local heavyIn: { [string]: boolean } = {}
	for ri, road in ROADS do
		if road.kind ~= "street" or road.y0 ~= road.y1 then
			continue
		end
		local stops = CityPlan.crossings(road)
		table.insert(stops, 1, road.from)
		table.insert(stops, road.to)
		for i = 1, #stops - 1 do
			local a, b = stops[i], stops[i + 1]
			if b - a < 130 or (ri * 7 + i * 13) % 100 >= 30 then
				continue
			end
			local side = if (ri + i) % 2 == 0 then 1 else -1
			local mid = (a + b) / 2
			local frame = lotFrame(road, mid, side) * CFrame.new(0, 0, 7)
			local pos = frame.Position
			local district = CityPlan.district(pos)
			if
				not district
				or district.tier == 0
				or not CityPlan.onLand(pos)
				or CityPlan.reserved(pos, 20)
			then
				continue
			end
			-- Open front (local -Z of the dumpster) faces the street.
			local yaw = if road.axis == "X"
				then (if side > 0 then 0 else 180)
				else (if side > 0 then 90 else -90)
			local spot: DumpsterSpot = { pos = pos, zone = "Green", yaw = yaw, pad = "enclosure" }
			if
				not heavyIn[district.id]
				and (
					district.id == "industrial"
					or district.id == "docks"
					or district.id == "downtown"
				)
			then
				heavyIn[district.id] = true
				spot.heavy = true
			end
			table.insert(list, spot)
		end
	end
	return list
end

CityPlan.DUMPSTERS = buildDumpsters()

-- ─── people and points of interest ────────────────────────────────────────

CityPlan.GIVERS = {
	earl = { pos = v3(-870, 0, -1108), yaw = 180 },
	rosa = { pos = v3(-420, 0, -183), yaw = 0 },
	vic = { pos = v3(1200, 0, 378), yaw = 180 },
	mae = { pos = v3(2420, 0, 17), yaw = 180 },
}

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
	assert(#CityPlan.DUMPSTERS > 40, `only {#CityPlan.DUMPSTERS} dumpsters`)
	for _, d in CityPlan.DUMPSTERS do
		assert(CityPlan.onLand(d.pos), `dumpster in the water at {d.pos}`)
	end
	for _, r in ROADS do
		assert(r.to > r.from, "road runs backwards")
	end
	assert(
		CityPlan.district(HIDEOUT) and (CityPlan.district(HIDEOUT) :: District).id == "southside",
		"hideout moved"
	)
end

return CityPlan
