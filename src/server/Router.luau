--!strict
-- Routes Net.Action requests to handlers behind a per-player, per-action token
-- bucket. A short burst is allowed (tapping Sell on several rows quickly), a
-- flood is not. Handlers return (ok, messageOrPayload); errors are logged and
-- never leak to clients.

local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

type Handler = (player: Player, payload: any) -> (boolean, any)
type Bucket = { tokens: number, last: number }

local BURST = 3
local MAX_PAYLOAD_STRING = 64

local handlers: { [string]: { fn: Handler, rate: number } } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local rejected: { [Player]: number } = {}

local Router = {}

-- minInterval is the sustained gap between calls; BURST calls may come at once.
function Router.on(action: string, minInterval: number, fn: Handler)
	assert(handlers[action] == nil, "duplicate action " .. action)
	handlers[action] = { fn = fn, rate = 1 / minInterval }
end

function Router.send(player: Player, kind: string, payload: any?)
	Net.Event:FireClient(player, kind, payload)
end

function Router.broadcast(kind: string, payload: any?)
	Net.Event:FireAllClients(kind, payload)
end

local function allow(player: Player, action: string, rate: number): boolean
	local now = os.clock()
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local b = mine[action]
	if not b then
		b = { tokens = BURST, last = now }
		mine[action] = b
	end
	b.tokens = math.min(BURST, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Every payload in this game is nil or a short string (an item uid, "all",
-- or a choice name). Anything else is rejected before a handler sees it.
local function validPayload(payload: any): boolean
	return payload == nil or (typeof(payload) == "string" and #payload <= MAX_PAYLOAD_STRING)
end

Net.Action.OnServerInvoke = function(player: Player, action: any, payload: any)
	if typeof(action) ~= "string" or not validPayload(payload) then
		return false, "Bad request"
	end
	local handler = handlers[action]
	if not handler then
		return false, "Bad request"
	end
	if not allow(player, action, handler.rate) then
		-- Logged as telemetry only: lag and retries trip this too, so never auto-ban.
		rejected[player] = (rejected[player] or 0) + 1
		if rejected[player] % 50 == 0 then
			warn(`[Router] {player.Name} hit the rate limit {rejected[player]} times`)
		end
		return false, "Slow down"
	end

	local ok, result, message = pcall(handler.fn, player, payload)
	if not ok then
		warn(`[Router] {action} failed for {player.Name}: {result}`)
		return false, "Something went wrong"
	end
	return result, message
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	rejected[player] = nil
end)

return Router
