--!strict
-- What the player's own character shows: a real backpack on their back that
-- grows with the backpack level, and walk speed (base + Running Shoes).

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Data = require(script.Parent.Data)

local PACKS = {
	{ size = Vector3.new(1.9, 2.3, 1.1), color = Color3.fromRGB(96, 74, 52) },
	{ size = Vector3.new(2.2, 2.7, 1.35), color = Color3.fromRGB(62, 82, 56) },
	{ size = Vector3.new(2.5, 3.1, 1.6), color = Color3.fromRGB(36, 40, 46) },
}

local Avatar = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart, offset: CFrame)
	b.CFrame = a.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function buildPack(character: Model, level: number)
	local old = character:FindFirstChild("TrashPack")
	if old then
		old:Destroy()
	end
	local torso = (
		character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	) :: BasePart?
	if not torso then
		return
	end
	local spec = PACKS[math.clamp(level, 1, #PACKS)]
	local model = Instance.new("Model")
	model.Name = "TrashPack"
	local s = spec.size
	-- Torso back is +Z; hang the pack just behind it.
	local back = CFrame.new(0, 0.1, torso.Size.Z / 2 + s.Z / 2)
	local body = part(model, "Body", s, spec.color, Enum.Material.Fabric)
	weld(torso, body, back)
	local flap = part(
		model,
		"Flap",
		Vector3.new(s.X + 0.05, s.Y * 0.3, s.Z + 0.08),
		spec.color:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Fabric
	)
	weld(body, flap, CFrame.new(0, s.Y * 0.36, 0))
	local pocket = part(
		model,
		"Pocket",
		Vector3.new(s.X * 0.7, s.Y * 0.35, 0.35),
		spec.color:Lerp(Color3.new(0, 0, 0), 0.12),
		Enum.Material.Fabric
	)
	weld(body, pocket, CFrame.new(0, -s.Y * 0.18, s.Z / 2 + 0.15))
	for _, x in { -0.45, 0.45 } do
		local strap = part(
			model,
			"Strap",
			Vector3.new(0.22, s.Y * 0.95, 0.08),
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Fabric
		)
		weld(torso, strap, CFrame.new(x, 0.15, -torso.Size.Z / 2 - 0.04))
	end
	if level >= 3 then
		local roll = part(
			model,
			"Bedroll",
			Vector3.new(s.X + 0.3, 0.8, 0.8),
			Color3.fromRGB(150, 60, 40),
			Enum.Material.Fabric
		)
		roll.Shape = Enum.PartType.Cylinder
		weld(body, roll, CFrame.new(0, s.Y / 2 + 0.35, 0))
	end
	model.Parent = character
end

-- Re-applies everything; called on spawn and whenever upgrades change.
function Avatar.refresh(player: Player)
	local character = player.Character
	local profile = Data.get(player)
	if not character or not profile then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local shoes = if Data.hasTool(profile, "shoes") then Config.TOOL_EFFECT.SHOES_SPEED else 0
		humanoid.WalkSpeed = Config.Player.WALK_SPEED + shoes
	end
	buildPack(character, profile.backpackLevel)
end

function Avatar.start()
	local function onPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			Avatar.refresh(player)
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			task.wait(0.5)
			Avatar.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Data.onLoaded(function(player)
		Avatar.refresh(player)
	end)
end

return Avatar
