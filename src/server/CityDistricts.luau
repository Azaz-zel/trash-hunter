--!strict
-- City landmarks (plaza, park, beach and pier, hills plateau, Port Haven
-- docks) and the building builders that Infill uses, made from World's kit.

local CityPlan = require(game:GetService("ReplicatedStorage").Shared.CityPlan)

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
	k.part(model, {
		Name = "Driveway",
		Size = Vector3.new(30, 0.3, 30),
		CFrame = cf * CFrame.new(w / 2 + 16, 0.15, -11),
		Color = Color3.fromRGB(196, 186, 170),
		Material = M.Cobblestone,
	})
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

-- ─── Port Haven: the second city, east along Route 9 ───────────────────────

-- Harbor Lockup: Port Haven's hideout (sell counter, safe from guards).
local function harborLockup(k: Kit, parent: Instance, center: Vector3)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "HarborLockup"
	local w, d, h = 48, 40, 16
	local base = CFrame.new(center.X, k.ROAD_TOP, center.Z)
	local wall = Color3.fromRGB(110, 120, 126)
	k.box(model, "Floor", base, Vector3.new(w, 0.3, d), C.concreteDark, M.Concrete)
	k.box(
		model,
		"WallBack",
		base * CFrame.new(0, 0, d / 2 - 0.5),
		Vector3.new(w, h, 1),
		wall,
		M.CorrodedMetal
	)
	for _, sx in { -1, 1 } do
		k.box(
			model,
			"WallSide",
			base * CFrame.new(sx * (w / 2 - 0.5), 0, 0),
			Vector3.new(1, h, d),
			wall,
			M.CorrodedMetal
		)
		-- Front wall either side of a wide roll-up door facing Main St.
		k.box(
			model,
			"WallFront",
			base * CFrame.new(sx * (w / 2 - 8), 0, -d / 2 + 0.5),
			Vector3.new(16, h, 1),
			wall,
			M.CorrodedMetal
		)
	end
	k.box(
		model,
		"DoorHeader",
		base * CFrame.new(0, 11, -d / 2 + 0.5),
		Vector3.new(16, h - 11, 1),
		wall,
		M.CorrodedMetal
	)
	k.box(
		model,
		"Roof",
		base * CFrame.new(0, h, 0),
		Vector3.new(w + 2, 1, d + 2),
		Color3.fromRGB(70, 74, 78),
		M.Metal
	)
	local signBoard = k.box(
		model,
		"LockupSign",
		base * CFrame.new(0, h + 1, -d / 2 - 0.2),
		Vector3.new(22, 3.4, 0.4),
		Color3.fromRGB(30, 60, 90),
		M.SmoothPlastic
	)
	k.sign(signBoard, Enum.NormalId.Front, "HARBOR LOCKUP", Color3.fromRGB(30, 60, 90), C.white)
	local lamp = k.box(
		model,
		"Lamp",
		base * CFrame.new(0, h - 1.4, 0),
		Vector3.new(6, 0.4, 6),
		Color3.fromRGB(255, 244, 220),
		M.Neon
	)
	k.light(
		lamp,
		"PointLight",
		{ Range = 40, Brightness = 1.4, Color = Color3.fromRGB(255, 236, 200) }
	)

	local counter = k.box(
		model,
		"SellCounter",
		base * CFrame.new(0, 0, 8),
		Vector3.new(10, 3.6, 3),
		Color3.fromRGB(84, 60, 44),
		M.Wood
	)
	local board = k.box(
		model,
		"SellSign",
		base * CFrame.new(0, 8, 12),
		Vector3.new(10, 2.6, 0.3),
		Color3.fromRGB(240, 196, 70)
	)
	k.sign(board, Enum.NormalId.Front, "WE BUY JUNK", Color3.fromRGB(240, 196, 70), C.ink)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell"
	prompt.ObjectText = "Harbor Lockup"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	for _, p in { Vector3.new(-16, 0, 12), Vector3.new(-16, 0, 6), Vector3.new(16, 0, 12) } do
		k.box(
			model,
			"Crate",
			base * CFrame.new(p),
			Vector3.new(4, 4, 4),
			Color3.fromRGB(150, 112, 70),
			M.WoodPlanks
		)
	end
	k.box(
		model,
		"Apron",
		CFrame.new(center.X, 0, center.Z - d / 2 - 14),
		Vector3.new(30, k.ROAD_TOP, 28),
		C.concrete,
		M.Concrete
	)
	model.Parent = parent
