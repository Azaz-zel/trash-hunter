--!strict
-- Fills the land along every street after the roads and landmarks are built,
-- packing lots shoulder to shoulder so the city reads as dense and lived in.
-- Each district gets its own mix: neon towers downtown, apartments and shops
-- in Midtown, varied (some walk-in) homes in the suburbs, stucco houses at the
-- beach, villas on the hills, warehouses and factories in the industrial
-- areas. Also dresses every sidewalk with lights, hydrants and bins.
--
-- Runs once at server start, after the Town folder is in the workspace (the
-- free-lot test is a spatial query).

local Shared = game:GetService("ReplicatedStorage").Shared
local CityPlan = require(Shared.CityPlan)

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

-- ─── more building types ──────────────────────────────────────────────────

-- A home you can walk into: door opening, furnished rooms, a lamp.
local function openHouse(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "OpenHouse"
	local w, d, h = 34, 30, 11
	local wall = pick(k, PALETTE)
	local mat = pick(k, { M.WoodPlanks, M.Brick, M.Plaster })
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Floor", body, Vector3.new(w, 1, d), Color3.fromRGB(150, 112, 80), M.WoodPlanks)
	k.box(model, "WallBack", body * CFrame.new(0, 1, d / 2 - 0.5), Vector3.new(w, h, 1), wall, mat)
	for _, sx in { -1, 1 } do
		k.box(
			model,
			"WallSide",
			body * CFrame.new(sx * (w / 2 - 0.5), 1, 0),
			Vector3.new(1, h, d),
			wall,
			mat
		)
		local seg = (w - 6) / 2
		k.box(
			model,
			"WallFront",
			cf * CFrame.new(sx * (3 + seg / 2), 1, 0.5),
			Vector3.new(seg, h, 1),
			wall,
			mat
		)
		k.window(model, cf * CFrame.new(sx * (3 + seg / 2), 4, -0.1), 5, 4)
	end
	k.box(model, "Lintel", cf * CFrame.new(0, 9, 0.5), Vector3.new(6, h - 8, 1), wall, mat)
	-- Inner wall splitting living room and bedroom, with a doorway.
	k.box(
		model,
		"InnerWall",
		body * CFrame.new(-w / 4 - 2, 1, 4),
		Vector3.new(w / 2 - 6, h, 0.6),
		C.trim,
		M.Plaster
	)
	k.box(
		model,
		"Ceiling",
		body * CFrame.new(0, 1 + h, 0),
		Vector3.new(w, 0.4, d),
		C.trim,
		M.Plaster
	)
	k.gableRoof(model, body * CFrame.new(0, 1.4 + h, 0), w, d, 7, pick(k, ROOFS))
	local lamp = k.box(
		model,
		"Lamp",
		body * CFrame.new(0, h - 0.4, 0),
		Vector3.new(2, 0.4, 2),
		Color3.fromRGB(255, 240, 210),
		M.Neon
	)
	k.light(
		lamp,
		"PointLight",
		{ Range = 22, Brightness = 1.2, Color = Color3.fromRGB(255, 226, 180) }
	)
	local inside = cf * CFrame.new(0, 1, 0)
	-- Living room: sofa facing a TV, rug, coffee table.
	local sofaColor = pick(
		k,
		{ Color3.fromRGB(90, 70, 60), Color3.fromRGB(50, 70, 100), Color3.fromRGB(110, 40, 40) }
	)
	k.box(model, "Sofa", inside * CFrame.new(8, 0, 8), Vector3.new(10, 2, 4), sofaColor, M.Fabric)
	k.box(
		model,
		"SofaBack",
		inside * CFrame.new(8, 2, 9.6),
		Vector3.new(10, 2.4, 0.8),
		sofaColor,
		M.Fabric
	)
	k.box(
		model,
		"Rug",
		inside * CFrame.new(8, 0.02, 14),
		Vector3.new(10, 0.05, 6),
		pick(k, PALETTE),
		M.Fabric
	)
	k.box(
		model,
		"CoffeeTable",
		inside * CFrame.new(8, 0, 14),
		Vector3.new(5, 1.4, 2.6),
		C.wood,
		M.Wood
	)
	k.box(
		model,
		"TVStand",
		inside * CFrame.new(8, 0, 22),
		Vector3.new(7, 2, 2),
		C.darkMetal,
		M.Wood
	)
	local tv = k.box(
		model,
		"TV",
		inside * CFrame.new(8, 2, 22.4),
		Vector3.new(6, 3.6, 0.3),
		Color3.fromRGB(20, 30, 60),
		M.Neon
	)
	tv.Transparency = 0.1
	-- Bedroom: bed and a wardrobe.
	k.box(model, "Bed", inside * CFrame.new(-10, 0, 22), Vector3.new(7, 2, 10), C.trim, M.Fabric)
	k.box(
		model,
		"Blanket",
		inside * CFrame.new(-10, 2, 23),
		Vector3.new(7.2, 0.4, 7),
		pick(k, PALETTE),
		M.Fabric
	)
	k.box(
		model,
		"Wardrobe",
		inside * CFrame.new(-15, 0, 12),
		Vector3.new(2.4, 8, 6),
		C.wood,
		M.Wood
	)
	-- Kitchen counter along the back wall.
	k.box(
		model,
		"Kitchen",
		inside * CFrame.new(-4, 0, 27.5),
		Vector3.new(12, 3.4, 2.4),
		C.trim,
		M.Marble
	)
	k.box(
		model,
		"Walkway",
		cf * CFrame.new(0, 0, -toCurb / 2),
		Vector3.new(4, 0.3, toCurb),
		C.concrete,
		M.Concrete
	)
	mailbox(k, model, cf * CFrame.new(5, 0, -toCurb + 2))
	model.Parent = parent
end

-- Stucco house with a terracotta roof (beach and hills).
local function stuccoHouse(k: Kit, parent: Instance, cf: CFrame, toCurb: number)
	local M = k.M
	local model = Instance.new("Model")
	model.Name = "House"
	local wall = pick(k, {
		Color3.fromRGB(240, 226, 200),
		Color3.fromRGB(236, 200, 170),
		Color3.fromRGB(220, 236, 230),
		Color3.fromRGB(250, 214, 214),
	})
	local terracotta = Color3.fromRGB(176, 88, 56)
	local w, d, h = 38, 30, 12
	local body = cf * CFrame.new(0, 0, d / 2)
	k.box(model, "Walls", body, Vector3.new(w, h, d), wall, M.Plaster)
	k.box(
		model,
		"Roof",
		body * CFrame.new(0, h, 0),
		Vector3.new(w + 3, 1.2, d + 3),
		terracotta,
		M.Slate
	)
	if k.rng:NextNumber() < 0.6 then
		k.box(
			model,
			"Upper",
			body * CFrame.new(-w / 4, h + 1.2, 2),
			Vector3.new(w / 2, 9, d - 8),
			wall,
			M.Plaster
		)
		k.box(
			model,
			"UpperRoof",
			body * CFrame.new(-w / 4, h + 10.2, 2),
			Vector3.new(w / 2 + 2, 1, d - 6),
			terracotta,
			M.Slate
		)
		k.window(model, cf * CFrame.new(-w / 4, h + 4, 3.85), 5, 4)
	end
	k.box(
		model,
		"Arch",
		cf * CFrame.new(6, 0, -0.2),
		Vector3.new(6, 8.5, 0.3),
		Color3.fromRGB(120, 80, 50),
		M.Wood
	)
	k.window(model, cf * CFrame.new(-8, 3.5, -0.15), 6, 4)
	k.window(model, cf * CFrame.new(15, 3.5, -0.15), 4, 4)
	k.box(
		model,
		"Courtyard",
		cf * CFrame.new(0, 0, -toCurb / 2),
		Vector3.new(w, 0.3, toCurb - 2),
		Color3.fromRGB(196, 160, 120),
		M.Cobblestone
	)
	k.box(
		model,
		"LowWall",
		cf * CFrame.new(0, 0, -toCurb + 1.5),
		Vector3.new(w, 3, 1),
		wall,
		M.Plaster
	)
	k.tree(model, (cf * CFrame.new(-w / 2 + 4, 0, -toCurb / 2)).Position, 1, nil, "palm")
	if k.rng:NextNumber() < 0.5 then
		parkedCar(k, model, cf * CFrame.new(w / 2 + 7, 0.3, 6) * CFrame.Angles(0, math.rad(180), 0))
	end
	model.Parent = parent
end

-- Mid-rise apartments or a hotel: stacked floors with glazed bands.
local function midrise(
	k: Kit,
	parent: Instance,
	cf: CFrame,
	w: number,
	floors: number,
	pastel: boolean
)
	local C, M = k.C, k.M
	local model = Instance.new("Model")
	model.Name = "Apartments"
	local d = 40
	local wall = if pastel
		then pick(k, {
			Color3.fromRGB(250, 220, 200),
			Color3.fromRGB(200, 236, 230),
			Color3.fromRGB(240, 240, 210),
		})
		else pick(k, PALETTE)
	local body = cf * CFrame.new(0, 0, d / 2)
	local fh = 11
	k.box(
		model,
		"Walls",
		body,
		Vector3.new(w, floors * fh, d),
		wall,
		if pastel then M.Plaster else pick(k, { M.Brick, M.Concrete, M.Plaster })
	)
	k.box(
		model,
		"Roof",
		body * CFrame.new(0, floors * fh, 0),
		Vector3.new(w + 1, 1.2, d + 1),
		C.concreteDark,
		M.Concrete
	)
	k.box(
		model,
		"WaterTank",
		body * CFrame.new(w / 4, floors * fh + 1.2, 6),
		Vector3.new(6, 7, 6),
		C.wood,
		M.WoodPlanks
	)
	for f = 1, floors - 1 do
		local band = k.box(
			model,
			"Glazing",
			cf * CFrame.new(0, f * fh + 2.5, -0.2),
			Vector3.new(w - 4, 5, 0.3),
			C.glass,
			M.Glass
		)
		band.Transparency = 0.2
		band.Reflectance = 0.2
		for x = -w / 2 + 8, w / 2 - 8, 9 do
			k.box(
				model,
				"Mullion",
				cf * CFrame.new(x, f * fh + 2.5, -0.4),
				Vector3.new(0.5, 5, 0.3),
				wall,
				M.Concrete
			)
		end
		if pastel then
			k.box(
				model,
				"Balcony",
				cf * CFrame.new(0, f * fh, -1.6),
				Vector3.new(w - 6, 0.5, 3),
				C.white,
				M.Concrete
			)
		end
	end
	-- Ground floor: entrance and a lit shop sign.
	k.box(
		model,
		"Entrance",
		cf * CFrame.new(0, 0, -0.2),
		Vector3.new(8, 9, 0.3),
		Color3.fromRGB(40, 44, 50),
		M.Glass
	)
	local signColor = if k.NEON then pick(k, k.NEON) else C.white
	local signBoard = k.box(
		model,
		"Sign",
		cf * CFrame.new(-w / 4, 6, -0.6),
		Vector3.new(w / 3, 2.4, 0.3),
		Color3.fromRGB(16, 16, 22),
		M.Neon
	)
	k.sign(
		signBoard,
		Enum.NormalId.Front,
		pick(k, SHOP_NAMES),
		Color3.fromRGB(16, 16, 22),
		signColor
	)
	model.Parent = parent
end

-- ─── lot search ───────────────────────────────────────────────────────────

type Plan = { width: number, depth: number, build: (Kit, Instance, CFrame) -> () }

local function choose(k: Kit, options: { { any } }): any
	local total = 0
	for _, o in options do
		total += o[1]
	end
	local roll = k.rng:NextNumber() * total
	for _, o in options do
		roll -= o[1]
		if roll <= 0 then
			return o[2]
		end
	end
	return options[1][2]
end

local function home(fn: any, width: number, toCurb: number, depth: number?): Plan
	return {
		width = width,
		depth = depth or (toCurb + 50),
		build = function(kit, parent, cf)
			fn(kit, parent, cf * CFrame.new(0, 0, toCurb), toCurb)
		end,
	}
end

local function shopPlan(k: Kit): Plan
	local w = k.rng:NextInteger(3, 5) * 10
	return {
		width = w + 2,
		depth = 48,
		build = function(kit, parent, cf)
			shop(kit, parent, cf, w)
		end,
	}
end

local function midrisePlan(k: Kit, pastel: boolean): Plan
	local w = k.rng:NextInteger(5, 8) * 8
	local floors = k.rng:NextInteger(4, 8)
	return {
		width = w + 2,
		depth = 44,
		build = function(kit, parent, cf)
			midrise(kit, parent, cf * CFrame.new(0, 0, 2), w, floors, pastel)
		end,
	}
end

-- What to build in a district; nil means leave the land alone.
local function planFor(k: Kit, districtId: string?): Plan?
	if districtId == "downtown" then
		if k.rng:NextNumber() < 0.75 then
			local w = k.rng:NextInteger(5, 9) * 10
			local d = k.rng:NextInteger(5, 7) * 10
			local h = k.rng:NextInteger(8, 26) * 10
			return {
				width = w + 4,
				depth = d + 6,
				build = function(kit, parent, cf)
					kit.neonTower(parent, cf * CFrame.new(0, 0, d / 2 + 3), w, d, h)
				end,
			}
		end
		return shopPlan(k)
	elseif districtId == "midtown" or districtId == "oldport" then
		return choose(k, {
			{ 4, midrisePlan(k, false) },
			{ 4, shopPlan(k) },
			{ 2, home(townhouses, 58, 10) },
		})
	elseif districtId == "southside" then
		return choose(k, {
			{ 3, home(openHouse, 40, 12) },
			{ 3, home(cottage, 42, 12) },
			{ 2, home(porchBungalow, 56, 14) },
			{ 2, home(townhouses, 58, 10) },
			{
				1,
				{
					width = 30,
					depth = 52,
					build = function(kit, parent, cf)
						kit.bungalow(parent, cf * CFrame.new(0, 0, 14))
					end,
				},
			},
		})
	elseif districtId == "eastgate" then
		return choose(k, {
			{ 3, home(classicHouse, 82, 18) },
			{ 3, home(porchBungalow, 58, 16) },
			{ 2, home(cottage, 44, 14) },
			{ 2, home(modernHome, 78, 18) },
			{ 2, home(openHouse, 40, 14) },
			{ 1, home(stuccoHouse, 56, 14) },
		})
	elseif districtId == "beach" then
		return choose(k, {
			{ 3, home(stuccoHouse, 58, 14) },
			{ 3, shopPlan(k) },
			{ 2, midrisePlan(k, true) },
		})
	elseif districtId == "hills" then
		return choose(k, {
			{
				4,
				{
					width = 112,
					depth = 82,
					build = function(kit, parent, cf)
						kit.mansion(parent, cf * CFrame.new(-14, 0, 20))
					end,
				},
			},
			{ 3, home(modernHome, 80, 22) },
			{ 2, home(stuccoHouse, 60, 18) },
		})
	elseif districtId == "industrial" or districtId == "docks" then
		if k.rng:NextNumber() < 0.3 then
			local w = k.rng:NextInteger(7, 11) * 10
			return {
				width = w + 4,
				depth = 74,
				build = function(kit, parent, cf)
					kit.factory(
						parent,
						cf * CFrame.new(0, 0, 37) * CFrame.Angles(0, math.pi, 0),
						w,
						60,
						k.rng:NextInteger(18, 30),
						pick(k, PALETTE),
						pick(k, {
							"ACME SUPPLY",
							"BAKER STEEL",
							"RIVET WORKS",
							"UNITED STORAGE",
							"COASTAL PACKING",
						})
					)
				end,
			}
		end
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
			if not hit:FindFirstAncestor("Tree") then
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

local function flatStreets(): { CityPlan.Road }
	local out = {}
	for _, road in CityPlan.ROADS do
		if road.kind == "street" and road.y0 == road.y1 then
			table.insert(out, road)
		end
	end
	return out
end

-- Walks both sides of every street, packing lots shoulder to shoulder.
local function fillLots(k: Kit, parent: Instance): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:WaitForChild("Town") }
	local built = 0
	for _, road in flatStreets() do
		for _, side in { -1, 1 } do
			local along = road.from + 12
			while along < road.to - 12 do
				local step = 8
				local probe = CityPlan.lotFrame(road, along, side) * CFrame.new(0, 0, 20)
				local district = CityPlan.district(probe.Position)
				if district and district.tier > 0 and CityPlan.onLand(probe.Position) then
					local plan = planFor(k, district.id)
					if plan then
						-- Centre the lot on `along + width / 2` so it starts at `along`.
						local base = CityPlan.lotFrame(road, along + plan.width / 2, side)
							* CFrame.new(0, 0, 1)
						local far = base * CFrame.new(0, 0, plan.depth)
						local inside = CityPlan.district(far.Position)
						local center = base * CFrame.new(0, 12, plan.depth / 2)
						-- Bottom 0.05 above the street so paved slabs count but lawn does not.
						local size = Vector3.new(plan.width, 23.9, plan.depth)
						if
							inside
							and inside.id == district.id
							and CityPlan.onLand(far.Position)
							and not CityPlan.reserved(center.Position, plan.width / 2)
							and not blocked(center, size, params)
						then
							clearTrees(center, size, params)
							plan.build(k, parent, base)
							built += 1
							step = plan.width + 1
							if built % 40 == 0 then
								task.wait() -- keep the server responsive while the city builds
							end
						end
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
	for _, road in flatStreets() do
		local crossings = CityPlan.crossings(road)
		local function nearCrossing(along: number): boolean
			for _, c in crossings do
				if math.abs(c - along) < 30 then
					return true
				end
			end
			return false
		end
		local i = 0
		local along = road.from + 20
		local y = road.y0 + k.WALK_TOP
		while along < road.to - 20 do
			i += 1
			if not nearCrossing(along) then
				local side = if i % 2 == 0 then 1 else -1
				local off = side * (road.w / 2 + 1.6)
				local pos = if road.axis == "X"
					then Vector3.new(along, y, road.at + off)
					else Vector3.new(road.at + off, y, along)
				-- Lamp arm reaches over the road: yaw so local -Z points at it.
				local yaw = if road.axis == "X"
					then (if side > 0 then 0 else 180)
					else (if side > 0 then 90 else -90)
				if CityPlan.onLand(pos) and free(pos) then
					k.streetLight(parent, pos, yaw, i % 3 == 0)
				end
				local edge = -side * (road.w / 2 + 4)
				local extra = if road.axis == "X"
					then Vector3.new(along + 12, y, road.at + edge)
					else Vector3.new(road.at + edge, y, along + 12)
				if CityPlan.onLand(extra) and free(extra) then
					if i % 3 == 0 then
						k.hydrant(parent, extra)
					elseif i % 3 == 1 then
						k.trashCan(parent, extra, Color3.fromRGB(40, 60, 46))
					end
				end
			end
			along += if road.w >= 30 then 100 else 130
		end
	end
end

function Infill.build(k: Kit, parent: Instance): number
	local folder = Instance.new("Folder")
	folder.Name = "Infill"
	folder.Parent = parent
	local built = fillLots(k, folder)
	dressStreets(k, folder)
	-- Shop interiors still glow (neon), but only one in three casts real light:
	-- hundreds of lights cost too much on phones.
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("SurfaceLight") and d.Parent and d.Parent.Name == "Interior" then
			n += 1
			if n % 3 ~= 0 then
				d:Destroy()
			end
		end
	end
	return built
end

return Infill
