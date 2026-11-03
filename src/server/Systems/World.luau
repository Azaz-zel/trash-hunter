--!strict
-- Builds the Suburbs blockout at server start from Config.World, so the map
-- lives in git with the code. Stylized and saturated on purpose (GDD section 9).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local W = Config.World
local FONT = Enum.Font.FredokaOne

local COLORS = {
	grass = Color3.fromRGB(116, 196, 92),
	road = Color3.fromRGB(64, 66, 78),
	hideout = Color3.fromRGB(232, 178, 92),
	fence = Color3.fromRGB(96, 104, 120),
	redFloor = Color3.fromRGB(176, 40, 44),
	redWall = Color3.fromRGB(70, 70, 82),
	dumpster = Color3.fromRGB(38, 120, 66),
	dumpsterLid = Color3.fromRGB(26, 84, 46),
	fancyDumpster = Color3.fromRGB(40, 72, 140),
	fancyLid = Color3.fromRGB(28, 50, 100),
	counter = Color3.fromRGB(255, 200, 48),
	shop = Color3.fromRGB(80, 170, 255),
	shelf = Color3.fromRGB(150, 98, 60),
	cream = Color3.fromRGB(250, 244, 228),
	ink = Color3.fromRGB(28, 30, 44),
	signRed = Color3.fromRGB(200, 40, 40),
}

local World = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function sign(target: BasePart, face: Enum.NormalId, text: string, bg: Color3, fg: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg
	label.TextColor3 = fg
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = target
end

-- A wall along one axis from a to b (flat XZ points), with an optional gap.
local function wall(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	height: number,
	color: Color3,
	gap: NumberRange?
)
	local alongX = math.abs(b.X - a.X) > math.abs(b.Z - a.Z)
	local lo = if alongX then math.min(a.X, b.X) else math.min(a.Z, b.Z)
	local hi = if alongX then math.max(a.X, b.X) else math.max(a.Z, b.Z)
	local spans = if gap then { { lo, gap.Min }, { gap.Max, hi } } else { { lo, hi } }
	for _, span in spans do
		local length = span[2] - span[1]
		if length <= 0 then
			continue
		end
		local mid = (span[1] + span[2]) / 2
		part(parent, {
			Name = "Wall",
			Size = if alongX
				then Vector3.new(length, height, 1)
				else Vector3.new(1, height, length),
			Position = if alongX
				then Vector3.new(mid, height / 2, a.Z)
				else Vector3.new(a.X, height / 2, mid),
			Color = color,
			Material = Enum.Material.DiamondPlate,
		})
	end
end

local function buildDumpster(
	parent: Instance,
	spec: { pos: Vector3, zone: string, tutorial: boolean? }
): Model
	local model = Instance.new("Model")
	model.Name = if spec.tutorial then "TutorialDumpster" else "Dumpster"
	local fancy = spec.zone == "Red"
	local facing = Vector3.new(W.HIDEOUT_CENTER.X, 0, W.HIDEOUT_CENTER.Z)
	if fancy then
		facing = Vector3.new(W.RED_CENTER.X, 0, W.RED_CENTER.Z)
	end
	if (facing - spec.pos).Magnitude < 1 then
		facing = spec.pos + Vector3.new(0, 0, -1)
	end
	local base =
		CFrame.lookAt(spec.pos + Vector3.new(0, 2.2, 0), Vector3.new(facing.X, 2.2, facing.Z))

	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(7, 4, 4.5),
		CFrame = base,
		Color = if fancy then COLORS.fancyDumpster else COLORS.dumpster,
		Material = Enum.Material.Metal,
	})
	-- Lid hinges on the back (+Z) edge; the client rotates it open locally.
	part(model, {
		Name = "Lid",
		Size = Vector3.new(7.3, 0.4, 4.8),
		CFrame = base * CFrame.new(0, 2.2, 0),
		Color = if fancy then COLORS.fancyLid else COLORS.dumpsterLid,
		Material = Enum.Material.Metal,
	})
	for _, x in { -2.8, 2.8 } do
		part(model, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 1, 1),
			CFrame = base * CFrame.new(x, -2.1, -1.6) * CFrame.Angles(0, math.rad(90), 0),
			Color = COLORS.ink,
		})
	end

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Enabled = false
	light.Range = 16
	light.Brightness = 0
	light.Parent = body

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Enabled = false
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Speed = NumberRange.new(14, 24)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.Lifetime = NumberRange.new(0.6, 1.1)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Acceleration = Vector3.new(0, -30, 0)
	burst.LightEmission = 0.6
	burst.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SearchPrompt"
	prompt.ActionText = "Search"
	prompt.ObjectText = if fancy then "Private Dumpster" else "Dumpster"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Search.RANGE - 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("Zone", spec.zone)
	model:SetAttribute("Tutorial", spec.tutorial == true)
	model.Parent = parent
	CollectionService:AddTag(model, "Dumpster")
	return model
