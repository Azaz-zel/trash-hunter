--!strict
-- Builds the road network from CityPlan's graph.
-- - Streets follow their polylines (bends, hill climbs, cul-de-sacs).
-- - Sidewalks sit flush beside the asphalt, so cars never snag on a step.
-- - Intersections get a round asphalt pad and concrete corners, crosswalks
--   and either traffic lights (busy crossings) or stop signs.
-- - The freeway is an elevated deck on pillars, with a suspension bridge
--   over open water.
--
-- Layering (top heights above a road's base), lowest first: edge asphalt
-- 0.20, corner concrete 0.205, sidewalk 0.24, junction asphalt 0.22, then
-- markings 0.23.

local CityPlan = require(game:GetService("ReplicatedStorage").Shared.CityPlan)

type Kit = any
type Edge = CityPlan.Edge
type Node = CityPlan.Node

local WALK_W = CityPlan.WALK_W
local THICK = 2 -- road parts extend down so hill roads never float over terrain

local Roads = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A slab whose top is `top` studs above the segment a->b, offset sideways.
local function strip(
	k: Kit,
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	top: number,
	offset: number,
	color: Color3,
	material: Enum.Material,
	collide: boolean?
): Part?
	local d = b - a
	if flat(d).Magnitude < 0.5 then
		return nil
	end
	local cf = CFrame.lookAt(a, b)
	local right = cf.RightVector
	local mid = (a + b) / 2 + right * offset
	local len = d.Magnitude
	return k.part(parent, {
		Name = name,
		Size = Vector3.new(width, THICK, len + 0.6),
		CFrame = CFrame.lookAt(mid, mid + d) * CFrame.new(0, top - THICK / 2, 0),
		Color = color,
		Material = material,
		CanCollide = if collide == nil then true else collide,
		TopSurface = Enum.SurfaceType.Smooth,
	})
end

local function disc(
	k: Kit,
	parent: Instance,
	name: string,
	center: Vector3,
	radius: number,
	top: number,
	color: Color3,
	material: Enum.Material
)
	k.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(THICK, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, top - THICK / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

-- The polyline between arc lengths s0 and s1 (both clamped to the edge).
local function slice(e: Edge, s0: number, s1: number): { Vector3 }
	local out = {}
	if s1 <= s0 then
		return out
	end
	table.insert(out, (CityPlan.pointAt(e, s0)))
	local acc = 0
	for k = 2, #e.points do
		acc += (flat(e.points[k]) - flat(e.points[k - 1])).Magnitude
		if acc > s0 + 0.5 and acc < s1 - 0.5 then
			table.insert(out, e.points[k])
		end
	end
	table.insert(out, (CityPlan.pointAt(e, s1)))
	return out
end

local function isJunction(n: Node): boolean
	return n.gap > 0 and not n.bulb
end

local function buildStreet(k: Kit, parent: Instance, e: Edge)
	local C, M = k.C, k.M
	local w = e.w
	-- Asphalt runs to the node centres (junction pads cover the overlap).
	for i = 2, #e.points do
		strip(k, parent, "Road", e.points[i - 1], e.points[i], w, 0.2, 0, C.asphalt, M.Asphalt)
	end
	-- Sidewalks and curbs stop where the junction's concrete corner begins.
	local s0 = if e.a.bulb then 0 elseif isJunction(e.a) then e.a.gap else 0
	local s1 = e.length - (if e.b.bulb then 0 elseif isJunction(e.b) then e.b.gap else 0)
	local walk = slice(e, s0, s1)
	for i = 2, #walk do
		for _, side in { -1, 1 } do
			strip(
				k,
				parent,
				"Sidewalk",
				walk[i - 1],
				walk[i],
				WALK_W,
				0.24,
				side * (w / 2 + WALK_W / 2),
				C.concrete,
				M.Concrete
			)
			strip(
				k,
				parent,
				"Curb",
				walk[i - 1],
				walk[i],
				0.6,
				0.38,
				side * (w / 2 + 0.3),
				Color3.fromRGB(196, 194, 188),
				M.Concrete,
				false
			)
		end
	end
	-- Lane markings between the junctions.
	local m0 = (if isJunction(e.a) then e.a.gap else 0) + 2
	local m1 = e.length - (if isJunction(e.b) then e.b.gap else 0) - 2
	if e.b.bulb then
		m1 = e.length - CityPlan.BULB_R - 2
	end
	local marks = slice(e, m0, m1)
	if e.kind == "arterial" or e.kind == "hill" then
		for i = 2, #marks do
			for _, off in { -0.35, 0.35 } do
				strip(
					k,
					parent,
					"CenterLine",
					marks[i - 1],
					marks[i],
					0.3,
					0.23,
					off,
					C.lineYellow,
					M.SmoothPlastic,
					false
				)
			end
			if w >= 30 then
				for _, side in { -1, 1 } do
					strip(
						k,
						parent,
						"EdgeLine",
						marks[i - 1],
						marks[i],
						0.3,
						0.23,
						side * (w / 2 - 1.5),
						C.lineWhite,
						M.SmoothPlastic,
						false
					)
				end
			end
		end
	elseif m1 - m0 > 10 then
		-- Dashed centre line on local streets.
		local s = m0
		while s + 6 < m1 do
			local a = CityPlan.pointAt(e, s)
			local b = CityPlan.pointAt(e, s + 6)
			strip(
				k,
				parent,
				"CenterDash",
				a,
				b,
				0.3,
				0.23,
				0,
				if e.kind == "collector" then C.lineYellow else C.lineWhite,
				M.SmoothPlastic,
				false
			)
			s += 14
		end
	end
	-- Crosswalks just outside each junction.
	for _, endA in { true, false } do
		local n = if endA then e.a else e.b
		if isJunction(n) and #n.edges >= 3 and e.length > n.gap * 2 + 20 then
			local s = if endA then n.gap + 3 else e.length - n.gap - 3
			local p, t = CityPlan.pointAt(e, s)
			local right = Vector3.new(-t.Z, 0, t.X)
			local stripes = math.floor(w / 3)
			for q = 0, stripes - 1 do
				local off = -w / 2 + 1.5 + q * 3
				local c = p + right * off
				k.part(parent, {
					Name = "Crosswalk",
					Size = Vector3.new(1.6, 0.05, 6),
					CFrame = CFrame.lookAt(c, c + t) * CFrame.new(0, 0.23, 0),
					Color = C.lineWhite,
					CanCollide = false,
				})
			end
		end
	end
end

-- Elevated deck along the edge's polyline: barriers, neon strips, pillars,
-- and towers with cables where it crosses open water.
local function buildDeck(k: Kit, parent: Instance, e: Edge)
	local C, M = k.C, k.M
	local w = e.w
	local function overWater(p: Vector3): boolean
		for _, r in CityPlan.WATER do
			if p.X > r.x0 and p.X < r.x1 and p.Z > r.z0 and p.Z < r.z1 then
				return true
			end
		end
		return false
	end
	for i = 2, #e.points do
		local a, b = e.points[i - 1], e.points[i]
		strip(k, parent, "Road", a, b, w, 0.2, 0, C.asphalt, M.Asphalt)
		for _, side in { -1, 1 } do
			strip(
				k,
				parent,
				"Barrier",
				a + Vector3.new(0, 1.6, 0),
				b + Vector3.new(0, 1.6, 0),
				1.2,
				1.4,
				side * (w / 2 + 0.6),
				C.concrete,
				M.Concrete
			)
			local neon = strip(
				k,
				parent,
				"NeonStrip",
				a + Vector3.new(0, 3.1, 0),
				b + Vector3.new(0, 3.1, 0),
				0.3,
				0.1,
				side * (w / 2 + 0.6),
				Color3.fromRGB(0, 220, 255),
				M.Neon,
				false
			)
			if neon then
				neon.CastShadow = false
			end
			strip(
				k,
				parent,
				"EdgeLine",
				a,
				b,
				0.3,
				0.23,
				side * (w / 2 - 1.5),
				C.lineWhite,
				M.SmoothPlastic,
				false
			)
		end
		for _, off in { -0.35, 0.35 } do
			strip(
				k,
				parent,
				"CenterLine",
				a,
				b,
				0.3,
				0.23,
				off,
				C.lineYellow,
				M.SmoothPlastic,
				false
			)
		end
	end
	local s = 30
	while s < e.length - 10 do
		local top = CityPlan.pointAt(e, s)
		local ground = CityPlan.hillY(top.X, top.Z)
		local height = top.Y - ground
		if
			height > 7
			and not overWater(top)
			and CityPlan.clearance(Vector3.new(top.X, 0, top.Z)) > -e.w / 2 - 6
		then
			k.part(parent, {
				Name = "Pillar",
				Size = Vector3.new(6, height - 1, 4),
				CFrame = CFrame.new(top.X, ground + (height - 1) / 2, top.Z),
				Color = Color3.fromRGB(150, 148, 142),
				Material = M.Concrete,
			})
		end
		s += 60
	end
	-- Suspension towers where the deck enters and leaves open water.
	local towers = {}
	local wasWet = false
	s = 0
	while s <= e.length do
		local p = CityPlan.pointAt(e, s)
		local wet = overWater(p)
		if wet ~= wasWet then
			table.insert(towers, s + (if wet then 20 else -20))
			wasWet = wet
		end
		s += 10
	end
	for _, ts in towers do
		local top, t = CityPlan.pointAt(e, ts)
		local right = Vector3.new(-t.Z, 0, t.X)
		for _, sx in { -1, 1 } do
			local base = top + right * sx * (w / 2 + 3)
			k.part(parent, {
				Name = "BridgeTower",
				Size = Vector3.new(4, top.Y + 70, 4),
				CFrame = CFrame.new(base.X, (top.Y + 70) / 2 - 10, base.Z),
				Color = Color3.fromRGB(196, 60, 40),
				Material = M.Metal,
			})
			local beacon = k.part(parent, {
				Name = "TowerLight",
				Size = Vector3.new(4.4, 2, 4.4),
				CFrame = CFrame.new(base.X, top.Y + 60, base.Z),
				Color = Color3.fromRGB(255, 40, 170),
				Material = M.Neon,
			})
			beacon.CastShadow = false
			for _, dir in { -1, 1 } do
				for q = 1, 4 do
					local anchor = CityPlan.pointAt(e, math.clamp(ts + dir * q * 22, 0, e.length))
						+ right * sx * (w / 2 + 1)
					local from = Vector3.new(base.X, top.Y + 56, base.Z)
					k.part(parent, {
						Name = "Cable",
						Size = Vector3.new(0.3, 0.3, (anchor - from).Magnitude),
						CFrame = CFrame.lookAt((from + anchor) / 2, anchor),
						Color = Color3.fromRGB(220, 220, 224),
						Material = M.Metal,
						CanCollide = false,
					})
				end
			end
		end
	end
end

local function buildNode(k: Kit, parent: Instance, n: Node)
	local C, M = k.C, k.M
	if n.bulb then
		disc(k, parent, "Junction", n.pos, CityPlan.BULB_R, 0.22, C.asphalt, M.Asphalt)
		disc(k, parent, "Corner", n.pos, CityPlan.BULB_R + WALK_W, 0.205, C.concrete, M.Concrete)
		-- A planted island in the middle of the turning circle.
		disc(k, parent, "Island", n.pos, 6, 0.6, Color3.fromRGB(80, 120, 60), M.Grass)
		k.tree(parent, n.pos + Vector3.new(0, 0.6, 0), 0.8)
		return
	end
	if not isJunction(n) then
		return
	end
	disc(k, parent, "Junction", n.pos, n.gap + 4, 0.22, C.asphalt, M.Asphalt)
	disc(k, parent, "Corner", n.pos, n.gap + WALK_W + 2, 0.205, C.concrete, M.Concrete)
	if #n.edges < 3 then
		return
	end
	-- Signals at busy crossings, stop signs elsewhere: one per approach, on
	-- the driver's right just before the junction.
	for _, e in n.edges do
		local out = CityPlan.leaving(e, n)
		local right = Vector3.new(out.Z, 0, -out.X) -- right-hand side of a car arriving at n
		local pos = n.pos + out * (n.gap + 3) + right * (e.w / 2 + 3) + Vector3.new(0, 0.24, 0)
		if n.signal then
			-- The arm (local -Z) reaches across the arriving lanes.
			-- Cars arriving along `out` reversed: east-west arrivals are group A.
			local group = if math.abs(out.X) >= math.abs(out.Z) then "A" else "B"
			k.trafficLight(parent, pos, math.deg(math.atan2(right.X, right.Z)), group)
		else
			-- The sign face (local -Z) looks back at the arriving drivers.
			k.stopSign(parent, pos, math.deg(math.atan2(-out.X, -out.Z)))
		end
	end
end

function Roads.build(k: Kit, parent: Instance)
	local count = 0
	for _, e in CityPlan.EDGES do
		if e.kind == "freeway" then
			buildDeck(k, parent, e)
		else
			buildStreet(k, parent, e)
		end
		count += 1
		if count % 60 == 0 then
			task.wait()
		end
	end
	for _, n in CityPlan.NODES do
		if #n.edges > 0 then
			buildNode(k, parent, n)
		end
	end
end

return Roads
