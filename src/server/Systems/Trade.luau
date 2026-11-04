--!strict
-- Player-to-player trading. One player asks a nearby player; if they accept,
-- both get a trade window. Each side offers up to MAX_ITEMS backpack items
-- and some cash. Any change to an offer clears both "Ready" ticks. When both
-- are ready, both confirm; the server then re-checks everything (items still
-- there, bag room, cash, distance) and swaps it all at once.
-- Trades end if a player leaves, walks away or gets chased.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)

local TC = Config.Trade

type Offer = { items: { string }, cash: number }
type Session = {
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
}

local Trade = {}

local invites: { [Player]: { from: Player, expires: number } } = {}
local sessions: { [Player]: Session } = {}

local function other(s: Session, p: Player): Player
	return if s.a == p then s.b else s.a
end

local function near(a: Player, b: Player, range: number): boolean
	local ra, rb = Guard.root(a), Guard.root(b)
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= range
end

local function busy(p: Player): string?
	if p:GetAttribute("Chased") == true or (tonumber(p:GetAttribute("Wanted")) or 0) > 0 then
		return "Not while the law is after you."
	end
	return nil
end

-- What each side sees: both offers with item ids (for pictures), cash, ticks.
local function view(s: Session, p: Player): any
	local function describe(owner: Player): any
		local profile = Data.get(owner)
		local offer = s.offers[owner]
		local items = {}
		for _, uid in offer.items do
			for _, entry in if profile then profile.backpack else {} do
				if entry.uid == uid then
					table.insert(items, { uid = uid, id = entry.id, mutation = entry.mutation })
				end
			end
		end
		return {
			items = items,
			cash = offer.cash,
			ready = s.ready[owner] == true,
			confirmed = s.confirmed[owner] == true,
		}
	end
	local them = other(s, p)
	return { with = them.DisplayName, mine = describe(p), theirs = describe(them) }
end

local function sendBoth(s: Session, kind: string)
	Router.send(s.a, kind, view(s, s.a))
	Router.send(s.b, kind, view(s, s.b))
end

local function close(s: Session, reason: string)
	sessions[s.a], sessions[s.b] = nil, nil
	Router.send(s.a, "tradeClosed", { reason = reason })
	Router.send(s.b, "tradeClosed", { reason = reason })
end

local function request(player: Player, userId: any): (boolean, string?)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, nil
	end
	if sessions[player] or sessions[target] then
		return false, "Already trading."
	end
	local why = busy(player) or busy(target)
	if why then
		return false, why
	end
	if not near(player, target, TC.RANGE) then
		return false, "Get closer to trade."
	end
	-- One open request per target, so nobody can be spammed with popups.
	local open = invites[target]
	if open and open.expires > os.clock() then
		return false, `{target.DisplayName} already has a request open.`
	end
	invites[target] = { from = player, expires = os.clock() + TC.REQUEST_SECONDS }
	Router.send(target, "tradeInvite", { from = player.DisplayName, seconds = TC.REQUEST_SECONDS })
	return true, `Trade request sent to {target.DisplayName}.`
end

local function respond(player: Player, accept: any): (boolean, string?)
	local invite = invites[player]
	invites[player] = nil
	if not invite or invite.expires < os.clock() or not invite.from.Parent then
		return false, "That request expired."
	end
	local from = invite.from
	if accept ~= true then
		Router.send(from, "toast", { text = `{player.DisplayName} declined the trade.` })
		return true, nil
	end
	if sessions[player] or sessions[from] then
		return false, "Already trading."
	end
	if not near(player, from, TC.RANGE) then
		return false, "Too far apart to trade."
	end
	local s: Session = {
		a = from,
		b = player,
		offers = { [from] = { items = {}, cash = 0 }, [player] = { items = {}, cash = 0 } },
		ready = {},
		confirmed = {},
	}
	sessions[from], sessions[player] = s, s
	sendBoth(s, "tradeOpen")
	return true, nil
end

