--!strict
-- Houses on Sunset Lane, and each player's storage. Every player owns the
-- free Trailer; Maple Realty sells other homes (Config.Houses), and owning
-- several you choose which one you live in.
--
-- No two players ever fight over a house: what you buy is the house *type*,
-- saved in your profile. The street's lots are handed out per server, one
-- free lot to each player as they join (8 lots, 8 players per server), and
-- your house type is built on whichever lot you got. Two players with the
-- same Villa simply get two Villas side by side.
--
-- Storage lives in the house (it used to be the Hideout shelf): the house's
-- storage holds Config.Houses[i].storage items; the most valuable ones stand
-- on the pedestals for visitors, who can like the house once per server.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Types = require(Shared.Types)
local ItemModels = require(Shared.ItemModels)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local World = require(script.Parent.World)

-- Footprint and look per house type (Config.Houses holds price and sizes).
type Style = {
	w: number,
	d: number,
	h: number,
	cols: number,
	wall: Color3,
	mat: Enum.Material,
	roof: string, -- "gable" | "flat" | "thatch" | "trailer"
	trim: Color3?,
	neon: boolean?,
	stilts: boolean?,
}
local STYLE: { [string]: Style } = {
	trailer = {
		w = 30,
		d = 16,
		h = 10,
		cols = 2,
		wall = Color3.fromRGB(214, 214, 204),
		mat = Enum.Material.DiamondPlate,
		roof = "trailer",
		trim = Color3.fromRGB(60, 120, 160),
	},
	starter = {
		w = 36,
		d = 30,
		h = 12,
		cols = 2,
		wall = Color3.fromRGB(170, 190, 200),
		mat = Enum.Material.WoodPlanks,
		roof = "gable",
	},
	bungalow = {
		w = 40,
		d = 30,
		h = 11,
		cols = 2,
		wall = Color3.fromRGB(240, 226, 196),
		mat = Enum.Material.WoodPlanks,
		roof = "thatch",
		stilts = true,
		trim = Color3.fromRGB(40, 150, 150),
	},
	family = {
		w = 46,
		d = 36,
		h = 14,
		cols = 4,
		wall = Color3.fromRGB(196, 170, 140),
		mat = Enum.Material.Brick,
		roof = "gable",
		trim = Color3.fromRGB(240, 240, 236),
	},
	loft = {
		w = 50,
		d = 40,
		h = 18,
		cols = 4,
		wall = Color3.fromRGB(40, 42, 52),
		mat = Enum.Material.Concrete,
		roof = "flat",
		neon = true,
	},
	villa = {
		w = 58,
		d = 44,
		h = 16,
		cols = 4,
		wall = Color3.fromRGB(232, 230, 224),
		mat = Enum.Material.Plaster,
		roof = "flat",
		trim = Color3.fromRGB(200, 170, 110),
	},
}

local function houseOf(profile: any): (any, Style)
	for _, h in Config.Houses do
		if h.id == profile.house then
			return h, STYLE[h.id] or STYLE.starter
		end
	end
	return Config.Houses[1], STYLE.trailer
end
local SETBACK = 12 -- lawn between sidewalk and the front wall
local STILT_LIFT = 3 -- the beach bungalow's floor height
local LIKE_RANGE = 18

type Lot = { cf: CFrame, owner: Player?, folder: Folder }

local lots: { Lot } = {}
local lotOf: { [Player]: Lot } = {}
local likedBy: { [Player]: { [Player]: boolean } } = {} -- owner -> likers this server

local Housing = {}

-- Lot front at the sidewalk edge; local -Z faces the street.
-- Config.Lots holds the lot frames (front of the lot, +Z away from the street).
local function lotFrame(spec: CFrame): CFrame
	return spec
end

local function forSaleSign(lot: Lot)
	local k = World.kit
	local cf = lot.cf * CFrame.new(10, 0, 4)
	k.box(lot.folder, "SignPost", cf, Vector3.new(0.5, 6, 0.5), k.C.darkMetal, k.M.Metal)
	local board = k.box(
		lot.folder,
		"ForSale",
		cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(6, 3.4, 0.3),
		Color3.fromRGB(176, 40, 32),
		k.M.SmoothPlastic
	)
	k.sign(
		board,
		Enum.NormalId.Back,
		"FOR SALE\nMaple Realty",
		Color3.fromRGB(176, 40, 32),
		k.C.white
	)
