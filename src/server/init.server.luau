--!strict
-- TrashHunter server entry point. Two-phase bootstrap: init() all systems,
-- then start() all systems.

local Players = game:GetService("Players")

-- Hold characters until the city (and its Hideout spawn) is built. World.init
-- yields while it builds the roads; a player who joined meanwhile used to
-- spawn at the Baseplate's SpawnLocation in the middle of Downtown (tier 4)
-- instead of at the Hideout.
Players.CharacterAutoLoads = false

local Systems = script:FindFirstChild("Systems")

local loaded: { [string]: any } = {}
if Systems then
	for _, child in Systems:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, system in loaded do
	if typeof(system.init) == "function" then
		system.init()
	end
end

Players.CharacterAutoLoads = true
for _, player in Players:GetPlayers() do
	if not player.Character then
		task.spawn(player.LoadCharacter, player)
	end
end

for _, system in loaded do
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end

print("[TrashHunter] server started")
