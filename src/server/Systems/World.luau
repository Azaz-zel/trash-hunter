--!strict
-- Builds the Suburbs blockout at server start from Config.World, so the map
-- lives in git with the code. Stylized and saturated on purpose (GDD section 9).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Raccoon = require(Shared.Raccoon)

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

	-- A few lazy flies so dumpsters read as dumpsters from a distance.
	local flies = Instance.new("ParticleEmitter")
	flies.Name = "Flies"
	flies.Rate = 3
	flies.Lifetime = NumberRange.new(2, 3)
	flies.Speed = NumberRange.new(1, 2)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.RotSpeed = NumberRange.new(-200, 200)
	flies.Size = NumberSequence.new(0.18)
	flies.Color = ColorSequence.new(COLORS.ink)
	flies.Acceleration = Vector3.new(0, 0.6, 0)
	flies.Drag = 2
	flies.Parent = body

	local bagSpots = {
		Vector3.new(-4.6, -1.4, 0.6),
		Vector3.new(4.4, -1.5, -0.4),
		Vector3.new(-4.2, -1.6, -1.6),
	}
	for i, offset in bagSpots do
		local bag = part(model, {
			Name = "TrashBag",
			Size = Vector3.new(2, 1.8, 2) * (if i == 3 then 0.75 else 1),
			CFrame = base * CFrame.new(offset),
			Color = if i == 2 then Color3.fromRGB(60, 120, 70) else Color3.fromRGB(36, 38, 46),
			Material = Enum.Material.Plastic,
			CanCollide = false,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bag
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SearchPrompt"
	prompt.ActionText = "Search"
	prompt.ObjectText = if fancy then "Private Dumpster" else "Dumpster"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Search.RANGE - 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.PrimaryPart = body
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
	CollectionService:AddTag(head, "StreetLight")
end

local function buildMailbox(parent: Instance, pos: Vector3, color: Color3)
	part(parent, {
		Name = "MailPost",
		Size = Vector3.new(0.4, 3, 0.4),
		Position = pos + Vector3.new(0, 1.5, 0),
		Color = COLORS.shelf,
	})
	part(parent, {
		Name = "Mailbox",
		Size = Vector3.new(1.2, 1, 1.8),
		Position = pos + Vector3.new(0, 3.4, 0),
		Color = color,
	})
	part(parent, {
		Name = "Flag",
		Size = Vector3.new(0.1, 0.8, 0.3),
		Position = pos + Vector3.new(0.65, 3.8, 0.4),
		Color = COLORS.signRed,
	})
end

local function buildHydrant(parent: Instance, pos: Vector3)
	part(parent, {
		Name = "Hydrant",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 1.2, 1.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.signRed,
	})
	part(parent, {
		Name = "HydrantCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.2, 1.2, 1.2),
		Position = pos + Vector3.new(0, 2.5, 0),
		Color = COLORS.signRed,
	})
end

-- A string of colored bulbs: the cue that the Hideout is the cozy, safe place.
local function stringLights(parent: Instance, a: Vector3, b: Vector3, count: number)
	local palette = { COLORS.counter, COLORS.shop, Color3.fromRGB(255, 110, 150), COLORS.grass }
	for i = 0, count do
		local t = i / count
		local sag = math.sin(t * math.pi) * 1.2
		part(parent, {
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			Position = a:Lerp(b, t) - Vector3.new(0, sag, 0),
			Color = palette[i % #palette + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
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
		Size = Vector3.new(400, 0.2, 12),
		Position = Vector3.new(0, 0.1, 46),
		Color = COLORS.road,
	})
	part(ground, {
		Name = "Road",
		Size = Vector3.new(400, 0.2, 12),
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
		local color = houseColors[(i - 1) % #houseColors + 1]
		buildHouse(deco, h[1], color, h[2])
		local front = CFrame.new(h[1]) * CFrame.Angles(0, math.rad(h[2]), 0) * CFrame.new(5, 0, -13)
		buildMailbox(deco, front.Position, color)
	end
	for _, pos in
		{
			Vector3.new(-48, 0, 54),
			Vector3.new(48, 0, 38),
			Vector3.new(-48, 0, -28),
			Vector3.new(52, 0, -44),
		}
	do
		buildHydrant(deco, pos)
	end
	for _, x in { -150, -100, -50, 50, 100, 150 } do
		lamp(deco, Vector3.new(x, 0, 53))
		lamp(deco, Vector3.new(x, 0, -43))
	end
	lamp(deco, Vector3.new(-9, 0, 70))
	lamp(deco, Vector3.new(9, 0, 82))

	-- Hideout dressing: string lights, a beat-up couch, the mascot on the sign.
	local top = 7
	stringLights(
		hideout,
		c + Vector3.new(-half + 1, top, -half + 1),
		c + Vector3.new(half - 1, top, -half + 1),
		16
	)
	stringLights(
		hideout,
		c + Vector3.new(-half + 1, top, -half + 1),
		c + Vector3.new(-half + 1, top, half - 1),
		16
	)
	stringLights(
		hideout,
		c + Vector3.new(half - 1, top, -half + 1),
		c + Vector3.new(half - 1, top, half - 1),
		16
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(hideout, {
				Name = "LightPole",
				Size = Vector3.new(0.6, top + 0.5, 0.6),
				Position = c + Vector3.new(sx * (half - 1), (top + 0.5) / 2, sz * (half - 1)),
				Color = COLORS.fence,
			})
		end
	end
	local couch = Color3.fromRGB(196, 92, 60)
	part(hideout, {
		Name = "CouchSeat",
		Size = Vector3.new(8, 1.6, 3),
		Position = c + Vector3.new(0, 1.05, -14),
		Color = couch,
		Material = Enum.Material.Fabric,
	})
	part(hideout, {
		Name = "CouchBack",
		Size = Vector3.new(8, 2.6, 1),
		Position = c + Vector3.new(0, 2.5, -15.6),
		Color = couch,
		Material = Enum.Material.Fabric,
	})
	for _, x in { -4.4, 4.4 } do
		part(hideout, {
			Name = "CouchArm",
			Size = Vector3.new(1, 2.4, 3.4),
			Position = c + Vector3.new(x, 1.5, -14.2),
			Color = couch,
			Material = Enum.Material.Fabric,
		})
	end
	local mascot = Raccoon.build(1.8, false)
	mascot.Name = "Mascot"
	mascot:PivotTo(CFrame.new(c + Vector3.new(0, 12, half)) * CFrame.Angles(0, math.rad(180), 0))
	mascot.Parent = hideout
	local trophy = part(mascot, {
		Name = "GoldenPC",
		Size = Vector3.new(1.4, 1.8, 1.4),
		CFrame = CFrame.new(c + Vector3.new(1.8, 14.2, half + 2.6))
			* CFrame.Angles(0, math.rad(20), math.rad(-15)),
		Color = Color3.fromRGB(255, 216, 0),
		Material = Enum.Material.Foil,
	})
	local shine = Instance.new("PointLight")
	shine.Color = trophy.Color
	shine.Range = 10
	shine.Brightness = 1.5
	shine.Parent = trophy
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

	Lighting.ClockTime = Config.DayCycle.START
	Lighting.Brightness = 2.4
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local air = Instance.new("Atmosphere")
		air.Density = 0.32
		air.Offset = 0.1
		air.Color = Color3.fromRGB(205, 220, 240)
		air.Decay = Color3.fromRGB(120, 140, 180)
		air.Haze = 0.5
		air.Glare = 0
		air.Parent = Lighting
	end
	local terrain = workspace.Terrain
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Parent = terrain
	end
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	if not Lighting:FindFirstChild("TrashHunterGrade") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "TrashHunterGrade"
		grade.Saturation = 0.15
		grade.Contrast = 0.05
		grade.Parent = Lighting
	end
end

-- Day/night cycle. Street lights follow the time of day. Nights stay bright
-- enough to read on a phone, just bluer and moodier.
local function setLights(on: boolean)
	for _, head in CollectionService:GetTagged("StreetLight") do
		if head:IsA("BasePart") then
			head.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local light = head:FindFirstChildOfClass("SpotLight")
			if light then
				light.Enabled = on
			end
		end
	end
	workspace:SetAttribute("Night", on)
end

function World.start()
	local D = Config.DayCycle
	local STEP = 0.5
	local clock = D.START
	local lightsOn: boolean? = nil
	task.spawn(function()
		while true do
			local night = clock >= D.LIGHTS_ON or clock < D.LIGHTS_OFF
			if night ~= lightsOn then
				lightsOn = night
				setLights(night)
				Lighting.OutdoorAmbient = if night
					then Color3.fromRGB(110, 110, 160)
					else Color3.fromRGB(150, 140, 150)
			end
			task.wait(STEP)
			clock = (clock + 24 * STEP / D.DAY_LENGTH * (if night then D.NIGHT_SPEED else 1)) % 24
			Lighting.ClockTime = clock
		end
	end)
end

return World
