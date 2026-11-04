--!strict
-- Fills the empty land along every road after the hand-placed districts are
-- built, so the town reads as dense and lived in. Walks each side of each road
-- in lot-sized steps and, where the lot is free, builds something that fits the
-- district: varied homes in the suburbs, shops downtown and in Old Port,
-- warehouses in the industrial areas. Also dresses every sidewalk with street
-- lights, hydrants, bins and bus stops, and parks cars in driveways.
--
-- Runs once at server start, after the Town folder is in the workspace (the
-- free-lot test is a spatial query).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Districts = require(Shared.Districts)
local MapData = require(Shared.MapData)

type Kit = any

local Infill = {}

local PALETTE = {
	Color3.fromRGB(214, 206, 186),
	Color3.fromRGB(176, 186, 190),
	Color3.fromRGB(226, 222, 212),
	Color3.fromRGB(150, 160, 146),
	Color3.fromRGB(196, 176, 150),
	Color3.fromRGB(128, 140, 158),
	Color3.fromRGB(190, 150, 130),
	Color3.fromRGB(170, 190, 168),
	Color3.fromRGB(222, 200, 160),
	Color3.fromRGB(120, 110, 104),
	Color3.fromRGB(200, 120, 100),
	Color3.fromRGB(104, 124, 140),
}
local ROOFS = {
	Color3.fromRGB(70, 66, 64),
	Color3.fromRGB(96, 74, 60),
	Color3.fromRGB(60, 70, 84),
	Color3.fromRGB(120, 60, 50),
	Color3.fromRGB(50, 52, 56),
}
local CAR_COLORS = {
	Color3.fromRGB(150, 22, 28),
	Color3.fromRGB(34, 52, 94),
	Color3.fromRGB(196, 196, 198),
	Color3.fromRGB(30, 30, 32),
	Color3.fromRGB(240, 240, 238),
	Color3.fromRGB(70, 84, 72),
	Color3.fromRGB(150, 120, 80),
}
local SHOP_NAMES = {
	"CORNER DELI",
	"LUCKY LAUNDROMAT",
	"MAIN ST BARBER",
	"PAGE TURNER BOOKS",
	"SUNRISE BAKERY",
	"VINNIE'S PIZZA",
	"QUICK MART",
	"THRIFT TREASURES",
	"GOLDEN DRAGON",
	"TECH FIX",
	"BLOOM FLORIST",
	"PET PALACE",
	"SECOND SPIN RECORDS",
	"PAWN & LOAN",
	"NAIL STUDIO",
	"TACO TOWN",
	"ACE INSURANCE",
	"DENTAL CARE",
	"MARINE SUPPLY",
	"BAIT & TACKLE",
}

