--!strict
-- The game's only two remotes. Client -> server requests go through Action
-- (a RemoteFunction routed by name); server -> client pushes go through Event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	Instance.new("RemoteFunction", folder).Name = "Action"
	Instance.new("RemoteEvent", folder).Name = "Event"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

return {
	Action = folder:WaitForChild("Action") :: RemoteFunction,
	Event = folder:WaitForChild("Event") :: RemoteEvent,
}
