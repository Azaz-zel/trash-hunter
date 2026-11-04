--!strict
-- Client-side mirror of the server state plus a dispatcher for Net.Event.
-- The client never decides anything; it only displays what the server sent.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Settings = require(script.Parent.Settings)

local handlers: { [string]: { (any) -> () } } = {}
local state: Types.State? = nil
local sounds: { [string]: Sound } = {}

local Store = {}

function Store.on(kind: string, fn: (any) -> ())
	handlers[kind] = handlers[kind] or {}
	table.insert(handlers[kind], fn)
end

-- Local-only events (for example a toast after a failed request).
function Store.emit(kind: string, payload: any)
	for _, fn in handlers[kind] or {} do
		task.spawn(fn, payload)
	end
end

function Store.get(): Types.State?
	return state
end

function Store.action(name: string, payload: any?): (boolean, any)
	local ok, result, message = pcall(Net.Action.InvokeServer, Net.Action, name, payload)
	if not ok then
		Store.emit("toast", { text = "Connection hiccup. Try again." })
		return false, nil
	end
	if result ~= true and typeof(message) == "string" then
		Store.emit("toast", { text = message })
	end
	return result == true, message
end

function Store.play(id: string, volume: number?)
	local sound = sounds[id]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.SoundGroup = Settings.group("Effects")
		sound.Parent = SoundService
		sounds[id] = sound
	end
	local s = sound :: Sound
	s.Volume = volume or 0.6
	SoundService:PlayLocalSound(s)
end

Net.Event.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "state" then
		state = payload
	end
	Store.emit(kind, payload)
end)

return Store