end

local function pedestalSpots(lot: Lot, shape: Style, slots: number): { CFrame }
	local rows = math.ceil(slots / shape.cols)
	local out = {}
	for i = 1, slots do
		local col = (i - 1) % shape.cols
		local row = math.floor((i - 1) / shape.cols)
		local x = (col - (shape.cols - 1) / 2) * ((shape.w - 14) / math.max(shape.cols - 1, 1))
		local z = SETBACK + 9 + row * ((shape.d - 16) / math.max(rows - 1, 1))
		table.insert(out, lot.cf * CFrame.new(x, 1.2 + (if shape.stilts then STILT_LIFT else 0), z))
	end
	return out
end

local function showItem(parent: Instance, spot: CFrame, entry: Types.BagItem)
	local item = Items.ById[entry.id]
	if not item then
		return
	end
	local model = ItemModels.trophy(
		entry.id,
		entry.mutation,
		3,
		spot * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.rad(30), 0)
	)
	local _, scaled = model:GetBoundingBox()
	model.Parent = parent
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(150, 36)
	tag.StudsOffset = Vector3.new(0, scaled.Y / 2 + 1.4, 0)
	tag.MaxDistance = 36
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Items.Rarities[item.rarity].color
	label.TextStrokeTransparency = 0.25
	label.Text = Items.label(entry.id, entry.mutation)
	label.Parent = tag
	tag.Parent = model.PrimaryPart
end

-- Furniture the owner bought (Config.Decor), each at its own spot. `base` is
-- the house centre on the floor; local -Z faces the street.
local function furnish(
	model: Model,
	base: CFrame,
	w: number,
	d: number,
	h: number,
	owned: { [string]: boolean }
)
	local k = World.kit
	local C, M = k.C, k.M
	local floor = base * CFrame.new(0, 1.2, 0)
	if owned.rug then
		k.box(
			model,
			"Rug",
			floor,
			Vector3.new(w * 0.45, 0.1, d * 0.4),
			Color3.fromRGB(150, 60, 70),
			M.Fabric
		)
	end
	if owned.plant then
		local spot = floor * CFrame.new(w / 2 - 3, 0, -d / 2 + 3)
		k.box(model, "Pot", spot, Vector3.new(2, 2, 2), Color3.fromRGB(170, 90, 60), M.Slate)
		local leaves = k.part(model, {
			Name = "Fern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.5, 4, 4.5),
			CFrame = spot * CFrame.new(0, 3.6, 0),
			Color = Color3.fromRGB(60, 130, 60),
			Material = M.Grass,
		})
		leaves.CanCollide = false
	end
	if owned.sofa then
		local spot = floor * CFrame.new(-w / 4, 0, d / 2 - 3)
		k.box(
			model,
			"SofaBase",
			spot,
			Vector3.new(9, 1.6, 3.4),
			Color3.fromRGB(90, 55, 40),
			M.Leather
		)
		k.box(
			model,
			"SofaBack",
			spot * CFrame.new(0, 1.6, 1.3),
			Vector3.new(9, 2.2, 0.8),
			Color3.fromRGB(90, 55, 40),
			M.Leather
		)
		for _, sx in { -1, 1 } do
			k.box(
				model,
				"SofaArm",
				spot * CFrame.new(sx * 4.3, 1.6, 0),
				Vector3.new(0.6, 1.2, 3.4),
				Color3.fromRGB(80, 48, 36),
				M.Leather
			)
		end
	end
	if owned.fridge then
		local spot = floor * CFrame.new(w / 2 - 3, 0, d / 2 - 2.5)
		k.box(
			model,
			"Fridge",
			spot,
			Vector3.new(3, 6.5, 2.6),
			Color3.fromRGB(120, 200, 190),
			M.SmoothPlastic
		)
		k.box(
			model,
			"FridgeHandle",
			spot * CFrame.new(-1, 3.2, -1.4),
			Vector3.new(0.2, 2, 0.2),
			C.metal,
			M.Metal
		)
	end
	if owned.arcade then
		local spot = floor * CFrame.new(-w / 2 + 2.5, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
		k.box(
			model,
			"Arcade",
			spot,
			Vector3.new(3, 6.4, 2.6),
			Color3.fromRGB(40, 30, 80),
			M.SmoothPlastic
		)
		local screen = k.box(
			model,
			"ArcadeScreen",
			spot * CFrame.new(0, 3.8, -1.35),
			Vector3.new(2.2, 1.8, 0.1),
			Color3.fromRGB(0, 230, 255),
			M.Neon
		)
		screen.CanCollide = false
	end
	if owned.neon then
		local sign = k.box(
			model,
			"NeonSign",
			floor * CFrame.new(0, h * 0.62, d / 2 - 0.9),
			Vector3.new(10, 2.2, 0.2),
			Color3.fromRGB(20, 10, 30),
			M.SmoothPlastic
		)
		sign.CanCollide = false
		k.sign(
			sign,
			Enum.NormalId.Front,
			"TRASH HUNTER",
			Color3.fromRGB(20, 10, 30),
			Color3.fromRGB(255, 60, 200)
		)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 60, 200)
		glow.Range = 14
		glow.Brightness = 1.2
		glow.Parent = sign
	end
	if owned.trophy then
		local spot = floor * CFrame.new(w / 2 - 2, 0, 0)
		k.box(model, "CaseBase", spot, Vector3.new(2.6, 2.4, 5), Color3.fromRGB(60, 40, 30), M.Wood)
		local glass = k.box(
			model,
			"CaseGlass",
			spot * CFrame.new(0, 2.4, 0),
			Vector3.new(2.4, 3.6, 4.8),
			C.glass,
			M.Glass
		)
		glass.Transparency = 0.7
		k.part(model, {
			Name = "Trophy",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 1.4, 1.4),
			CFrame = spot * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 60),
			Material = M.Foil,
		})
	end