end

local function buildShelf(parent: Instance, index: number, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Shelf" .. index
	local cf = CFrame.lookAt(pos, Vector3.new(W.HIDEOUT_CENTER.X, pos.Y, W.HIDEOUT_CENTER.Z))
	local back = part(model, {
		Name = "Back",
		Size = Vector3.new(7, 6, 0.6),
		CFrame = cf * CFrame.new(0, 3, 0.9),
		Color = COLORS.shelf,
		Material = Enum.Material.Wood,
	})
	local board = part(model, {
		Name = "Board",
		Size = Vector3.new(7, 0.5, 2.2),
		CFrame = cf * CFrame.new(0, 2.5, 0),
		Color = COLORS.shelf,
		Material = Enum.Material.Wood,
	})
	for i, x in { -2.3, 0, 2.3 } do
		local slot = Instance.new("Attachment")
		slot.Name = "Slot" .. i
		slot.Position = Vector3.new(x, 1.2, 0)
		slot.Parent = board
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "OwnerTag"
	tag.Size = UDim2.fromOffset(220, 40)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.MaxDistance = 80
	tag.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = COLORS.cream
	label.TextStrokeTransparency = 0.3
	label.Parent = tag
	tag.Parent = back
	model.PrimaryPart = board
	model.Parent = parent
end

local function buildHouse(parent: Instance, pos: Vector3, color: Color3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	part(parent, {
		Name = "House",
		Size = Vector3.new(20, 12, 16),
		CFrame = cf * CFrame.new(0, 6, 0),
		Color = color,
	})
	for _, side in { -1, 1 } do
		part(parent, {
			Name = "Roof",
			Size = Vector3.new(22, 1, 11),
			CFrame = cf * CFrame.new(0, 15, side * 4.3) * CFrame.Angles(math.rad(side * 35), 0, 0),
			Color = Color3.fromRGB(150, 60, 50),
		})
	end
	part(parent, {
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = cf * CFrame.new(0, 3.5, -8.1),
		Color = COLORS.ink,
	})
end

local function buildTree(parent: Instance, pos: Vector3)
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 76, 48),
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		Position = pos + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(70, 160, 70),
	})
end

