--!strict
-- Builds the Trash Hunter raccoon mascot out of parts (no external assets).
-- Faces -Z. With `movable`, every part is welded to an anchored, invisible
-- Root so a single CFrame tween on Root moves the whole body.

local Raccoon = {}

local FUR = Color3.fromRGB(132, 132, 144)
local LIGHT = Color3.fromRGB(205, 205, 212)
local DARK = Color3.fromRGB(34, 34, 42)
local WHITE = Color3.fromRGB(250, 250, 250)

type Spec = {
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	sphere: boolean?,
	tilt: number?,
}

local SPECS: { Spec } = {
	{
		name = "Body",
		size = Vector3.new(2, 1.6, 2.8),
		pos = Vector3.new(0, 1.1, 0.2),
		color = FUR,
		sphere = true,
	},
	{
		name = "Belly",
		size = Vector3.new(1.4, 1.1, 2),
		pos = Vector3.new(0, 0.95, -0.1),
		color = LIGHT,
		sphere = true,
	},
	{
		name = "Head",
		size = Vector3.new(1.6, 1.4, 1.5),
		pos = Vector3.new(0, 1.95, -1.3),
		color = FUR,
		sphere = true,
	},
	{
		name = "Mask",
		size = Vector3.new(1.55, 0.5, 1.1),
		pos = Vector3.new(0, 2.05, -1.65),
		color = DARK,
		sphere = true,
	},
	{
		name = "Snout",
		size = Vector3.new(0.7, 0.5, 0.7),
		pos = Vector3.new(0, 1.75, -1.95),
		color = LIGHT,
		sphere = true,
	},
	{
		name = "Nose",
		size = Vector3.new(0.3, 0.25, 0.25),
		pos = Vector3.new(0, 1.85, -2.3),
		color = DARK,
		sphere = true,
	},
	{
		name = "EyeL",
		size = Vector3.new(0.34, 0.34, 0.2),
		pos = Vector3.new(-0.34, 2.08, -2.12),
		color = WHITE,
		sphere = true,
	},
	{
		name = "EyeR",
		size = Vector3.new(0.34, 0.34, 0.2),
		pos = Vector3.new(0.34, 2.08, -2.12),
		color = WHITE,
		sphere = true,
	},
	{
		name = "PupilL",
		size = Vector3.new(0.16, 0.16, 0.1),
		pos = Vector3.new(-0.34, 2.08, -2.22),
		color = DARK,
		sphere = true,
	},
	{
		name = "PupilR",
		size = Vector3.new(0.16, 0.16, 0.1),
		pos = Vector3.new(0.34, 2.08, -2.22),
		color = DARK,
		sphere = true,
	},
	{
		name = "EarL",
		size = Vector3.new(0.5, 0.6, 0.3),
		pos = Vector3.new(-0.55, 2.6, -1.2),
		color = FUR,
		sphere = true,
	},
	{
		name = "EarR",
		size = Vector3.new(0.5, 0.6, 0.3),
		pos = Vector3.new(0.55, 2.6, -1.2),
		color = FUR,
		sphere = true,
	},
	{
		name = "LegFL",
		size = Vector3.new(0.4, 0.7, 0.4),
		pos = Vector3.new(-0.6, 0.35, -0.8),
		color = DARK,
	},
	{
		name = "LegFR",
		size = Vector3.new(0.4, 0.7, 0.4),
		pos = Vector3.new(0.6, 0.35, -0.8),
		color = DARK,
	},
	{
		name = "LegBL",
		size = Vector3.new(0.4, 0.7, 0.4),
		pos = Vector3.new(-0.6, 0.35, 1),
		color = DARK,
	},
	{
		name = "LegBR",
		size = Vector3.new(0.4, 0.7, 0.4),
		pos = Vector3.new(0.6, 0.35, 1),
		color = DARK,
	},
	{
		name = "Tail1",
		size = Vector3.new(0.65, 0.65, 0.9),
		pos = Vector3.new(0, 1.35, 1.75),
		color = FUR,
		sphere = true,
		tilt = 25,
	},
	{
		name = "Tail2",
		size = Vector3.new(0.65, 0.65, 0.9),
		pos = Vector3.new(0, 1.7, 2.4),
		color = DARK,
		sphere = true,
		tilt = 35,
	},
	{
		name = "Tail3",
		size = Vector3.new(0.6, 0.6, 0.9),
		pos = Vector3.new(0, 2.15, 2.95),
		color = FUR,
		sphere = true,
		tilt = 45,
	},
	{
		name = "Tail4",
		size = Vector3.new(0.5, 0.5, 0.7),
		pos = Vector3.new(0, 2.6, 3.35),
		color = DARK,
		sphere = true,
		tilt = 60,
	},
}

function Raccoon.build(scale: number, movable: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Raccoon"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1) * scale
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in SPECS do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Size = spec.size * scale
		p.Color = spec.color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = spec.name == "Body"
		p.CFrame = CFrame.new(spec.pos * scale) * CFrame.Angles(math.rad(spec.tilt or 0), 0, 0)
		if spec.sphere then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		if movable then
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		else
			p.Anchored = true
		end
		p.Parent = model
	end
	return model
end

return Raccoon
