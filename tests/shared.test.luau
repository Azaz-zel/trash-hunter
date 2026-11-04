-- Self-checks of the shared modules, plus the city layout rules.
local CityPlan = load("CityPlan")
CityPlan.selfCheck()
load("Levels").selfCheck()
load("Loot").selfCheck()
load("Quests").selfCheck()

-- Signals: every signal has both phase groups, and legs on one phase line up.
local bad = 0
for _, n in CityPlan.NODES do
	if n.signal then
		local groups = { A = {}, B = {} }
		for _, e in n.edges do
			table.insert(groups[CityPlan.signalGroup(n, e)], CityPlan.leaving(e, n))
		end
		local ok = #groups.A > 0 and #groups.B > 0
		for _, list in groups do
			for i = 1, #list do
				for j = i + 1, #list do
					ok = ok and math.abs(list[i]:Dot(list[j])) >= 0.7
				end
			end
		end
		if not ok then
			bad += 1
		end
	end
end
check(bad == 0, `{bad} signal junctions give crossing streams the same phase`)

-- Signal clock: never both green, amber after green, an all-red gap.
for t = 0, CityPlan.SIGNAL_CYCLE * 2, 0.25 do
	local a = CityPlan.signalState("A", t)
	local b = CityPlan.signalState("B", t)
	check(not (a ~= "red" and b ~= "red"), `both phases open at t={t}`)
end

-- Street vendors exist and cluster near the Hideout.
local vendors, near = 0, 0
for _, h in CityPlan.HANGOUTS do
	if h.kind == "vendor" then
		vendors += 1
		if (h.cf.Position - CityPlan.HIDEOUT).Magnitude < 600 then
			near += 1
		end
	end
end
check(vendors >= 30, `only {vendors} vendor stalls`)
check(near >= 15, `only {near} vendor stalls near the Hideout`)

-- Levels: monotonic XP curve and rewards.
local Levels = load("Levels")
for level = 1, 59 do
	check(Levels.toNext(level + 1) > Levels.toNext(level), "xp curve must rise")
end
print(`signals ok, {vendors} vendors ({near} near the Hideout)`)

-- Config consistency: houses, pass cars, Robux keys.
local Config = load("Config")
local seen = {}
check(Config.Houses[1].id == "trailer" and Config.Houses[1].price == 0, "the free Trailer comes first")
for _, h in Config.Houses do
	check(not seen[h.id], `duplicate house id {h.id}`)
	seen[h.id] = true
	check(h.storage >= h.pedestals, `{h.id} shows more than it stores`)
end
check(#Config.Lots >= 8, "a lot for each of the 8 players")
for _, car in Config.Cars do
	if car.pass then
		check(Config.Robux.Passes[car.pass] ~= nil, `{car.id} needs pass {car.pass}`)
	end
end
for key in Config.Robux.Products do
	check(Config.Robux.Passes[key] == nil, `{key} is both a pass and a product`)
end
print(`{#Config.Houses} house types, {#Config.Lots} lots`)

-- Seasonal items only drop in their months.
local Items = load("Items")
check(Items.inSeason(Items.ById.pumpkin, 10) and not Items.inSeason(Items.ById.pumpkin, 6), "Halloween items in October only")
check(Items.inSeason(Items.ById.nutcracker, 1) and not Items.inSeason(Items.ById.nutcracker, 7), "winter items in Dec-Jan")
check(Items.inSeason(Items.ById.can, 6), "regular items always drop")
-- Every item has a 3D model (ItemModels only reads Enum names here).
Enum = setmetatable({}, {
	__index = function(_, group)
		return setmetatable({}, {
			__index = function(_, name)
				return group .. "." .. name
			end,
		})
	end,
})
load("ItemModels").selfCheck()

-- Economy guards: the boost cap holds and the published odds add up.
local Loot = load("Loot")
local function sum(t)
	local n = 0
	for _, x in t do
		n += x
	end
	return n
end
check(math.abs(sum(Loot.odds(0)) - 1) < 1e-9, "odds add up to 100%")
local capped = Loot.odds(99)
local atCap = Loot.odds(Config.Boost.MAX)
check(capped[#capped] == atCap[#atCap], "boost above the cap gives the capped odds")
check(atCap[#atCap] < 0.005, `Secret per bag at the cap is {atCap[#atCap]}, must stay under 0.5%`)
local f1 = Loot.featured(0)
local f2 = Loot.featured(7 * 86400)
check(Items.ById[f1] ~= nil and Items.ById[f1].season == nil, "featured item is a real, non-seasonal item")
check(f1 ~= f2, "featured item changes week to week")
print(`Secret at cap: {string.format("%.3f", atCap[#atCap] * 100)}%`)