local function lamp(parent: Instance, pos: Vector3)
	part(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.8, 14, 0.8),
		Position = pos + Vector3.new(0, 7, 0),
		Color = COLORS.redWall,
	})
	local head = part(parent, {
		Name = "LampHead",
		Size = Vector3.new(2, 1, 2),
		Position = pos + Vector3.new(0, 14.5, 0),
		Color = Color3.fromRGB(255, 236, 160),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 70
	light.Range = 28
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Parent = head
end

function World.init()
	local old = workspace:FindFirstChild("Town")
	if old then
		old:Destroy()
	end
	local town = Instance.new("Folder")
	town.Name = "Town"

	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = town
	part(ground, {
		Name = "Grass",
		Size = Vector3.new(420, 1, 420),
		Position = Vector3.new(0, -0.45, 0),
		Color = COLORS.grass,
	})
	part(ground, {
		Name = "Road",
		Size = Vector3.new(14, 0.2, 70),
		Position = Vector3.new(0, 0.1, 57),
		Color = COLORS.road,
	})
	part(ground, {
		Name = "Road",
		Size = Vector3.new(220, 0.2, 12),
		Position = Vector3.new(0, 0.1, 46),
		Color = COLORS.road,
	})
	part(ground, {
		Name = "Road",
		Size = Vector3.new(220, 0.2, 12),
		Position = Vector3.new(0, 0.1, -36),
		Color = COLORS.road,
	})

	-- Hideout
	local hideout = Instance.new("Folder")
	hideout.Name = "Hideout"
	hideout.Parent = town
	local size = W.HIDEOUT_SIZE
	local c = W.HIDEOUT_CENTER
	part(hideout, {
		Name = "Floor",
		Size = Vector3.new(size, 0.5, size),
		Position = c + Vector3.new(0, 0.05, 0),
		Color = COLORS.hideout,
		Material = Enum.Material.WoodPlanks,
	})
	local half = size / 2
	local gap = NumberRange.new(-6, 6)
	wall(
		hideout,
		c + Vector3.new(-half, 0, -half),
		c + Vector3.new(half, 0, -half),
		3,
		COLORS.fence,
		nil
	)
	wall(
		hideout,
		c + Vector3.new(-half, 0, half),
		c + Vector3.new(half, 0, half),
		3,
		COLORS.fence,
		NumberRange.new(c.X - 6, c.X + 6)
	)
	wall(
		hideout,
		c + Vector3.new(-half, 0, -half),
		c + Vector3.new(-half, 0, half),
		3,
		COLORS.fence,
		NumberRange.new(c.Z + gap.Min, c.Z + gap.Max)
	)
	wall(
		hideout,
		c + Vector3.new(half, 0, -half),
		c + Vector3.new(half, 0, half),
		3,
		COLORS.fence,
		NumberRange.new(c.Z + gap.Min, c.Z + gap.Max)
	)

	local arch = part(hideout, {
		Name = "HideoutSign",
		Size = Vector3.new(16, 4, 0.6),
		Position = c + Vector3.new(0, 10, half),
		Color = COLORS.ink,
	})
	sign(arch, Enum.NormalId.Back, "HIDEOUT", COLORS.ink, COLORS.counter)
	sign(arch, Enum.NormalId.Front, "HIDEOUT", COLORS.ink, COLORS.counter)
	for _, x in { -8.5, 8.5 } do
		part(hideout, {
			Name = "Pole",
			Size = Vector3.new(1, 12, 1),
			Position = c + Vector3.new(x, 6, half),
			Color = COLORS.fence,
		})
	end

	local counter = part(hideout, {
		Name = "SellCounter",
		Size = Vector3.new(8, 3.5, 3),
		Position = W.SELL_POINT + Vector3.new(0, 1.75, 0),
		Color = COLORS.counter,
	})
	sign(counter, Enum.NormalId.Back, "SELL", COLORS.counter, COLORS.ink)
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell & Display"
	sellPrompt.ObjectText = "Pawn Counter"
	sellPrompt.HoldDuration = 0
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = counter

	local shop = part(hideout, {
		Name = "UpgradeShop",
		Size = Vector3.new(8, 3.5, 3),
		Position = W.SHOP_POINT + Vector3.new(0, 1.75, 0),
		Color = COLORS.shop,
	})
	sign(shop, Enum.NormalId.Back, "UPGRADES", COLORS.shop, COLORS.ink)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Upgrades"
	shopPrompt.ObjectText = "Gear Shop"
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shop

	local shelves = Instance.new("Folder")
	shelves.Name = "Shelves"
	shelves.Parent = hideout
	local edge = half - 3
	local shelfSpots = {
		Vector3.new(-edge, 0, -2),
		Vector3.new(-edge, 0, 8),
		Vector3.new(-edge, 0, 16),
		Vector3.new(edge, 0, -2),
		Vector3.new(edge, 0, 8),
		Vector3.new(edge, 0, 16),
		Vector3.new(-4, 0, -edge),
		Vector3.new(4, 0, -edge),
	}
	for i, spot in shelfSpots do
		buildShelf(shelves, i, c + spot)
	end

	-- Red zone: fenced private lot with clear warnings (GDD section 5).
	local red = Instance.new("Folder")
	red.Name = "RedZone"
	red.Parent = town
	local rc = W.RED_CENTER
	local hx, hz = W.RED_SIZE.X / 2, W.RED_SIZE.Y / 2
	part(red, {
		Name = "Floor",
		Size = Vector3.new(W.RED_SIZE.X, 0.4, W.RED_SIZE.Y),
		Position = rc + Vector3.new(0, 0.05, 0),
		Color = COLORS.redFloor,
	})
	wall(
		red,
		rc + Vector3.new(-hx, 0, -hz),
		rc + Vector3.new(hx, 0, -hz),
		9,
		COLORS.redWall,
		NumberRange.new(rc.X - 6, rc.X + 6)
	)
	wall(red, rc + Vector3.new(-hx, 0, hz), rc + Vector3.new(hx, 0, hz), 9, COLORS.redWall, nil)
	wall(
		red,
		rc + Vector3.new(hx, 0, -hz),
		rc + Vector3.new(hx, 0, hz),
		9,
		COLORS.redWall,
		NumberRange.new(rc.Z - 10, rc.Z + 2)
	)
	wall(
		red,
		rc + Vector3.new(-hx, 0, -hz),
		rc + Vector3.new(-hx, 0, hz),
		9,
		COLORS.redWall,
		NumberRange.new(rc.Z + 10, rc.Z + 22)
	)
	for _, x in { -20, 20 } do
		local board = part(red, {
			Name = "KeepOut",
			Size = Vector3.new(14, 5, 0.3),
			Position = rc + Vector3.new(x, 5, -hz - 0.7),
			Color = COLORS.signRed,
		})
		sign(board, Enum.NormalId.Front, "PRIVATE PROPERTY\nKEEP OUT", COLORS.signRed, COLORS.cream)
	end
	for _, corner in
		{
			Vector3.new(-hx + 3, 0, -hz + 3),
			Vector3.new(hx - 3, 0, -hz + 3),
			Vector3.new(-hx + 3, 0, hz - 3),
			Vector3.new(hx - 3, 0, hz - 3),
		}
	do
		lamp(red, rc + corner)
	end

	local dumpsters = Instance.new("Folder")
	dumpsters.Name = "Dumpsters"
	dumpsters.Parent = town
	for _, spec in W.Dumpsters do
		buildDumpster(dumpsters, spec)
	end

	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = town
	local houseColors = {
		Color3.fromRGB(240, 220, 160),
		Color3.fromRGB(170, 210, 240),
		Color3.fromRGB(240, 170, 170),
		Color3.fromRGB(200, 230, 170),
	}
	local houses = {
		{ Vector3.new(-95, 0, 20), 90 },
		{ Vector3.new(-95, 0, -60), 90 },
		{ Vector3.new(95, 0, 20), -90 },
		{ Vector3.new(95, 0, -60), -90 },
		{ Vector3.new(-40, 0, -80), 0 },
		{ Vector3.new(40, 0, -80), 0 },
	}
	for i, h in houses do
		buildHouse(deco, h[1], houseColors[(i - 1) % #houseColors + 1], h[2])
	end
	for _, pos in
		{
			Vector3.new(-30, 0, 70),
			Vector3.new(30, 0, 72),
			Vector3.new(-75, 0, 60),
			Vector3.new(75, 0, 62),
			Vector3.new(-70, 0, -15),
			Vector3.new(70, 0, -12),
			Vector3.new(-20, 0, -60),
			Vector3.new(22, 0, -58),
		}
	do
		buildTree(deco, pos)
	end

	town.Parent = workspace

	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Parent = workspace
	end
	local sp = spawn :: SpawnLocation
	sp.Anchored = true
	sp.Size = Vector3.new(8, 1, 8)
	sp.Position = c + Vector3.new(0, 0.6, 8)
	sp.Neutral = true
	sp.Duration = 0
	sp.Color = COLORS.counter
	sp.Transparency = 0.2
	local decal = sp:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1 -- the Town ground replaces it
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end

	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	if not Lighting:FindFirstChild("TrashHunterGrade") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "TrashHunterGrade"
		grade.Saturation = 0.15
		grade.Contrast = 0.05
		grade.Parent = Lighting
	end
end

return World
