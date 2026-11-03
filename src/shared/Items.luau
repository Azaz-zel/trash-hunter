--!strict
-- Item catalog, rarities and mutations. Rarity color doubles as the value tier
-- so players can read worth at a glance (GDD section 4).

export type Rarity = {
	name: string,
	color: Color3,
	weight: number,
}

export type Item = {
	id: string,
	name: string,
	rarity: number, -- index into Rarities
	value: number,
}

export type Mutation = {
	id: string,
	name: string,
	mult: number,
	chance: number,
	color: Color3,
}

local Rarities: { Rarity } = {
	{ name = "Common", color = Color3.fromRGB(176, 176, 176), weight = 60 },
	{ name = "Uncommon", color = Color3.fromRGB(88, 204, 96), weight = 25 },
	{ name = "Rare", color = Color3.fromRGB(64, 148, 255), weight = 10 },
	{ name = "Epic", color = Color3.fromRGB(176, 96, 255), weight = 4 },
	{ name = "Legendary", color = Color3.fromRGB(255, 152, 40), weight = 0.9 },
	{ name = "Jackpot", color = Color3.fromRGB(255, 216, 0), weight = 0.1 },
}

local List: { Item } = {
	{ id = "cardboard", name = "Soggy Cardboard", rarity = 1, value = 2 },
	{ id = "can", name = "Crushed Can", rarity = 1, value = 3 },
	{ id = "bottle", name = "Glass Bottle", rarity = 1, value = 3 },
	{ id = "shoe", name = "Lonely Shoe", rarity = 1, value = 4 },

	{ id = "hoodie", name = "Faded Hoodie", rarity = 2, value = 10 },
	{ id = "toolbox", name = "Rusty Toolbox", rarity = 2, value = 12 },
	{ id = "gnome", name = "Garden Gnome", rarity = 2, value = 14 },
	{ id = "toaster", name = "Busted Toaster", rarity = 2, value = 15 },

	{ id = "keyboard", name = "Clicky Keyboard", rarity = 3, value = 40 },
	{ id = "monitor", name = "Old Monitor", rarity = 3, value = 45 },
	{ id = "skateboard", name = "Skateboard", rarity = 3, value = 50 },
	{ id = "boombox", name = "Boombox", rarity = 3, value = 55 },

	{ id = "console", name = "Retro Console", rarity = 4, value = 140 },
	{ id = "guitar", name = "Electric Guitar", rarity = 4, value = 160 },
	{ id = "gpu", name = "Graphics Card", rarity = 4, value = 180 },

	{ id = "baseball", name = "Signed Baseball", rarity = 5, value = 500 },
	{ id = "duck", name = "Giant Rubber Duck", rarity = 5, value = 600 },
	{ id = "toilet", name = "Golden Toilet", rarity = 5, value = 750 },

	{ id = "limited_console", name = "Limited Edition Console", rarity = 6, value = 2500 },
	{ id = "gaming_pc", name = "Golden Gaming PC", rarity = 6, value = 3000 },
}

-- Ordered rarest first: the roll checks Golden before Shiny.
local Mutations: { Mutation } = {
	{
		id = "golden",
		name = "Golden",
		mult = 5,
		chance = 0.01,
		color = Color3.fromRGB(255, 216, 0),
	},
	{
		id = "shiny",
		name = "Shiny",
		mult = 2,
		chance = 0.05,
		color = Color3.fromRGB(150, 240, 255),
	},
}

local byId: { [string]: Item } = {}
local byRarity: { { Item } } = {}
for i = 1, #Rarities do
	byRarity[i] = {}
end
for _, item in List do
	assert(byId[item.id] == nil, "duplicate item id " .. item.id)
	byId[item.id] = item
	table.insert(byRarity[item.rarity], item)
end
for i, bucket in byRarity do
	assert(#bucket > 0, "rarity " .. i .. " has no items")
end

local mutationById: { [string]: Mutation } = {}
for _, m in Mutations do
	mutationById[m.id] = m
end

local Items = {
	Rarities = Rarities,
	List = List,
	Mutations = Mutations,
	ById = byId,
	ByRarity = byRarity,
	MutationById = mutationById,
}

function Items.value(itemId: string, mutation: string?): number
	local item = byId[itemId]
	if not item then
		return 0
	end
	local m = mutation and mutationById[mutation]
	return item.value * (if m then m.mult else 1)
end

function Items.label(itemId: string, mutation: string?): string
	local item = byId[itemId]
	local name = if item then item.name else "???"
	local m = mutation and mutationById[mutation]
	return if m then m.name .. " " .. name else name
end

-- Key used by the collection book: one entry per item and per mutation.
function Items.collectionKey(itemId: string, mutation: string?): string
	return if mutation then itemId .. ":" .. mutation else itemId
end

return Items
