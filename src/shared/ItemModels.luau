--!strict
-- Small part-built 3D models for every item, used as "pictures" in
-- ViewportFrames (bag, collection book, reveal card) and on display shelves.
-- No external assets: each model is a handful of primitives with real-world
-- materials. Models are centered on the origin, roughly 4 studs across.

local Items = require(script.Parent.Items)

local M = Enum.Material

type Spec = {
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	rot: Vector3?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local SPECS: { [string]: { Spec } } = {
	pumpkin = {
		{
			size = v(3.2, 3, 3.2),
			pos = v(0, 0, 0),
			color = rgb(240, 120, 20),
			material = M.SmoothPlastic,
			shape = BALL,
		},
		{
			size = v(0.5, 0.9, 0.5),
			pos = v(0, 1.7, 0),
			color = rgb(70, 110, 40),
			material = M.Wood,
		},
		{
			size = v(0.5, 0.5, 0.2),
			pos = v(-0.7, 0.4, -1.5),
			color = rgb(255, 220, 80),
			material = M.Neon,
		},
		{
			size = v(0.5, 0.5, 0.2),
			pos = v(0.7, 0.4, -1.5),
			color = rgb(255, 220, 80),
			material = M.Neon,
		},
		{
			size = v(1.4, 0.4, 0.2),
			pos = v(0, -0.5, -1.5),
			color = rgb(255, 220, 80),
			material = M.Neon,
		},
	},
	cape = {
		{
			size = v(3.4, 3.6, 0.4),
			pos = v(0, -0.2, 0.3),
			color = rgb(20, 20, 26),
			material = M.Fabric,
		},
		{
			size = v(3.2, 3.4, 0.2),
			pos = v(0, -0.2, 0),
			color = rgb(160, 10, 20),
			material = M.Fabric,
		},
		{
			size = v(3.6, 0.8, 0.8),
			pos = v(0, 1.8, 0.1),
			color = rgb(20, 20, 26),
			material = M.Fabric,
			rot = v(-20, 0, 0),
		},
	},
	doll = {
		{
			size = v(1.6, 2, 1.2),
			pos = v(0, -0.6, 0),
			color = rgb(230, 225, 210),
			material = M.Fabric,
		},
		{
			size = v(1.4, 1.4, 1.4),
			pos = v(0, 1, 0),
			color = rgb(240, 220, 200),
			material = M.SmoothPlastic,
			shape = BALL,
		},
		{
			size = v(1.5, 0.7, 1.5),
			pos = v(0, 1.5, 0.1),
			color = rgb(30, 20, 20),
			material = M.Fabric,
		},
		{
			size = v(0.2, 0.2, 0.1),
			pos = v(-0.3, 1.1, -0.7),
			color = rgb(255, 30, 40),
			material = M.Neon,
		},
		{
			size = v(0.2, 0.2, 0.1),
			pos = v(0.3, 1.1, -0.7),
			color = rgb(255, 30, 40),
			material = M.Neon,
		},
	},
	snowglobe = {
		{
			size = v(0.8, 2.4, 2.4),
			pos = v(0, -1.1, 0),
			color = rgb(110, 70, 40),
			material = M.Wood,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(2.8, 2.8, 2.8),
			pos = v(0, 0.6, 0),
			color = rgb(200, 230, 255),
			material = M.Glass,
			shape = BALL,
		},
		{
			size = v(0.6, 1.2, 0.6),
			pos = v(0, 0.4, 0),
			color = rgb(40, 120, 60),
			material = M.SmoothPlastic,
		},
		{
			size = v(1.6, 0.3, 1.6),
			pos = v(0, -0.3, 0),
			color = rgb(250, 250, 255),
			material = M.Snow,
		},
	},
	ornament = {
		{
			size = v(2.8, 2.8, 2.8),
			pos = v(0, -0.2, 0),
			color = rgb(255, 200, 60),
			material = M.Foil,
			shape = BALL,
		},
		{
			size = v(0.8, 0.5, 0.8),
			pos = v(0, 1.4, 0),
			color = rgb(180, 180, 190),
			material = M.Metal,
		},
		{
			size = v(0.15, 0.8, 0.8),
			pos = v(0, 1.9, 0),
			color = rgb(180, 180, 190),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 90, 0),
		},
	},
	nutcracker = {
		{
			size = v(1.6, 2.2, 1.2),
			pos = v(0, -0.6, 0),
			color = rgb(190, 20, 30),
			material = M.SmoothPlastic,
		},
		{
			size = v(1.2, 1.2, 1.2),
			pos = v(0, 1, 0),
			color = rgb(240, 210, 180),
			material = M.SmoothPlastic,
		},
		{
			size = v(1.2, 1.4, 1.2),
			pos = v(0, 2.2, 0),
			color = rgb(20, 20, 26),
			material = M.Fabric,
		},
		{
			size = v(1.3, 0.5, 0.3),
			pos = v(0, 0.6, -0.6),
			color = rgb(245, 245, 245),
			material = M.Fabric,
		},
		{
			size = v(1.8, 0.3, 1.4),
			pos = v(0, 0.3, 0),
			color = rgb(255, 200, 60),
			material = M.Foil,
		},
	},
	cardboard = {
		{
			size = v(3.6, 2.4, 2.6),
			pos = v(0, 0, 0),
			color = rgb(176, 136, 92),
			material = M.Cardboard,
		},
		{
			size = v(3.7, 0.15, 1.4),
			pos = v(0, 1.25, -0.7),
			color = rgb(150, 114, 74),
			material = M.Cardboard,
			rot = v(-25, 0, 0),
		},
		{
			size = v(3.8, 0.3, 0.4),
			pos = v(0, 0.2, -1.31),
			color = rgb(206, 196, 170),
			material = M.Fabric,
		},
	},
	can = {
		{
			size = v(2.4, 1.3, 1.3),
			pos = v(0, 0, 0),
			color = rgb(196, 40, 40),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.15, 1.2, 1.2),
			pos = v(0, 1.25, 0),
			color = rgb(200, 200, 204),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
	},
	bottle = {
		{
			size = v(2.4, 1.2, 1.2),
			pos = v(0, -0.4, 0),
			color = rgb(60, 130, 80),
			material = M.Glass,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(1.4, 0.5, 0.5),
			pos = v(0, 1.4, 0),
			color = rgb(60, 130, 80),
			material = M.Glass,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(1, 1.25, 0.02),
			pos = v(0, -0.4, -0.61),
			color = rgb(230, 220, 190),
			material = M.Fabric,
		},
	},
	shoe = {
		{
			size = v(1.4, 0.4, 3.4),
			pos = v(0, -0.6, 0),
			color = rgb(240, 240, 236),
			material = M.Rubber,
		},
		{
			size = v(1.3, 1, 2.4),
			pos = v(0, 0, 0.4),
			color = rgb(40, 60, 110),
			material = M.Fabric,
		},
		{
			size = v(1.2, 1.2, 1),
			pos = v(0, 0.6, 1.1),
			color = rgb(40, 60, 110),
			material = M.Fabric,
		},
	},
	hoodie = {
		{ size = v(3, 3, 0.9), pos = v(0, 0, 0), color = rgb(120, 120, 128), material = M.Fabric },
		{
			size = v(0.9, 2.8, 0.8),
			pos = v(-1.9, -0.1, 0),
			color = rgb(110, 110, 118),
			material = M.Fabric,
			rot = v(0, 0, -12),
		},
		{
			size = v(0.9, 2.8, 0.8),
			pos = v(1.9, -0.1, 0),
			color = rgb(110, 110, 118),
			material = M.Fabric,
			rot = v(0, 0, 12),
		},
		{
			size = v(1.6, 1.2, 1),
			pos = v(0, 1.8, 0.2),
			color = rgb(104, 104, 112),
			material = M.Fabric,
		},
	},
	toolbox = {
		{
			size = v(3.6, 1.8, 1.8),
			pos = v(0, 0, 0),
			color = rgb(176, 40, 32),
			material = M.CorrodedMetal,
		},
		{
			size = v(1.6, 0.25, 0.3),
			pos = v(0, 1.3, 0),
			color = rgb(40, 40, 44),
			material = M.Metal,
		},
		{
			size = v(0.25, 0.5, 0.3),
			pos = v(-0.7, 1.05, 0),
			color = rgb(40, 40, 44),
			material = M.Metal,
		},
		{
			size = v(0.25, 0.5, 0.3),
			pos = v(0.7, 1.05, 0),
			color = rgb(40, 40, 44),
			material = M.Metal,
		},
	},
	gnome = {
		{
			size = v(1.8, 1.8, 1.8),
			pos = v(0, -0.8, 0),
			color = rgb(40, 90, 160),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(1.2, 1.2, 1.2),
			pos = v(0, 0.5, 0),
			color = rgb(240, 200, 170),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(1, 1.6, 1),
			pos = v(0, 1.6, 0),
			color = rgb(200, 40, 40),
			material = M.Plastic,
			rot = v(0, 45, 0),
		},
		{
			size = v(0.9, 0.9, 0.5),
			pos = v(0, 0.1, -0.45),
			color = rgb(240, 240, 240),
			material = M.Plastic,
			shape = BALL,
		},
	},
	toaster = {
		{ size = v(3, 2, 1.8), pos = v(0, 0, 0), color = rgb(200, 202, 206), material = M.Metal },
		{
			size = v(0.4, 0.1, 1.4),
			pos = v(-0.6, 1.02, 0),
			color = rgb(30, 30, 30),
			material = M.Metal,
		},
		{
			size = v(0.4, 0.1, 1.4),
			pos = v(0.6, 1.02, 0),
			color = rgb(30, 30, 30),
			material = M.Metal,
		},
		{
			size = v(0.3, 0.6, 0.3),
			pos = v(1.6, 0.3, 0),
			color = rgb(30, 30, 30),
			material = M.Plastic,
		},
	},
	keyboard = {
		{
			size = v(4, 0.4, 1.4),
			pos = v(0, 0, 0),
			color = rgb(36, 36, 40),
			material = M.Plastic,
			rot = v(8, 0, 0),
		},
		{
			size = v(3.6, 0.15, 1.1),
			pos = v(0, 0.25, 0),
			color = rgb(220, 220, 224),
			material = M.Plastic,
			rot = v(8, 0, 0),
		},
	},
	monitor = {
		{
			size = v(3.8, 2.6, 0.4),
			pos = v(0, 0.4, 0),
			color = rgb(30, 30, 34),
			material = M.Plastic,
		},
		{
			size = v(3.4, 2.2, 0.05),
			pos = v(0, 0.4, -0.22),
			color = rgb(40, 70, 110),
			material = M.Glass,
		},
		{
			size = v(0.5, 1, 0.4),
			pos = v(0, -1.3, 0.1),
			color = rgb(30, 30, 34),
			material = M.Plastic,
		},
		{
			size = v(1.8, 0.2, 1.2),
			pos = v(0, -1.8, 0.1),
			color = rgb(30, 30, 34),
			material = M.Plastic,
		},
	},
	skateboard = {
		{ size = v(1.2, 0.2, 4.2), pos = v(0, 0, 0), color = rgb(210, 70, 40), material = M.Wood },
		{
			size = v(1.25, 0.05, 4.1),
			pos = v(0, 0.12, 0),
			color = rgb(40, 40, 40),
			material = M.Sand,
		},
		{
			size = v(0.5, 0.5, 0.5),
			pos = v(-0.55, -0.35, 1.4),
			color = rgb(240, 240, 220),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.5, 0.5, 0.5),
			pos = v(0.55, -0.35, 1.4),
			color = rgb(240, 240, 220),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.5, 0.5, 0.5),
			pos = v(-0.55, -0.35, -1.4),
			color = rgb(240, 240, 220),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.5, 0.5, 0.5),
			pos = v(0.55, -0.35, -1.4),
			color = rgb(240, 240, 220),
			material = M.Plastic,
			shape = BALL,
		},
	},
	boombox = {
		{ size = v(4, 2.2, 1.2), pos = v(0, 0, 0), color = rgb(50, 50, 56), material = M.Plastic },
		{
			size = v(0.15, 1.4, 1.4),
			pos = v(-1.2, -0.1, -0.6),
			color = rgb(20, 20, 22),
			material = M.Fabric,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.15, 1.4, 1.4),
			pos = v(1.2, -0.1, -0.6),
			color = rgb(20, 20, 22),
			material = M.Fabric,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(3.2, 0.25, 0.3),
			pos = v(0, 1.4, 0),
			color = rgb(180, 180, 186),
			material = M.Metal,
		},
	},
	console = {
		{
			size = v(3.6, 0.8, 2.4),
			pos = v(0, 0, 0),
			color = rgb(150, 150, 156),
			material = M.Plastic,
		},
		{
			size = v(1.4, 0.4, 0.9),
			pos = v(-0.2, 0.4, 1.8),
			color = rgb(60, 60, 66),
			material = M.Plastic,
		},
		{
			size = v(0.5, 0.1, 0.5),
			pos = v(1.1, 0.45, -0.5),
			color = rgb(200, 40, 40),
			material = M.Neon,
		},
	},
	guitar = {
		{
			size = v(2.2, 2.6, 0.5),
			pos = v(0, -0.9, 0),
			color = rgb(190, 30, 40),
			material = M.Plastic,
			rot = v(0, 0, 20),
		},
		{
			size = v(0.4, 3, 0.25),
			pos = v(0.6, 1.3, 0),
			color = rgb(110, 76, 44),
			material = M.Wood,
			rot = v(0, 0, 20),
		},
		{
			size = v(0.7, 0.8, 0.3),
			pos = v(1.15, 2.85, 0),
			color = rgb(30, 30, 30),
			material = M.Wood,
			rot = v(0, 0, 20),
		},
	},
	gpu = {
		{ size = v(4, 1.6, 0.5), pos = v(0, 0, 0), color = rgb(40, 40, 44), material = M.Metal },
		{
			size = v(0.2, 1.3, 1.3),
			pos = v(-0.9, 0, -0.3),
			color = rgb(30, 30, 32),
			material = M.Plastic,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.2, 1.3, 1.3),
			pos = v(0.9, 0, -0.3),
			color = rgb(30, 30, 32),
			material = M.Plastic,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(3.6, 0.15, 0.5),
			pos = v(0, 0.85, 0),
			color = rgb(60, 200, 120),
			material = M.Neon,
		},
	},
	baseball = {
		{
			size = v(1.6, 1.6, 1.6),
			pos = v(0, 0, 0),
			color = rgb(246, 244, 236),
			material = M.Leather,
			shape = BALL,
		},
		{
			size = v(1.62, 0.08, 0.3),
			pos = v(0, 0.2, 0),
			color = rgb(200, 40, 40),
			material = M.Fabric,
			rot = v(0, 0, 20),
		},
		{
			size = v(2.4, 0.5, 2.4),
			pos = v(0, -1.1, 0),
			color = rgb(110, 76, 44),
			material = M.Wood,
			shape = CYL,
			rot = v(0, 0, 90),
		},
	},
	duck = {
		{
			size = v(3, 2.4, 2.4),
			pos = v(0, -0.4, 0),
			color = rgb(250, 210, 40),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(1.8, 1.8, 1.8),
			pos = v(0, 1.1, -0.6),
			color = rgb(250, 210, 40),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.9, 0.4, 0.8),
			pos = v(0, 0.95, -1.6),
			color = rgb(240, 120, 30),
			material = M.Plastic,
		},
		{
			size = v(0.3, 0.3, 0.2),
			pos = v(-0.45, 1.4, -1.45),
			color = rgb(20, 20, 20),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.3, 0.3, 0.2),
			pos = v(0.45, 1.4, -1.45),
			color = rgb(20, 20, 20),
			material = M.Plastic,
			shape = BALL,
		},
	},
	toilet = {
		{
			size = v(1.6, 1.6, 2.4),
			pos = v(0, -0.8, 0),
			color = rgb(255, 210, 60),
			material = M.Foil,
		},
		{
			size = v(0.3, 2.4, 2.4),
			pos = v(0, 0.15, -0.3),
			color = rgb(255, 210, 60),
			material = M.Foil,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(2, 2.2, 0.8),
			pos = v(0, 0.6, 1.3),
			color = rgb(255, 210, 60),
			material = M.Foil,
		},
	},
	limited_console = {
		{
			size = v(3.6, 0.9, 2.4),
			pos = v(0, 0, 0),
			color = rgb(240, 240, 244),
			material = M.Glass,
		},
		{
			size = v(3.7, 0.12, 2.5),
			pos = v(0, 0.2, 0),
			color = rgb(255, 196, 40),
			material = M.Foil,
		},
		{
			size = v(1.4, 0.4, 0.9),
			pos = v(-0.2, 0.45, 1.8),
			color = rgb(255, 196, 40),
			material = M.Foil,
		},
		{
			size = v(0.5, 0.1, 0.5),
			pos = v(1.1, 0.5, -0.5),
			color = rgb(60, 160, 255),
			material = M.Neon,
		},
	},
	gaming_pc = {
		{ size = v(1.8, 3.6, 3.4), pos = v(0, 0, 0), color = rgb(255, 196, 40), material = M.Foil },
		{
			size = v(0.05, 3, 2.8),
			pos = v(-0.92, 0, 0),
			color = rgb(120, 200, 255),
			material = M.Glass,
		},
		{
			size = v(0.1, 0.9, 0.9),
			pos = v(-0.85, 0.6, 0.6),
			color = rgb(255, 60, 200),
			material = M.Neon,
			shape = CYL,
			rot = v(0, 0, 0),
		},
		{
			size = v(0.1, 0.9, 0.9),
			pos = v(-0.85, -0.6, -0.6),
			color = rgb(60, 220, 255),
			material = M.Neon,
			shape = CYL,
			rot = v(0, 0, 0),
		},
	},

	-- ─── Port Haven ───────────────────────────────────────────────────────
	rope = {
		{
			size = v(0.9, 3.2, 3.2),
			pos = v(0, 0, 0),
			color = rgb(196, 160, 108),
			material = M.Fabric,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.95, 1.3, 1.3),
			pos = v(0, 0, 0),
			color = rgb(120, 96, 64),
			material = M.Fabric,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(2.2, 0.35, 0.35),
			pos = v(1.6, -0.3, 1.2),
			color = rgb(196, 160, 108),
			material = M.Fabric,
			rot = v(0, 30, 0),
		},
	},
	net = {
		{
			size = v(3.6, 0.3, 3),
			pos = v(0, -0.4, 0),
			color = rgb(96, 116, 100),
			material = M.Fabric,
			rot = v(0, 0, 8),
		},
		{
			size = v(2.4, 0.3, 1.6),
			pos = v(-0.4, 0, 0.4),
			color = rgb(80, 100, 86),
			material = M.Fabric,
			rot = v(0, 20, -10),
		},
		{ size = v(0.8, 0.8, 0.8), pos = v(1.4, 0, -1), color = rgb(230, 110, 40), shape = BALL },
		{ size = v(0.8, 0.8, 0.8), pos = v(-1.4, 0.2, 1), color = rgb(230, 110, 40), shape = BALL },
	},
	buoy = {
		{
			size = v(2.6, 2.6, 2.6),
			pos = v(0, -0.2, 0),
			color = rgb(206, 50, 40),
			material = M.Plastic,
			shape = BALL,
		},
		{
			size = v(0.6, 2.7, 2.7),
			pos = v(0, -0.2, 0),
			color = rgb(240, 240, 236),
			material = M.Plastic,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.3, 1.4, 0.3),
			pos = v(0, 1.6, 0),
			color = rgb(70, 70, 74),
			material = M.Metal,
		},
	},
	crabtrap = {
		{
			size = v(3.2, 1.8, 2.4),
			pos = v(0, 0, 0),
			color = rgb(150, 156, 160),
			material = M.DiamondPlate,
		},
		{
			size = v(3.3, 0.2, 2.5),
			pos = v(0, 0.95, 0),
			color = rgb(110, 116, 120),
			material = M.Metal,
		},
		{
			size = v(0.2, 1.2, 0.2),
			pos = v(0, 1.6, 0),
			color = rgb(196, 160, 108),
			material = M.Fabric,
		},
	},
	lantern = {
		{
			size = v(0.4, 1.8, 1.8),
			pos = v(0, -1.2, 0),
			color = rgb(40, 44, 40),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(2, 1.4, 1.4),
			pos = v(0, 0, 0),
			color = rgb(220, 230, 220),
			material = M.Glass,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.8, 0.8, 0.8),
			pos = v(0, 0, 0),
			color = rgb(255, 180, 60),
			material = M.Neon,
			shape = BALL,
		},
		{
			size = v(0.5, 1.6, 1.6),
			pos = v(0, 1.2, 0),
			color = rgb(40, 44, 40),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(1.2, 0.2, 0.2),
			pos = v(0, 1.8, 0),
			color = rgb(40, 44, 40),
			material = M.Metal,
		},
	},
	compass = {
		{
			size = v(0.5, 3, 3),
			pos = v(0, 0, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.1, 2.5, 2.5),
			pos = v(0, 0.27, 0),
			color = rgb(240, 234, 220),
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.12, 0.12, 2),
			pos = v(0, 0.35, 0),
			color = rgb(200, 40, 40),
			rot = v(0, 35, 0),
		},
	},
	oar = {
		{
			size = v(4.2, 0.3, 0.3),
			pos = v(-0.6, 0, 0),
			color = rgb(156, 112, 70),
			material = M.Wood,
			rot = v(0, 0, 20),
		},
		{
			size = v(1.5, 0.15, 0.9),
			pos = v(1.8, 0.65, 0),
			color = rgb(140, 98, 60),
			material = M.Wood,
			rot = v(0, 0, 20),
		},
	},
	helmet = {
		{
			size = v(2.8, 2.8, 2.8),
			pos = v(0, 0.2, 0),
			color = rgb(186, 116, 64),
			material = M.Metal,
			shape = BALL,
		},
		{
			size = v(0.3, 1.3, 1.3),
			pos = v(0, 0.3, -1.3),
			color = rgb(170, 200, 210),
			material = M.Glass,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.7, 3.2, 3.2),
			pos = v(0, -1.3, 0),
			color = rgb(150, 92, 50),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
	},
	wheel = {
		{
			size = v(0.4, 3.2, 3.2),
			pos = v(0, 0, 0),
			color = rgb(140, 96, 56),
			material = M.Wood,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.5, 2.2, 2.2),
			pos = v(0, 0, 0),
			color = rgb(30, 30, 30),
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{ size = v(4.2, 0.3, 0.3), pos = v(0, 0, 0), color = rgb(160, 112, 66), material = M.Wood },
		{
			size = v(4.2, 0.3, 0.3),
			pos = v(0, 0, 0),
			color = rgb(160, 112, 66),
			material = M.Wood,
			rot = v(0, 0, 90),
		},
		{
			size = v(4.2, 0.3, 0.3),
			pos = v(0, 0, 0),
			color = rgb(160, 112, 66),
			material = M.Wood,
			rot = v(0, 0, 45),
		},
		{
			size = v(4.2, 0.3, 0.3),
			pos = v(0, 0, 0),
			color = rgb(160, 112, 66),
			material = M.Wood,
			rot = v(0, 0, -45),
		},
		{
			size = v(0.6, 0.8, 0.8),
			pos = v(0, 0, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 90, 0),
		},
	},
	spyglass = {
		{
			size = v(2.4, 0.9, 0.9),
			pos = v(-0.8, 0, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
			shape = CYL,
		},
		{
			size = v(1.8, 0.65, 0.65),
			pos = v(1.2, 0, 0),
			color = rgb(176, 130, 50),
			material = M.Metal,
			shape = CYL,
		},
		{
			size = v(0.6, 1, 1),
			pos = v(-1.9, 0, 0),
			color = rgb(80, 52, 30),
			material = M.Leather,
			shape = CYL,
		},
	},
	sextant = {
		{
			size = v(0.3, 3, 0.3),
			pos = v(-0.7, 0.2, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
			rot = v(0, 0, -25),
		},
		{
			size = v(0.3, 3, 0.3),
			pos = v(0.7, 0.2, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
			rot = v(0, 0, 25),
		},
		{
			size = v(3.2, 0.3, 0.3),
			pos = v(0, -1.1, 0),
			color = rgb(196, 150, 60),
			material = M.Metal,
		},
		{
			size = v(0.8, 0.8, 0.1),
			pos = v(0, 1.3, 0),
			color = rgb(190, 220, 230),
			material = M.Glass,
		},
		{
			size = v(0.5, 1.2, 0.5),
			pos = v(0, -1.8, 0.3),
			color = rgb(80, 52, 30),
			material = M.Wood,
		},
	},
	bottleship = {
		{
			size = v(3.4, 1.8, 1.8),
			pos = v(0, 0, 0),
			color = rgb(190, 220, 210),
			material = M.Glass,
			shape = CYL,
		},
		{
			size = v(0.8, 0.8, 0.8),
			pos = v(2, 0, 0),
			color = rgb(150, 110, 70),
			material = M.Wood,
			shape = CYL,
		},
		{
			size = v(1.8, 0.4, 0.6),
			pos = v(0, -0.45, 0),
			color = rgb(120, 70, 40),
			material = M.Wood,
		},
		{
			size = v(0.1, 1, 0.8),
			pos = v(0, 0.3, 0),
			color = rgb(240, 236, 226),
			material = M.Fabric,
		},
	},
	anchor = {
		{
			size = v(0.5, 3.4, 0.5),
			pos = v(0, 0.2, 0),
			color = rgb(255, 200, 40),
			material = M.Foil,
		},
		{ size = v(2, 0.4, 0.4), pos = v(0, 1.3, 0), color = rgb(255, 200, 40), material = M.Foil },
		{
			size = v(0.3, 1, 1),
			pos = v(0, 2.2, 0),
			color = rgb(255, 200, 40),
			material = M.Foil,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(1.8, 0.45, 0.45),
			pos = v(-0.75, -1.2, 0),
			color = rgb(255, 200, 40),
			material = M.Foil,
			rot = v(0, 0, -35),
		},
		{
			size = v(1.8, 0.45, 0.45),
			pos = v(0.75, -1.2, 0),
			color = rgb(255, 200, 40),
			material = M.Foil,
			rot = v(0, 0, 35),
		},
	},
	figurehead = {
		{
			size = v(2.6, 1.3, 1.3),
			pos = v(0, 0, 0),
			color = rgb(176, 130, 86),
			material = M.Wood,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(1.1, 1.1, 1.1),
			pos = v(0, 1.8, 0),
			color = rgb(190, 146, 100),
			material = M.Wood,
			shape = BALL,
		},
		{
			size = v(1.2, 1.4, 0.4),
			pos = v(0, 2, 0.5),
			color = rgb(150, 60, 40),
			material = M.Wood,
		},
		{
			size = v(0.6, 1.6, 1.6),
			pos = v(0, -1.6, 0.4),
			color = rgb(40, 130, 120),
			material = M.Wood,
			rot = v(30, 0, 0),
		},
	},
	chest = {
		{
			size = v(3.4, 1.8, 2.2),
			pos = v(0, -0.4, 0),
			color = rgb(110, 66, 36),
			material = M.Wood,
		},
		{
			size = v(3.4, 2.2, 2.2),
			pos = v(0, 0.5, 0),
			color = rgb(120, 72, 40),
			material = M.Wood,
			shape = CYL,
		},
		{
			size = v(0.3, 2.6, 2.5),
			pos = v(-1, 0, 0),
			color = rgb(255, 200, 40),
			material = M.Foil,
		},
		{ size = v(0.3, 2.6, 2.5), pos = v(1, 0, 0), color = rgb(255, 200, 40), material = M.Foil },
		{
			size = v(0.8, 0.8, 0.8),
			pos = v(0.3, 1.7, -0.4),
			color = rgb(255, 210, 60),
			material = M.Foil,
			shape = BALL,
		},
		{
			size = v(0.7, 0.7, 0.7),
			pos = v(-0.4, 1.6, 0.3),
			color = rgb(255, 210, 60),
			material = M.Foil,
			shape = BALL,
		},
	},

	-- ─── more Maple finds ─────────────────────────────────────────────────
	pizzabox = {
		{
			size = v(3.6, 0.6, 3.6),
			pos = v(0, 0, 0),
			color = rgb(196, 160, 110),
			material = M.Cardboard,
		},
		{ size = v(2.2, 0.05, 1.2), pos = v(0, 0.31, 0), color = rgb(200, 40, 40) },
		{
			size = v(3.6, 0.6, 3.6),
			pos = v(0, 1.4, 1.4),
			color = rgb(190, 152, 104),
			material = M.Cardboard,
			rot = v(-55, 0, 0),
		},
	},
	newspaper = {
		{
			size = v(3.4, 0.4, 2.4),
			pos = v(0, 0, 0),
			color = rgb(206, 204, 196),
			material = M.Fabric,
			rot = v(0, 15, 6),
		},
		{
			size = v(3.2, 0.1, 2.2),
			pos = v(0.2, 0.3, 0.1),
			color = rgb(150, 150, 146),
			material = M.Fabric,
			rot = v(0, 25, -4),
		},
	},
	brokenlamp = {
		{
			size = v(0.4, 1.4, 1.4),
			pos = v(0, -1.4, 0),
			color = rgb(60, 60, 64),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.3, 2.6, 0.3),
			pos = v(0.2, -0.1, 0),
			color = rgb(80, 80, 84),
			material = M.Metal,
			rot = v(0, 0, -12),
		},
		{
			size = v(2.2, 1.6, 2.2),
			pos = v(0.6, 1.4, 0),
			color = rgb(230, 210, 170),
			material = M.Fabric,
			rot = v(0, 0, 30),
		},
	},
	radio = {
		{ size = v(3, 2, 1.2), pos = v(0, 0, 0), color = rgb(150, 40, 40), material = M.Plastic },
		{
			size = v(0.1, 1, 1),
			pos = v(0.6, 0, -0.62),
			color = rgb(40, 40, 40),
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.15, 2.6, 0.15),
			pos = v(-1.2, 2.2, 0),
			color = rgb(200, 200, 204),
			material = M.Metal,
			rot = v(0, 0, 20),
		},
	},
	sneakers = {
		{
			size = v(1.6, 1.1, 3.6),
			pos = v(-0.9, 0, 0),
			color = rgb(236, 236, 236),
			material = M.Fabric,
		},
		{
			size = v(1.7, 0.4, 3.8),
			pos = v(-0.9, -0.6, 0),
			color = rgb(200, 60, 60),
			material = M.Rubber,
		},
		{
			size = v(1.6, 1.1, 3.6),
			pos = v(0.9, 0, 0.4),
			color = rgb(236, 236, 236),
			material = M.Fabric,
			rot = v(0, 12, 0),
		},
		{
			size = v(1.7, 0.4, 3.8),
			pos = v(0.9, -0.6, 0.4),
			color = rgb(200, 60, 60),
			material = M.Rubber,
			rot = v(0, 12, 0),
		},
	},
	teddy = {
		{
			size = v(2.4, 2.6, 2),
			pos = v(0, -0.4, 0),
			color = rgb(150, 100, 60),
			material = M.Fabric,
			shape = BALL,
		},
		{
			size = v(1.8, 1.8, 1.8),
			pos = v(0, 1.4, 0),
			color = rgb(160, 110, 66),
			material = M.Fabric,
			shape = BALL,
		},
		{
			size = v(0.7, 0.7, 0.7),
			pos = v(-0.7, 2.2, 0),
			color = rgb(150, 100, 60),
			material = M.Fabric,
			shape = BALL,
		},
		{
			size = v(0.7, 0.7, 0.7),
			pos = v(0.7, 2.2, 0),
			color = rgb(150, 100, 60),
			material = M.Fabric,
			shape = BALL,
		},
	},
	camera = {
		{ size = v(3.2, 2, 1.4), pos = v(0, 0, 0), color = rgb(30, 30, 32), material = M.Metal },
		{
			size = v(1.2, 1.4, 1.4),
			pos = v(0, 0, -1),
			color = rgb(60, 60, 64),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.1, 1, 1),
			pos = v(0, 0, -1.65),
			color = rgb(90, 130, 170),
			material = M.Glass,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(3.2, 0.4, 1.4),
			pos = v(0, 1.1, 0),
			color = rgb(200, 200, 204),
			material = M.Metal,
		},
	},
	vinyl = {
		{
			size = v(0.15, 3.4, 3.4),
			pos = v(0, 0, 0),
			color = rgb(20, 20, 22),
			material = M.Plastic,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.17, 1.2, 1.2),
			pos = v(0, 0, 0),
			color = rgb(220, 60, 60),
			shape = CYL,
			rot = v(0, 0, 90),
		},
	},
	drone = {
		{
			size = v(1.6, 0.6, 1.6),
			pos = v(0, 0, 0),
			color = rgb(240, 240, 240),
			material = M.Plastic,
		},
		{ size = v(3.6, 0.2, 0.3), pos = v(0, 0.1, 0), color = rgb(40, 40, 44), rot = v(0, 45, 0) },
		{
			size = v(3.6, 0.2, 0.3),
			pos = v(0, 0.1, 0),
			color = rgb(40, 40, 44),
			rot = v(0, -45, 0),
		},
		{
			size = v(0.1, 1.2, 1.2),
			pos = v(1.3, 0.3, 1.3),
			color = rgb(90, 90, 96),
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.1, 1.2, 1.2),
			pos = v(-1.3, 0.3, -1.3),
			color = rgb(90, 90, 96),
			shape = CYL,
			rot = v(0, 0, 90),
		},
	},
	headphones = {
		{
			size = v(3, 0.4, 0.6),
			pos = v(0, 1.4, 0),
			color = rgb(30, 30, 34),
			material = M.Plastic,
		},
		{
			size = v(0.8, 1.6, 1.6),
			pos = v(-1.4, 0, 0),
			color = rgb(200, 40, 60),
			material = M.Plastic,
			shape = CYL,
		},
		{
			size = v(0.8, 1.6, 1.6),
			pos = v(1.4, 0, 0),
			color = rgb(200, 40, 60),
			material = M.Plastic,
			shape = CYL,
		},
	},
	trophy = {
		{
			size = v(2.2, 0.8, 2.2),
			pos = v(0, -1.6, 0),
			color = rgb(60, 40, 30),
			material = M.Wood,
		},
		{
			size = v(0.5, 2, 0.5),
			pos = v(0, -0.3, 0),
			color = rgb(220, 180, 60),
			material = M.Metal,
		},
		{
			size = v(1.6, 1.6, 1.6),
			pos = v(0, 1.2, 0),
			color = rgb(230, 190, 70),
			material = M.Metal,
			shape = BALL,
		},
	},
	goldwatch = {
		{
			size = v(0.4, 2.2, 2.2),
			pos = v(0, 0, 0),
			color = rgb(255, 200, 50),
			material = M.Foil,
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{
			size = v(0.1, 1.8, 1.8),
			pos = v(0, 0, -0.22),
			color = rgb(240, 240, 236),
			shape = CYL,
			rot = v(0, 90, 0),
		},
		{ size = v(1, 3.6, 0.3), pos = v(0, 0, 0.3), color = rgb(240, 190, 40), material = M.Foil },
	},
	diamondring = {
		{
			size = v(0.4, 2.4, 2.4),
			pos = v(0, 0, 0),
			color = rgb(255, 210, 60),
			material = M.Foil,
			shape = CYL,
		},
		{
			size = v(1, 1, 1),
			pos = v(0, 1.5, 0),
			color = rgb(200, 240, 255),
			material = M.Glass,
			rot = v(45, 0, 45),
		},
	},
	neonkatana = {
		{
			size = v(0.3, 4.6, 0.6),
			pos = v(0, 0.8, 0),
			color = rgb(0, 230, 255),
			material = M.Neon,
			rot = v(0, 0, 25),
		},
		{
			size = v(0.4, 1.4, 0.5),
			pos = v(0.85, -1.9, 0),
			color = rgb(30, 30, 40),
			material = M.Fabric,
			rot = v(0, 0, 25),
		},
		{
			size = v(1.4, 0.2, 1),
			pos = v(0.6, -1.2, 0),
			color = rgb(255, 40, 170),
			material = M.Neon,
			rot = v(0, 0, 25),
		},
	},
	cyberarm = {
		{
			size = v(1.1, 2.6, 1.1),
			pos = v(0, 0.9, 0),
			color = rgb(180, 186, 196),
			material = M.Metal,
		},
		{
			size = v(1, 2.4, 1),
			pos = v(0.3, -1.3, 0),
			color = rgb(150, 156, 166),
			material = M.Metal,
			rot = v(0, 0, -15),
		},
		{
			size = v(0.3, 4.6, 0.3),
			pos = v(0.6, 0, 0.6),
			color = rgb(255, 40, 170),
			material = M.Neon,
		},
		{
			size = v(1.2, 1, 1.2),
			pos = v(0.6, -2.7, 0),
			color = rgb(120, 126, 136),
			material = M.Metal,
		},
	},
	alienegg = {
		{
			size = v(2.6, 3.4, 2.6),
			pos = v(0, 0.2, 0),
			color = rgb(60, 255, 150),
			material = M.Neon,
			shape = BALL,
		},
		{
			size = v(2.8, 1, 2.8),
			pos = v(0, -1.6, 0),
			color = rgb(60, 60, 70),
			material = M.Metal,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.6, 0.6, 0.6),
			pos = v(0.6, 1, -1.1),
			color = rgb(20, 40, 30),
			material = M.Glass,
			shape = BALL,
		},
	},
	seashell = {
		{
			size = v(2.8, 2.2, 2.2),
			pos = v(0, 0, 0),
			color = rgb(240, 200, 180),
			material = M.SmoothPlastic,
			shape = BALL,
		},
		{
			size = v(1.6, 1.4, 1.4),
			pos = v(1.2, 0.6, 0),
			color = rgb(236, 180, 160),
			material = M.SmoothPlastic,
			shape = BALL,
		},
	},
	snorkel = {
		{ size = v(3, 1.8, 1), pos = v(0, 0, 0), color = rgb(50, 160, 220), material = M.Plastic },
		{
			size = v(2.6, 1.4, 0.2),
			pos = v(0, 0, -0.55),
			color = rgb(190, 230, 240),
			material = M.Glass,
		},
		{
			size = v(0.5, 3.4, 0.5),
			pos = v(1.8, 1.4, 0.2),
			color = rgb(240, 200, 40),
			material = M.Plastic,
		},
	},
	flaregun = {
		{
			size = v(3.2, 1.1, 1.1),
			pos = v(0.4, 0.6, 0),
			color = rgb(230, 100, 30),
			material = M.Plastic,
			shape = CYL,
		},
		{
			size = v(0.9, 2, 0.8),
			pos = v(-0.8, -0.6, 0),
			color = rgb(220, 90, 30),
			material = M.Plastic,
			rot = v(0, 0, -15),
		},
	},
	doubloons = {
		{
			size = v(2.6, 2.4, 2.6),
			pos = v(0, 0, 0),
			color = rgb(120, 80, 50),
			material = M.Fabric,
			shape = BALL,
		},
		{
			size = v(0.3, 1.2, 1.2),
			pos = v(1.4, -0.9, 0.6),
			color = rgb(255, 200, 40),
			material = M.Foil,
			shape = CYL,
		},
		{
			size = v(0.3, 1.2, 1.2),
			pos = v(1.2, -1, -0.8),
			color = rgb(255, 200, 40),
			material = M.Foil,
			shape = CYL,
			rot = v(0, 40, 0),
		},
	},
	krakeneye = {
		{
			size = v(3, 3, 3),
			pos = v(0, 0, 0),
			color = rgb(255, 210, 60),
			material = M.Neon,
			shape = BALL,
		},
		{
			size = v(0.5, 1.8, 0.4),
			pos = v(0, 0, -1.4),
			color = rgb(20, 20, 20),
			material = M.SmoothPlastic,
		},
		{
			size = v(1.4, 0.5, 3),
			pos = v(0, -1.6, 1),
			color = rgb(120, 40, 120),
			material = M.SmoothPlastic,
			rot = v(20, 0, 0),
		},
	},
	mermaidcrown = {
		{
			size = v(3, 0.8, 3),
			pos = v(0, -0.8, 0),
			color = rgb(255, 210, 60),
			material = M.Foil,
			shape = CYL,
			rot = v(0, 0, 90),
		},
		{
			size = v(0.4, 2, 0.4),
			pos = v(0, 0.4, -1.3),
			color = rgb(255, 210, 60),
			material = M.Foil,
		},
		{
			size = v(0.4, 1.6, 0.4),
			pos = v(1.2, 0.2, -0.6),
			color = rgb(255, 210, 60),
			material = M.Foil,
		},
		{
			size = v(0.4, 1.6, 0.4),
			pos = v(-1.2, 0.2, -0.6),
			color = rgb(255, 210, 60),
			material = M.Foil,
		},
		{
			size = v(0.8, 0.8, 0.8),
			pos = v(0, 1.5, -1.3),
			color = rgb(120, 255, 230),
			material = M.Neon,
			shape = BALL,
		},
		{
			size = v(0.6, 0.6, 0.6),
			pos = v(1.2, 1.1, -0.6),
			color = rgb(255, 120, 200),
			material = M.Neon,
			shape = BALL,
		},
		{
			size = v(0.6, 0.6, 0.6),
			pos = v(-1.2, 1.1, -0.6),
			color = rgb(255, 120, 200),
			material = M.Neon,
			shape = BALL,
		},
	},
}

