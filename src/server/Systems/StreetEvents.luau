--!strict
-- Small street scenes that pop up near players now and then, so the city
-- feels like it runs on its own:
--   performer    a street dancer on the sidewalk with a little crowd
--   fenderbender two cars bumped at the curb, hazards on, drivers arguing
--   trafficstop  a police cruiser pulled a car over, lights flashing
-- At most MAX_ACTIVE at once; each lasts LIFETIME seconds, then clears away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityPlan = require(ReplicatedStorage.Shared.CityPlan)
local Npc = require(script.Parent.Parent.Npc)

local MAX_ACTIVE = 2
local LIFETIME = 150
local MIN_GAP, MAX_GAP = 40, 90 -- seconds between new scenes
local NEAR_MIN, NEAR_MAX = 90, 260 -- studs from a player

local StreetEvents = {}

local rng = Random.new()
local folder: Folder
local active = 0

type Scene = { root: Model, npcs: { Npc.Npc }, alive: boolean }

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- A street near a player: an edge, the distance along it, and its tangent.
local function streetNear(): (CityPlan.Edge?, number)
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil, 0
	end
	local who = pick(players)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, 0
	end
	for _ = 1, 60 do
		local e = pick(CityPlan.EDGES)
		if
			(e.kind == "arterial" or e.kind == "collector" or e.kind == "street")
			and e.length > 90
			and e.points[1].Y < 1
		then
			local s = e.length * rng:NextNumber(0.35, 0.65)
			local p = CityPlan.pointAt(e, s)
			local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
			if
				d > NEAR_MIN
				and d < NEAR_MAX
				and CityPlan.onLand(p)
				and not CityPlan.reserved(p, 20)
			then
				return e, s
			end
		end
	end
	return nil, 0
end

-- Frame on the curb lane at distance s, `inset` studs in from the curb,
-- facing along the traffic on that side (right-hand traffic: the tangent).
local function curbFrame(e: CityPlan.Edge, s: number, inset: number): CFrame
	local p, t = CityPlan.pointAt(e, s)
	local right = Vector3.new(-t.Z, 0, t.X)
	local pos = p + right * (e.w / 2 - inset) + Vector3.new(0, CityPlan.SURFACE, 0)
	return CFrame.lookAt(pos, pos + t)
end

-- Sidewalk frame `out` studs from the curb at distance s (root height),
-- looking toward the road.
local function walkFrame(e: CityPlan.Edge, s: number, out: number): CFrame
	local p, t = CityPlan.pointAt(e, s)
	local right = Vector3.new(-t.Z, 0, t.X)
	local pos = p + right * (e.w / 2 + out) + Vector3.new(0, CityPlan.SURFACE + 3.2, 0)
	return CFrame.lookAt(pos, pos - right)
end

-- Stands at `at`, looking at `other`.
local function facing(at: CFrame, other: CFrame): CFrame
	return CFrame.lookAt(at.Position, Vector3.new(other.X, at.Y, other.Z))
end

local function car(parent: Instance, name: string, cf: CFrame): Model?
	local templates = ReplicatedStorage:FindFirstChild("VehicleTemplates")
	local source: Instance? = nil
	if templates then
		if name == "PoliceCar" then
			source = templates:FindFirstChild("PoliceCar")
		else
			local civil = {}
			for _, m in templates:GetChildren() do
				if m:IsA("Model") and m.Name ~= "PoliceCar" then
					table.insert(civil, m)
				end
			end
			source = if #civil > 0 then pick(civil) else nil
		end
	end
	if not source or not source:IsA("Model") then
		return nil
	end
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local bb, size = m:GetBoundingBox()
	local lift = m:GetPivot().Y - (bb.Y - size.Y / 2)
	m:PivotTo(cf + Vector3.new(0, lift, 0))
	m.Parent = parent
	return m
end