end

local function container(k: Kit, parent: Instance, cf: CFrame, color: Color3)
	k.box(parent, "Container", cf, Vector3.new(8.6, 9, 20), color, k.M.CorrodedMetal)
	-- Ribs read as a shipping container from a distance.
	for z = -8, 8, 4 do
		k.box(
			parent,
			"Rib",
			cf * CFrame.new(0, 0, z),
			Vector3.new(8.8, 9, 0.3),
			color:Lerp(Color3.new(0, 0, 0), 0.25),
			k.M.Metal
		)
	end
end

local function containerYard(
	k: Kit,
	parent: Instance,
	x0: number,
	z0: number,
	cols: number,
	rows: number
)
	local colors = {
		Color3.fromRGB(176, 52, 40),
		Color3.fromRGB(40, 92, 150),
		Color3.fromRGB(50, 130, 80),
		Color3.fromRGB(210, 150, 40),
		Color3.fromRGB(110, 110, 116),
	}
	local rng = k.rng
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			for level = 0, rng:NextInteger(1, 3) - 1 do
				container(
					k,
					parent,
					CFrame.new(x0 + c * 11, k.ROAD_TOP + level * 9, z0 - r * 24),
					colors[rng:NextInteger(1, #colors)]
				)
			end
		end
	end
end

local function gantryCrane(k: Kit, parent: Instance, pos: Vector3)
	local M = k.M
	local orange = Color3.fromRGB(220, 110, 30)
	for _, sx in { -12, 12 } do
		for _, sz in { -6, 6 } do
			k.box(
				parent,
				"CraneLeg",
				CFrame.new(pos + Vector3.new(sx, 0, sz)),
				Vector3.new(1.6, 46, 1.6),
				orange,
				M.Metal
			)
		end
	end
	k.box(
		parent,
		"CraneBeam",
		CFrame.new(pos + Vector3.new(0, 46, 0)),
		Vector3.new(26, 3, 14),
		orange,
		M.Metal
	)
	k.box(
		parent,
		"CraneBoom",
		CFrame.new(pos + Vector3.new(30, 44, 0)),
		Vector3.new(70, 2.4, 3),
		orange,
		M.Metal
	)
	k.box(
		parent,
		"CraneCab",
		CFrame.new(pos + Vector3.new(6, 40, 0)),
		Vector3.new(6, 5, 6),
		Color3.fromRGB(230, 230, 226),
		M.SmoothPlastic
	)
end

local function lighthouse(k: Kit, parent: Instance, pos: Vector3)
	local M = k.M
	local model = Instance.new("Model")
	model.Name = "Lighthouse"
	for i = 0, 5 do
		k.part(model, {
			Name = "Tower",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 12 - i * 0.6, 12 - i * 0.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 5 + i * 10, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = if i % 2 == 0
				then Color3.fromRGB(240, 240, 236)
				else Color3.fromRGB(196, 40, 36),
			Material = M.SmoothPlastic,
		})
	end
	local lamp = k.part(model, {
		Name = "Lamp",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, 7, 7),
		CFrame = CFrame.new(pos + Vector3.new(0, 62.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 236, 170),
		Material = M.Neon,
	})
	k.light(
		lamp,
		"PointLight",
		{ Range = 60, Brightness = 2, Color = Color3.fromRGB(255, 230, 170) }
	)
	k.box(
		model,
		"Cap",
		CFrame.new(pos + Vector3.new(0, 65, 0)),
		Vector3.new(8, 3, 8),
		Color3.fromRGB(40, 44, 48),
		M.Metal
	)
	model.Parent = parent
end

local function pier(k: Kit, parent: Instance, x0: number, x1: number, z: number, width: number)
	local M = k.M
	local wood = Color3.fromRGB(128, 98, 70)
	k.part(parent, {
		Name = "Pier",
		Size = Vector3.new(x1 - x0, 0.8, width),
		CFrame = CFrame.new((x0 + x1) / 2, 0.1, z),
		Color = wood,
		Material = M.WoodPlanks,
	})
	local x = x0 + 6
	while x < x1 do
		for _, sz in { -1, 1 } do
			k.part(parent, {
				Name = "Piling",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(8, 1.2, 1.2),
				CFrame = CFrame.new(x, -3, z + sz * (width / 2 - 0.6))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = wood:Lerp(Color3.new(0, 0, 0), 0.3),
				Material = M.Wood,
			})
		end
		x += 14
	end
end

local function boat(k: Kit, parent: Instance, cf: CFrame, color: Color3)
	local M = k.M
	k.box(parent, "Hull", cf * CFrame.new(0, -1.6, 0), Vector3.new(8, 3.2, 22), color, M.Wood)
	k.box(
		parent,
		"Deck",
		cf * CFrame.new(0, 1.6, 0),
		Vector3.new(7.4, 0.3, 21),
		Color3.fromRGB(176, 140, 96),
		M.WoodPlanks
	)
	k.box(
		parent,
		"Cabin",
		cf * CFrame.new(0, 1.9, 3),
		Vector3.new(5, 4, 6),
		Color3.fromRGB(236, 236, 230),
		M.SmoothPlastic
	)
	k.box(
		parent,
		"Mast",
		cf * CFrame.new(0, 1.9, -4),
		Vector3.new(0.4, 12, 0.4),
		Color3.fromRGB(200, 200, 196),
		M.Metal
	)
end

-- ─── cyberpunk dressing ───────────────────────────────────────────────────

local NEON = {
	Color3.fromRGB(0, 230, 255),
	Color3.fromRGB(255, 40, 170),
	Color3.fromRGB(170, 80, 255),
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(60, 255, 150),
}
local BRANDS = {
	"KAIJU COLA",
	"NOVA BANK",
	"SYNTH//LIFE",
	"ORBITAL AIR",
	"ZEN NOODLE",
	"HYPERDRIVE",
	"MOTOKO TECH",
	"NEON NIGHTS",
	"PULSE RADIO",
	"QUANTUM ZERO",
}

-- A glowing rooftop or wall billboard.
local function billboard(k: Kit, parent: Instance, cf: CFrame, w: number, h: number)
	local color = NEON[k.rng:NextInteger(1, #NEON)]
	local frame = k.box(
		parent,
		"BillboardFrame",
		cf,
		Vector3.new(w + 1, h + 1, 0.6),
		Color3.fromRGB(20, 20, 26),
		k.M.Metal
	)
	local screen = k.box(
		parent,
		"Billboard",
		cf * CFrame.new(0, 0.5, -0.35),
		Vector3.new(w, h, 0.1),
		Color3.fromRGB(12, 12, 20),
		k.M.Neon
	)
	k.sign(
		screen,
		Enum.NormalId.Front,
		BRANDS[k.rng:NextInteger(1, #BRANDS)],
		Color3.fromRGB(12, 12, 20),
		color
	)
	k.box(
		parent,
		"BillboardEdge",
		cf * CFrame.new(0, -h / 2, -0.4),
		Vector3.new(w + 1, 0.3, 0.2),
		color,
		k.M.Neon
	)
	return frame
end

-- Skyscraper with neon edge strips, a crown light and a rooftop billboard.
local function neonTower(k: Kit, parent: Instance, cf: CFrame, w: number, d: number, h: number)
	local M = k.M
	local glass = ({
		Color3.fromRGB(40, 56, 80),
		Color3.fromRGB(30, 40, 56),
		Color3.fromRGB(60, 70, 96),
		Color3.fromRGB(44, 30, 60),
	})[k.rng:NextInteger(1, 4)]
	tower(k, parent, cf, w, d, h, glass, BRANDS[k.rng:NextInteger(1, #BRANDS)])
	local color = NEON[k.rng:NextInteger(1, #NEON)]
	for _, sx in { -1, 1 } do
		k.box(
			parent,
			"NeonEdge",
			cf * CFrame.new(sx * (w / 2 + 0.9), 12, -d / 2 - 0.9),
			Vector3.new(0.4, h - 12, 0.4),
			color,
			M.Neon
		)
	end
	k.box(
		parent,
		"NeonCrown",
		cf * CFrame.new(0, h + 3, -d / 2 - 0.6),
		Vector3.new(w + 1, 0.5, 0.3),
		color,
		M.Neon
	)
	if k.rng:NextNumber() < 0.6 then
		billboard(k, parent, cf * CFrame.new(0, h + 12, 0), math.min(w - 6, 40), 14)
	end
	if k.rng:NextNumber() < 0.5 then
		-- A vertical sign hanging off the corner, Tokyo style.
		local sign = k.box(
			parent,
			"BladeSign",
			cf * CFrame.new(w / 2 + 3, h * 0.45, -d / 2 + 4),
			Vector3.new(0.6, math.min(30, h * 0.3), 6),
			Color3.fromRGB(12, 12, 20),
			M.Neon
		)
		k.sign(
			sign,
			Enum.NormalId.Right,
			BRANDS[k.rng:NextInteger(1, #BRANDS)],
			Color3.fromRGB(12, 12, 20),
			color
		)
	end
end

-- ─── landmarks ────────────────────────────────────────────────────────────

local function rectPart(
	k: Kit,
	parent: Instance,
	name: string,
	r: any,
	y: number,
	h: number,
	color: Color3,
	material: Enum.Material
)
	return k.part(parent, {
		Name = name,
		Size = Vector3.new(r.x1 - r.x0, h, r.z1 - r.z0),
		CFrame = CFrame.new((r.x0 + r.x1) / 2, y + h / 2, (r.z0 + r.z1) / 2),
		Color = color,
		Material = material,
	})
end

local function buildPlaza(k: Kit, parent: Instance)
	local C, M = k.C, k.M
	local r = CityPlan.PLAZA
	local folder = Instance.new("Folder")
	folder.Name = "CivicPlaza"
	folder.Parent = parent
	rectPart(k, folder, "Ground", r, 0, k.ROAD_TOP, Color3.fromRGB(150, 146, 140), M.Concrete)
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	local fountain = CFrame.new(cx, 0, cz)
	k.part(folder, {
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 30, 30),
		CFrame = fountain * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 186, 178),
		Material = M.Granite,
	})
	local water = k.part(folder, {
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 27, 27),
		CFrame = fountain * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(0, 200, 230),
		Material = M.Neon,
	})
	water.Transparency = 0.4
	-- A holographic statue: a tall neon pillar with a turning ring.
	k.box(
		folder,
		"HoloPillar",
		fountain * CFrame.new(0, 2, 0),
		Vector3.new(2, 24, 2),
		Color3.fromRGB(255, 40, 170),
		M.Neon
	)
	for _, x in { r.x0 + 20, r.x1 - 20 } do
		for _, z in { r.z0 + 20, r.z1 - 20 } do
			k.tree(folder, Vector3.new(x, 0, z), 1.1, nil, "oak")
			k.bench(folder, CFrame.new(x + (if x < cx then 14 else -14), k.ROAD_TOP, z))
		end
	end
	billboard(k, folder, CFrame.new(cx, 22, r.z1 - 4), 50, 18)
	for _, side in { -1, 1 } do
		k.box(
			folder,
			"LightStrip",
			CFrame.new(cx + side * 40, k.ROAD_TOP, cz),
			Vector3.new(0.6, 0.2, r.z1 - r.z0 - 30),
			NEON[1],
			M.Neon
		)
	end
	local _ = C
end

local function buildPark(k: Kit, parent: Instance)
	local M = k.M
	local r = CityPlan.PARK
	local folder = Instance.new("Folder")
	folder.Name = "MidtownPark"
	folder.Parent = parent
	rectPart(k, folder, "Ground", r, 0, 0.3, Color3.fromRGB(86, 132, 62), M.Grass)
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	local pond = k.part(folder, {
		Name = "Pond",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 60, 60),
		CFrame = CFrame.new(cx + 30, 0.35, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 110, 130),
		Material = M.Glass,
	})
	pond.Transparency = 0.2
	pond.Reflectance = 0.2
	for _, p in { { r.x0, cz, r.x1, cz }, { cx, r.z0, cx, r.z1 } } do
		local a, b = Vector3.new(p[1], 0.4, p[2]), Vector3.new(p[3], 0.4, p[4])
		k.part(folder, {
			Name = "Path",
			Size = Vector3.new(6, 0.2, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = Color3.fromRGB(196, 180, 150),
			Material = M.Pebble,
		})
	end
	for i = 1, 26 do
		local pos = Vector3.new(
			k.rng:NextNumber(r.x0 + 8, r.x1 - 8),
			0.3,
			k.rng:NextNumber(r.z0 + 8, r.z1 - 8)
		)
		if
			(pos - Vector3.new(cx + 30, 0.3, cz)).Magnitude > 36
			and math.abs(pos.X - cx) > 6
			and math.abs(pos.Z - cz) > 6
		then
			k.tree(folder, pos, k.rng:NextNumber(0.9, 1.3))
		end
		if i <= 6 then
			k.bench(folder, CFrame.new(cx - 40 + i * 12, 0.3, cz + 5))
		end
	end
end

local function ferrisWheel(k: Kit, parent: Instance, center: Vector3)
	local M = k.M
	local model = Instance.new("Model")
	model.Name = "FerrisWheel"
	local radius = 34
	for _, side in { -1, 1 } do
		-- A-frame legs on both faces of the wheel.
		for _, lean in { -1, 1 } do
			local foot = center + Vector3.new(lean * 24, -radius - 4, side * 6)
			local top = center + Vector3.new(0, 0, side * 6)
			k.part(model, {
				Name = "Leg",
				Size = Vector3.new(1.4, 1.4, (top - foot).Magnitude),
				CFrame = CFrame.lookAt((foot + top) / 2, top),
				Color = Color3.fromRGB(230, 230, 236),
				Material = M.Metal,
			})
		end
	end
	k.part(model, {
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 4, 4),
		CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(80, 80, 90),
		Material = M.Metal,
	})
	local spokes = 16
	for i = 0, spokes - 1 do
		local a = i / spokes * math.pi * 2
		local rim = center + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		k.part(model, {
			Name = "Spoke",
			Size = Vector3.new(0.5, 0.5, radius),
			CFrame = CFrame.lookAt((center + rim) / 2, rim),
			Color = Color3.fromRGB(230, 230, 236),
			Material = M.Metal,
		})
		local nextA = (i + 1) / spokes * math.pi * 2
		local rim2 = center + Vector3.new(math.cos(nextA) * radius, math.sin(nextA) * radius, 0)
		k.part(model, {
			Name = "Rim",
			Size = Vector3.new(0.8, 0.8, (rim2 - rim).Magnitude),
			CFrame = CFrame.lookAt((rim + rim2) / 2, rim2),
			Color = NEON[(i % #NEON) + 1],
			Material = M.Neon,
		})
		k.box(
			model,
			"Gondola",
			CFrame.new(rim - Vector3.new(0, 4, 0)),
			Vector3.new(4, 4, 5),
			NEON[((i + 2) % #NEON) + 1],
			M.SmoothPlastic
		)
	end
	model.Parent = parent
end

local function buildBeach(k: Kit, parent: Instance)
	local C, M = k.C, k.M
	local folder = Instance.new("Folder")
	folder.Name = "Westshore"
	folder.Parent = parent
	local b = CityPlan.BEACH
	-- Boardwalk along the sand's inland edge.
	k.part(folder, {
		Name = "Boardwalk",
		Size = Vector3.new(10, 0.6, b.z1 - b.z0),
		CFrame = CFrame.new(b.x1 - 5, 0.3, (b.z0 + b.z1) / 2),
		Color = Color3.fromRGB(150, 116, 84),
		Material = M.WoodPlanks,
	})
	for z = b.z0 + 60, b.z1 - 60, 140 do
		-- Lifeguard tower and a couple of umbrellas.
		local stand = CFrame.new(b.x0 + 50, 0, z)
		for _, sx in { -2, 2 } do
			for _, sz in { -2, 2 } do
				k.box(
					folder,
					"TowerLeg",
					stand * CFrame.new(sx, 0, sz),
					Vector3.new(0.5, 8, 0.5),
					C.white,
					M.Wood
				)
			end
		end
		k.box(
			folder,
			"TowerCabin",
			stand * CFrame.new(0, 8, 0),
			Vector3.new(6, 5, 6),
			Color3.fromRGB(230, 70, 60),
			M.WoodPlanks
		)
		k.box(
			folder,
			"TowerRoof",
			stand * CFrame.new(0, 13, 0),
			Vector3.new(7, 0.6, 7),
			C.white,
			M.SmoothPlastic
		)
		for i = 1, 3 do
			local u = CFrame.new(b.x0 + 20 + i * 18, 0, z + 40 + (i % 2) * 14)
			k.box(folder, "UmbrellaPole", u, Vector3.new(0.3, 7, 0.3), C.white, M.Metal)
			k.part(folder, {
				Name = "Umbrella",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 10, 10),
				CFrame = u * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = NEON[k.rng:NextInteger(1, #NEON)],
				Material = M.Fabric,
			})
			k.box(
				folder,
				"Towel",
				u * CFrame.new(3, 0.1, 3),
				Vector3.new(3, 0.1, 6),
				NEON[k.rng:NextInteger(1, #NEON)],
				M.Fabric
			)
		end
		k.tree(folder, Vector3.new(b.x1 - 14, 0, z + 70), 1.2, nil, "palm")
	end
	-- Pier out into the ocean, with an arcade strip and the Ferris wheel.
	local pz = -200
	local x0, x1 = b.x0 - 340, b.x1
	k.part(folder, {
		Name = "Pier",
		Size = Vector3.new(x1 - x0, 1, 34),
		CFrame = CFrame.new((x0 + x1) / 2, 1.5, pz),
		Color = Color3.fromRGB(140, 108, 78),
		Material = M.WoodPlanks,
	})
	for x = x0 + 8, b.x0, 20 do
		for _, sz in { -15, 15 } do
			k.part(folder, {
				Name = "Piling",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(14, 1.4, 1.4),
				CFrame = CFrame.new(x, -5, pz + sz) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(90, 70, 52),
				Material = M.Wood,
			})
		end
	end
	for _, sz in { -16.5, 16.5 } do
		k.box(
			folder,
			"PierRail",
			CFrame.new((x0 + x1) / 2, 2, pz + sz),
			Vector3.new(x1 - x0, 3, 0.4),
			C.white,
			M.Wood
		)
	end
	for i = 0, 4 do
		local stall = CFrame.new(b.x0 - 40 - i * 30, 2, pz - 10)
		k.box(
			folder,
			"Arcade",
			stall,
			Vector3.new(20, 10, 10),
			Color3.fromRGB(30, 30, 44),
			M.SmoothPlastic
		)
		local sign = k.box(
			folder,
			"ArcadeSign",
			stall * CFrame.new(0, 10, 4),
			Vector3.new(18, 3, 0.3),
			Color3.fromRGB(12, 12, 20),
			M.Neon
		)
		k.sign(
			sign,
			Enum.NormalId.Back,
			({ "ARCADE", "TACOS", "PRIZES", "BOBA", "TICKETS" })[i + 1],
			Color3.fromRGB(12, 12, 20),
			NEON[(i % #NEON) + 1]
		)
	end
	ferrisWheel(k, folder, Vector3.new(x0 + 60, 40, pz + 4))
	-- Palms along Ocean Dr.
	for z = b.z0 + 30, b.z1 - 30, 46 do
		k.tree(folder, Vector3.new(b.x1 - 2, 0, z), 1.1, nil, "palm")
	end
end

local function buildPlateau(k: Kit, parent: Instance)
	local M = k.M
	local p = CityPlan.PLATEAU
	local folder = Instance.new("Folder")
	folder.Name = "VistaHills"
	folder.Parent = parent
	local rock = Color3.fromRGB(120, 108, 92)
	local blocks = {
		{ x0 = p.x0, x1 = p.gorge.x0, z0 = p.z0, z1 = p.gorge.z1 },
		{ x0 = p.gorge.x1, x1 = p.x1, z0 = p.z0, z1 = p.gorge.z1 },
		{ x0 = p.x0, x1 = p.x1, z0 = p.gorge.z1, z1 = p.z1 },
	}
	for _, r in blocks do
		rectPart(k, folder, "Cliff", r, 0, p.height - 0.4, rock, M.Rock)
		-- The grass top is named Lawn so infill treats it as open ground.
		local top = rectPart(
			k,
			folder,
			"Lawn",
			r,
			p.height - 0.42,
			0.4,
			Color3.fromRGB(96, 128, 66),
			M.Grass
		)
		top.CanCollide = true
	end
	-- Big letters on the cliff face above the city.
	local word = "VISTA"
	for i = 1, #word do
		local letter = k.box(
			folder,
			"HillLetter",
			CFrame.new(-1200 + i * 26, p.height - 2, p.z0 + 30) * CFrame.Angles(math.rad(-15), 0, 0),
			Vector3.new(22, 26, 1),
			Color3.fromRGB(245, 245, 240),
			M.SmoothPlastic
		)
		k.sign(
			letter,
			Enum.NormalId.Front,
			word:sub(i, i),
			Color3.fromRGB(245, 245, 240),
			Color3.fromRGB(30, 30, 30)
		)
	end
	-- Pines along the cliff edge and the back of the plateau.
	for x = p.x0 + 20, p.x1 - 20, 34 do
		if x < p.gorge.x0 - 30 or x > p.gorge.x1 + 30 then
			k.tree(
				folder,
				Vector3.new(x, p.height, p.z0 + 10 + k.rng:NextNumber(0, 8)),
				1.1,
				nil,
				"pine"
			)
		end
		k.tree(folder, Vector3.new(x, p.height, p.z1 - 12), 1.3, nil, "pine")
	end
end

local function buildIsland(k: Kit, parent: Instance)
	local M = k.M
	local folder = Instance.new("Folder")
	folder.Name = "PortHaven"
	folder.Parent = parent
	harborLockup(k, folder, CityPlan.LOCKUP)
	-- East quay wall, cranes and moored boats.
	k.part(folder, {
		Name = "Quay",
		Size = Vector3.new(20, 8.4, 2560),
		CFrame = CFrame.new(2670, -3.9, 0),
		Color = Color3.fromRGB(150, 146, 138),
		Material = M.Concrete,
	})
	for _, z in { -700, -200, 400, 900 } do
		gantryCrane(k, folder, Vector3.new(2655, 0, z))
	end
	for _, z in { -950, -450, 150, 650 } do
		pier(k, folder, 2680, 2810, z, 14)
		boat(
			k,
			folder,
			CFrame.new(2745, -0.6, z + 16) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(240, 240, 236)
		)
	end
	k.part(folder, {
		Name = "Breakwater",
		Size = Vector3.new(16, 4, 220),
		CFrame = CFrame.new(2900, -1.4, 1200),
		Color = Color3.fromRGB(120, 118, 112),
		Material = M.Slate,
	})
	lighthouse(k, folder, Vector3.new(2900, 0.6, 1300))
	welcomeSign(
		k,
		folder,
		at(2080, -560, 90),
		"PORT HAVEN",
		"Harbor city",
		Color3.fromRGB(30, 60, 90)
	)
end

-- Exposes the building builders to Infill through the kit.
function CityDistricts.extendKit(k: Kit)
	k.bungalow = function(parent: Instance, cf: CFrame)
		bungalow(k, parent, cf)
	end
	k.trailer = function(parent: Instance, cf: CFrame)
		trailer(k, parent, cf)
	end
	k.mansion = function(parent: Instance, cf: CFrame)
		mansion(k, parent, cf)
	end
	k.neonTower = function(parent: Instance, cf: CFrame, w: number, d: number, h: number)
		neonTower(k, parent, cf, w, d, h)
	end
	k.factory = function(
		parent: Instance,
		cf: CFrame,
		w: number,
		d: number,
		h: number,
		wall: Color3,
		name: string
	)
		factory(k, parent, cf, w, d, h, wall, name)
	end
	k.containerYard = function(parent: Instance, x0: number, z0: number, cols: number, rows: number)
		containerYard(k, parent, x0, z0, cols, rows)
	end
	k.billboard = function(parent: Instance, cf: CFrame, w: number, h: number)
		billboard(k, parent, cf, w, h)
	end
	k.NEON = NEON
end

function CityDistricts.build(parent: Instance, k: Kit)
	buildPlaza(k, parent)
	buildPark(k, parent)
	buildBeach(k, parent)
	buildPlateau(k, parent)
	buildIsland(k, parent)
end

return CityDistricts
