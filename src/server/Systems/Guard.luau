--!strict
-- Movement sanity check and position helpers. A horizontal jump faster than
-- Config.Guard.MAX_SPEED flags the player for a short time; flagged players
-- cannot finish searches, sell, or end a chase inside the Hideout.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local World = Config.World
local SAMPLE = 0.25

local lastPos: { [Player]: Vector3 } = {}
local flaggedUntil: { [Player]: number } = {}
-- Server-initiated teleports (capture) must not trip the check.
local ignoreUntil: { [Player]: number } = {}

local Guard = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Guard.root(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Guard.distance(player: Player, point: Vector3): number
	local root = Guard.root(player)
	return if root then (flat(root.Position) - flat(point)).Magnitude else math.huge
end

function Guard.nearestHideout(point: Vector3): Vector3
	local best, bestDist = World.HIDEOUTS[1], math.huge
	for _, c in World.HIDEOUTS do
		local dist = (flat(point) - flat(c)).Magnitude
		if dist < bestDist then
			best, bestDist = c, dist
		end
	end
	return best
end

function Guard.inHideout(player: Player): boolean
	for _, c in World.HIDEOUTS do
		if Guard.distance(player, c) <= World.HIDEOUT_RADIUS then
			return true
		end
	end
	return false
end

function Guard.inRedZone(position: Vector3): boolean
	local offset = position - World.RED_CENTER
	return math.abs(offset.X) <= World.RED_SIZE.X / 2 and math.abs(offset.Z) <= World.RED_SIZE.Y / 2
end

-- At a store counter that sells this kind of thing, or holding Shop Anywhere.
-- city: only that city's stores stock it (nil: any store of that kind).
function Guard.atStore(player: Player, sells: string, city: string?): (boolean, string?)
	local function matches(store: any): boolean
		return city == nil or (store.city or "maple") == city
	end
	if Guard.isFlagged(player) then
		return false, "Hold on..."
	end
	if player:GetAttribute("Pass_shopanywhere") then
		return true, nil
	end
	for _, store in Config.Stores do
		if
			store.sells == sells
			and matches(store)
			and Guard.distance(player, store.counter) <= store.range
		then
			return true, nil
		end
	end
	for _, store in Config.Stores do
		if store.sells == sells and matches(store) then
			return false, `Visit {store.name} to buy this.`
		end
	end
	return false, nil
end

function Guard.isFlagged(player: Player): boolean
	return (flaggedUntil[player] or 0) > os.clock()
end

function Guard.teleport(player: Player, position: Vector3)
	local root = Guard.root(player)
	if not root then
		return
	end
	ignoreUntil[player] = os.clock() + 1
	root.AssemblyLinearVelocity = Vector3.zero
	root:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	lastPos[player] = nil
end

function Guard.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < SAMPLE then
			return
		end
		local elapsed = acc
		acc = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = Guard.root(player)
			if not root then
				lastPos[player] = nil
				continue
			end
			local pos = flat(root.Position)
			local prev = lastPos[player]
			lastPos[player] = pos
			if prev and (ignoreUntil[player] or 0) < now then
				local speed = (pos - prev).Magnitude / elapsed
				local humanoid = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
				local seated = humanoid ~= nil and humanoid.SeatPart ~= nil
				if
					speed
					> (if seated then Config.Guard.MAX_VEHICLE_SPEED else Config.Guard.MAX_SPEED)
				then
					flaggedUntil[player] = now + Config.Guard.FLAG_SECONDS
					warn(`[Guard] {player.Name} moved at {math.floor(speed)} studs/s`)
				end
			end
			-- Replicated so the client can enable Hideout-only buttons.
			player:SetAttribute("InHideout", Guard.inHideout(player))
			player:SetAttribute("InRedZone", Guard.inRedZone(root.Position))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
		flaggedUntil[player] = nil
		ignoreUntil[player] = nil
	end)
end

return Guard