end

-- Rebuilds the whole lot. Cheap enough: only on buy, upgrade, display and likes.
local function render(lot: Lot)
	lot.folder:ClearAllChildren()
	local owner = lot.owner
	local profile = owner and Data.get(owner)
	if not owner or not profile or profile.house == "" then
		forSaleSign(lot)
		return
	end
	local k = World.kit
	local C, M = k.C, k.M
	local spec, shape = houseOf(profile)
	local w, d, h = shape.w, shape.d, shape.h
	-- Beach bungalows stand on stilts: everything is lifted.
	local lift = if shape.stilts then STILT_LIFT else 0
	local base = lot.cf * CFrame.new(0, lift, SETBACK + d / 2)
	local villa = shape.roof == "flat"
	local wallColor = shape.wall
	local wallMat = shape.mat
	local model = Instance.new("Model")
	model.Name = "House"

	k.box(
		model,
		"Path",
		lot.cf * CFrame.new(0, 0, SETBACK / 2),
		Vector3.new(6, 0.3, SETBACK),
		C.concrete,
		M.Concrete
	)
	k.box(model, "Foundation", base, Vector3.new(w + 0.4, 1.2, d + 0.4), C.concreteDark, M.Concrete)
	k.box(
		model,
		"Floor",
		base * CFrame.new(0, 1.2, 0),
		Vector3.new(w - 1, 0.2, d - 1),
		Color3.fromRGB(150, 110, 74),
		M.WoodPlanks
	)
	-- Walls as panels so the room is walkable; the front has a doorway and a
	-- shop-style window so trophies show from the street.
	local t = 1
	k.box(
		model,
		"WallBack",
		base * CFrame.new(0, 1.2, d / 2 - t / 2),
		Vector3.new(w, h, t),
		wallColor,
		wallMat
	)
	for _, sx in { -1, 1 } do
		k.box(
			model,
			"WallSide",
			base * CFrame.new(sx * (w / 2 - t / 2), 1.2, 0),
			Vector3.new(t, h, d),
			wallColor,
			wallMat
		)
	end
	local front = base * CFrame.new(0, 1.2, -d / 2 + t / 2)
	local door = 8
	local sideW = (w - door) / 2
	-- Left of the door: solid wall; right of the door: low wall + big window.
	k.box(
		model,
		"WallFront",
		front * CFrame.new(-(door / 2 + sideW / 2), 0, 0),
		Vector3.new(sideW, h, t),
		wallColor,
		wallMat
	)
	k.box(
		model,
		"WallFront",
		front * CFrame.new(door / 2 + sideW / 2, 0, 0),
		Vector3.new(sideW, 3, t),
		wallColor,
		wallMat
	)
	local glass = k.box(
		model,
		"Window",
		front * CFrame.new(door / 2 + sideW / 2, 3, 0),
		Vector3.new(sideW, h - 5, 0.3),
		Color3.fromRGB(170, 200, 220),
		M.Glass
	)
	glass.Transparency = 0.6
	k.box(
		model,
		"WallFront",
		front * CFrame.new(door / 2 + sideW / 2, h - 2, 0),
		Vector3.new(sideW, 2, t),
		wallColor,
		wallMat
	)
	k.box(
		model,
		"Lintel",
		front * CFrame.new(0, 10, 0),
		Vector3.new(door, h - 10, t),
		wallColor,
		wallMat
	)

	local top = base * CFrame.new(0, 1.2 + h, 0)
	if shape.roof == "flat" then
		k.box(model, "Roof", top, Vector3.new(w + 2, 1, d + 2), C.concreteDark, M.Concrete)
		for _, sx in { -1, 1 } do
			k.box(
				model,
				"Parapet",
				top * CFrame.new(sx * (w / 2 + 0.5), 1, 0),
				Vector3.new(1, 1.6, d + 2),
				shape.trim or wallColor,
				M.Plaster
			)
		end
		if shape.neon then
			-- Neon Loft: glowing trim along the roofline and a rooftop sign.
			for _, sz in { -1, 1 } do
				local strip = k.box(
					model,
					"NeonTrim",
					top * CFrame.new(0, 0.4, sz * (d / 2 + 1.1)),
					Vector3.new(w + 2, 0.3, 0.3),
					Color3.fromRGB(255, 60, 200),
					M.Neon
				)
				strip.CanCollide = false
			end
			local glow = k.box(
				model,
				"NeonSide",
				base * CFrame.new(-w / 2 - 0.3, 1.2, 0),
				Vector3.new(0.3, h, 0.4),
				Color3.fromRGB(0, 230, 255),
				M.Neon
			)
			glow.CanCollide = false
		end
	elseif shape.roof == "trailer" then
		-- Rounded metal roof and a coloured band round the trailer.
		k.part(model, {
			Name = "Roof",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(w + 1, 6, d + 1),
			CFrame = top * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = wallColor,
			Material = M.DiamondPlate,
		})
		k.box(
			model,
			"Band",
			base * CFrame.new(0, 4, -d / 2 - 0.15),
			Vector3.new(w, 1.4, 0.3),
			shape.trim or C.white,
			M.SmoothPlastic
		)
	elseif shape.roof == "thatch" then
		k.gableRoof(model, top, w + 6, d + 6, 8, Color3.fromRGB(170, 140, 80))
	else
		k.gableRoof(model, top, w + 2, d + 2, if w > 40 then 9 else 7, Color3.fromRGB(70, 60, 56))
	end
	if villa then
		k.box(
			model,
			"Ceiling",
			top * CFrame.new(0, -0.2, 0),
			Vector3.new(w, 0.2, d),
			Color3.fromRGB(236, 232, 224),
			M.SmoothPlastic
		)
	end
	if shape.stilts then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				k.box(
					model,
					"Stilt",
					lot.cf * CFrame.new(sx * (w / 2 - 1), 0, SETBACK + d / 2 + sz * (d / 2 - 1)),
					Vector3.new(1, lift, 1),
					Color3.fromRGB(120, 90, 60),
					M.Wood
				)
			end
		end
		k.box(
			model,
			"Steps",
			lot.cf * CFrame.new(0, 0, SETBACK - 1.5),
			Vector3.new(8, lift + 1.2, 3),
			Color3.fromRGB(150, 110, 74),
			M.WoodPlanks
		)
	end
	if shape.trim and shape.roof == "gable" then
		k.box(
			model,
			"Shutter",
			base * CFrame.new(-w / 4, 4, -d / 2 - 0.3),
			Vector3.new(1, 6, 0.3),
			shape.trim,
			M.WoodPlanks
		)
	end
	local lamp = k.box(
		model,
		"Lamp",
		top * CFrame.new(0, -1.2, 0),
		Vector3.new(4, 0.4, 4),
		Color3.fromRGB(255, 244, 220),
		M.Neon
	)
	local glow = Instance.new("PointLight")
	glow.Range = math.max(w, d) * 0.8
	glow.Brightness = 1.2
	glow.Color = Color3.fromRGB(255, 236, 200)
	glow.Parent = lamp

	furnish(model, base, w, d, h, profile.decor)

	-- Storage chest: open it to move things between bag and house storage.
	local chest = k.box(
		model,
		"StorageChest",
		base * CFrame.new(w / 2 - 4, 1.2, d / 2 - 3),
		Vector3.new(5, 3, 3),
		Color3.fromRGB(110, 75, 45),
		M.Wood
	)
	local chestPrompt = Instance.new("ProximityPrompt")
	chestPrompt.Name = "StoragePrompt"
	chestPrompt.ActionText = "Open storage"
	chestPrompt.ObjectText = `{#profile.home}/{spec.storage} stored`
	chestPrompt.HoldDuration = 0
	chestPrompt.MaxActivationDistance = 10
	chestPrompt.RequiresLineOfSight = false
	chestPrompt.Parent = chest

	-- Pedestals show the most valuable things in storage.
	local showcase = table.clone(profile.home)
	table.sort(showcase, function(a, b)
		return Items.value(a.id, a.mutation) > Items.value(b.id, b.mutation)
	end)
	for i, spot in pedestalSpots(lot, shape, spec.pedestals) do
		k.box(
			model,
			"Pedestal",
			spot,
			Vector3.new(3, 3.4, 3),
			Color3.fromRGB(236, 234, 230),
			M.Marble
		)
		local entry = showcase[i]
		if entry then
			showItem(model, spot, entry)
		end
	end

	-- Mailbox with the name plate and the like prompt.
	local box = k.box(
		model,
		"Mailbox",
		lot.cf * CFrame.new(-6, 0, 2),
		Vector3.new(1.2, 4, 1.2),
		C.darkMetal,
		M.Metal
	)
	local plate = Instance.new("BillboardGui")
	plate.Size = UDim2.fromOffset(220, 50)
	plate.StudsOffset = Vector3.new(0, 4, 0)
	plate.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(246, 247, 249)
	label.TextStrokeTransparency = 0.3
	label.Text = `{owner.DisplayName}'s {spec.name}\n♥ {profile.likes}`
	label.Parent = plate
	plate.Parent = box
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ActionText = "Like"
	prompt.ObjectText = `{owner.DisplayName}'s house`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = LIKE_RANGE - 4
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	box:SetAttribute("Lot", table.find(lots, lot))
	model.Parent = lot.folder