-- Blinking lights at a car's corners (hazards) or on its roof (police bar).
local function blinkers(scene: Scene, m: Model, colors: { Color3 }, roof: boolean)
	local cf, size = m:GetBoundingBox()
	local lamps = {}
	local spots = if roof
		then { Vector3.new(-1, size.Y / 2 + 0.3, 0), Vector3.new(1, size.Y / 2 + 0.3, 0) }
		else {
			Vector3.new(-size.X / 2 + 0.4, 0, -size.Z / 2),
			Vector3.new(size.X / 2 - 0.4, 0, -size.Z / 2),
			Vector3.new(-size.X / 2 + 0.4, 0, size.Z / 2),
			Vector3.new(size.X / 2 - 0.4, 0, size.Z / 2),
		}
	for i, v in spots do
		local lamp = part(m, {
			Name = "EventLamp",
			Size = if roof then Vector3.new(1.4, 0.5, 0.8) else Vector3.new(0.6, 0.4, 0.3),
			CFrame = cf * CFrame.new(v),
			Color = colors[(i - 1) % #colors + 1],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		if roof then
			local l = Instance.new("PointLight")
			l.Color = lamp.Color
			l.Range = 22
			l.Brightness = 0
			l.Parent = lamp
		end
		table.insert(lamps, lamp)
	end
	task.spawn(function()
		local on = false
		while scene.alive do
			on = not on
			for i, lamp in lamps do
				local lit = if roof then (i == 1) == on else on
				lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
				local l = lamp:FindFirstChildOfClass("PointLight")
				if l then
					l.Brightness = if lit then 4 else 0
				end
			end
			task.wait(if roof then 0.3 else 0.5)
		end
	end)
end

local function person(scene: Scene, name: string, cf: CFrame, kind: string?): Npc.Npc?
	local npc = Npc.new(kind or "civilian", name, cf, scene.root, rng)
	if npc then
		npc.root.Anchored = true
		table.insert(scene.npcs, npc)
	end
	return npc
end

-- Two people taking turns at a line, with gestures, until the scene ends.
local function argue(scene: Scene, a: Npc.Npc, b: Npc.Npc, lines: { { string } })
	task.spawn(function()
		local k = 0
		while scene.alive do
			k += 1
			local who = if k % 2 == 1 then a else b
			local pair = lines[(k - 1) % #lines + 1]
			who:say(pick(pair), 3)
			who:play(if rng:NextNumber() < 0.6 then "point" else "laugh")
			task.wait(rng:NextNumber(3.5, 5.5))
		end
	end)
end

-- ─── scenes ───────────────────────────────────────────────────────────────

local function performer(scene: Scene): boolean
	local e, s = streetNear()
	if not e then
		return false
	end
	local stage = walkFrame(e, s, 6)
	local dancer = person(scene, "StreetDancer", stage)
	if not dancer then
		return false
	end
	dancer:play("dance", true)
	local sign = part(scene.root, {
		Name = "ShowSign",
		Size = Vector3.new(3, 2, 0.2),
		CFrame = stage * CFrame.new(3.5, -2, 0) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(30, 30, 36),
		CanCollide = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 200)
	label.Text = "TIPS WELCOME"
	label.Parent = gui
	gui.Parent = sign
	part(scene.root, {
		Name = "TipJar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 1, 1),
		CFrame = stage * CFrame.new(-2.5, -2.6, -1) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	})
	-- A small crowd in an arc on the road side of the walk, facing the dancer.
	local crowd = {}
	for i = 1, 4 do
		local a = math.rad(-50 + (i - 1) * 33)
		local at = (stage * CFrame.new(math.sin(a) * 6, 0, -math.cos(a) * 6)).Position
		local npc = person(scene, "Watcher" .. i, CFrame.lookAt(at, stage.Position))
		if npc then
			table.insert(crowd, npc)
		end
	end
	task.spawn(function()
		while scene.alive do
			task.wait(rng:NextNumber(4, 8))
			local fan = if #crowd > 0 then pick(crowd) else nil
			if fan and scene.alive then
				fan:play("cheer")
				if rng:NextNumber() < 0.4 then
					fan:say(pick({ "Woo!", "Let's gooo!", "Encore!", "Sick moves!" }), 2)
				end
			end
		end
	end)
	return true
end

local function fenderBender(scene: Scene): boolean
	local e, s = streetNear()
	if not e then
		return false
	end
	local front = car(scene.root, "Car", curbFrame(e, s, 4.5))
	local back = car(
		scene.root,
		"Car",
		curbFrame(e, s - 12.5, 4) * CFrame.Angles(0, math.rad(rng:NextNumber(8, 16)), 0)
	)
	if not front or not back then
		return false
	end
	blinkers(scene, front, { Color3.fromRGB(255, 160, 30) }, false)
	blinkers(scene, back, { Color3.fromRGB(255, 160, 30) }, false)
	local hood = back:GetBoundingBox() * CFrame.new(0, 0, -5)
	local puff = part(scene.root, {
		Name = "Steam",
		Size = Vector3.new(1, 1, 1),
		CFrame = hood,
		Transparency = 1,
		CanCollide = false,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(220, 220, 220)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = puff
	for k = 0, 2 do
		local cone = curbFrame(e, s - 24 - k * 4, 2)
		part(scene.root, {
			Name = "Cone",
			Size = Vector3.new(0.9, 1.6, 0.9),
			CFrame = cone + Vector3.new(0, 0.8, 0),
			Color = Color3.fromRGB(255, 110, 20),
		})
	end
	local a = person(scene, "DriverA", facing(walkFrame(e, s - 4, 3), walkFrame(e, s - 8, 3)))
	local b = person(scene, "DriverB", facing(walkFrame(e, s - 8, 3), walkFrame(e, s - 4, 3)))
	if a and b then
		argue(scene, a, b, {
			{ "You hit my car!", "Look at my bumper!" },
			{ "You stopped out of nowhere!", "Ever heard of brakes?" },
			{ "I'm calling my insurance.", "Fine, call 'em!" },
			{ "This is a brand new car!", "Then park it at home!" },
		})
	end
	return true
end

local function trafficStop(scene: Scene): boolean
	local e, s = streetNear()
	if not e then
		return false
	end
	local stopped = car(scene.root, "Car", curbFrame(e, s, 4.5))
	local cruiser = car(scene.root, "PoliceCar", curbFrame(e, s - 15, 4.5))
	if not stopped or not cruiser then
		return false
	end
	blinkers(scene, cruiser, { Color3.fromRGB(255, 40, 40), Color3.fromRGB(40, 90, 255) }, true)
	local cop =
		person(scene, "Officer", facing(walkFrame(e, s + 1, 2), walkFrame(e, s + 4, 2.5)), "police")
	local driver = person(scene, "Driver", facing(walkFrame(e, s + 4, 2.5), walkFrame(e, s + 1, 2)))
	if cop and driver then
		argue(scene, cop, driver, {
			{ "License and registration.", "Do you know why I pulled you over?" },
			{ "Was I going too fast?", "Officer, I can explain!" },
			{ "Fifty-five in a thirty zone.", "Your tail light's out, too." },
			{ "Come on, it's my birthday...", "I'll be careful, promise." },
			{ "I'll let you off with a warning.", "Don't let me see you again." },
		})
	end
	return true
end

local SCENES = { performer, fenderBender, trafficStop }

local function run(kind: (Scene) -> boolean)
	local root = Instance.new("Model")
	root.Name = "StreetEvent"
	root.Parent = folder
	local scene: Scene = { root = root, npcs = {}, alive = true }
	local ok, built = pcall(kind, scene)
	if not ok or not built then
		if not ok then
			warn("[StreetEvents] " .. tostring(built))
		end
		scene.alive = false
		root:Destroy()
		return
	end
	active += 1
	task.delay(LIFETIME, function()
		scene.alive = false
		for _, npc in scene.npcs do
			npc:destroy()
		end
		root:Destroy()
		active -= 1
	end)
end

function StreetEvents.start()
	folder = Instance.new("Folder")
	folder.Name = "StreetEvents"
	folder.Parent = workspace:WaitForChild("Town")
	task.spawn(function()
		task.wait(30)
		while true do
			if active < MAX_ACTIVE and #Players:GetPlayers() > 0 then
				run(pick(SCENES))
			end
			task.wait(rng:NextNumber(MIN_GAP, MAX_GAP))
		end
	end)
end

return StreetEvents
