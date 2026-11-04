--!strict
-- Player cars: spawn your car next to you, drive it (Roblox's own vehicle kit
-- handles driving and mobile controls), and use the trunk as extra storage
-- that guards cannot confiscate. Only the owner may drive or open the trunk;
-- friends can ride in the passenger seats.

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Progress = require(script.Parent.Progress)
local Pedestrians = require(script.Parent.Pedestrians)

local CAR_ASSET = 6418230807 -- Roblox-owned drivable "Police Car" from the vehicle kit
local CAR = Config.CAR

local cars: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}
local template: Model? = nil
local folder: Folder

local Vehicles = {}

local function carColor(id: string): Color3
	for _, c in Config.Cars do
		if c.id == id then
			return c.color
		end
	end
	return Config.Cars[1].color
end

local function carName(id: string): string
	for _, c in Config.Cars do
		if c.id == id then
			return c.name
		end
	end
	return "Car"
end

-- Strip the police look but keep every part the kit's scripts may reference.
local function prepareTemplate(model: Model)
	for _, d in model:GetDescendants() do
		local rackLight = d:IsA("Light")
			and d.Parent ~= nil
			and string.find(string.lower(d.Parent.Name), "rack") ~= nil
		if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui") or rackLight then
			d:Destroy()
		elseif d:IsA("BasePart") then
			local n = string.lower(d.Name)
			if string.find(n, "light_rack") or string.find(n, "light_blue") or n == "light_red" then
				d.Transparency = 1
			end
		end
	end
end

local function paint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and (
				d.BrickColor == BrickColor.new("Institutional white")
				or d.BrickColor == BrickColor.new("Lily white")
			)
		then
			d.Color = color
		end
	end
end

local function ownerOf(model: Model): Player?
	return Players:GetPlayerByUserId(tonumber(model:GetAttribute("Owner")) or 0)
end

-- Puts a player who just left a seat beside the car instead of inside its body.
local function stepOut(seat: BasePart, humanoid: Humanoid, model: Model)
	local rider = Players:GetPlayerFromCharacter(humanoid.Parent)
	if not rider or not model.Parent then
		return
	end
	local _, size = model:GetBoundingBox()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, humanoid.Parent :: Instance }
	local side = seat.CFrame.RightVector
	for _, dir in { -side, side, seat.CFrame.LookVector, -seat.CFrame.LookVector } do
		local spot = seat.Position + dir * (size.X / 2 + 3)
		local blocked = false
		-- Box from the seat height up, so the ground under the car never counts.
		local probe = CFrame.new(spot + Vector3.new(0, 2, 0))
		for _, hit in workspace:GetPartBoundsInBox(probe, Vector3.new(3, 3.5, 3), params) do
			if hit.CanCollide and hit.Size.Y > 1.2 then
				blocked = true
				break
			end
		end
		if not blocked then
			Guard.teleport(rider, Vector3.new(spot.X, seat.Position.Y - 2, spot.Z))
			return
		end
	end
	Guard.teleport(rider, seat.Position + Vector3.new(0, size.Y, 0))
end

local function guardSeats(model: Model)
	for _, seat in model:GetDescendants() do
		if seat:IsA("VehicleSeat") or seat:IsA("Seat") then
			local last: Humanoid? = nil
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local left = last
				last = seat.Occupant
				if left and not seat.Occupant then
					task.defer(stepOut, seat, left, model)
				end
			end)
		end
		if seat:IsA("VehicleSeat") then
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local humanoid = seat.Occupant
				local rider = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
				if rider and rider ~= ownerOf(model) then
					local w = seat:FindFirstChild("SeatWeld")
					if w then
						w:Destroy()
					end
					humanoid.Jump = true
					Router.send(rider, "toast", { text = "Only the owner can drive this car." })
				end
			end)
		end
	end
end