local ItemModels = {}

-- Builds the model for an item. Mutations tint it (Golden) or add a sparkle (Shiny).
function ItemModels.build(itemId: string, mutation: string?): Model
	local model = Instance.new("Model")
	model.Name = itemId
	local specs = SPECS[itemId]
	if not specs then
		specs = { { size = v(2, 2, 2), pos = v(0, 0, 0), color = rgb(120, 120, 120) } }
	end
	for i, s in specs do
		local p = Instance.new("Part")
		p.Name = "P" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = s.size
		p.Color = s.color
		p.Material = s.material or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if s.shape then
			p.Shape = s.shape
		end
		local rot = s.rot or Vector3.zero
		p.CFrame = CFrame.new(s.pos)
			* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		if mutation == "golden" and p.Material ~= M.Neon then
			p.Color = p.Color:Lerp(rgb(255, 200, 40), 0.75)
			p.Material = M.Foil
		elseif mutation == "shiny" then
			p.Reflectance = 0.35
		end
		p.Parent = model
		if i == 1 then
			model.PrimaryPart = p
		end
	end
	return model
end

-- A copy for world displays (shelves, pedestals): scaled to fit a `fit`-stud
-- cube and set down with its bottom on `base` (turned by `base`'s rotation).
function ItemModels.trophy(itemId: string, mutation: string?, fit: number, base: CFrame): Model
	local model = ItemModels.build(itemId, mutation)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(math.min(1.5, fit / math.max(size.X, size.Y, size.Z)))
	local cf, scaled = model:GetBoundingBox()
	local lift = model:GetPivot().Position.Y - (cf.Position.Y - scaled.Y / 2)
	model:PivotTo(base * CFrame.new(0, lift, 0))
	model.Name = "Trophy"
	return model
end

-- Puts a slowly turning item into a ViewportFrame. `silhouette` hides what it is.
function ItemModels.show(
	viewport: ViewportFrame,
	itemId: string,
	mutation: string?,
	silhouette: boolean?
)
	viewport:ClearAllChildren()
	local model = ItemModels.build(itemId, mutation)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() * CFrame.new(-cf.Position))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(30) / 2) * 0.9
	camera.FieldOfView = 30
	camera.CFrame =
		CFrame.lookAt(Vector3.new(distance * 0.55, distance * 0.35, -distance * 0.8), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.BackgroundTransparency = 1
	if silhouette then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.new(0, 0, 0)
				d.Material = Enum.Material.SmoothPlastic -- Neon would still glow
				d.Reflectance = 0
			end
		end
		viewport.Ambient = Color3.new(0, 0, 0)
		viewport.LightColor = Color3.new(0, 0, 0)
		viewport.ImageColor3 = Color3.fromRGB(60, 64, 72)
	else
		viewport.Ambient = Color3.fromRGB(150, 150, 156)
		viewport.LightColor = Color3.fromRGB(255, 250, 240)
		viewport.LightDirection = Vector3.new(-1, -1.4, 0.6)
		viewport.ImageColor3 = Color3.new(1, 1, 1)
	end
end

-- Every item has a model (the self-check catches typos in ids).
function ItemModels.selfCheck()
	for _, item in Items.List do
		assert(SPECS[item.id], "no model for item " .. item.id)
	end
end

return ItemModels
