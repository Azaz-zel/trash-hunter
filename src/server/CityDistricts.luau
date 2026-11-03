--!strict
-- The outer districts of the town, built with World's kit of primitives.
-- Loot tier rises from Eastside (1) to Maple Grove (2), Hillcrest Estates (3),
-- the Business District (4) and the Industrial Park (5). Each district looks
-- like what it is worth: worn bungalows and a trailer park, gated mansions with
-- pools, glass office towers, factories with smokestacks and a rail yard.
-- Also fills the Town Center gaps and plants the tree belt around the map.

local CityDistricts = {}

type Kit = any

-- ─── helpers ───────────────────────────────────────────────────────────────

local function at(x: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function welcomeSign(
	k: Kit,
	parent: Instance,
	cf: CFrame,
	title: string,
	sub: string,
	bg: Color3
)
	local C, M = k.C, k.M
	for _, x in { -6, 6 } do
		k.box(
			parent,
			"SignPost",
			cf * CFrame.new(x, 0, 0),
			Vector3.new(0.8, 6, 0.8),
			C.darkMetal,
			M.Metal
		)
	end
	local board =
		k.box(parent, "WelcomeSign", cf * CFrame.new(0, 5, 0), Vector3.new(16, 5, 0.6), bg, M.Wood)
	k.sign(board, Enum.NormalId.Front, title .. "\n" .. sub, bg, C.white)
	k.sign(board, Enum.NormalId.Back, title .. "\n" .. sub, bg, C.white)
end

local function slab(
	k: Kit,
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material
)
	k.part(parent, {
		Name = "Ground",
		Size = Vector3.new(x1 - x0, k.ROAD_TOP, z1 - z0),
		CFrame = CFrame.new((x0 + x1) / 2, k.ROAD_TOP / 2 - 0.02, (z0 + z1) / 2),
		Color = color,
		Material = material,
	})
end

local function streetTrees(
	k: Kit,
	parent: Instance,
	axis: string,
	roadAt: number,
	from: number,
	to: number,
	step: number,
	skip: { number }?
)
	local edge = k.ROAD_W / 2 + k.WALK_W - 2
	local p = from
	while p <= to do
		local blocked = false
		for _, s in skip or {} do
			if math.abs(p - s) < 30 then
				blocked = true
			end
		end
		if not blocked then
			for _, side in { -1, 1 } do
				local pos = if axis == "X"
					then Vector3.new(p, 0, roadAt + side * edge)
					else Vector3.new(roadAt + side * edge, 0, p)
				k.tree(parent, pos, 0.9)
			end
		end
		p += step
	end
end

-- ─── Eastside: low-income housing ──────────────────────────────────────────

local function bungalow(k: Kit, parent: Instance, cf: CFrame)
	local C, M, rng = k.C, k.M, k.rng
	local model = Instance.new("Model")
	model.Name = "Bungalow"
	local siding = k.SIDING[rng:NextInteger(1, #k.SIDING)]:Lerp(Color3.fromRGB(150, 140, 120), 0.35)
	local w, d, h = 26, 22, 10
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Walls", body * CFrame.new(0, 0.8, 0), Vector3.new(w, h, d), siding, M.WoodPlanks)
	k.box(model, "Foundation", body, Vector3.new(w + 0.4, 0.8, d + 0.4), C.concreteDark, M.Concrete)
	k.gableRoof(model, body * CFrame.new(0, 0.8 + h, 0), w, d, 5, Color3.fromRGB(80, 76, 72))
	k.box(
		model,
		"Door",
		cf * CFrame.new(-6, 0.8, -0.2),
		Vector3.new(3.4, 7.4, 0.3),
		Color3.fromRGB(70, 64, 58),
		M.Wood
	)
	k.box(
		model,
		"Stoop",
		cf * CFrame.new(-6, 0, -2.2),
		Vector3.new(6, 0.8, 4),
		C.concreteDark,
		M.Concrete
	)
	k.window(model, cf * CFrame.new(5, 3.5, -0.15), 5, 4)
	-- Chain-link front yard fence and a gravel driveway.
	local fence = k.box(
		model,
		"ChainLink",
		cf * CFrame.new(-1, 0, -12),
		Vector3.new(w + 4, 4, 0.12),
		C.metal,
		M.DiamondPlate
	)
	fence.Transparency = 0.55
	fence.CastShadow = false
	k.part(model, {
		Name = "Driveway",
		Size = Vector3.new(10, 0.25, 14),
		CFrame = cf * CFrame.new(w / 2 + 6, 0.12, -6),
		Color = Color3.fromRGB(120, 114, 104),
		Material = M.Pebble,
	})
	if rng:NextNumber() < 0.7 then
		k.trashCan(model, (cf * CFrame.new(w / 2 + 6, 0, -12)).Position, Color3.fromRGB(46, 50, 56))
	end
	if rng:NextNumber() < 0.5 then
		k.tree(model, (cf * CFrame.new(-w / 2 - 4, 0, d + 6)).Position, 0.9, 3)
	end
	model.Parent = parent
end

local function trailer(k: Kit, parent: Instance, cf: CFrame)
	local C, M, rng = k.C, k.M, k.rng
	local color = ({
		Color3.fromRGB(214, 210, 196),
		Color3.fromRGB(176, 190, 196),
		Color3.fromRGB(200, 186, 150),
	})[rng:NextInteger(1, 3)]
	k.box(parent, "MobileHome", cf * CFrame.new(0, 1.4, 0), Vector3.new(14, 9, 44), color, M.Metal)
	k.box(parent, "Skirting", cf, Vector3.new(14, 1.4, 44), C.darkMetal, M.Metal)
	k.box(
		parent,
		"TrailerRoof",
		cf * CFrame.new(0, 10.4, 0),
		Vector3.new(14.6, 0.6, 44.6),
		C.metal,
		M.Metal
	)
	for _, z in { -12, 4 } do
		k.window(parent, cf * CFrame.new(-7.2, 4.5, z) * CFrame.Angles(0, math.rad(90), 0), 5, 3)
	end
	k.box(parent, "Steps", cf * CFrame.new(-9, 0, -4), Vector3.new(3, 1.4, 4), C.wood, M.WoodPlanks)
end

local function buildEastside(k: Kit, parent: Instance)
	local C, M = k.C, k.M
	local folder = Instance.new("Folder")
	folder.Name = "Eastside"
	folder.Parent = parent

	-- Bungalow rows: both sides of Elm St, south side of Maple Ave.
	for _, block in { { -1225, -1007 }, { -953, -727 } } do
		local x = block[1] + 16
		while x < block[2] - 30 do
			bungalow(k, folder, at(x, -79, 0))
			bungalow(k, folder, at(x + 8, -161, 180))
			bungalow(k, folder, at(x + 4, -281, 180))
			x += 46
		end
	end

	-- Corner stores on Main St with the service alley behind.
	k.storefront(
		folder,
		at(-900, 57),
		50,
		50,
		16,
		Color3.fromRGB(178, 164, 140),
		M.Brick,
		"QUIK STOP",
		Color3.fromRGB(170, 40, 30)
	)
	k.storefront(
		folder,
		at(-835, 57),
		46,
		50,
		14,
		Color3.fromRGB(160, 150, 136),
		M.Concrete,
		"EASTSIDE LAUNDRY",
		Color3.fromRGB(40, 80, 120)
	)
	k.storefront(
		folder,
		at(-772, 57),
		44,
		50,
		14,
		Color3.fromRGB(150, 120, 100),
		M.Brick,
		"CHECKS CASHED",
		Color3.fromRGB(40, 110, 60)
	)
	slab(k, folder, -925, -745, 90, 118, C.asphaltLight, M.Asphalt)

	-- Eastgate Apartments: two-story walk-up.
	local apt = at(-850, 215)
	for floor = 0, 1 do
		k.box(
			folder,
			"Apartments",
			apt * CFrame.new(0, floor * 11, 0),
			Vector3.new(180, 11, 40),
			Color3.fromRGB(176, 150, 120),
			M.Brick
		)
		for i = 0, 11 do
			k.window(folder, apt * CFrame.new(-80 + i * 14.5, floor * 11 + 3, -20.15), 4, 4)
		end
	end
	k.box(folder, "AptRoof", apt * CFrame.new(0, 22, 0), Vector3.new(182, 1, 42), C.roof, M.Slate)
	slab(k, folder, -940, -727, 140, 192, C.asphaltLight, M.Asphalt)

	-- Trailer park.
	slab(k, folder, -1225, -1007, 40, 268, Color3.fromRGB(120, 114, 104), M.Pebble)
	for row = 0, 3 do
		for col = 0, 1 do
			trailer(k, folder, at(-1200 + row * 52, 90 + col * 120, 0))
		end
	end
	welcomeSign(
		k,
		folder,
		at(-1100, 34, 180),
		"SHADY PINES",
		"MOBILE HOME PARK",
		Color3.fromRGB(70, 90, 60)
	)

	-- Utility poles, worn street, trees.
	local last: Vector3? = nil
	for x = -1230, -650, 70 do
		local top = k.utilityPole(folder, Vector3.new(x, 0, -120 + k.ROAD_W / 2 + k.WALK_W - 1))
		if last then
			k.wire(folder, last, top)
		end
		last = top
	end
	streetTrees(k, folder, "X", -120, -1220, -660, 44, { -980, -700 })
	streetTrees(k, folder, "X", -240, -1220, -660, 50, { -980, -700 })
	welcomeSign(k, folder, at(-660, -30, 90), "EASTSIDE", "LOOT TIER 1", Color3.fromRGB(80, 80, 80))
end

-- ─── Hillcrest Estates: luxury homes ───────────────────────────────────────

local function mansion(k: Kit, parent: Instance, cf: CFrame)
	local C, M, rng = k.C, k.M, k.rng
	local model = Instance.new("Model")
	model.Name = "Mansion"
	local stone = ({
		Color3.fromRGB(232, 226, 214),
		Color3.fromRGB(214, 204, 186),
		Color3.fromRGB(196, 196, 194),
	})[rng:NextInteger(1, 3)]
	local w, d, h = 56, 40, 26
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Walls", body * CFrame.new(0, 1, 0), Vector3.new(w, h, d), stone, M.Limestone)
	k.box(model, "Plinth", body, Vector3.new(w + 1, 1, d + 1), C.concreteDark, M.Granite)
	k.gableRoof(model, body * CFrame.new(0, 1 + h, 0), w, d, 10, Color3.fromRGB(56, 58, 64))
	-- Portico with columns.
	k.box(
		model,
		"PorticoRoof",
		cf * CFrame.new(0, 17, -5),
		Vector3.new(18, 1.4, 10),
		C.white,
		M.Limestone
	)
	for _, x in { -7.5, -2.5, 2.5, 7.5 } do
		k.part(model, {
			Name = "Column",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 1.4, 1.4),
			CFrame = cf * CFrame.new(x, 9, -9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.white,
			Material = M.Marble,
		})
	end
	k.box(model, "Steps", cf * CFrame.new(0, 0, -6), Vector3.new(20, 1, 10), C.white, M.Marble)
	k.box(
		model,
		"Doors",
		cf * CFrame.new(0, 1, -0.2),
		Vector3.new(6, 10, 0.3),
		Color3.fromRGB(50, 34, 26),
		M.Wood
	)
	for floor = 0, 1 do
		for _, x in { -22, -14, 14, 22 } do
			k.window(model, cf * CFrame.new(x, 4 + floor * 12, -0.15), 5, 7)
		end
	end
	-- Three-car garage wing.
	local wing = cf * CFrame.new(w / 2 + 16, 0, d / 2 - 4)
	k.box(
		model,
		"GarageWing",
		wing * CFrame.new(0, 1, 0),
		Vector3.new(32, 13, d - 8),
		stone,
		M.Limestone
	)
	for i = -1, 1 do
		k.box(
			model,
			"GarageDoor",
			cf * CFrame.new(w / 2 + 16 + i * 10, 1, 3.9),
			Vector3.new(8, 9, 0.3),
			Color3.fromRGB(90, 70, 52),
			M.Wood
		)
	end
	k.part(
		model,
		{
			Name = "Driveway",
			Size = Vector3.new(30, 0.3, 30),
			CFrame = cf * CFrame.new(w / 2 + 16, 0.15, -11),
			Color = Color3.fromRGB(196, 186, 170),
			Material = M.Cobblestone,
		}
	)
	-- Pool behind the house.
	local pool = cf * CFrame.new(0, 0, d + 14)
	k.box(
		model,
		"PoolDeck",
		pool,
		Vector3.new(40, 0.6, 20),
		Color3.fromRGB(220, 214, 200),
		M.Limestone
	)
	local water = k.box(
		model,
		"Pool",
		pool * CFrame.new(0, 0.62, 0),
		Vector3.new(30, 0.1, 12),
		Color3.fromRGB(60, 170, 210),
		M.Glass
	)
	water.Transparency = 0.2
	water.Reflectance = 0.3
	-- Hedges and trees.
	for _, x in { -32, 32 } do
		k.box(
			model,
			"Hedge",
			cf * CFrame.new(x, 0, -14),
			Vector3.new(16, 4, 3),
			Color3.fromRGB(46, 84, 44),
			M.LeafyGrass
		)
	end
	k.tree(model, (cf * CFrame.new(-w / 2 - 12, 0, 8)).Position, 1.2)
	k.tree(model, (cf * CFrame.new(-w / 2 - 10, 0, d + 22)).Position, 1.1)
	model.Parent = parent
end

local function buildHillcrest(k: Kit, parent: Instance)
	local C, M = k.C, k.M
	local folder = Instance.new("Folder")
	folder.Name = "Hillcrest"
	folder.Parent = parent

	-- Stone perimeter wall with a gatehouse on the boulevard.
	local stone = Color3.fromRGB(176, 166, 150)
	for _, span in { { -640, -30 }, { 30, 640 } } do
		k.box(
			folder,
			"EstateWall",
			CFrame.new((span[1] + span[2]) / 2, 0, -495),
			Vector3.new(span[2] - span[1], 7, 2),
			stone,
			M.Cobblestone
		)
	end
	for _, x in { -32, 32 } do
		k.box(folder, "GatePillar", at(x, -495), Vector3.new(4, 10, 4), stone, M.Cobblestone)
	end
	local gatehouse = at(44, -512)
	k.box(
		folder,
		"Gatehouse",
		gatehouse,
		Vector3.new(12, 10, 10),
		Color3.fromRGB(226, 220, 206),
		M.Limestone
	)
	k.box(
		folder,
		"GatehouseRoof",
		gatehouse * CFrame.new(0, 10, 0),
		Vector3.new(14, 1, 12),
		Color3.fromRGB(56, 58, 64),
		M.Slate
	)
	welcomeSign(
		k,
		folder,
		at(-40, -485, 180),
		"HILLCREST ESTATES",
		"LOOT TIER 3",
		Color3.fromRGB(40, 56, 46)
	)

	-- Boulevard median with trees.
	for z = -520, -870, -30 do
		k.part(
			folder,
			{
				Name = "Median",
				Size = Vector3.new(6, 0.6, 26),
				CFrame = CFrame.new(0, 0.5, z),
				Color = Color3.fromRGB(72, 110, 58),
				Material = M.LeafyGrass,
			}
		)
		k.tree(folder, Vector3.new(0, 0.6, z), 1)
	end

	-- Mansion rows along Hillcrest Dr (-640) and Ridge Ln (-860).
	for _, x in { -540, -420, -300, -170, 170, 300, 420, 540 } do
		mansion(k, folder, at(x, -593, 0))
		mansion(k, folder, at(x + 10, -687, 180))
		mansion(k, folder, at(x - 10, -833, 0))
		if math.abs(x) > 200 then
			mansion(k, folder, at(x, -927, 180))
		end
	end
	-- Service lane between the rows (where the bins go out).
	k.part(
		folder,
		{
			Name = "ServiceLane",
			Size = Vector3.new(1240, k.ROAD_TOP, 16),
			CFrame = CFrame.new(0, k.ROAD_TOP / 2, -760),
			Color = C.asphaltLight,
			Material = M.Asphalt,
		}
	)
	streetTrees(k, folder, "X", -640, -600, 600, 40, { 0 })
	streetTrees(k, folder, "X", -880, -600, 600, 40, { 0 })

	-- Country club at the end of the boulevard, golf green behind.
	local club = at(0, -960, 180)
	k.box(
		folder,
		"Clubhouse",
		club,
		Vector3.new(110, 18, 44),
		Color3.fromRGB(236, 232, 220),
		M.Limestone
	)
	k.gableRoof(folder, club * CFrame.new(0, 18, 0), 110, 44, 9, Color3.fromRGB(56, 58, 64))
	for i = -4, 4 do
		k.window(folder, club * CFrame.new(i * 11, 4, -22.15), 6, 8)
	end
	local clubSign = k.box(
		folder,
		"ClubSign",
		club * CFrame.new(0, 13, -22.4),
		Vector3.new(40, 3, 0.3),
		Color3.fromRGB(40, 56, 46)
	)
	k.sign(
		clubSign,
		Enum.NormalId.Front,
		"HILLCREST COUNTRY CLUB",
		Color3.fromRGB(40, 56, 46),
		Color3.fromRGB(230, 214, 160)
	)
	k.part(
		folder,
		{
			Name = "Green",
			Size = Vector3.new(300, 0.3, 60),
			CFrame = CFrame.new(0, 0.15, -1040),
			Color = Color3.fromRGB(86, 150, 66),
			Material = M.Grass,
		}
	)
	k.box(folder, "FlagPin", at(60, -1040), Vector3.new(0.2, 8, 0.2), C.white)
	k.box(
		folder,
		"Flag",
		at(61.2, -1040) * CFrame.new(0, 6.6, 0),
		Vector3.new(2.2, 1.4, 0.05),
		Color3.fromRGB(200, 40, 40)
	)
end

-- ─── Business District: offices ────────────────────────────────────────────

local function tower(
	k: Kit,
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	glass: Color3,
	name: string
)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "OfficeTower"
	local core =
		k.box(model, "Glass", cf * CFrame.new(0, 12, 0), Vector3.new(w, h - 12, d), glass, M.Glass)
	core.Reflectance = 0.35
	k.box(model, "Lobby", cf, Vector3.new(w + 2, 12, d + 2), Color3.fromRGB(60, 62, 66), M.Granite)
	-- Floor bands every 12 studs read as storeys from the street.
	for y = 24, h - 6, 12 do
		k.box(
			model,
			"FloorBand",
			cf * CFrame.new(0, y, 0),
			Vector3.new(w + 0.4, 0.8, d + 0.4),
			Color3.fromRGB(150, 156, 162),
			M.Metal
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.box(
				model,
				"Corner",
				cf * CFrame.new(sx * w / 2, 0, sz * d / 2),
				Vector3.new(1.6, h, 1.6),
				Color3.fromRGB(150, 156, 162),
				M.Metal
			)
		end
	end
	k.box(
		model,
		"Crown",
		cf * CFrame.new(0, h, 0),
		Vector3.new(w + 1, 3, d + 1),
		Color3.fromRGB(120, 126, 132),
		M.Metal
	)
	k.box(
		model,
		"RoofUnit",
		cf * CFrame.new(w / 5, h + 3, 0),
		Vector3.new(w / 3, 6, d / 3),
		C.concrete,
		M.Metal
	)
	local canopy = k.box(
		model,
		"Canopy",
		cf * CFrame.new(0, 10, -d / 2 - 4),
		Vector3.new(24, 1, 8),
		Color3.fromRGB(40, 42, 46),
		M.Metal
	)
	k.light(
		canopy,
		"SurfaceLight",
		{ Face = Enum.NormalId.Bottom, Range = 16, Brightness = 1.2, Angle = 110 }
	)
	local nameplate = k.box(
		model,
		"Name",
		cf * CFrame.new(0, 7, -d / 2 - 1.2),
		Vector3.new(30, 2.4, 0.3),
		Color3.fromRGB(60, 62, 66)
	)
	k.sign(nameplate, Enum.NormalId.Front, name, Color3.fromRGB(60, 62, 66), C.white, true)
	model.Parent = parent
end

local function buildBusiness(k: Kit, parent: Instance): { CFrame }
	local C, M = k.C, k.M
	local folder = Instance.new("Folder")
	folder.Name = "BusinessDistrict"
	folder.Parent = parent
	local paving = Color3.fromRGB(168, 164, 156)
	slab(k, folder, 787, 1013, 27, 273, paving, M.Concrete)
	slab(k, folder, 1067, 1240, 27, 273, paving, M.Concrete)
	slab(k, folder, 1067, 1240, -213, -27, paving, M.Concrete)

	tower(k, folder, at(845, 110), 80, 70, 160, Color3.fromRGB(70, 100, 124), "CRESTLINE FINANCIAL")
	tower(k, folder, at(965, 200), 60, 56, 112, Color3.fromRGB(60, 86, 96), "HARBOR & LANE LLP")
	tower(k, folder, at(1150, 130), 90, 80, 210, Color3.fromRGB(80, 104, 130), "SUMMIT TOWER")
	tower(k, folder, at(1150, -60), 80, 50, 96, Color3.fromRGB(70, 92, 110), "NORTHSTAR INSURANCE")
	tower(k, folder, at(1150, -180), 80, 50, 72, Color3.fromRGB(86, 100, 112), "MEDICAL ARTS")

	-- Plaza: fountain, planters, benches.
	local fountain = at(960, 80)
	k.part(
		folder,
		{
			Name = "FountainBasin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 22, 22),
			CFrame = fountain * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(190, 186, 178),
			Material = M.Granite,
		}
	)
	local water = k.part(
		folder,
		{
			Name = "FountainWater",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 20, 20),
			CFrame = fountain * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 150, 190),
			Material = M.Glass,
		}
	)
	water.Transparency = 0.25
	local jet = Instance.new("ParticleEmitter")
	jet.Rate = 40
	jet.Speed = NumberRange.new(14, 18)
	jet.SpreadAngle = Vector2.new(6, 6)
	jet.Lifetime = NumberRange.new(1, 1.4)
	jet.Acceleration = Vector3.new(0, -30, 0)
	jet.Size = NumberSequence.new(0.5, 1.2)
	jet.Transparency = NumberSequence.new(0.3, 1)
	jet.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	jet.EmissionDirection = Enum.NormalId.Top
	jet.Parent = water
	for _, p in
		{
			Vector3.new(910, 0, 50),
			Vector3.new(1000, 0, 50),
			Vector3.new(910, 0, 150),
			Vector3.new(1000, 0, 140),
		}
	do
		k.box(
			folder,
			"Planter",
			CFrame.new(p),
			Vector3.new(10, 2, 10),
			Color3.fromRGB(120, 116, 110),
			M.Concrete
		)
		k.tree(folder, p + Vector3.new(0, 2, 0), 1)
	end
	for _, x in { 930, 990 } do
		k.bench(folder, at(x, 106, 180))
	end

	-- Coffee shop and bank across Main St.
	k.storefront(
		folder,
		at(840, -54, 180),
		60,
		44,
		18,
		Color3.fromRGB(110, 80, 60),
		M.Brick,
		"ROAST & CO. COFFEE",
		Color3.fromRGB(40, 70, 50)
	)
	k.storefront(
		folder,
		at(950, -54, 180),
		90,
		44,
		22,
		Color3.fromRGB(200, 196, 186),
		M.Limestone,
		"FIRST NATIONAL BANK",
		Color3.fromRGB(30, 50, 90)
	)

	-- Parking garage.
	local garage = at(890, -180)
	for level = 0, 2 do
		k.box(
			folder,
			"GarageDeck",
			garage * CFrame.new(0, level * 10, 0),
			Vector3.new(200, 1, 60),
			C.concrete,
			M.Concrete
		)
		k.box(
			folder,
			"GarageParapet",
			garage * CFrame.new(0, level * 10 + 1, -29.5),
			Vector3.new(200, 3, 1),
			C.concrete,
			M.Concrete
		)
	end
	for x = -95, 95, 38 do
		for _, z in { -28, 28 } do
			k.box(
				folder,
				"GarageColumn",
				garage * CFrame.new(x, 0, z),
				Vector3.new(2, 30, 2),
				C.concreteDark,
				M.Concrete
			)
		end
	end
	local garageSign = k.box(
		folder,
		"GarageSign",
		garage * CFrame.new(-60, 26, -30.3),
		Vector3.new(30, 4, 0.3),
		Color3.fromRGB(30, 80, 160)
	)
	k.sign(garageSign, Enum.NormalId.Front, "PUBLIC PARKING", Color3.fromRGB(30, 80, 160), C.white)

	-- Office campus and lot south of Maple Ave.
	tower(
		k,
		folder,
		at(900, -340),
		220,
		60,
		36,
		Color3.fromRGB(80, 96, 106),
		"MAPLEWOOD BUSINESS PARK"
	)
	local stalls = k.parkingLot(folder, Vector3.new(900, 0, -435), Vector2.new(220, 60), { -440 })

	streetTrees(k, folder, "X", 0, 660, 1230, 36, { 760, 1040 })
	streetTrees(k, folder, "X", -120, 660, 1230, 36, { 760, 1040 })
	welcomeSign(
		k,
		folder,
		at(660, -60, -90),
		"BUSINESS DISTRICT",
		"LOOT TIER 4",
		Color3.fromRGB(40, 50, 70)
	)
	return stalls
end

-- ─── Industrial Park ───────────────────────────────────────────────────────

local function factory(
	k: Kit,
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	wall: Color3,
	name: string
)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "Factory"
	k.box(model, "Shed", cf, Vector3.new(w, h, d), wall, M.Concrete)
	-- Sawtooth roof.
	local teeth = math.floor(d / 24)
	for i = 0, teeth - 1 do
		local z = -d / 2 + 12 + i * 24
		k.wedge(
			model,
			"Sawtooth",
			cf * CFrame.new(0, h + 4, z),
			Vector3.new(w, 8, 24),
			C.metal,
			M.CorrodedMetal
		)
	end
	for i = -2, 2 do
		k.box(
			model,
			"BayDoor",
			cf * CFrame.new(i * (w / 6), 0, -d / 2 - 0.2),
			Vector3.new(16, 16, 0.4),
			C.metal,
			M.CorrodedMetal
		)
	end
	local plate = k.box(
		model,
		"FactorySign",
		cf * CFrame.new(0, h - 8, -d / 2 - 0.4),
		Vector3.new(w * 0.6, 6, 0.3),
		wall
	)
	k.sign(plate, Enum.NormalId.Front, name, wall, Color3.fromRGB(40, 44, 50), true)
	model.Parent = parent
	return model
end

local function smokestack(k: Kit, parent: Instance, pos: Vector3, height: number)
	local stack = k.part(parent, {
		Name = "Smokestack",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 7, 7),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 70, 56),
		Material = k.M.Brick,
	})
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(height / 2, 0, 0)
	top.Parent = stack
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(8, 12)
	smoke.Speed = NumberRange.new(4, 6)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = Vector3.new(2, 1, 0)
	smoke.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 24) })
	smoke.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(190, 190, 190))
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.LightInfluence = 1
	smoke.Parent = top
