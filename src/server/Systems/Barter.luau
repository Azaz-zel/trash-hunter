--!strict
-- Bartering with pedestrians. A walker eyes one random item in your backpack
-- and makes an offer: cash (sometimes generous, sometimes a lowball) or a
-- swap for a specific item they show you up front. Offers are rolled and kept
-- on the server; the client only sees them and answers accept or decline.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Loot = require(Shared.Loot)
local Districts = require(Shared.Districts)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)

local B = Config.Barter
local rng = Random.new()

type Offer = {
	npc: Model,
	uid: string, -- backpack item they want
	cash: number?, -- cash offer, or
	swap: Loot.Roll?, -- the item they give in exchange
	expires: number,
}

local offers: { [Player]: Offer } = {}
local traded: { [Player]: { [Model]: number } } = {} -- next trade time per walker

local Barter = {}

local function npcPos(npc: Model): Vector3
	return npc:GetPivot().Position
end

local function makeOffer(player: Player, npc: Model): (boolean, string?)
	local profile = Data.get(player)
	if not profile or Guard.isFlagged(player) then
		return false, nil
	end
	if Guard.distance(player, npcPos(npc)) > B.RANGE then
		return false, nil
	end
	local name = npc:GetAttribute("DisplayName") or "Stranger"
	local readyAt = traded[player] and traded[player][npc]
	if readyAt and readyAt > os.clock() then
		return false, `{name} already traded with you. Try someone else.`
	end
	if #profile.backpack == 0 then
		return false, `{name}: "Got anything interesting? Your bag's empty."`
	end
	local entry = profile.backpack[rng:NextInteger(1, #profile.backpack)]
	local item = Items.ById[entry.id]
	if not item then
		return false, nil
	end
	local value = Items.value(entry.id, entry.mutation)
	local offer: Offer = { npc = npc, uid = entry.uid, expires = os.clock() + B.OFFER_SECONDS }
	if rng:NextNumber() < B.SWAP_CHANCE then
		-- Same rarity, sometimes one up or down; the item is shown before accepting.
		local roll = rng:NextNumber()
		local shift = if roll < 0.25 then 1 elseif roll < 0.45 then -1 else 0
		local rarity = math.clamp(item.rarity + shift, 1, math.max(item.rarity, 5))
		offer.swap = Loot.roll(rng, 0, rarity, Districts.cityAt(npcPos(npc)))
	else
		local mult = if rng:NextNumber() < B.LOWBALL_CHANCE
			then rng:NextNumber(0.6, 0.95)
			else rng:NextNumber(1.1, 1.6)
		offer.cash = math.max(1, math.floor(value * mult))
	end
	offers[player] = offer
	npc:SetAttribute("BusyUntil", os.clock() + B.OFFER_SECONDS)
	local swap = offer.swap
	Router.send(player, "barterOffer", {
		name = name,
		wantId = entry.id,
		wantMutation = entry.mutation,
		wantValue = value,
		cash = offer.cash,
		giveId = swap and swap.itemId,
		giveMutation = swap and swap.mutation,
		giveValue = swap and swap.value,
		seconds = B.OFFER_SECONDS,
	})
	return true, nil
end

local function answer(player: Player, choice: any): (boolean, string?)
	local offer = offers[player]
	if not offer or (choice ~= "accept" and choice ~= "decline") then
		return false, nil
	end
	offers[player] = nil
	offer.npc:SetAttribute("BusyUntil", nil)
	if choice == "decline" then
		return true, nil
	end
	local profile = Data.get(player)
	if not profile or Guard.isFlagged(player) then
		return false, nil
	end
	if os.clock() > offer.expires then
		return false, "They got bored and walked off."
	end
	if not offer.npc.Parent or Guard.distance(player, npcPos(offer.npc)) > B.RANGE + 4 then
		return false, "You walked away from the deal."
	end
	local entry = Data.removeItem(profile.backpack, offer.uid)
	if not entry then
		return false, "You don't have that item anymore."
	end
	traded[player] = traded[player] or {}
	traded[player][offer.npc] = os.clock() + B.NPC_COOLDOWN
	local swap = offer.swap
	if swap then
		Data.addItem(profile, swap.itemId, swap.mutation)
		Data.discover(profile, swap.itemId, swap.mutation, player)
		Router.send(player, "bought", { name = Items.label(swap.itemId, swap.mutation) })
	else
		local cash = offer.cash or 0
		profile.cash += cash
		Router.send(player, "sold", { amount = cash, count = 1 })
	end
	Data.push(player)
	return true, nil
end

local function bind(npc: Instance)
	if not npc:IsA("Model") then
		return
	end
	local prompt = npc:FindFirstChild("TradePrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player)
		local ok, message = makeOffer(player, npc)
		if not ok and message then
			Router.send(player, "toast", { text = message })
		end
	end)
end

function Barter.init()
	Router.on("barter", 0.3, answer)
end

function Barter.start()
	CollectionService:GetInstanceAddedSignal("Trader"):Connect(bind)
	for _, npc in CollectionService:GetTagged("Trader") do
		bind(npc)
	end
	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		traded[player] = nil
	end)
end

return Barter