-- Head and tail lamps on a player car; lit at night (see the loop in start).
local function addLamps(car: Model)
	local bb, size = car:GetBoundingBox()
	local look = bb:VectorToObjectSpace(car:GetPivot().LookVector)
	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat then
		look = bb:VectorToObjectSpace(seat.CFrame.LookVector)
	end
	local f = if math.abs(look.X) > math.abs(look.Z)
		then Vector3.new(math.sign(look.X), 0, 0)
		else Vector3.new(0, 0, math.sign(look.Z))
	local r = Vector3.new(-f.Z, 0, f.X)
	local halfL = (math.abs(f.X) * size.X + math.abs(f.Z) * size.Z) / 2
	local halfW = (math.abs(r.X) * size.X + math.abs(r.Z) * size.Z) / 2
	local worldF = bb:VectorToWorldSpace(f)
	local root = car.PrimaryPart or (seat :: BasePart?)
	if not root then
		return
	end
	for _, spec in
		{
			{ along = halfL, color = Color3.fromRGB(255, 244, 214), name = "HeadLamp" },
			{ along = -halfL, color = Color3.fromRGB(200, 20, 20), name = "TailLamp" },
		}
	do
		for _, side in { -1, 1 } do
			local pos = (bb * CFrame.new(
				f * spec.along + r * side * (halfW - 1) - Vector3.yAxis * size.Y * 0.1
			)).Position
			local p = Instance.new("Part")
			p.Name = spec.name
			p.Size = Vector3.new(1.1, 0.45, 0.15)
			p.CFrame = CFrame.lookAt(pos, pos + worldF * math.sign(spec.along))
			p.Color = spec.color
			p.Material = Enum.Material.SmoothPlastic
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			if spec.name == "HeadLamp" and side == 1 then
				local beam = Instance.new("SpotLight")
				beam.Face = Enum.NormalId.Front
				beam.Angle = 60
				beam.Range = 55
				beam.Brightness = 3
				beam.Enabled = false
				beam.Parent = p
			end
			p.Parent = car
		end
	end
end

local function lampsOn(car: Model, on: boolean)
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "HeadLamp" or d.Name == "TailLamp") then
			d.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local beam = d:FindFirstChildOfClass("SpotLight")
			if beam then
				beam.Enabled = on
			end
		end
	end
end

-- Horn: people in front of the car jump out of the way.
local function honk(player: Player): (boolean, string?)
	local car = cars[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not car or not seat or not seat:IsDescendantOf(car) then
		return false, nil
	end
	local ahead = seat.Position + seat.CFrame.LookVector * (CAR.HONK_RANGE / 2)
	Pedestrians.panic(ahead, CAR.HONK_RANGE / 2, nil)
	return true, nil
end

local function removeCar(player: Player)
	local old = cars[player]
	cars[player] = nil
	if old then
		old:Destroy()
	end
end

local function spawnCar(player: Player): (boolean, string?)
	local profile = Data.get(player)
	local root = Guard.root(player)
	if not profile or not root or not template then
		return false, if template then nil else "Cars are not available right now."
	end
	if player:GetAttribute("Chased") then
		return false, "No time, run!"
	end
	local now = os.clock()
	local wait = CAR.SPAWN_COOLDOWN - (now - (lastSpawn[player] or -math.huge))
	if wait > 0 then
		return false, `Wait {math.ceil(wait)}s.`
	end
	lastSpawn[player] = now
	removeCar(player)

	local car = template:Clone()
	car.Name = player.Name .. "'s " .. carName(profile.car)
	paint(car, carColor(profile.car))
	car:SetAttribute("Owner", player.UserId)
	car:SetAttribute("CarId", profile.car)

	-- Place it beside the player on clear ground; inside the Hideout (or when
	-- every side is blocked) it goes to the apron out front.
	local cf, size = car:GetBoundingBox()
	local lift = car:GetPivot().Y - (cf.Y - size.Y / 2)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car, player.Character :: Model, workspace.Terrain }
	local function clear(spot: Vector3, facing: Vector3): CFrame?
		local placed = CFrame.lookAt(
			Vector3.new(spot.X, 0.4 + lift, spot.Z),
			Vector3.new(spot.X, 0.4 + lift, spot.Z) + facing
		)
		local box = placed * car:GetPivot():ToObjectSpace(cf)
		for _, hit in workspace:GetPartBoundsInBox(box, size, params) do
			if hit.CanCollide and hit.Size.Y >= 1.2 then
				return nil -- something taller than a road or slab is in the way
			end
		end
		return placed
	end
	local target: CFrame? = nil
	if not Guard.inHideout(player) then
		for _, offset in { right * 10, -right * 10, -look * 12, look * 14 } do
			target = clear(root.Position + offset, look)
			if target then
				break
			end
		end
	end
	local c = Guard.nearestHideout(root.Position)
	car:PivotTo(
		target
			or CFrame.lookAt(
				Vector3.new(c.X, 0.4 + lift, c.Z - 42),
				Vector3.new(c.X + 10, 0.4 + lift, c.Z - 42)
			)
	)

	local floor = car:FindFirstChild("FloorPanel", true)
	if floor and floor:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrunkPrompt"
		prompt.ActionText = "Open trunk"
		prompt.ObjectText = carName(profile.car)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = CAR.TRUNK_RANGE - 2
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.T
		prompt.UIOffset = Vector2.new(0, 60)
		prompt.Parent = floor
	end
	addLamps(car)
	lampsOn(car, workspace:GetAttribute("Night") == true)
	car.Parent = folder
	guardSeats(car)
	cars[player] = car
	return true, nil