end

local function assign(player: Player)
	local profile = Data.get(player)
	if lotOf[player] or not profile or profile.house == "" then
		return
	end
	for _, lot in lots do
		if not lot.owner then
			lot.owner = player
			lotOf[player] = lot
			render(lot)
			-- The map's "My house" button routes here.
			player:SetAttribute("HomePos", (lot.cf * CFrame.new(0, 0, SETBACK)).Position)
			return
		end
	end
end

local function release(player: Player)
	local lot = lotOf[player]
	lotOf[player] = nil
	likedBy[player] = nil
	for _, set in likedBy do
		set[player] = nil
	end
	if lot then
		lot.owner = nil
		render(lot)
	end
	player:SetAttribute("InOwnHouse", nil)
	player:SetAttribute("HomePos", nil)
end

-- Buys a house type, or moves into one you own (Maple Realty counter).
local function buyHouse(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local spec = nil
	for _, h in Config.Houses do
		if h.id == id then
			spec = h
		end
	end
	if not profile or not spec then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "house")
	if not ok then
		return false, message
	end
	if profile.house == spec.id then
		return false, "You already live there."
	end
	if not profile.houses[spec.id] then
		if profile.cash < spec.price then
			return false, `You need ${spec.price - profile.cash} more.`
		end
		profile.cash -= spec.price
		profile.houses[spec.id] = true
		Router.send(player, "bought", { name = spec.name })
	end
	if #profile.home > spec.storage then
		Data.push(player)
		return false,
			`Your storage holds {#profile.home} things; the {spec.name} fits {spec.storage}. Take some out first.`
	end
	profile.house = spec.id
	assign(player)
	local lot = lotOf[player]
	if lot then
		render(lot)
		Router.send(
			player,
			"routeTo",
			{ pos = (lot.cf * CFrame.new(0, 0, SETBACK)).Position, name = spec.name }
		)
	end
	Data.push(player)
	return true, if lot then `Moved into the {spec.name}. GPS set.` else nil
