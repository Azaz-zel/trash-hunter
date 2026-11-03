--!strict
-- Routes Net.Action requests to handlers with a per-player, per-action rate limit.
-- Handlers return (ok, messageOrPayload); errors are logged and never leak to clients.

local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

type Handler = (player: Player, payload: any) -> (boolean, any)

local handlers: { [string]: { fn: Handler, interval: number } } = {}
local lastCall: { [Player]: { [string]: number } } = {}

local Router = {}

function Router.on(action: string, minInterval: number, fn: Handler)
	assert(handlers[action] == nil, "duplicate action " .. action)
	handlers[action] = { fn = fn, interval = minInterval }
end

function Router.send(player: Player, kind: string, payload: any?)
	Net.Event:FireClient(player, kind, payload)
end

function Router.broadcast(kind: string, payload: any?)
	Net.Event:FireAllClients(kind, payload)
end

Net.Action.OnServerInvoke = function(player: Player, action: any, payload: any)
	if typeof(action) ~= "string" then
		return false, "Bad request"
	end
	local handler = handlers[action]
	if not handler then
		return false, "Bad request"
	end

	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local now = os.clock()
	if now - (calls[action] or 0) < handler.interval then
		return false, "Slow down"
	end
	calls[action] = now

	local ok, result, message = pcall(handler.fn, player, payload)
	if not ok then
		warn(`[Router] {action} failed for {player.Name}: {result}`)
		return false, "Something went wrong"
	end
	return result, message
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

return Router