local function offer(player: Player, payload: any): (boolean, string?)
	local s = sessions[player]
	local profile = Data.get(player)
	if not s or not profile or typeof(payload) ~= "table" or typeof(payload.items) ~= "table" then
		return false, nil
	end
	local items: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in payload.items do
		if typeof(uid) ~= "string" or seen[uid] then
			continue
		end
		for _, entry in profile.backpack do
			if entry.uid == uid then
				seen[uid] = true
				table.insert(items, uid)
			end
		end
	end
	if #items > TC.MAX_ITEMS then
		return false, `Up to {TC.MAX_ITEMS} items per side.`
	end
	local cash = math.floor(tonumber(payload.cash) or 0)
	if cash ~= cash or cash < 0 then
		cash = 0
	end
	cash = math.min(cash, profile.cash)
	s.offers[player] = { items = items, cash = cash }
	s.ready, s.confirmed = {}, {}
	sendBoth(s, "tradeUpdate")
	return true, nil
end

-- Moves everything, or nothing if anything changed.
local function execute(s: Session): string?
	local pa, pb = Data.get(s.a), Data.get(s.b)
	if not pa or not pb then
		return "A save is still loading."
	end
	if not near(s.a, s.b, TC.RANGE * 1.5) then
		return "You walked too far apart."
	end
	local function take(profile: Types.PlayerProfile, o: Offer): { Types.BagItem }?
		local out = {}
		for _, uid in o.items do
			local found = nil
			for _, entry in profile.backpack do
				if entry.uid == uid then
					found = entry
				end
			end
			if not found then
				return nil
			end
			table.insert(out, found)
		end
		return out
	end
	local oa, ob = s.offers[s.a], s.offers[s.b]
	local ga, gb = take(pa, oa), take(pb, ob)
	if not ga or not gb or pa.cash < oa.cash or pb.cash < ob.cash then
		return "Something in the offer is gone."
	end
	if
		#pa.backpack - #ga + #gb > Data.capacity(pa, s.a)
		or #pb.backpack - #gb + #ga > Data.capacity(pb, s.b)
	then
		return "Not enough bag room."
	end
	for _, entry in ga do
		Data.removeItem(pa.backpack, entry.uid)
	end
	for _, entry in gb do
		Data.removeItem(pb.backpack, entry.uid)
	end
	for _, entry in ga do
		Data.addItem(pb, entry.id, entry.mutation)
		Data.discover(pb, entry.id, entry.mutation, s.b)
	end
	for _, entry in gb do
		Data.addItem(pa, entry.id, entry.mutation)
		Data.discover(pa, entry.id, entry.mutation, s.a)
	end
	pa.cash += ob.cash - oa.cash
	pb.cash += oa.cash - ob.cash
	Data.push(s.a)
	Data.push(s.b)
	return nil
end

local function setReady(player: Player, on: any): (boolean, string?)
	local s = sessions[player]
	if not s then
		return false, nil
	end
	s.ready[player] = on == true
	s.confirmed = {}
	sendBoth(s, "tradeUpdate")
	return true, nil
end

local function confirm(player: Player): (boolean, string?)
	local s = sessions[player]
	if not s or not s.ready[s.a] or not s.ready[s.b] then
		return false, "Both of you need to be Ready first."
	end
	s.confirmed[player] = true
	if s.confirmed[s.a] and s.confirmed[s.b] then
		local problem = execute(s)
		close(s, problem or "done")
		return problem == nil, problem
	end
	sendBoth(s, "tradeUpdate")
	return true, nil
end

local function cancel(player: Player): (boolean, string?)
	local s = sessions[player]
	if s then
		close(s, `{player.DisplayName} cancelled.`)
	end
	return true, nil
end

function Trade.init()
	Router.on("tradeRequest", 1, request)
	Router.on("tradeRespond", 0.5, respond)
	Router.on("tradeOffer", 0.2, offer)
	Router.on("tradeReady", 0.2, setReady)
	Router.on("tradeConfirm", 0.5, confirm)
	Router.on("tradeCancel", 0.5, cancel)
end

function Trade.start()
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local s = sessions[player]
		if s then
			close(s, `{player.DisplayName} left.`)
		end
	end)
	-- Walking away or getting chased ends a trade.
	task.spawn(function()
		while true do
			task.wait(1)
			local done = {}
			for _, s in sessions do
				if not done[s] then
					done[s] = true
					if not near(s.a, s.b, TC.RANGE * 1.5) then
						close(s, "You walked too far apart.")
					elseif busy(s.a) or busy(s.b) then
						close(s, "The law showed up.")
					end
				end
			end
		end
	end)
end

return Trade
