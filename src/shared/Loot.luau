--!strict
-- Pure loot roll. The server is the only caller that grants items; this module
-- is shared so the odds stay in one place (and can be shown to players later).

local Config = require(script.Parent.Config)
local Items = require(script.Parent.Items)

export type Roll = {
	itemId: string,
	rarity: number,
	mutation: string?,
	value: number,
}

local Loot = {}

function Loot.weights(boost: number): { number }
	local factor = 1 + Config.Boost.BIAS_STEP * math.max(boost, 0)
	local out = {}
	for i, rarity in Items.Rarities do
		out[i] = rarity.weight * factor ^ (i - 1)
	end
	return out
end

function Loot.rollRarity(rng: Random, boost: number): number
	local weights = Loot.weights(boost)
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = rng:NextNumber() * total
	for i, w in weights do
		pick -= w
		if pick <= 0 then
			return i
		end
	end
	return #weights
end

function Loot.roll(rng: Random, boost: number, forceRarity: number?): Roll
	local rarity = forceRarity or Loot.rollRarity(rng, boost)
	local bucket = Items.ByRarity[rarity]
	local item = bucket[rng:NextInteger(1, #bucket)]
	local mutation: string? = nil
	for _, m in Items.Mutations do
		if rng:NextNumber() < m.chance then
			mutation = m.id
			break
		end
	end
	return {
		itemId = item.id,
		rarity = rarity,
		mutation = mutation,
		value = Items.value(item.id, mutation),
	}
end

-- Cheap sanity check, run by the server in Studio only.
function Loot.selfCheck()
	local rng = Random.new(1)
	local n = 20000
	local function rarePlusShare(boost: number): number
		local hits = 0
		for _ = 1, n do
			if Loot.rollRarity(rng, boost) >= 3 then
				hits += 1
			end
		end
		return hits / n
	end
	local base, boosted = rarePlusShare(0), rarePlusShare(Config.Boost.RED_ZONE)
	assert(base > 0.12 and base < 0.18, `Rare+ share at boost 0 is {base}, expected about 0.15`)
	assert(boosted > base * 1.5, `boost does not raise Rare+ odds ({base} -> {boosted})`)
	local forced = Loot.roll(rng, 0, 3)
	assert(forced.rarity == 3 and Items.ById[forced.itemId].rarity == 3, "forced rarity ignored")
	assert(Items.value("monitor", "golden") == 225, "mutation multiplier wrong")
end

return Loot
