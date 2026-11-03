--!strict
-- Houses on Sunset Lane. Buying (and upgrading) happens at the Maple Realty
-- counter. Owners get a lot for the session; the house shows their best finds
-- on pedestals, and visitors can like it once per server.

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

-- Footprint and look per house level (Config.Houses holds price and slots).
local SHAPE = {
	{ w = 36, d = 30, h = 12, cols = 2 },
	{ w = 46, d = 36, h = 14, cols = 4 },
	{ w = 58, d = 44, h = 16, cols = 4 },
}
local SETBACK = 12 -- lawn between sidewalk and the front wall
local LIKE_RANGE = 18

type Lot = { cf: CFrame, owner: Player?, folder: Folder }

local lots: { Lot } = {}
local lotOf: { [Player]: Lot } = {}
local likedBy: { [Player]: { [Player]: boolean } } = {} -- owner -> likers this server

local Housing = {}

-- Lot front at the sidewalk edge; local -Z faces the street.
local function lotFrame(spec: any): CFrame
	return CFrame.new(spec.x, 0, Config.LOT_ROAD_Z)
		* CFrame.Angles(0, math.rad(spec.yaw), 0)
		* CFrame.new(0, 0, 31)
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

local function pedestalSpots(lot: Lot, level: number): { CFrame }
	local shape = SHAPE[level]
	local slots = Config.Houses[level].slots
	local rows = math.ceil(slots / shape.cols)
	local out = {}
	for i = 1, slots do
		local col = (i - 1) % shape.cols
		local row = math.floor((i - 1) / shape.cols)
		local x = (col - (shape.cols - 1) / 2) * ((shape.w - 14) / math.max(shape.cols - 1, 1))
		local z = SETBACK + 9 + row * ((shape.d - 16) / math.max(rows - 1, 1))
		table.insert(out, lot.cf * CFrame.new(x, 1.2, z))
	end
	return out
end

local function showItem(parent: Instance, spot: CFrame, entry: Types.BagItem)
	local item = Items.ById[entry.id]
	if not item then
		return
	end
	local model = ItemModels.build(entry.id, entry.mutation)
	local _, size = model:GetBoundingBox()
	local scale = math.min(1, 3 / math.max(size.X, size.Y, size.Z))
	model:ScaleTo(scale)
	local _, scaled = model:GetBoundingBox()
	model:PivotTo(spot * CFrame.new(0, 3.4 + scaled.Y / 2, 0) * CFrame.Angles(0, math.rad(30), 0))
	model.Name = "Trophy"
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

-- Rebuilds the whole lot. Cheap enough: only on buy, upgrade, display and likes.
local function render(lot: Lot)
	lot.folder:ClearAllChildren()
	local owner = lot.owner
	local profile = owner and Data.get(owner)
	if not owner or not profile or profile.houseLevel < 1 then
		forSaleSign(lot)
		return
	end
	local k = World.kit
	local C, M = k.C, k.M
	local level = profile.houseLevel
	local shape = SHAPE[level]
	local w, d, h = shape.w, shape.d, shape.h
	local base = lot.cf * CFrame.new(0, 0, SETBACK + d / 2)
	local villa = level >= 3
	local wallColor = if villa
		then Color3.fromRGB(232, 230, 224)
		elseif level == 2 then Color3.fromRGB(196, 170, 140)
		else Color3.fromRGB(170, 190, 200)
	local wallMat = if villa then M.Plaster else M.WoodPlanks
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
	if villa then
		k.box(model, "Roof", top, Vector3.new(w + 2, 1, d + 2), C.concreteDark, M.Concrete)
		for _, sx in { -1, 1 } do
			k.box(
				model,
				"Parapet",
				top * CFrame.new(sx * (w / 2 + 0.5), 1, 0),
				Vector3.new(1, 1.6, d + 2),
				wallColor,
				M.Plaster
			)
		end
	else
		k.gableRoof(
			model,
			top,
			w + 2,
			d + 2,
			if level == 2 then 9 else 7,
			Color3.fromRGB(70, 60, 56)
		)
		k.box(
			model,
			"Ceiling",
			top * CFrame.new(0, -0.2, 0),
			Vector3.new(w, 0.2, d),
			Color3.fromRGB(236, 232, 224),
			M.SmoothPlastic
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

	-- Pedestals with the owner's finds.
	for i, spot in pedestalSpots(lot, level) do
		k.box(
			model,
			"Pedestal",
			spot,
			Vector3.new(3, 3.4, 3),
			Color3.fromRGB(236, 234, 230),
			M.Marble
		)
		local entry = profile.home[i]
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
	label.Text = `{owner.DisplayName}'s {Config.Houses[level].name}\n♥ {profile.likes}`
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
	if lotOf[player] or not profile or profile.houseLevel < 1 then
		return
	end
	for _, lot in lots do
		if not lot.owner then
			lot.owner = player
			lotOf[player] = lot
			render(lot)
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
end

local function buyHouse(player: Player): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "house")
	if not ok then
		return false, message
	end
	local nextHouse = Config.Houses[profile.houseLevel + 1]
	if not nextHouse then
		return false, "You already own the best house."
	end
	if profile.cash < nextHouse.price then
		return false, `You need ${nextHouse.price - profile.cash} more.`
	end
	profile.cash -= nextHouse.price
	profile.houseLevel += 1
	assign(player)
	local lot = lotOf[player]
	if lot then
		render(lot)
	end
	Data.push(player)
	Router.send(player, "bought", { name = nextHouse.name })
	if not lot then
		Router.send(
			player,
			"toast",
			{ text = "Sunset Lane is full on this server. Your house shows up when a lot frees." }
		)
	end
	return true, nil
end

local function inOwnHouse(player: Player): boolean
	return player:GetAttribute("InOwnHouse") == true and not Guard.isFlagged(player)
end

local function homeDisplay(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile or profile.houseLevel < 1 then
		return false, nil
	end
	if not inOwnHouse(player) then
		return false, "Stand inside your house to set up the pedestals."
	end
	if #profile.home >= Config.Houses[profile.houseLevel].slots then
		return false, "Every pedestal is taken. Upgrade at Maple Realty for more."
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
		return false, "Stand inside your house to take things back."
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
				if profile and root and profile.houseLevel >= 1 then
					local shape = SHAPE[profile.houseLevel]
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
