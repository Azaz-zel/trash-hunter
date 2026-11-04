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
		TIME = 1.2, -- seconds of rummaging before the bags show up
		DEEPER_TIME = 1,
		BAGS = 3,
		MAX_DEEPER = 2,
		COOLDOWN = 90, -- per player, per dumpster
		RANGE = 10, -- studs from dumpster to start
		KEEP_RANGE = 14, -- studs allowed while rummaging
		CHOICE_TIMEOUT = 20, -- auto-resolve an ignored choice
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

	-- Index 1 is the free starter car. Trunk items are safe from guards.
	Cars = table.freeze({
		table.freeze({
			id = "sedan",
			name = "Old Sedan",
			price = 0,
			trunk = 8,
			color = Color3.fromRGB(122, 116, 104),
		}),
		table.freeze({
			id = "wagon",
			name = "Station Wagon",
			price = 1200,
			trunk = 16,
			color = Color3.fromRGB(40, 66, 98),
		}),
		table.freeze({
			id = "pickup",
			name = "Work Truck",
			price = 4000,
			trunk = 30,
			color = Color3.fromRGB(150, 28, 30),
		}),
		-- Port Haven cars, sold at Bayside Autos.
		table.freeze({
			id = "van",
			name = "Harbor Van",
			price = 2600,
			trunk = 22,
			color = Color3.fromRGB(32, 120, 128),
			city = "port",
		}),
		table.freeze({
			id = "hauler",
			name = "Dock Hauler",
			price = 9000,
			trunk = 44,
			color = Color3.fromRGB(214, 120, 30),
			city = "port",
		}),
	}),
	CAR = table.freeze({
		SPAWN_COOLDOWN = 12,
		TRUNK_RANGE = 16, -- studs from the car to use the trunk
		SELL_RANGE = 90, -- the car must be this close to the Hideout to sell the trunk
	}),

	-- Robux: convenience only, never random items or odds. Set real ids from the
	-- Creator Dashboard; an id of 0 shows the item as "Coming soon".
	Robux = table.freeze({
		POCKETS_BONUS = 6,
		Passes = table.freeze({
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
			range = 14,
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
			range = 14,
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
	Houses = table.freeze({
		table.freeze({ name = "Starter Home", price = 6000, slots = 4 }),
		table.freeze({ name = "Family Home", price = 25000, slots = 8 }),
		table.freeze({ name = "Collector's Villa", price = 90000, slots = 12 }),
	}),
	-- Lot fronts on Sunset Ln (z = -640). yaw 0 = house north of the road.
	-- Lot frames on Sunset Ln (Eastgate): origin at the front, +Z away from the street.
	Lots = table.freeze(table.clone(CityPlan.LOTS)),

	-- Higher-tier districts need a permit: their dumpsters stay locked until the
	-- stat reaches the target. Stats only grow, so a permit is never lost. The
	-- Meridian yard has guards instead of a permit.
	Gates = table.freeze({
		midtown = table.freeze({ stat = "searches", need = 12, text = "Search 12 dumpsters" }),
		hills = table.freeze({ stat = "rares", need = 4, text = "Find 4 Rare-or-better items" }),
		downtown = table.freeze({ stat = "earned", need = 5000, text = "Earn $5,000 from sales" }),
		docks = table.freeze({ stat = "rares", need = 12, text = "Find 12 Rare-or-better items" }),
	}),

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
				yaw = CityPlan.GIVERS.earl.yaw,
				line = "Back in my day we found treasure in every can.",
			}),
			table.freeze({
				id = "rosa",
				name = "Rosa",
				pos = CityPlan.GIVERS.rosa.pos,
				yaw = CityPlan.GIVERS.rosa.yaw,
				line = "I pay well for help. Interested?",
			}),
			table.freeze({
				id = "mae",
				name = "Captain Mae",
				pos = CityPlan.GIVERS.mae.pos,
				yaw = CityPlan.GIVERS.mae.yaw,
				line = "The tide brings in strange things. Want work?",
			}),
			table.freeze({
				id = "vic",
				name = "Vic",
				pos = CityPlan.GIVERS.vic.pos,
				yaw = CityPlan.GIVERS.vic.yaw,
				line = "That yard's full of goodies. Got the nerve?",
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

	-- One district a day gets extra loot ("Hot District"), the same for every server.
	HOT_DISTRICT_BOOST = 0.5,

	-- Rarity weight for tier i is base * (1 + BIAS_STEP * boost) ^ i.
	Boost = table.freeze({
		BIAS_STEP = 0.5,
		RED_ZONE = 1,
		PER_DEEPER = 1,
		FRIEND = 0.25,
		HEAVY = 1, -- heavy dumpsters need two players to open
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