local function pick<T>(k: Kit, list: { T }): T
	return list[k.rng:NextInteger(1, #list)]
end

-- ─── small props ──────────────────────────────────────────────────────────

-- Low-poly parked car (cheap: no physics, a handful of parts).
local function parkedCar(k: Kit, parent: Instance, cf: CFrame)
	local M = k.M
	local color = pick(k, CAR_COLORS)
	local model = Instance.new("Model")
	model.Name = "ParkedCar"
	k.box(
		model,
		"Body",
		cf * CFrame.new(0, 1.2, 0),
		Vector3.new(6.4, 2.4, 14),
		color,
		M.SmoothPlastic
	)
	local cabin = k.box(
		model,
		"Cabin",
		cf * CFrame.new(0, 3.6, 0.8),
		Vector3.new(5.8, 2.2, 7),
		color,
		M.SmoothPlastic
	)
	cabin.Color = color
	k.box(
		model,
		"Glass",
		cf * CFrame.new(0, 3.7, 0.8),
		Vector3.new(5.9, 1.6, 6.6),
		Color3.fromRGB(40, 50, 60),
		M.Glass
	)
	for _, x in { -3.1, 3.1 } do
		for _, z in { -4.4, 4.4 } do
			k.part(model, {
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 2.6, 2.6),
				CFrame = cf * CFrame.new(x, 1.1, z),
				Color = Color3.fromRGB(26, 26, 28),
				Material = M.Rubber,
			})
		end
	end
	k.box(
		model,
		"Light",
		cf * CFrame.new(0, 1.6, -7.05),
		Vector3.new(5.6, 0.6, 0.1),
		Color3.fromRGB(250, 240, 210),
		M.Neon
	)
	model.Parent = parent
end

local function hedge(k: Kit, parent: Instance, cf: CFrame, length: number)
	k.box(parent, "Hedge", cf, Vector3.new(length, 3, 2.4), Color3.fromRGB(52, 90, 46), k.M.Grass)
end

local function picketFence(k: Kit, parent: Instance, cf: CFrame, length: number, gap: number)
	local white = Color3.fromRGB(236, 234, 228)
	for _, side in { -1, 1 } do
		local segment = (length - gap) / 2
		local mid = side * (gap / 2 + segment / 2)
		k.box(
			parent,
			"Fence",
			cf * CFrame.new(mid, 0, 0),
			Vector3.new(segment, 3, 0.3),
			white,
			k.M.WoodPlanks
		)
	end
end

local function flowerBed(k: Kit, parent: Instance, cf: CFrame, length: number)
	k.box(parent, "Bed", cf, Vector3.new(length, 0.6, 2.4), Color3.fromRGB(80, 56, 40), k.M.Ground)
	local colors = {
		Color3.fromRGB(220, 60, 80),
		Color3.fromRGB(240, 200, 60),
		Color3.fromRGB(200, 120, 220),
		Color3.fromRGB(250, 250, 250),
	}
	for x = -length / 2 + 1, length / 2 - 1, 1.6 do
		k.part(parent, {
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = cf * CFrame.new(x, 0.9, k.rng:NextNumber(-0.6, 0.6)),
			Color = pick(k, colors),
			Material = k.M.SmoothPlastic,
			CanCollide = false,
		})
	end
end

local function mailbox(k: Kit, parent: Instance, cf: CFrame)
	k.box(parent, "MailPost", cf, Vector3.new(0.4, 3.6, 0.4), k.C.wood, k.M.Wood)
	k.box(
		parent,
		"Mailbox",
		cf * CFrame.new(0, 3.6, 0),
		Vector3.new(1.2, 1.2, 2),
		pick(k, {
			k.C.darkMetal,
			Color3.fromRGB(30, 60, 110),
			Color3.fromRGB(150, 30, 34),
		}),
		k.M.Metal
	)
end

-- Windows on a facade: `cols` evenly spaced across width `w`, at height `y`.
local function windowRow(
	k: Kit,
	parent: Instance,
	front: CFrame,
	w: number,
	y: number,
	cols: number,
	size: number
)
	for i = 1, cols do
		local x = -w / 2 + (i - 0.5) * (w / cols)
		k.window(parent, front * CFrame.new(x, y, -0.15), size, size)
	end
end

-- ─── homes (cf = front wall centre at ground level; -Z faces the street) ──

local function cottage(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "House"
	local w, d, h = 28, 24, 10
	local wall = pick(k, PALETTE)
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Foundation", body, Vector3.new(w + 0.4, 1.2, d + 0.4), C.concreteDark, M.Concrete)
	k.box(model, "Walls", body * CFrame.new(0, 1.2, 0), Vector3.new(w, h, d), wall, M.WoodPlanks)
	k.gableRoof(model, body * CFrame.new(0, 1.2 + h, 0), w, d, 10, pick(k, ROOFS))
	-- Dormer in the front roof slope.
	k.box(
		model,
		"Dormer",
		body * CFrame.new(0, 1.2 + h, -d / 4),
		Vector3.new(7, 5, 5),
		wall,
		M.WoodPlanks
	)
	k.window(model, body * CFrame.new(0, 3.4 + h, -d / 4 - 2.6), 3.6, 3)
	local front = cf * CFrame.new(0, 1.2, -0.1)
	k.box(
		model,
		"Door",
		front * CFrame.new(0, 0, -0.1),
		Vector3.new(3.6, 7.6, 0.3),
		pick(k, {
			Color3.fromRGB(150, 40, 40),
			Color3.fromRGB(40, 90, 70),
			Color3.fromRGB(240, 200, 70),
		}),
		M.Wood
	)
	windowRow(k, model, front * CFrame.new(-8, 0, 0), 8, 3.4, 1, 4.4)
	windowRow(k, model, front * CFrame.new(8, 0, 0), 8, 3.4, 1, 4.4)
	flowerBed(k, model, cf * CFrame.new(-8, 0, -2), 9)
	flowerBed(k, model, cf * CFrame.new(8, 0, -2), 9)
	k.box(
		model,
		"Walkway",
		cf * CFrame.new(0, 0, -toCurb / 2),
		Vector3.new(4, 0.3, toCurb),
		C.concrete,
		M.Concrete
	)
	picketFence(k, model, cf * CFrame.new(0, 0, -toCurb + 3), w + 10, 5)
	mailbox(k, model, cf * CFrame.new(5, 0, -toCurb + 2))
	k.tree(model, (cf * CFrame.new(w / 2 + 6, 0, -toCurb / 2)).Position, 0.9)
	model.Parent = parent
end

local function porchBungalow(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "House"
	local w, d, h = 36, 30, 11
	local wall = pick(k, PALETTE)
	local trim = C.trim
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Foundation", body, Vector3.new(w + 0.4, 2, d + 0.4), C.brick, M.Brick)
	k.box(model, "Walls", body * CFrame.new(0, 2, 0), Vector3.new(w, h, d), wall, M.WoodPlanks)
	k.gableRoof(model, body * CFrame.new(0, 2 + h, 0), w, d, 7, pick(k, ROOFS))
	-- Full-width front porch with posts, rail and its own roof.
	local porch = cf * CFrame.new(0, 0, -4)
	k.box(model, "Porch", porch, Vector3.new(w, 2, 8), C.wood, M.WoodPlanks)
	k.box(
		model,
		"PorchRoof",
		porch * CFrame.new(0, 2 + h - 1, 0),
		Vector3.new(w + 1, 0.6, 9),
		trim,
		M.SmoothPlastic
	)
	for i = 0, 4 do
		local x = -w / 2 + 1 + i * (w - 2) / 4
		k.box(
			model,
			"Post",
			porch * CFrame.new(x, 2, -3.6),
			Vector3.new(0.8, h - 1, 0.8),
			trim,
			M.Wood
		)
	end
	for _, side in { -1, 1 } do
		k.box(
			model,
			"Rail",
			porch * CFrame.new(side * (w / 4 + 2), 4.4, -3.6),
			Vector3.new(w / 2 - 6, 0.4, 0.4),
			trim,
			M.Wood
		)
	end
	k.box(model, "Steps", cf * CFrame.new(0, 0, -9), Vector3.new(6, 1, 2.4), C.concrete, M.Concrete)
	local front = cf * CFrame.new(0, 2, -0.1)
	k.box(model, "Door", front * CFrame.new(0, 0, -0.1), Vector3.new(3.6, 8, 0.3), C.wood, M.Wood)
	windowRow(k, model, front * CFrame.new(-10, 0, 0), 10, 3, 1, 5)
	windowRow(k, model, front * CFrame.new(10, 0, 0), 10, 3, 1, 5)
	k.box(
		model,
		"Walkway",
		cf * CFrame.new(0, 0, -10 - (toCurb - 10) / 2),
		Vector3.new(4, 0.3, toCurb - 10),
		C.concrete,
		M.Concrete
	)
	-- Gravel drive on the side with a parked car.
	k.box(
		model,
		"Driveway",
		cf * CFrame.new(w / 2 + 7, 0, d / 2 - toCurb / 2),
		Vector3.new(11, 0.3, d + toCurb),
		C.concreteDark,
		M.Pebble
	)
	if k.rng:NextNumber() < 0.7 then
		parkedCar(k, model, cf * CFrame.new(w / 2 + 7, 0.3, 4) * CFrame.Angles(0, math.rad(180), 0))
	end
	mailbox(k, model, cf * CFrame.new(-4, 0, -toCurb + 2))
	hedge(k, model, cf * CFrame.new(-w / 2 + 6, 0, -toCurb + 3), 12)
	model.Parent = parent
end

local function modernHome(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "House"
	local white = Color3.fromRGB(232, 230, 226)
	local dark = Color3.fromRGB(52, 54, 58)
	local timber = Color3.fromRGB(150, 104, 66)
	-- Ground floor box, upper box cantilevered to one side, flat roofs.
	local low = cf * CFrame.new(0, 0, 14)
	k.box(model, "Ground", low, Vector3.new(40, 11, 28), white, M.Plaster)
	local up = cf * CFrame.new(6, 11, 16)
	k.box(model, "Upper", up, Vector3.new(30, 10, 24), dark, M.Concrete)
	k.box(
		model,
		"Cladding",
		up * CFrame.new(-8, 0, -12.1),
		Vector3.new(12, 10, 0.3),
		timber,
		M.WoodPlanks
	)
	k.box(
		model,
		"RoofLow",
		low * CFrame.new(0, 11, 0),
		Vector3.new(41, 0.6, 29),
		C.concreteDark,
		M.Concrete
	)
	k.box(
		model,
		"RoofHigh",
		up * CFrame.new(0, 10, 0),
		Vector3.new(31, 0.6, 25),
		C.concreteDark,
		M.Concrete
	)
	local glassLow = k.box(
		model,
		"Glazing",
		cf * CFrame.new(-6, 1, -0.2),
		Vector3.new(22, 8, 0.3),
		Color3.fromRGB(60, 80, 96),
		M.Glass
	)
	glassLow.Transparency = 0.25
	local glassUp = k.box(
		model,
		"Glazing",
		up * CFrame.new(6, 2, -12.2),
		Vector3.new(14, 6, 0.3),
		Color3.fromRGB(60, 80, 96),
		M.Glass
	)
	glassUp.Transparency = 0.25
	k.box(model, "Door", cf * CFrame.new(12, 0, -0.2), Vector3.new(4, 8.5, 0.3), timber, M.Wood)
	-- Carport with a car.
	local port = cf * CFrame.new(-28, 0, 10)
	k.box(model, "CarportRoof", port * CFrame.new(0, 9, 0), Vector3.new(16, 0.6, 22), dark, M.Metal)
	for _, x in { -7.5, 7.5 } do
		k.box(
			model,
			"CarportPost",
			port * CFrame.new(x, 0, -10),
			Vector3.new(0.6, 9, 0.6),
			dark,
			M.Metal
		)
	end
	k.box(
		model,
		"Driveway",
		cf * CFrame.new(-28, 0, 10 - (toCurb + 10) / 2 + 11),
		Vector3.new(14, 0.3, toCurb + 22),
		C.concrete,
		M.Concrete
	)
	parkedCar(k, model, port * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.rad(180), 0))
	k.box(
		model,
		"Path",
		cf * CFrame.new(12, 0, -toCurb / 2),
		Vector3.new(3, 0.3, toCurb),
		C.concrete,
		M.Slate
	)
	for z = -toCurb + 4, -4, 6 do
		k.box(
			model,
			"Grass",
			cf * CFrame.new(0, 0, z),
			Vector3.new(14, 0.4, 0.4),
			Color3.fromRGB(90, 96, 92),
			M.Slate
		)
	end
	k.tree(model, (cf * CFrame.new(0, 0, -toCurb / 2)).Position, 1, nil, "birch")
	mailbox(k, model, cf * CFrame.new(16, 0, -toCurb + 2))
	model.Parent = parent
end

local function townhouses(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "Townhouses"
	local unit, d, h = 18, 30, 22
	for i = -1, 1 do
		local u = cf * CFrame.new(i * unit, 0, d / 2)
		local color = pick(k, PALETTE)
		k.box(
			model,
			"Unit",
			u,
			Vector3.new(unit - 0.2, h, d),
			color,
			if i == 0 then M.Brick else M.WoodPlanks
		)
		k.box(
			model,
			"Cornice",
			u * CFrame.new(0, h, 0),
			Vector3.new(unit, 1.2, d + 0.6),
			C.trim,
			M.SmoothPlastic
		)
		local front = cf * CFrame.new(i * unit, 0, -0.1)
		k.box(
			model,
			"Stoop",
			front * CFrame.new(-4, 0, -2),
			Vector3.new(4, 2, 4),
			C.concrete,
			M.Concrete
		)
		k.box(
			model,
			"Door",
			front * CFrame.new(-4, 2, -0.1),
			Vector3.new(3.4, 7.6, 0.3),
			pick(k, ROOFS),
			M.Wood
		)
		k.window(model, front * CFrame.new(3, 4, -0.15), 5, 5)
		k.window(model, front * CFrame.new(-3.5, 13, -0.15), 4, 5)
		k.window(model, front * CFrame.new(3.5, 13, -0.15), 4, 5)
	end
	k.box(
		model,
		"Walk",
		cf * CFrame.new(0, 0, -toCurb / 2),
		Vector3.new(unit * 3, 0.3, toCurb),
		C.concrete,
		M.Concrete
	)
	for _, x in { -unit * 1.5 - 2, unit * 1.5 + 2 } do
		k.tree(model, (cf * CFrame.new(x, 0, -toCurb / 2)).Position, 0.8)
	end
	model.Parent = parent
end

local function classicHouse(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	k.house(parent, cf, toCurb, k.rng:NextNumber() < 0.5)
end

-- ─── commercial and industrial ────────────────────────────────────────────

local function shop(k: Kit, parent: Instance, cf: CFrame, w: number)
	local M = k.M
	local walls = { M.Brick, M.Plaster, M.Concrete, M.WoodPlanks }
	k.storefront(
		parent,
		cf * CFrame.new(0, 0, 22),
		w,
		44,
		22 + k.rng:NextInteger(0, 2) * 6,
		pick(k, PALETTE),
		pick(k, walls),
		pick(k, SHOP_NAMES),
		pick(k, ROOFS):Lerp(Color3.fromRGB(200, 60, 50), k.rng:NextNumber())
	)
end

local function warehouse(k: Kit, parent: Instance, cf: CFrame)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "Warehouse"
	local wall = pick(k, {
		Color3.fromRGB(150, 146, 136),
		Color3.fromRGB(120, 130, 140),
		Color3.fromRGB(170, 160, 140),
		Color3.fromRGB(110, 120, 110),
	})
	local body = cf * CFrame.new(0, 0, 34)
	k.box(model, "Shed", body, Vector3.new(56, 20, 44), wall, M.CorrodedMetal)
	k.box(model, "Roof", body * CFrame.new(0, 20, 0), Vector3.new(58, 1, 46), C.darkMetal, M.Metal)
	for _, x in { -16, 0, 16 } do
		k.box(
			model,
			"RollDoor",
			cf * CFrame.new(x, 0, 11.8),
			Vector3.new(11, 12, 0.4),
			C.metal,
			M.DiamondPlate
		)
	end
	k.box(
		model,
		"Dock",
		cf * CFrame.new(0, 0, 9),
		Vector3.new(50, 3, 6),
		C.concreteDark,
		M.Concrete
	)
	k.box(
		model,
		"Yard",
		cf * CFrame.new(0, 0, -2),
		Vector3.new(60, 0.3, 18),
		C.asphaltLight,
		M.Asphalt
	)
	for i = 1, k.rng:NextInteger(2, 5) do
		k.box(
			model,
			"Pallet",
			cf * CFrame.new(-26 + i * 8, 0.3, -6),
			Vector3.new(4, 3, 4),
			Color3.fromRGB(150, 112, 70),
			M.WoodPlanks
		)
	end
	local signBoard = k.box(
		model,
		"Sign",
		body * CFrame.new(0, 16, -22.3),
		Vector3.new(24, 3, 0.3),
		Color3.fromRGB(30, 40, 60)
	)
	k.sign(
		signBoard,
		Enum.NormalId.Front,
		pick(k, {
			"ACME SUPPLY",
			"NORTHLINE FREIGHT",
			"BAKER STEEL",
			"COASTAL PACKING",
			"RIVET WORKS",
			"UNITED STORAGE",
		}),
		Color3.fromRGB(30, 40, 60),
		C.white
	)
	if k.rng:NextNumber() < 0.6 then
		parkedCar(k, model, cf * CFrame.new(26, 0.3, -4) * CFrame.Angles(0, math.rad(90), 0))
	end
	model.Parent = parent
end

-- ─── lot search ───────────────────────────────────────────────────────────

type Plan = { width: number, depth: number, build: (Kit, Instance, CFrame) -> () }

local HOME_STYLES = {
	{ fn = cottage, width = 52 },
	{ fn = porchBungalow, width = 64 },
	{ fn = classicHouse, width = 84 },
	{ fn = modernHome, width = 80 },
	{ fn = townhouses, width = 62 },
}

local function homePlan(k: Kit, weights: { number }, toCurb: number): Plan
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = k.rng:NextNumber() * total
	local style = HOME_STYLES[1]
	for i, w in weights do
		roll -= w
		if roll <= 0 then
			style = HOME_STYLES[i]
			break
		end
	end
	return {
		width = style.width,
		depth = 78,
		build = function(kit, parent, cf)
			style.fn(kit, parent, cf * CFrame.new(0, 0, toCurb), toCurb)
		end,
	}
end

-- What to build in a district; nil means leave the land alone.
local function planFor(k: Kit, districtId: string?): Plan?
	if districtId == "eastside" then
		return homePlan(k, { 4, 4, 2, 0, 1 }, 16)
	elseif districtId == "maple" then
		return homePlan(k, { 2, 3, 4, 1, 2 }, 20)
	elseif districtId == "hillcrest" then
		return homePlan(k, { 0, 1, 3, 4, 0 }, 26)
	elseif districtId == "town" or districtId == "oldport" then
		if k.rng:NextNumber() < 0.25 then
			return homePlan(k, { 0, 0, 0, 0, 1 }, 10)
		end
		local w = k.rng:NextInteger(3, 5) * 10
		return {
			width = w + 6,
			depth = 50,
			build = function(kit, parent, cf)
				shop(kit, parent, cf, w)
			end,
		}
	elseif districtId == "industrial" or districtId == "docks" then
		return {
			width = 68,
			depth = 64,
			build = function(kit, parent, cf)
				warehouse(kit, parent, cf)
			end,
		}
	end
	return nil
end

local function blocked(box: CFrame, size: Vector3, params: OverlapParams): boolean
	for _, hit in workspace:GetPartBoundsInBox(box, size, params) do
		if hit.CanCollide and hit.Name ~= "Lawn" and hit.Name ~= "Seabed" then
			-- Loose trees give way to buildings; anything else blocks the lot.
			local tree = hit:FindFirstAncestor("Tree")
			if not tree then
				return true
			end
		end
	end
	return false
end

local function clearTrees(box: CFrame, size: Vector3, params: OverlapParams)
	for _, hit in workspace:GetPartBoundsInBox(box, size, params) do
		local tree = hit:FindFirstAncestor("Tree")
		if tree then
			tree:Destroy()
		end
	end
end

-- Keeps open space around landmarks players need to reach.
local function nearLandmark(pos: Vector3): boolean
	local spots = {}
	for _, h in Config.World.HIDEOUTS do
		table.insert(spots, h)
	end
	for _, s in Config.Stores do
		table.insert(spots, s.counter)
	end
	for _, g in Config.Quests.givers do
		table.insert(spots, g.pos)
	end
	for _, d in Config.World.Dumpsters do
		table.insert(spots, d.pos)
	end
	for _, p in spots do
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 45 then
			return true
		end
	end
	local rc, rs = Config.World.RED_CENTER, Config.World.RED_SIZE
	return math.abs(pos.X - rc.X) < rs.X / 2 + 40 and math.abs(pos.Z - rc.Z) < rs.Y / 2 + 40
end

local function fillLots(k: Kit, parent: Instance): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:WaitForChild("Town") }
	local edge = k.ROAD_W / 2 + k.WALK_W + 1
	local built = 0
	for _, road in MapData.ROADS do
		for _, side in { -1, 1 } do
			local along = road.from + 30
			while along < road.to - 30 do
				-- Lot frame: origin at the sidewalk edge, +Z away from the road.
				local base = if road.axis == "X"
					then CFrame.new(along, 0, road.at + side * edge) * CFrame.Angles(
						0,
						math.rad(if side > 0 then 0 else 180),
						0
					)
					else CFrame.new(road.at + side * edge, 0, along) * CFrame.Angles(
						0,
						math.rad(if side > 0 then 90 else -90),
						0
					)
				local probe = base * CFrame.new(0, 0, 30)
				local district = Districts.at(probe.Position)
				local plan = planFor(k, district and district.id)
				local step = 30
				if plan and district and district.tier > 0 and not nearLandmark(probe.Position) then
					-- Bottom at 0.05 so paved slabs (top 0.18) count but the lawn does not.
					local center = base * CFrame.new(0, 12, plan.depth / 2 + 1)
					local size = Vector3.new(plan.width, 23.9, plan.depth)
					local inside = Districts.at((base * CFrame.new(0, 0, plan.depth)).Position)
					if
						inside
						and inside.id == district.id
						and not blocked(center, size, params)
					then
						clearTrees(center, size, params)
						plan.build(k, parent, base)
						built += 1
						step = plan.width
					end
				end
				along += step
			end
		end
	end
	return built
end

-- ─── streetscape ──────────────────────────────────────────────────────────

local function dressStreets(k: Kit, parent: Instance)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:WaitForChild("Town") }
	local function free(pos: Vector3): boolean
		for _, hit in
			workspace:GetPartBoundsInBox(
				CFrame.new(pos + Vector3.new(0, 3, 0)),
				Vector3.new(3, 5, 3),
				params
			)
		do
			if hit.CanCollide and hit.Name ~= "Lawn" then
				return false
			end
		end
		return true
	end
	local function nearCrossing(road: any, along: number): boolean
		for _, other in MapData.ROADS do
			if
				other.axis ~= road.axis
				and math.abs(other.at - along) < 30
				and road.at >= other.from - 30
				and road.at <= other.to + 30
			then
				return true
			end
		end
		return false
	end
	for _, road in MapData.ROADS do
		local i = 0
		local along = road.from + 20
		while along < road.to - 20 do
			i += 1
			if not nearCrossing(road, along) then
				local side = if i % 2 == 0 then 1 else -1
				local off = side * (k.ROAD_W / 2 + 1.6)
				local pos = if road.axis == "X"
					then Vector3.new(along, k.WALK_TOP, road.at + off)
					else Vector3.new(road.at + off, k.WALK_TOP, along)
				-- Lamp arm reaches over the road: yaw so local -Z points at it.
				local yaw = if road.axis == "X"
					then (if side > 0 then 0 else 180)
					else (if side > 0 then 90 else -90)
				if free(pos) then
					k.streetLight(parent, pos, yaw)
				end
				-- Something on the sidewalk every other lamp.
				local extra = Vector3.new(0, 0, 0)
				if road.axis == "X" then
					extra = Vector3.new(along + 12, k.WALK_TOP, road.at - off * 1.15)
				else
					extra = Vector3.new(road.at - off * 1.15, k.WALK_TOP, along + 12)
				end
				if i % 3 == 0 and free(extra) then
					k.hydrant(parent, extra)
				elseif i % 3 == 1 and free(extra) then
					k.trashCan(parent, extra, Color3.fromRGB(40, 60, 46))
				end
			end
			along += 95
		end
	end
end

function Infill.build(k: Kit, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Infill"
	folder.Parent = parent
	local built = fillLots(k, folder)
	dressStreets(k, folder)
	return built
end

return Infill