end

local function buildIndustrial(k: Kit, parent: Instance)
	local C, M, rng = k.C, k.M, k.rng
	local folder = Instance.new("Folder")
	folder.Name = "IndustrialPark"
	folder.Parent = parent
	local yardGround = Color3.fromRGB(128, 126, 120)
	slab(k, folder, -1240, -587, 327, 673, yardGround, M.Concrete)
	slab(k, folder, -533, -257, 327, 673, yardGround, M.Concrete)
	slab(k, folder, 257, 533, 327, 673, yardGround, M.Concrete)
	slab(k, folder, 587, 1240, 327, 673, yardGround, M.Concrete)

	-- West: Bayline Steel and A1 Scrap.
	factory(
		k,
		folder,
		at(-800, 480),
		260,
		150,
		46,
		Color3.fromRGB(190, 184, 172),
		"BAYLINE STEEL WORKS"
	)
	smokestack(k, folder, Vector3.new(-650, 0, 520), 90)
	smokestack(k, folder, Vector3.new(-630, 0, 540), 76)
	local scrap = at(-1110, 520)
	for _, side in { -1, 1 } do
		k.box(
			folder,
			"ScrapFence",
			scrap * CFrame.new(side * 100, 0, 0),
			Vector3.new(0.4, 12, 280),
			C.metal,
			M.CorrodedMetal
		)
	end
	for _ = 1, 16 do
		local tilt = CFrame.Angles(
			math.rad(rng:NextNumber(-15, 15)),
			rng:NextNumber(0, 6.28),
			math.rad(rng:NextNumber(-15, 15))
		)
		local size =
			Vector3.new(rng:NextNumber(8, 20), rng:NextNumber(4, 10), rng:NextNumber(8, 18))
		k.box(
			folder,
			"ScrapPile",
			scrap * CFrame.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(-120, 110)) * tilt,
			size,
			C.metal:Lerp(Color3.fromRGB(130, 76, 44), rng:NextNumber(0.2, 0.9)),
			M.CorrodedMetal
		)
	end
	k.box(
		folder,
		"CraneMast",
		scrap * CFrame.new(40, 0, 60),
		Vector3.new(3, 46, 3),
		Color3.fromRGB(220, 170, 30),
		M.Metal
	)
	k.box(
		folder,
		"CraneBoom",
		scrap * CFrame.new(10, 44, 60),
		Vector3.new(66, 2.4, 2.4),
		Color3.fromRGB(220, 170, 30),
		M.Metal
	)
	welcomeSign(
		k,
		folder,
		at(-1110, 345, 180),
		"A1 SCRAP & METAL",
		"WE BUY SCRAP",
		Color3.fromRGB(120, 60, 30)
	)
	for i = 0, 2 do
		k.part(folder, {
			Name = "Tank",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(36, 30, 30),
			CFrame = CFrame.new(-470 + i * 70, 18, 440) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(214, 214, 210),
			Material = M.Metal,
		})
	end

	-- East: bottling plant, self storage, truck lot.
	factory(
		k,
		folder,
		at(820, 480),
		240,
		140,
		40,
		Color3.fromRGB(176, 186, 196),
		"NORTHFIELD BOTTLING CO."
	)
	smokestack(k, folder, Vector3.new(955, 0, 590), 70)
	for i = 0, 3 do
		k.part(folder, {
			Name = "Silo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(50, 16, 16),
			CFrame = CFrame.new(980 + (i % 2) * 20, 25, 420 + math.floor(i / 2) * 20)
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 200, 204),
			Material = M.Metal,
		})
	end
	for row = 0, 2 do
		local base = at(395, 380 + row * 100)
		k.box(
			folder,
			"StorageRow",
			base,
			Vector3.new(240, 10, 30),
			Color3.fromRGB(196, 176, 140),
			M.Concrete
		)
		for i = 0, 11 do
			k.box(
				folder,
				"UnitDoor",
				base * CFrame.new(-110 + i * 20, 0, -15.2),
				Vector3.new(14, 8, 0.3),
				Color3.fromRGB(200, 90, 40),
				M.CorrodedMetal
			)
		end
	end
	welcomeSign(
		k,
		folder,
		at(395, 340, 180),
		"U-STORE-IT",
		"SELF STORAGE",
		Color3.fromRGB(200, 90, 40)
	)
	for i = 0, 5 do
		k.box(
			folder,
			"Trailer",
			at(1130, 420 + i * 36, 90) * CFrame.new(0, 4, 0),
			Vector3.new(8.5, 12, 44),
			if i % 2 == 0 then C.white else Color3.fromRGB(190, 60, 50),
			M.Metal
		)
	end

	-- Rail line north of Rail Rd with parked boxcars.
	k.part(
		folder,
		{
			Name = "Ballast",
			Size = Vector3.new(2480, 0.8, 14),
			CFrame = CFrame.new(0, 0.4, 780),
			Color = Color3.fromRGB(110, 104, 96),
			Material = M.Pebble,
		}
	)
	for _, z in { 777.5, 782.5 } do
		k.part(
			folder,
			{
				Name = "Rail",
				Size = Vector3.new(2480, 0.5, 0.4),
				CFrame = CFrame.new(0, 1.05, z),
				Color = Color3.fromRGB(90, 84, 80),
				Material = M.Metal,
			}
		)
	end
	for x = -1236, 1236, 8 do
		k.part(
			folder,
			{
				Name = "Tie",
				Size = Vector3.new(1.2, 0.3, 9),
				CFrame = CFrame.new(x, 0.9, 780),
				Color = Color3.fromRGB(70, 56, 44),
				Material = M.Wood,
				CanCollide = false,
			}
		)
	end
	local boxcarColors =
		{ Color3.fromRGB(140, 54, 40), Color3.fromRGB(60, 80, 110), Color3.fromRGB(120, 110, 60) }
	for i = 0, 9 do
		local x = -500 + i * 48
		k.box(
			folder,
			"Boxcar",
			at(x, 780, 90) * CFrame.new(0, 3, 0),
			Vector3.new(10, 13, 44),
			boxcarColors[i % 3 + 1],
			M.CorrodedMetal
		)
	end

	welcomeSign(
		k,
		folder,
		at(-560 + 40, 325, 180),
		"INDUSTRIAL PARK",
		"LOOT TIER 5",
		Color3.fromRGB(110, 70, 30)
	)
	streetTrees(k, folder, "X", 700, -1220, 1220, 60, { -560, 560 })