end

local function inOwnHouse(player: Player): boolean
	return player:GetAttribute("InOwnHouse") == true and not Guard.isFlagged(player)
end

local function homeDisplay(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile or profile.house == "" then
		return false, nil
	end
	if not inOwnHouse(player) then
		return false, "Stand inside your house to use its storage."
	end
	local spec = houseOf(profile)
	if #profile.home >= spec.storage then
		return false, "Storage is full. Bigger houses at Maple Realty hold more."
	end
	local entry = Data.removeItem(profile.backpack, uid)
	if not entry then
		return false, "That item is gone."
	end
	table.insert(profile.home, entry)
	local lot = lotOf[player]
	if lot then
		render(lot)
	end
	Data.push(player)
	return true, nil
end

local function homeTake(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	if not inOwnHouse(player) then
		return false, "Stand inside your house to use its storage."
	end
	if #profile.backpack >= Data.capacity(profile, player) then
		return false, "Backpack full."
	end
	local entry = Data.removeItem(profile.home, uid)
	if not entry then
		return false, "That item is gone."
	end
	table.insert(profile.backpack, entry)
	local lot = lotOf[player]
	if lot then
		render(lot)
	end
	Data.push(player)
	return true, nil
end

local function like(player: Player, index: any): (boolean, string?)
	if typeof(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return false, nil
	end
	local lot = lots[index]
	local owner = lot and lot.owner
	local ownerProfile = owner and Data.get(owner)
	if not lot or not owner or not ownerProfile then
		return false, nil
	end
	if owner == player then
		return false, "That's your own house."
	end
	if Guard.distance(player, (lot.cf * CFrame.new(-6, 0, 2)).Position) > LIKE_RANGE then
		return false, nil
	end
	local set = likedBy[owner]
	if not set then
		set = {}
		likedBy[owner] = set
	end
	if set[player] then
		return false, "You already liked this house."
	end
	set[player] = true
	ownerProfile.likes += 1
	render(lot)
	Router.send(owner, "liked", { by = player.DisplayName, likes = ownerProfile.likes })
	Data.push(player)
	return true, nil
end

-- Re-renders a player's house (new furniture).
function Housing.refresh(player: Player)
	local lot = lotOf[player]
	if lot then
		render(lot)
	end
end

function Housing.init()
	Router.on("buyHouse", 0.5, buyHouse)
	Router.on("homeDisplay", 0.2, homeDisplay)
	Router.on("homeTake", 0.2, homeTake)
	Router.on("likeHouse", 0.5, like)
end

function Housing.start()
	local folder = Instance.new("Folder")
	folder.Name = "Houses"
	folder.Parent = workspace:WaitForChild("Town")
	for i, spec in Config.Lots do
		local lotFolder = Instance.new("Folder")
		lotFolder.Name = "Lot" .. i
		lotFolder.Parent = folder
		local lot: Lot = { cf = lotFrame(spec), owner = nil, folder = lotFolder }
		lots[i] = lot
		render(lot)
	end
	Data.onLoaded(function(player)
		assign(player)
	end)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
	Data.onRelease(function(player)
		release(player)
	end)

	-- "Inside your own house" drives the pedestal actions on the client.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, lot in lotOf do
				local profile = Data.get(player)
				local root = Guard.root(player)
				local inside = false
				if profile and root and profile.house ~= "" then
					local _, shape = houseOf(profile)
					local rel = (lot.cf * CFrame.new(0, 0, SETBACK + shape.d / 2)):PointToObjectSpace(
						root.Position
					)
					inside = math.abs(rel.X) <= shape.w / 2 + 2
						and math.abs(rel.Z) <= shape.d / 2 + 2
				end
				if (player:GetAttribute("InOwnHouse") == true) ~= inside then
					player:SetAttribute("InOwnHouse", inside)
				end
			end
		end
	end)
end

return Housing
