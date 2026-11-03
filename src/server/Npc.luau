--!strict
-- Shared server-side humanoid NPC: builds an R15 rig from a catalog outfit,
-- plays walk/run/idle animations, and moves toward a goal with a straight
-- MoveTo when the line is clear, falling back to PathfindingService around
-- walls and fences. Used by the security guards and the pedestrians.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local ANIM = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://913376220",
}

-- Catalog layered clothing (asset ids) used for outfits.
local CLOTHING = {
	policeShirt = 80924038038644,
	policePants = 140048946599540,
	policeHat = "117845791540808",
	hair = "1772336109", -- Roblox "Down to Earth Hair"
	tops = {
		{ id = 16092650924, kind = Enum.AccessoryType.Jacket },
		{ id = 17775630860, kind = Enum.AccessoryType.Jacket },
		{ id = 81422739745999, kind = Enum.AccessoryType.Jacket },
		{ id = 14067855884, kind = Enum.AccessoryType.Sweater },
		{ id = 106401482203605, kind = Enum.AccessoryType.TShirt },
		{ id = 136406663455163, kind = Enum.AccessoryType.TShirt },
		{ id = 9180371398, kind = Enum.AccessoryType.TShirt },
	},
	pants = { 82935835255895, 17772764977, 93566112176809, 100508742541378 },
}

local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(150, 98, 66),
	Color3.fromRGB(104, 66, 44),
}

export type Npc = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	moveToward: (self: Npc, goal: Vector3, now: number) -> (),
	stop: (self: Npc) -> (),
	face: (self: Npc, direction: Vector3) -> (),
	destroy: (self: Npc) -> (),
	_path: { PathWaypoint }?,
	_pathIndex: number,
	_pathBusy: boolean,
	_lastPath: number,
	_lastMove: number,
	_conns: { RBXScriptConnection },
}

local Npc = {}
Npc.__index = Npc

local moveParams = RaycastParams.new()
moveParams.FilterType = Enum.RaycastFilterType.Exclude

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function describe(kind: string, rng: Random): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = skin
	desc.LeftLegColor = skin
	desc.RightLegColor = skin
	local accessories = {}
	if kind == "police" then
		table.insert(
			accessories,
			{
				AssetId = CLOTHING.policePants,
				AccessoryType = Enum.AccessoryType.Pants,
				IsLayered = true,
				Order = 1,
			}
		)
		table.insert(
			accessories,
			{
				AssetId = CLOTHING.policeShirt,
				AccessoryType = Enum.AccessoryType.Shirt,
				IsLayered = true,
				Order = 2,
			}
		)
		desc.HatAccessory = CLOTHING.policeHat
	else
		local top = CLOTHING.tops[rng:NextInteger(1, #CLOTHING.tops)]
		table.insert(
			accessories,
			{
				AssetId = CLOTHING.pants[rng:NextInteger(1, #CLOTHING.pants)],
				AccessoryType = Enum.AccessoryType.Pants,
				IsLayered = true,
				Order = 1,
			}
		)
		table.insert(
			accessories,
			{ AssetId = top.id, AccessoryType = top.kind, IsLayered = true, Order = 2 }
		)
		if rng:NextNumber() < 0.7 then
			desc.HairAccessory = CLOTHING.hair
		end
	end
	-- false: only replace layered clothing, keep the HatAccessory/HairAccessory set above.
	pcall(desc.SetAccessories, desc, accessories, false)
	return desc
end

-- kind: "police" | "civilian"
function Npc.new(kind: string, name: string, cframe: CFrame, parent: Instance, rng: Random): Npc?
	local ok, result = pcall(
		Players.CreateHumanoidModelFromDescription,
		Players,
		describe(kind, rng),
		Enum.HumanoidRigType.R15
	)
	if not ok then
		-- Catalog hiccup: fall back to a plain rig rather than no NPC.
		ok, result = pcall(
			Players.CreateHumanoidModelFromDescription,
			Players,
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
		if not ok then
			warn("[Npc] could not build " .. name .. ": " .. tostring(result))
			return nil
		end
	end
	local model = result :: Model
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- a LocalScript never runs on an NPC; we drive animations here
	end
	model:PivotTo(cframe)
	model.Parent = parent
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetNetworkOwner(nil)
		end
	end

	-- Tracks must be loaded after the rig is in the DataModel or they stay empty.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local function track(id: string, priority: Enum.AnimationPriority): AnimationTrack
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local t = (animator :: Animator):LoadAnimation(anim)
		t.Priority = priority
		t.Looped = true
		return t
	end
	local idle = track(ANIM.idle, Enum.AnimationPriority.Idle)
	local walk = track(ANIM.walk, Enum.AnimationPriority.Movement)
	local run = track(ANIM.run, Enum.AnimationPriority.Movement)
	idle:Play()
	local moving: AnimationTrack? = nil
	local conns = {}
	table.insert(
		conns,
		humanoid.Running:Connect(function(speed)
			local want = if speed < 0.5 then nil elseif speed > 12 then run else walk
			if want == moving then
				return
			end
			if moving then
				moving:Stop(0.2)
			end
			moving = want
			if want then
				want:Play(0.2)
			end
		end)
	)

	local self = setmetatable({
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		_path = nil,
		_pathIndex = 2,
		_pathBusy = false,
		_lastPath = 0,
		_lastMove = 0,
		_conns = conns,
	}, Npc)
	return (self :: any) :: Npc
end

function Npc.stop(self: Npc)
	self.humanoid:MoveTo(self.root.Position)
	self._path = nil
end

-- Turn in place toward a horizontal direction (used for "looking around").
function Npc.face(self: Npc, direction: Vector3)
	local dir = flat(direction)
	if dir.Magnitude < 0.01 then
		return
	end
	local pos = self.root.Position
	self.root.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
end

function Npc.moveToward(self: Npc, goal: Vector3, now: number)
	if now - self._lastMove < 0.2 then
		return
	end
	self._lastMove = now
	local filter: { Instance } = { self.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	moveParams.FilterDescendantsInstances = filter
	local origin = self.root.Position
	if not workspace:Raycast(origin, flat(goal - origin), moveParams) then
		self._path = nil
		self.humanoid:MoveTo(goal)
		return
	end
	if not self._pathBusy and now - self._lastPath > 0.8 then
		self._pathBusy = true
		self._lastPath = now
		task.spawn(function()
			local p = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true,
				WaypointSpacing = 6,
			})
			local okPath = pcall(p.ComputeAsync, p, origin, goal)
			if okPath and p.Status == Enum.PathStatus.Success then
				self._path = p:GetWaypoints()
				self._pathIndex = 2
			else
				self._path = nil
			end
			self._pathBusy = false
		end)
	end
	local path = self._path
	if path and path[self._pathIndex] then
		local waypoint = path[self._pathIndex]
		if (flat(waypoint.Position) - flat(origin)).Magnitude < 3 then
			self._pathIndex += 1
			waypoint = path[self._pathIndex] or waypoint
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			self.humanoid.Jump = true
		end
		self.humanoid:MoveTo(waypoint.Position)
	end
end

function Npc.destroy(self: Npc)
	for _, c in self._conns do
		c:Disconnect()
	end
	self.model:Destroy()
end

return Npc