end

-- ─── Town Center infill ────────────────────────────────────────────────────

local function buildTownInfill(k: Kit, parent: Instance)
	local C, M = k.C, k.M
	local folder = Instance.new("Folder")
	folder.Name = "TownCenter"
	folder.Parent = parent

	-- Town hall with columns and a flagpole.
	local hall = at(10, -110, 180)
	k.box(folder, "TownHall", hall, Vector3.new(96, 26, 56), Color3.fromRGB(176, 104, 84), M.Brick)
	k.gableRoof(folder, hall * CFrame.new(0, 26, 0), 96, 56, 10, Color3.fromRGB(60, 62, 66))
	for x = -15, 15, 6 do
		k.part(folder, {
			Name = "Column",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(20, 2, 2),
			CFrame = hall * CFrame.new(x, 10, -31) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.white,
			Material = M.Marble,
		})
	end
	k.box(
		folder,
		"Portico",
		hall * CFrame.new(0, 20, -31),
		Vector3.new(36, 2, 8),
		C.white,
		M.Marble
	)
	for i = -3, 3 do
		if i ~= 0 then
			k.window(folder, hall * CFrame.new(i * 12, 6, -28.15), 5, 8)
		end
	end
	local hallSign = k.box(
		folder,
		"HallSign",
		hall * CFrame.new(0, 23, -35.2),
		Vector3.new(30, 2.4, 0.3),
		C.white
	)
	k.sign(hallSign, Enum.NormalId.Front, "MAPLE CITY HALL", C.white, Color3.fromRGB(40, 40, 44))
	k.box(folder, "FlagPole", at(-30, -55), Vector3.new(0.5, 34, 0.5), C.metal, M.Metal)
	k.box(
		folder,
		"Flag",
		at(-26.5, -55) * CFrame.new(0, 29, 0),
		Vector3.new(7, 4, 0.1),
		Color3.fromRGB(180, 30, 40),
		M.Fabric
	)

	-- Church and fire station.
	local church = at(-520, -110, 180)
	k.box(
		folder,
		"Church",
		church,
		Vector3.new(50, 24, 80),
		Color3.fromRGB(230, 226, 214),
		M.WoodPlanks
	)
	k.gableRoof(
		folder,
		church * CFrame.new(0, 24, 0) * CFrame.Angles(0, math.rad(90), 0),
		80,
		50,
		14,
		Color3.fromRGB(70, 66, 64)
	)
	k.box(
		folder,
		"Steeple",
		church * CFrame.new(0, 0, -36),
		Vector3.new(12, 52, 12),
		Color3.fromRGB(236, 232, 222),
		M.WoodPlanks
	)
	k.wedge(
		folder,
		"Spire",
		church * CFrame.new(0, 60, -36),
		Vector3.new(12, 16, 12),
		Color3.fromRGB(70, 66, 64),
		M.Slate
	)
	local station = at(540, -105)
	k.box(
		folder,
		"FireStation",
		station,
		Vector3.new(80, 24, 60),
		Color3.fromRGB(170, 60, 50),
		M.Brick
	)
	for i = -1, 1 do
		k.box(
			folder,
			"EngineBay",
			station * CFrame.new(i * 24, 0, -30.2),
			Vector3.new(18, 16, 0.4),
			C.white,
			M.Metal
		)
	end
	local fireSign = k.box(
		folder,
		"FireSign",
		station * CFrame.new(0, 19, -30.4),
		Vector3.new(40, 3, 0.3),
		Color3.fromRGB(170, 60, 50)
	)
	k.sign(
		fireSign,
		Enum.NormalId.Front,
		"MAPLE CITY FIRE DEPT. STATION 1",
		Color3.fromRGB(170, 60, 50),
		C.white
	)

	-- Burger joint next to the gas station.
	k.storefront(
		folder,
		at(545, 220),
		60,
		40,
		16,
		Color3.fromRGB(196, 60, 40),
		M.Brick,
		"BURGER BARN",
		Color3.fromRGB(230, 180, 40)
	)

	-- Trees on the empty lots.
	for _, p in
		{
			Vector3.new(-80, 0, -60),
			Vector3.new(100, 0, -60),
			Vector3.new(-600, 0, -50),
			Vector3.new(620, 0, -40),
			Vector3.new(-100, 0, 220),
			Vector3.new(-40, 0, 250),
			Vector3.new(80, 0, 230),
			Vector3.new(120, 0, 270),
			Vector3.new(-600, 0, 250),
			Vector3.new(-450, 0, 270),
			Vector3.new(440, 0, 270),
			Vector3.new(620, 0, 160),
		}
	do
		k.tree(folder, p, 1.1)
	end
end

-- ─── tree belt around the map ──────────────────────────────────────────────

local function buildTreeBelt(k: Kit, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "TreeBelt"
	folder.Parent = parent
	local rng = k.rng
	local x0, x1, z0, z1 = -1290, 1290, -1110, 880
	local function edge(a: Vector3, b: Vector3, step: number, inset: number)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		local t = 0
		while t < len do
			local jitter = normal * rng:NextNumber(-8, 8) + normal * inset
			k.tree(folder, a + dir * t + jitter, rng:NextNumber(1.1, 1.6), 3)
			t += step + rng:NextNumber(-4, 4)
		end
	end
	local corners = {
		Vector3.new(x0, 0, z0),
		Vector3.new(x1, 0, z0),
		Vector3.new(x1, 0, z1),
		Vector3.new(x0, 0, z1),
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		edge(a, b, 22, 0)
		edge(a, b, 34, -28)
	end
end

function CityDistricts.build(parent: Instance, k: Kit): { CFrame }
	buildEastside(k, parent)
	buildHillcrest(k, parent)
	local stalls = buildBusiness(k, parent)
	buildIndustrial(k, parent)
	buildTownInfill(k, parent)
	buildTreeBelt(k, parent)
	return stalls
end

return CityDistricts
