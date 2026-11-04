--!strict
-- Tunable gameplay values. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a client-reported value from this file.
-- Every number is a starting point for playtest tuning (GDD section 7).

local CityPlan = require(script.Parent.CityPlan)

local v3 = Vector3.new

-- Frozen copies of the city's dumpster spots.
local dumpsters = {}
for _, d in CityPlan.DUMPSTERS do
	table.insert(dumpsters, table.freeze(table.clone(d)))
end
local districts = {}
for _, d in CityPlan.DISTRICTS do
	table.insert(districts, table.freeze(table.clone(d)))
end

return table.freeze({
	AUTOSAVE_INTERVAL = 60,
	DATASTORE_NAME = "TrashHunter_v1",

	-- Rummage: dig for a moment, then pick one of several trash bags. Each bag
	-- shows how heavy it is (a noisy hint of what is inside); tools add bags,
	-- speed up the dig, or reveal one bag's rarity.
	Search = table.freeze({
		DEEPER_TIME = 1, -- seconds per dig deeper (x1.4 to leave time to aim)
		BAGS = 3,
		MAX_DEEPER = 2,
		COOLDOWN = 90, -- per player, per dumpster
		RANGE = 10, -- studs from dumpster to start
		KEEP_RANGE = 14, -- studs allowed while rummaging
		CHOICE_TIMEOUT = 20, -- auto-resolve an ignored choice
		-- Perfect Dig: tap (F / DIG) while the marker crosses the gold zone.
		DIG_TIME = 1.8, -- the first dig is longer so there is time to aim
		PERFECT_WIDTH = 0.14, -- share of the bar
		GOOD_WIDTH = 0.34,
		PERFECT_BOOST = 0.5, -- plus one extra bag
		GOOD_BOOST = 0.25,
		TAP_SLACK = 0.15, -- reported vs server-measured timing (after ping), for jitter
		-- Combo: searches close together raise the odds.
		COMBO_WINDOW = 75, -- seconds to reach the next dumpster
		COMBO_STEP = 0.12, -- boost per combo step
		COMBO_MAX = 5,
		-- Fresh drops: a few dumpsters were just filled. Gold on the map.
		FRESH_COUNT = 6,
		FRESH_EVERY = 240,
		FRESH_BOOST = 0.8,
	}),

	-- Cash tools bought at the Hideout gear bench. Cash sinks with a clear effect.
	Tools = table.freeze({
		gloves = table.freeze({
			name = "Work Gloves",
			price = 80,
			order = 1,
			desc = "Rummage 40% faster.",
		}),
		shoes = table.freeze({
			name = "Running Shoes",
			price = 250,
			order = 2,
			desc = "+3 walk speed.",
		}),
		flashlight = table.freeze({
			name = "Flashlight",
			price = 450,
			order = 3,
			desc = "Shows what one bag is hiding.",
		}),
		crowbar = table.freeze({
			name = "Crowbar",
			price = 900,
			order = 4,
			desc = "Pry open a 4th bag every search.",
		}),
		detector = table.freeze({
			name = "Metal Detector",
			price = 2500,
			order = 5,
			desc = "Better odds in every dumpster.",
		}),
		-- Port Haven only: sold at Harbor Supply.
		magnet = table.freeze({
			name = "Magnet Kit",
			price = 3000,
			order = 6,
			desc = "+1 bag in every Port Haven dumpster.",
			city = "port",
		}),
	}),
	TOOL_EFFECT = table.freeze({
		GLOVES_SPEED = 0.6, -- rummage time multiplier
		SHOES_SPEED = 3,
		DETECTOR_BOOST = 0.3,
	}),

	-- Bought at the car dealers (Maple Motors, Bayside Autos). New players own
	-- none. Trunk items are safe from guards. `pass` cars come with a game pass.
	Cars = table.freeze({
		table.freeze({
			id = "sedan",
			top = 64, -- top speed, studs/s
			accel = 6, -- extra pull, studs/s²
			nitro = 2.5, -- seconds of nitro per charge
			name = "Old Sedan",
			price = 450, -- nobody starts with a car: this is the first goal
			trunk = 8,
			color = Color3.fromRGB(122, 116, 104),
		}),
		table.freeze({
			id = "wagon",
			top = 70, -- top speed, studs/s
			accel = 8, -- extra pull, studs/s²
			nitro = 3, -- seconds of nitro per charge
			name = "Station Wagon",
			price = 1200,
			trunk = 16,
			color = Color3.fromRGB(40, 66, 98),
		}),
		table.freeze({
			id = "pickup",
			top = 78, -- top speed, studs/s
			accel = 11, -- extra pull, studs/s²
			nitro = 3.5, -- seconds of nitro per charge
			name = "Work Truck",
			price = 4000,
			trunk = 30,
			color = Color3.fromRGB(150, 28, 30),
		}),
		-- Port Haven cars, sold at Bayside Autos.
		table.freeze({
			id = "van",
			top = 72, -- top speed, studs/s
			accel = 8, -- extra pull, studs/s²
			nitro = 3, -- seconds of nitro per charge
			name = "Harbor Van",
			price = 2600,
			trunk = 22,
			color = Color3.fromRGB(32, 120, 128),
			city = "port",
		}),
		table.freeze({
			id = "hauler",
			top = 84, -- top speed, studs/s
			accel = 13, -- extra pull, studs/s²
			nitro = 4, -- seconds of nitro per charge
			name = "Dock Hauler",
			price = 9000,
			trunk = 44,
			color = Color3.fromRGB(214, 120, 30),
			city = "port",
		}),
		-- Game pass car (Config.Robux.Passes.neon), shown at Maple Motors.
		table.freeze({
			id = "neon",
			top = 92,
			accel = 15,
			nitro = 4,
			name = "Neon Runner",
			price = 0,
			trunk = 20,
			color = Color3.fromRGB(70, 20, 110),
			pass = "neon",
		}),
	}),
	CAR = table.freeze({
		NITRO_PUSH = 34, -- studs/s² while nitro burns
		NITRO_OVER = 1.3, -- nitro may push past top speed by this factor
		NITRO_RECHARGE = 9, -- seconds from empty to full
		HONK_RANGE = 40, -- people this far ahead jump out of the way
		SPAWN_COOLDOWN = 12,
		TRUNK_RANGE = 16, -- studs from the car to use the trunk
		SELL_RANGE = 90, -- the car must be this close to the Hideout to sell the trunk
	}),

	-- Robux: convenience only, never random items or odds. Set real ids from the
	-- Creator Dashboard; an id of 0 shows the item as "Coming soon".
	Robux = table.freeze({
		POCKETS_BONUS = 6,
		-- Luck you can buy (Lucky Charm pass, Lucky Hour, Bag Reroll).
		LUCK = table.freeze({
			CHARM_BOOST = 0.25, -- forever, with the pass
			HOUR_BOOST = 0.6, -- while a Lucky Hour runs
			HOUR_SECONDS = 1800,
			REROLLS = 3, -- per Bag Reroll purchase
		}),
		Passes = table.freeze({
			lucky = table.freeze({
				id = 0,
				name = "Lucky Charm",
				price = 249,
				desc = "Better odds in every dumpster, forever.",
			}),
			vip = table.freeze({
				id = 0,
				name = "Scrapper VIP",
				price = 299,
				desc = "+20% sell price, gold VIP tag over your head.",
			}),
			neon = table.freeze({
				id = 0,
				name = "Neon Runner",
				price = 399,
				desc = "Exclusive car: fastest in town, neon underglow, trunk 20.",
			}),
			turbo = table.freeze({
				id = 0,
				name = "Turbo Kit",
				price = 149,
				desc = "Double nitro tank in every car, blue flame.",
			}),
			paint = table.freeze({
				id = 0,
				name = "Custom Paint",
				price = 99,
				desc = "Paint any car any colour and add underglow (Garage).",
			}),
			season = table.freeze({
				id = 0,
				name = "Season Pass",
				price = 349,
				desc = "Double cash from every level-up reward.",
			}),
			pockets = table.freeze({
				id = 0,
				name = "Bigger Pockets",
				price = 149,
				desc = "+6 backpack slots, forever.",
			}),
			homerun = table.freeze({
				id = 0,
				name = "Home Run",
				price = 199,
				desc = "Teleport to the Hideout (not during a chase).",
			}),
			shopanywhere = table.freeze({
				id = 0,
				name = "Shop Anywhere",
				price = 249,
				desc = "Buy gear and cars from any spot on the map.",
			}),
		}),
		Products = table.freeze({
			cash_small = table.freeze({ id = 0, name = "Cash Stack", price = 49, cash = 600 }),
			cash_large = table.freeze({ id = 0, name = "Cash Briefcase", price = 199, cash = 3000 }),
			luckyhour = table.freeze({
				id = 0,
				name = "Lucky Hour",
				price = 49,
				desc = "Much better odds for 30 minutes (stacks).",
			}),
			reroll = table.freeze({
				id = 0,
				name = "Bag Reroll x3",
				price = 35,
				desc = "Swap the bags in front of you for new ones, 3 times.",
			}),
			lawyer = table.freeze({
				id = 0,
				name = "Call a Lawyer",
				price = 29,
				desc = "Clears your wanted stars right now.",
			}),
			refill = table.freeze({
				id = 0,
				name = "Instant Refill",
				price = 25,
				desc = "Every dumpster you emptied is ready again.",
			}),
			truckday = table.freeze({
				id = 0,
				name = "Garbage Truck Day",
				price = 99,
				desc = "Fresh drops for the whole server, with your name on it.",
			}),
		}),
	}),

	-- Collection book rewards, paid once when the number of different items found is reached.
	Milestones = table.freeze({
		table.freeze({ found = 5, cash = 100 }),
		table.freeze({ found = 10, cash = 400 }),
		table.freeze({ found = 15, cash = 1200 }),
		table.freeze({ found = 20, cash = 4000 }),
	}),

	-- Guaranteed drops after a dry streak (searches without that rarity or better).
	PITY = table.freeze({ EPIC = 30, LEGENDARY = 120 }),

	-- Physical stores. Buying needs standing at the counter (or the Shop Anywhere pass).
	Stores = table.freeze({
		hardware = table.freeze({
			name = "Hank's Hardware",
			counter = CityPlan.storeCounter("hardware"),
			sells = "gear",
			range = 14,
		}),
		motors = table.freeze({
			name = "Maple Motors",
			counter = CityPlan.storeCounter("motors"),
			sells = "cars",
			range = 30, -- the whole showroom counts
		}),
		harbor = table.freeze({
			name = "Harbor Supply",
			counter = CityPlan.storeCounter("harbor"),
			sells = "gear",
			range = 14,
			city = "port",
		}),
		bayside = table.freeze({
			name = "Bayside Autos",
			counter = CityPlan.storeCounter("bayside"),
			sells = "cars",
			range = 30, -- the whole showroom counts
			city = "port",
		}),
		realty = table.freeze({
			name = "Maple Realty",
			counter = CityPlan.storeCounter("realty"),
			sells = "house",
			range = 14,
		}),
	}),

	-- Cities on the one connected map. Items, cars and tools without a city
	-- belong to Maple (the mainland). The Harbor Fwy bridge leads to Port Haven.
	Cities = table.freeze({
		maple = table.freeze({ name = "Maple", order = 1 }),
		port = table.freeze({ name = "Port Haven", order = 2 }),
	}),

	-- Houses on Sunset Ln: a trophy room other players can visit and like.
	-- Each level rebuilds the house bigger with more pedestals.
	-- House types (Maple Realty). Everyone owns the Trailer. You may own
	-- several and live in one; storage holds your things, pedestals show the
	-- most valuable of them. Lots are handed out per server (see Housing).
	Houses = table.freeze({
		table.freeze({ id = "trailer", name = "Trailer", price = 0, storage = 8, pedestals = 2 }),
		table.freeze({
			id = "starter",
			name = "Starter Home",
			price = 6000,
			storage = 14,
			pedestals = 4,
		}),
		table.freeze({
			id = "bungalow",
			name = "Beach Bungalow",
			price = 15000,
			storage = 18,
			pedestals = 4,
		}),
		table.freeze({
			id = "family",
			name = "Family Home",
			price = 25000,
			storage = 22,
			pedestals = 8,
		}),
		table.freeze({
			id = "loft",
			name = "Neon Loft",
			price = 50000,
			storage = 28,
			pedestals = 8,
		}),
		table.freeze({
			id = "villa",
			name = "Collector's Villa",
			price = 90000,
			storage = 36,
			pedestals = 12,
		}),
	}),
	-- Lot fronts on Sunset Ln (z = -640). yaw 0 = house north of the road.
	-- Lot frames on Sunset Ln (Eastgate): origin at the front, +Z away from the street.
	Lots = table.freeze(table.clone(CityPlan.LOTS)),

	-- District permits come from missions. Each district's dumpsters stay
	-- locked until you find its contact, take their mission, finish it and
	-- report back. Missions unlock in this order; Southside is open from the
	-- start. kind: "search" (n searches, optionally in `in`), "find" (n items of
	-- `rarity`+), "earn" (sell $n), "bring" (hand over an item of `rarity`+).
	Missions = table.freeze({
		table.freeze({
			id = "eastgate",
			district = "eastgate",
			contact = "marcus",
			kind = "search",
			n = 5,
			inDistrict = "southside",
			reward = 200,
			text = "Search 5 dumpsters in Southside",
			intro = "New in town? Prove you can dig. Then I'll get you into Eastgate.",
		}),
		table.freeze({
			id = "beach",
			district = "beach",
			contact = "kai",
			kind = "find",
			rarity = 2,
			n = 3,
			reward = 300,
			text = "Find 3 Uncommon-or-better items",
			intro = "The beach crowd only trades with people who know junk.",
		}),
		table.freeze({
			id = "midtown",
			district = "midtown",
			contact = "nova",
			kind = "earn",
			n = 1500,
			reward = 400,
			text = "Sell $1,500 worth of stuff",
			intro = "Midtown runs on money. Show me you can make some.",
		}),
		table.freeze({
			id = "downtown",
			district = "downtown",
			contact = "tony",
			kind = "bring",
			rarity = 3,
			n = 1,
			reward = 800,
			text = "Bring Tony a Rare-or-better item",
			intro = "Downtown bins are full of tech. Bring me something good first.",
		}),
		table.freeze({
			id = "hills",
			district = "hills",
			contact = "victoria",
			kind = "search",
			n = 6,
			inDistrict = "downtown",
			reward = 1200,
			text = "Search 6 dumpsters in Downtown",
			intro = "The Hills don't let just anyone in. Make a name downtown.",
		}),
		table.freeze({
			id = "industrial",
			district = "industrial",
			contact = "joe",
			kind = "find",
			rarity = 4,
			n = 1,
			reward = 1500,
			text = "Find an Epic-or-better item",
			intro = "The yard pays well, if you've got the eye for it.",
		}),
		table.freeze({
			id = "oldport",
			district = "oldport",
			contact = "mae",
			kind = "earn",
			n = 6000,
			reward = 1500,
			text = "Sell $6,000 worth of stuff",
			intro = "Port Haven is a different world. Come back when you're rich.",
		}),
		table.freeze({
			id = "docks",
			district = "docks",
			contact = "mae",
			kind = "search",
			n = 8,
			inDistrict = "oldport",
			reward = 2500,
			text = "Search 8 dumpsters in Old Port",
			intro = "The Docks are mine. Work Old Port first.",
		}),
	}),
	-- Mission contacts: where they stand and how they look on the map.
	Contacts = table.freeze({
		marcus = table.freeze({ name = "Marcus", pos = CityPlan.CONTACTS.marcus }),
		kai = table.freeze({ name = "Kai", pos = CityPlan.CONTACTS.kai }),
		nova = table.freeze({ name = "Nova", pos = CityPlan.CONTACTS.nova }),
		tony = table.freeze({ name = "Tony", pos = CityPlan.CONTACTS.tony }),
		victoria = table.freeze({ name = "Victoria", pos = CityPlan.CONTACTS.victoria }),
		joe = table.freeze({ name = "Joe", pos = CityPlan.CONTACTS.joe }),
		mae = table.freeze({ name = "Captain Mae", pos = CityPlan.CONTACTS.mae }),
	}),
	CONTACT_RANGE = 14,

	-- Daily login streak reward by streak day (repeats after day 7).
	STREAK = table.freeze({ 100, 150, 200, 300, 400, 500, 1000 }),

	-- Quest givers hand out one quest each per day (same for everyone).
	Quests = table.freeze({
		RANGE = 14,
		givers = table.freeze({
			table.freeze({
				id = "earl",
				name = "Old Earl",
				pos = CityPlan.GIVERS.earl.pos,
				yaw = 0,
				line = "Back in my day we found treasure in every can.",
			}),
			table.freeze({
				id = "rosa",
				name = "Rosa",
				pos = CityPlan.GIVERS.rosa.pos,
				yaw = 0,
				line = "I pay well for help. Interested?",
			}),
			table.freeze({
				id = "zed",
				name = "Zed",
				pos = CityPlan.GIVERS.zed.pos,
				yaw = 0,
				line = "Downtown never sleeps. Neither do I. Want a job?",
			}),
			table.freeze({
				id = "lola",
				name = "Lola",
				pos = CityPlan.GIVERS.lola.pos,
				yaw = 0,
				line = "Beach crowd throws out the best stuff.",
			}),
			table.freeze({
				id = "vic",
				name = "Vic",
				pos = CityPlan.GIVERS.vic.pos,
				yaw = 0,
				line = "That yard's full of goodies. Got the nerve?",
			}),
			table.freeze({
				id = "pete",
				name = "Pete",
				pos = CityPlan.GIVERS.pete.pos,
				yaw = 0,
				line = "Tide's out. Plenty washed up today.",
			}),
		}),
		pool = table.freeze({
			table.freeze({ kind = "search", n = 5, reward = 250, text = "Search 5 dumpsters" }),
			table.freeze({ kind = "search", n = 12, reward = 600, text = "Search 12 dumpsters" }),
			table.freeze({
				kind = "find",
				rarity = 3,
				n = 2,
				reward = 600,
				text = "Find 2 Rare-or-better items",
			}),
			table.freeze({
				kind = "find",
				rarity = 4,
				n = 1,
				reward = 1200,
				text = "Find an Epic-or-better item",
			}),
			table.freeze({
				kind = "earn",
				n = 1500,
				reward = 400,
				text = "Sell $1,500 worth of stuff",
			}),
			table.freeze({
				kind = "earn",
				n = 5000,
				reward = 1000,
				text = "Sell $5,000 worth of stuff",
			}),
			table.freeze({
				kind = "city",
				city = "port",
				n = 4,
				reward = 600,
				text = "Search 4 dumpsters in Port Haven",
			}),
			table.freeze({
				kind = "district",
				district = "beach",
				n = 4,
				reward = 500,
				text = "Search 4 dumpsters in Westshore",
			}),
			table.freeze({
				kind = "district",
				district = "southside",
				n = 3,
				reward = 700,
				text = "Search 3 dumpsters in Southside",
			}),
			table.freeze({
				kind = "yard",
				n = 2,
				reward = 900,
				text = "Search 2 dumpsters inside the Meridian yard",
			}),
			table.freeze({
				kind = "find",
				rarity = 2,
				n = 4,
				reward = 300,
				text = "Find 4 Uncommon-or-better items",
			}),
		}),
	}),

	-- Levels: XP from searching (by rarity), selling and missions. Every level
	-- pays cash (doubled with the Season Pass); titles every few levels.
	Levels = table.freeze({
		MAX = 60,
		BASE_XP = 120, -- XP from level 1 to 2
		STEP_XP = 45, -- each next level needs this much more
		SEARCH_XP = table.freeze({ 6, 9, 16, 30, 60, 120, 240, 400 }), -- by rarity
		SELL_PER_XP = 25, -- $ sold per XP point
		PERFECT_XP = 4,
		QUEST_XP = 60,
		MISSION_XP = 150,
		REWARD_PER_LEVEL = 60, -- cash at level-up = level * this
		TITLES = table.freeze({
			{ level = 1, name = "Rookie Scavenger" },
			{ level = 5, name = "Alley Rat" },
			{ level = 10, name = "Bin Diver" },
			{ level = 15, name = "Curb Collector" },
			{ level = 20, name = "Scrap Hustler" },
			{ level = 30, name = "Junk Baron" },
			{ level = 40, name = "Treasure Hound" },
			{ level = 50, name = "Trash Legend" },
		}),
	}),

	-- Live events (UTC). Weekend: twice the fresh drops. Happy hour: better sell prices.
	Events = table.freeze({
		WEEKEND_FRESH_MULT = 2,
		HAPPY_HOUR_UTC = table.freeze({ 18, 20, 2 }), -- hours that start one, each lasts 1 h
		HAPPY_HOUR_SELL = 1.25,
		VIP_SELL = 1.2,
	}),

	-- Story: a chain of chapters, each from a district "boss". Big Sal
	-- outside the Hideout hands them out; finish the goal, come back.
	-- goal kinds: search (any dumpster), district (search there), rare (find
	-- rarity >= n), perfect (Perfect Digs), earn ($ sold), combo (reach xN),
	-- yard (search inside the Meridian yard).
	Story = table.freeze({
		GIVER = table.freeze({ name = "Big Sal", pos = CityPlan.HIDEOUT + v3(-22, 0, -40) }),
		CHAPTERS = table.freeze({
			table.freeze({
				title = "Welcome to the Dump",
				boss = "Big Sal",
				intro = {
					"So you're the new kid. Everybody starts somewhere.",
					"Hit five dumpsters. Any five. Show me you're hungry.",
				},
				outro = {
					"Not bad. You've got the nose for it.",
					"Go see Lucky Lou in Eastgate. Tell him Sal sent you.",
				},
				goal = table.freeze({ kind = "search", n = 5, text = "Search 5 dumpsters" }),
				cash = 300,
				xp = 120,
			}),
			table.freeze({
				title = "Eastgate Hustle",
				boss = "Lucky Lou",
				intro = {
					"Sal's kid, huh? Lou don't do charity.",
					"Bring me proof: find three Uncommon-or-better pieces.",
				},
				outro = {
					"Alright, alright. You got luck AND legs.",
					"Coach Kim teaches the real technique. Go.",
				},
				goal = table.freeze({
					kind = "rare",
					rarity = 2,
					n = 3,
					text = "Find 3 Uncommon-or-better items",
				}),
				cash = 500,
				xp = 180,
			}),
			table.freeze({
				title = "Perfect Form",
				boss = "Coach Kim",
				intro = {
					"Digging is a sport. Timing is everything.",
					"Land three Perfect Digs. Gold zone, every time.",
				},
				outro = {
					"Beautiful form! The bins fear you now.",
					"Madame Vega in Midtown deals in serious money.",
				},
				goal = table.freeze({ kind = "perfect", n = 3, text = "Land 3 Perfect Digs" }),
				cash = 800,
				xp = 240,
			}),
			table.freeze({
				title = "Midtown Money",
				boss = "Madame Vega",
				intro = {
					"Darling, finding is nothing. SELLING is everything.",
					"Move three thousand dollars of goods. Then we talk.",
				},
				outro = {
					"Delicious. You understand value.",
					"DJ Static runs the night. Keep up with his tempo.",
				},
				goal = table.freeze({
					kind = "earn",
					n = 3000,
					text = "Sell $3,000 worth of stuff",
				}),
				cash = 1200,
				xp = 320,
			}),
			table.freeze({
				title = "Combo King",
				boss = "DJ Static",
				intro = {
					"Yo! The city's got a rhythm. Bin, bin, bin, BIN.",
					"Hit a x4 search combo. Don't drop the beat.",
				},
				outro = {
					"THAT'S what I'm talking about!",
					"The Fixer has a job. Behind the red fence. Careful.",
				},
				goal = table.freeze({ kind = "combo", n = 4, text = "Reach a x4 search combo" }),
				cash = 1600,
				xp = 400,
			}),
			table.freeze({
				title = "The Yard Job",
				boss = "The Fixer",
				intro = {
					"Meridian Logistics throws out more than boxes.",
					"Search three dumpsters inside their yard. Don't get caught.",
				},
				outro = {
					"Clean work. Nobody saw a thing.",
					"One last thing. The legend everyone talks about. Find it.",
				},
				goal = table.freeze({
					kind = "yard",
					n = 3,
					text = "Search 3 dumpsters in the Meridian yard",
				}),
				cash = 2500,
				xp = 600,
			}),
			table.freeze({
				title = "Trash Legend",
				boss = "Big Sal",
				intro = {
					"Kid... everyone's talking about you.",
					"Find a Legendary. Then you're not my kid anymore. You're the King.",
				},
				outro = {
					"Look at that. A real legend.",
					"This city's dumpsters are yours now. Long live the Trash King.",
				},
				goal = table.freeze({
					kind = "rare",
					rarity = 5,
					n = 1,
					text = "Find a Legendary-or-better item",
				}),
				cash = 6000,
				xp = 1200,
			}),
		}),
	}),

	-- Crews: search together. Each crewmate within RANGE adds BOOST to the odds.
	Crew = table.freeze({
		MAX = 4,
		RANGE = 80,
		BOOST = 0.15,
	}),

	-- Player-to-player trading.
	Trade = table.freeze({
		RANGE = 30, -- studs between the two players
		MAX_ITEMS = 6, -- per side
		REQUEST_SECONDS = 20,
	}),

	-- Hideout furniture for your house (bought at Maple Realty). One per slot.
	Decor = table.freeze({
		table.freeze({ id = "rug", name = "Shag Rug", price = 400 }),
		table.freeze({ id = "plant", name = "Big Fern", price = 300 }),
		table.freeze({ id = "sofa", name = "Leather Sofa", price = 1500 }),
		table.freeze({ id = "fridge", name = "Retro Fridge", price = 1800 }),
		table.freeze({ id = "arcade", name = "Arcade Cabinet", price = 4500 }),
		table.freeze({ id = "neon", name = "Neon Sign", price = 3000 }),
		table.freeze({ id = "trophy", name = "Trophy Case", price = 9000 }),
	}),

	-- One district a day gets extra loot ("Hot District"), the same for every server.
	HOT_DISTRICT_BOOST = 0.5,

	-- Rarity weight for tier i is base * (1 + BIAS_STEP * boost) ^ i.
	Boost = table.freeze({
		BIAS_STEP = 0.5,
		RED_ZONE = 1,
		PER_DEEPER = 1,
		FRIEND = 0.25,
		HEAVY = 1, -- heavy dumpsters need two players to open
		-- Cap on the summed boost. Every bonus stacked (yard, deeper, heavy,
		-- fresh, combo, Perfect, crew, luck) would reach ~9.9 and make Secrets
		-- 15000x likelier (6% per bag); 4.0 keeps the top end rare.
		MAX = 4.0,
	}),

	-- Pedestrians offer trades for one item in your backpack.
	Barter = table.freeze({
		RANGE = 14,
		OFFER_SECONDS = 25, -- an offer expires if left open
		NPC_COOLDOWN = 300, -- per player, per pedestrian
		SWAP_CHANCE = 0.3, -- otherwise they pay cash
		LOWBALL_CHANCE = 0.35, -- cash offers below pawn value
	}),

	Backpack = table.freeze({
		-- index = backpack level
		table.freeze({ capacity = 8, price = 0 }),
		table.freeze({ capacity = 12, price = 40 }),
		table.freeze({ capacity = 18, price = 350 }),
	}),

	SHELF_SLOTS = 3,
	MAX_LIKERS = 400, -- liker ids remembered per house (oldest drop off)

	Suspicion = table.freeze({
		SEARCH_RATE = 14, -- per second while digging in a red zone
		DEEPER_MULT = 1.5,
		SEEN_RATE = 25, -- per second while a guard sees you digging in a red zone
		SEEN_IDLE_RATE = 10, -- per second while a guard sees you just walking in a red zone
		DECAY_IN_RED = 8,
		DECAY_OUTSIDE = 20,
		WARN_LOW = 50,
		WARN_HIGH = 80,
	}),

	Police = table.freeze({
		GUARD_COUNT = 3,
		PATROL_SPEED = 8.5, -- each guard gets +-1 of this so they do not move in lockstep
		INVESTIGATE_SPEED = 11,
		CHASE_SPEED = 18.5, -- players walk at Player.WALK_SPEED (20)
		VISION_RANGE = 55,
		VISION_HALF_ANGLE = 32, -- degrees
		CATCH_RANGE = 4.5,
		CATCH_TIME = 0.5,
		LOSE_DISTANCE = 80,
		LOSE_TIME = 3,
		LEASH = 70, -- studs guards may follow a target outside the compound fence
		BACKUP_RADIUS = 140, -- other guards this close join a chase
		IMMUNITY_AFTER_CAPTURE = 5,
		KEEP_ON_CAPTURE = 1, -- most valuable items the guard lets you keep
		IMMUNITY_AFTER_DROP = 3,
		SUSPICION_AFTER_DROP = 30,
	}),

	Player = table.freeze({
		WALK_SPEED = 20, -- the town is big; default Roblox speed (16) feels slow
	}),

	-- Districts, cheapest to richest. A dumpster's loot boost = its district's
	-- boost (+ the red-zone boost inside the Meridian yard). First match wins,
	-- so the Meridian yard (inside Industrial Park) needs no entry of its own.
	Districts = table.freeze(districts),

	Guard = table.freeze({
		MAX_SPEED = 48, -- studs/s horizontal; anything faster counts as a teleport
		MAX_VEHICLE_SPEED = 170, -- while sitting in a car
		FLAG_SECONDS = 2,
	}),

	-- Gameplay anchors of the town. World.luau builds the city around these.
	-- Gameplay anchors of the city (see CityPlan). World builds around these.
	World = table.freeze({
		HIDEOUT_CENTER = CityPlan.HIDEOUT,
		HIDEOUT_RADIUS = 30, -- "inside the Hideout" for selling and ending chases
		-- Every hideout (selling, safe zone). The first is the main Hideout.
		HIDEOUTS = table.freeze({ CityPlan.HIDEOUT, CityPlan.LOCKUP }),
		SPAWN = CityPlan.HIDEOUT + v3(0, 0, 14),
		SELL_POINT = CityPlan.HIDEOUT + v3(-18, 0, 18),
		-- Meridian Logistics yard: the fenced private property.
		RED_CENTER = CityPlan.RED_CENTER,
		RED_SIZE = Vector2.new(460, 270),
		-- yaw turns the dumpster's open front (0 opens toward -Z); pad "wall"
		-- backs it against a wall, "enclosure" builds a three-sided block pen.
		Dumpsters = table.freeze(dumpsters),
		GUARD_POINTS = table.freeze(table.clone(CityPlan.GUARD_POINTS)),
	}),

	-- Licensed Roblox Creator Store audio (ProSoundEffects / APM Music).
	Sounds = table.freeze({
		RUMMAGE = "rbxassetid://9120258592",
		OPEN = "rbxassetid://9113100200",
		RARE = "rbxassetid://9116394545",
		EPIC = "rbxassetid://9116395089",
		JACKPOT = "rbxassetid://1840076509",
		WHISTLE = "rbxassetid://9125775207",
		CASH = "rbxassetid://1839881844",
		DAY_AMBIENCE = "rbxassetid://9117064941",
		NIGHT_AMBIENCE = "rbxassetid://9112764040",
		CHASE_MUSIC = "rbxassetid://1838489774",
		-- City life. Empty means silent: paste a Creator Store sound id
		-- ("rbxassetid://123") that your experience may use (check the
		-- asset's permissions). Search terms that work: "car horn",
		-- "police siren", "rain loop", "city traffic ambience", "crowd murmur".
		HORN = "",
		SIREN = "",
		RAIN = "",
		CITY_HUM = "",
		CROWD = "",
		-- Built into every Roblox client.
		CRASH = "rbxasset://sounds/collide.wav",
		GLASS = "rbxasset://sounds/glassbreak.wav",
	}),

	-- Car radio stations (R or the radio button cycles them while driving).
	-- Each needs at least one licensed track id; empty stations are skipped
	-- and the radio hides when none has tracks.
	Radio = table.freeze({
		table.freeze({ name = "NEON FM", tracks = table.freeze({}) }),
		table.freeze({ name = "Harbor Rock 98", tracks = table.freeze({}) }),
		table.freeze({ name = "Smooth Night Jazz", tracks = table.freeze({}) }),
	}),

	-- City police and wanted stars (outside the Meridian yard).
	Wanted = table.freeze({
		HEAT_PER_STAR = 100,
		RED_LIGHT = 45, -- heat for driving through a red light
		HIT_PERSON = 80, -- heat for running someone over
		HIT_SPEED = 14, -- studs/s a car needs to knock someone down
		DECAY = 6, -- heat lost per second while not wanted
		MAX_STARS = 3,
		COPS_PER_STAR = 2,
		MAX_COPS = 6, -- in the whole server
		CRUISER_FROM = 2, -- stars that bring police cars
		MAX_CRUISERS = 3, -- in the whole server
		CRUISER_SPEED = 70, -- studs/s on the road
		CRUISER_CATCH = 14, -- studs from a stopped car to arrest the driver
		COP_SPEED = 19, -- players run at 20, so a straight sprint barely escapes
		CATCH_RANGE = 4.5,
		CATCH_TIME = 0.6,
		SPAWN_MIN = 70, -- cops arrive on foot from this far
		SPAWN_MAX = 140,
		LOSE_RANGE = 110, -- out of every cop's reach ...
		LOSE_TIME = 8, -- ... for this long (+4 s per star) clears the stars
		ESCALATE_AFTER = 45, -- seconds of running before another star
	}),

	-- Weather: one clock for the server. Rain comes now and then.
	Weather = table.freeze({
		MIN_SPELL = 300, -- seconds a spell of weather lasts, at least
		MAX_SPELL = 720,
		RAIN_CHANCE = 0.35,
	}),

	-- One full day takes DAY_LENGTH seconds; night runs NIGHT_SPEED times faster.
	DayCycle = table.freeze({
		DAY_LENGTH = 1440, -- 24 minutes per in-game day
		NIGHT_SPEED = 1.8,
		START = 15,
		LIGHTS_ON = 17.6,
		LIGHTS_OFF = 6.4,
	}),
})
