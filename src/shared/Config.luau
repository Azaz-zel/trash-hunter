--!strict
-- Tunable gameplay values. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a client-reported value from this file.
-- Every number is a starting point for playtest tuning (GDD section 7).

local v3 = Vector3.new

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

	-- One district a day gets extra loot ("Hot District"), the same for every server.
	HOT_DISTRICT_BOOST = 0.5,

	-- Rarity weight for tier i is base * (1 + BIAS_STEP * boost) ^ i.
	Boost = table.freeze({
		BIAS_STEP = 0.55,
		RED_ZONE = 1,
		PER_DEEPER = 1,
		FRIEND = 0.25,
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
	Districts = table.freeze({
		table.freeze({
			id = "town",
			name = "Town Center",
			tier = 1,
			boost = 0,
			x0 = -640,
			x1 = 640,
			z0 = -200,
			z1 = 300,
		}),
		table.freeze({
			id = "eastside",
			name = "Eastside",
			tier = 1,
			boost = 0.2,
			x0 = -1300,
			x1 = -640,
			z0 = -500,
			z1 = 300,
		}),
		table.freeze({
			id = "maple",
			name = "Maple Grove",
			tier = 2,
			boost = 0.45,
			x0 = -640,
			x1 = 640,
			z0 = -495,
			z1 = -200,
		}),
		table.freeze({
			id = "hillcrest",
			name = "Hillcrest Estates",
			tier = 3,
			boost = 0.8,
			x0 = -640,
			x1 = 640,
			z0 = -1080,
			z1 = -495,
		}),
		table.freeze({
			id = "business",
			name = "Business District",
			tier = 4,
			boost = 1.2,
			x0 = 640,
			x1 = 1300,
			z0 = -500,
			z1 = 300,
		}),
		table.freeze({
			id = "industrial",
			name = "Industrial Park",
			tier = 5,
			boost = 1.6,
			x0 = -1300,
			x1 = 1300,
			z0 = 300,
			z1 = 900,
		}),
	}),

	Guard = table.freeze({
		MAX_SPEED = 48, -- studs/s horizontal; anything faster counts as a teleport
		MAX_VEHICLE_SPEED = 170, -- while sitting in a car
		FLAG_SECONDS = 2,
	}),

	-- Gameplay anchors of the town. World.luau builds the city around these.
	World = table.freeze({
		HIDEOUT_CENTER = v3(10, 0, 90),
		HIDEOUT_RADIUS = 30, -- "inside the Hideout" for selling and ending chases
		SPAWN = v3(10, 0, 104),
		SELL_POINT = v3(-8, 0, 108),
		SHOP_POINT = v3(28, 0, 108),
		-- Meridian Logistics yard: the fenced private property.
		RED_CENTER = v3(0, 0, 465),
		RED_SIZE = Vector2.new(460, 270),
		Dumpsters = table.freeze({
			table.freeze({ pos = v3(-34, 0, 72), zone = "Green", tutorial = true, yaw = 90 }),
			-- Downtown service alley
			table.freeze({ pos = v3(-370, 0, 112), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(-280, 0, 112), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(-190, 0, 112), zone = "Green", yaw = 0 }),
			-- Strip mall loading lane
			table.freeze({ pos = v3(205, 0, 232), zone = "Green", yaw = 180 }),
			table.freeze({ pos = v3(290, 0, 232), zone = "Green", yaw = 180 }),
			table.freeze({ pos = v3(375, 0, 232), zone = "Green", yaw = 180 }),
			-- Motel, gas station, apartments
			table.freeze({ pos = v3(-520, 0, 160), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(578, 0, 120), zone = "Green", yaw = 90 }),
			table.freeze({ pos = v3(-170, 0, -118), zone = "Green", yaw = 0 }),
			-- Eastside
			table.freeze({ pos = v3(-860, 0, 104), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(-1080, 0, 150), zone = "Green", yaw = 90 }),
			table.freeze({ pos = v3(-745, 0, 175), zone = "Green", yaw = 90 }),
			-- Maple Grove back alley
			table.freeze({ pos = v3(-330, 0, -356), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(110, 0, -356), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(470, 0, -356), zone = "Green", yaw = 0 }),
			-- Hillcrest Estates service lane and country club
			table.freeze({ pos = v3(-300, 0, -760), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(300, 0, -760), zone = "Green", yaw = 0 }),
			table.freeze({ pos = v3(70, 0, -968), zone = "Green", yaw = 90 }),
			-- Business District loading areas
			table.freeze({ pos = v3(880, 0, 254), zone = "Green", yaw = 180 }),
			table.freeze({ pos = v3(1150, 0, 254), zone = "Green", yaw = 180 }),
			table.freeze({ pos = v3(1000, 0, -196), zone = "Green", yaw = 90 }),
			-- Industrial Park (outside the Meridian fence)
			table.freeze({ pos = v3(-760, 0, 592), zone = "Green", yaw = 180 }),
			table.freeze({ pos = v3(-990, 0, 600), zone = "Green", yaw = 90 }),
			table.freeze({ pos = v3(880, 0, 592), zone = "Green", yaw = 180 }),
			-- Meridian yard, by the loading docks
			table.freeze({ pos = v3(-150, 0, 496), zone = "Red", yaw = 180 }),
			table.freeze({ pos = v3(-80, 0, 496), zone = "Red", yaw = 180 }),
			table.freeze({ pos = v3(80, 0, 496), zone = "Red", yaw = 180 }),
			table.freeze({ pos = v3(150, 0, 496), zone = "Red", yaw = 180 }),
			table.freeze({ pos = v3(-60, 0, 372), zone = "Red", yaw = 0 }),
			table.freeze({ pos = v3(-214, 0, 590), zone = "Red", yaw = 90 }),
		}),
		-- Open ground inside the yard the guards walk between (warehouses excluded).
		GUARD_POINTS = table.freeze({
			v3(0, 0, 358),
			v3(-120, 0, 364),
			v3(120, 0, 364),
			v3(-212, 0, 384),
			v3(212, 0, 384),
			v3(0, 0, 440),
			v3(-214, 0, 446),
			v3(214, 0, 446),
			v3(-160, 0, 512),
			v3(-60, 0, 516),
			v3(60, 0, 516),
			v3(160, 0, 512),
			v3(0, 0, 562),
			v3(-200, 0, 576),
			v3(200, 0, 576),
		}),
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
		DAY_LENGTH = 480,
		NIGHT_SPEED = 1.8,
		START = 15,
		LIGHTS_ON = 17.6,
		LIGHTS_OFF = 6.4,
	}),
})
