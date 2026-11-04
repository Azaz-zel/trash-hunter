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
	city: string?, -- nil means Maple; dumpsters only drop their city's items
	season: string?, -- only drops during this season (see SEASONS)
}

export type Mutation = {
	id: string,
	name: string,
	mult: number,
	chance: number,
	color: Color3,
}

local Rarities: { Rarity } = {
	{ name = "Common", color = Color3.fromRGB(176, 176, 176), weight = 62 },
	{ name = "Uncommon", color = Color3.fromRGB(88, 204, 96), weight = 25 },
	{ name = "Rare", color = Color3.fromRGB(64, 148, 255), weight = 9 },
	{ name = "Epic", color = Color3.fromRGB(176, 96, 255), weight = 3.2 },
	{ name = "Legendary", color = Color3.fromRGB(255, 152, 40), weight = 0.12 },
	{ name = "Jackpot", color = Color3.fromRGB(255, 216, 0), weight = 0.012 },
	{ name = "Mythic", color = Color3.fromRGB(255, 60, 120), weight = 0.003 },
	{ name = "Secret", color = Color3.fromRGB(120, 255, 230), weight = 0.0004 },
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

	-- Seasonal (limited): only in the dumpsters during their months.
	{
		id = "pumpkin",
		name = "Cursed Jack-o'-Lantern",
		rarity = 3,
		value = 90,
		season = "halloween",
	},
	{ id = "cape", name = "Vampire Cape", rarity = 4, value = 320, season = "halloween" },
	{ id = "doll", name = "Haunted Doll", rarity = 5, value = 1400, season = "halloween" },
	{ id = "snowglobe", name = "Vintage Snow Globe", rarity = 3, value = 90, season = "winter" },
	{ id = "ornament", name = "Golden Ornament", rarity = 4, value = 320, season = "winter" },
	{ id = "nutcracker", name = "Royal Nutcracker", rarity = 5, value = 1400, season = "winter" },

	{ id = "baseball", name = "Signed Baseball", rarity = 5, value = 500 },
	{ id = "duck", name = "Giant Rubber Duck", rarity = 5, value = 600 },
	{ id = "toilet", name = "Golden Toilet", rarity = 5, value = 750 },

	{ id = "limited_console", name = "Limited Edition Console", rarity = 6, value = 2500 },
	{ id = "gaming_pc", name = "Golden Gaming PC", rarity = 6, value = 3000 },

	{ id = "pizzabox", name = "Old Pizza Box", rarity = 1, value = 3 },
	{ id = "newspaper", name = "Soggy Newspaper", rarity = 1, value = 2 },
	{ id = "brokenlamp", name = "Broken Lamp", rarity = 1, value = 4 },
	{ id = "radio", name = "Pocket Radio", rarity = 2, value = 16 },
	{ id = "sneakers", name = "Worn Sneakers", rarity = 2, value = 18 },
	{ id = "teddy", name = "Teddy Bear", rarity = 2, value = 13 },
	{ id = "camera", name = "Film Camera", rarity = 3, value = 60 },
	{ id = "vinyl", name = "Vinyl Record", rarity = 3, value = 48 },
	{ id = "drone", name = "Toy Drone", rarity = 3, value = 65 },
	{ id = "headphones", name = "Studio Headphones", rarity = 4, value = 200 },
	{ id = "trophy", name = "Bowling Trophy", rarity = 4, value = 170 },
	{ id = "goldwatch", name = "Gold Watch", rarity = 5, value = 900 },
	{ id = "diamondring", name = "Diamond Ring", rarity = 6, value = 3500 },
	{ id = "neonkatana", name = "Neon Katana", rarity = 7, value = 12000 },
	{ id = "cyberarm", name = "Cybernetic Arm", rarity = 7, value = 15000 },
	{ id = "alienegg", name = "Alien Egg", rarity = 8, value = 50000 },

	-- Port Haven: worth a bit more, found only in Port Haven dumpsters.
	{ id = "rope", name = "Frayed Rope", rarity = 1, value = 4, city = "port" },
	{ id = "net", name = "Torn Fishing Net", rarity = 1, value = 4, city = "port" },
	{ id = "buoy", name = "Cracked Buoy", rarity = 1, value = 5, city = "port" },
	{ id = "crabtrap", name = "Bent Crab Trap", rarity = 1, value = 6, city = "port" },

	{ id = "lantern", name = "Ship Lantern", rarity = 2, value = 16, city = "port" },
	{ id = "compass", name = "Brass Compass", rarity = 2, value = 18, city = "port" },
	{ id = "oar", name = "Wooden Oar", rarity = 2, value = 14, city = "port" },

	{ id = "helmet", name = "Diving Helmet", rarity = 3, value = 65, city = "port" },
	{ id = "wheel", name = "Ship's Wheel", rarity = 3, value = 60, city = "port" },
	{ id = "spyglass", name = "Spyglass", rarity = 3, value = 55, city = "port" },

	{ id = "sextant", name = "Captain's Sextant", rarity = 4, value = 210, city = "port" },
	{ id = "bottleship", name = "Ship in a Bottle", rarity = 4, value = 190, city = "port" },

	{ id = "anchor", name = "Golden Anchor", rarity = 5, value = 850, city = "port" },
	{ id = "figurehead", name = "Mermaid Figurehead", rarity = 5, value = 750, city = "port" },

	{ id = "chest", name = "Pirate Treasure Chest", rarity = 6, value = 3800, city = "port" },
	{ id = "seashell", name = "Spiral Seashell", rarity = 1, value = 5, city = "port" },
	{ id = "snorkel", name = "Snorkel Mask", rarity = 2, value = 17, city = "port" },
	{ id = "flaregun", name = "Flare Gun", rarity = 3, value = 70, city = "port" },
	{ id = "doubloons", name = "Doubloon Pouch", rarity = 4, value = 230, city = "port" },
	{ id = "krakeneye", name = "Kraken Eye", rarity = 7, value = 14000, city = "port" },
	{ id = "mermaidcrown", name = "Mermaid's Crown", rarity = 8, value = 60000, city = "port" },
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
-- byCity[city][rarity] = items; every city must cover every rarity.
local byCity: { [string]: { { Item } } } = {}
for _, item in List do
	assert(byId[item.id] == nil, "duplicate item id " .. item.id)
	byId[item.id] = item
	local city = item.city or "maple"
	if not byCity[city] then
		byCity[city] = {}
		for i = 1, #Rarities do
			byCity[city][i] = {}
		end
	end
	table.insert(byCity[city][item.rarity], item)
end
for city, buckets in byCity do
	for i, bucket in buckets do
		assert(#bucket > 0, `{city} has no items of rarity {i}`)
	end
end

local mutationById: { [string]: Mutation } = {}
for _, m in Mutations do
	mutationById[m.id] = m
end

-- Months (UTC) each season runs.
local SEASONS: { [string]: { number } } = {
	halloween = { 10 },
	winter = { 12, 1 },
}

local Items = {
	Seasons = SEASONS,
	Rarities = Rarities,
	List = List,
	Mutations = Mutations,
	ById = byId,
	ByCity = byCity,
	MutationById = mutationById,
}

-- Can this item drop in `month` (1-12)? Items without a season always can.
function Items.inSeason(item: Item, month: number): boolean
	local season = item.season
	if not season then
		return true
	end
	return table.find(SEASONS[season] or {}, month) ~= nil
end

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