end

local function nearCar(player: Player): (Model?, string?)
	local car = cars[player]
	if not car or not car.Parent then
		return nil, "Spawn your car first."
	end
	if Guard.distance(player, car:GetPivot().Position) > CAR.TRUNK_RANGE then
		return nil, "Stand next to your car."
	end
	return car, nil
end

local function toTrunk(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	if player:GetAttribute("Chased") then
		return false, "No time, run!"
	end
	local car, message = nearCar(player)
	if not car then
		return false, message
	end
	local capacity = Data.trunkCapacity(profile)
	local moved = 0
	local list = if uid == "all" then table.clone(profile.backpack) else {}
	if uid ~= "all" then
		for _, entry in profile.backpack do
			if entry.uid == uid then
				table.insert(list, entry)
			end
		end
	end
	for _, entry in list do
		if #profile.trunk >= capacity then
			break
		end
		local taken = Data.removeItem(profile.backpack, entry.uid)
		if taken then
			table.insert(profile.trunk, taken)
			moved += 1
		end
	end
	if moved == 0 then
		return false, if #profile.trunk >= capacity then "Trunk is full." else "Nothing to stash."
	end
	Data.push(player)
	return true, nil
end

local function fromTrunk(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local car, message = nearCar(player)
	if not car then
		return false, message
	end
	if #profile.backpack >= Data.capacity(profile, player) then
		return false, "Backpack full."
	end
	local entry = Data.removeItem(profile.trunk, uid)
	if not entry then
		return false, "That item is gone."
	end
	table.insert(profile.backpack, entry)
	Data.push(player)
	return true, nil
end

local function sellTrunk(player: Player): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	if Guard.isFlagged(player) or not Guard.inHideout(player) then
		return false, "Sell at the Hideout."
	end
	local car = cars[player]
	if
		not car
		or (car:GetPivot().Position - Guard.nearestHideout(car:GetPivot().Position)).Magnitude
			> CAR.SELL_RANGE
	then
		return false, "Park your car at the Hideout first."
	end
	if #profile.trunk == 0 then
		return false, "Your trunk is empty."
	end
	local earned, count = 0, #profile.trunk
	for _, entry in profile.trunk do
		earned += Items.value(entry.id, entry.mutation)
	end
	table.clear(profile.trunk)
	profile.cash += earned
	Progress.track(player, "earn", { amount = earned })
	Data.advanceTutorial(profile, 1, player)
	Data.push(player)
	Router.send(player, "sold", { amount = earned, count = count })
	return true, nil
end

function Vehicles.init()
	Router.on("spawnCar", 1, spawnCar)
	Router.on("honk", 0.8, honk)
	Router.on("toTrunk", 0.15, toTrunk)
	Router.on("fromTrunk", 0.15, fromTrunk)
	Router.on("sellTrunk", 0.5, sellTrunk)
end

function Vehicles.start()
	folder = Instance.new("Folder")
	folder.Name = "PlayerCars"
	folder.Parent = workspace

	task.spawn(function()
		local ok, container = pcall(InsertService.LoadAsset, InsertService, CAR_ASSET)
		local model = ok and (container :: Instance):FindFirstChildWhichIsA("Model")
		if not model then
			warn("[Vehicles] could not load the car: " .. tostring(container))
			return
		end
		prepareTemplate(model)
		model.Name = "DriveTemplate"
		model.Parent = ServerStorage
		template = model
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeCar(player)
		lastSpawn[player] = nil
	end)
	workspace:GetAttributeChangedSignal("Night"):Connect(function()
		local night = workspace:GetAttribute("Night") == true
		for _, car in cars do
			lampsOn(car, night)
		end
	end)
end

return Vehicles
