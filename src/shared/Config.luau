--!strict
-- Tunable gameplay values. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a client-reported value from this file.
-- Every number is a starting point for playtest tuning (GDD section 7).

local v3 = Vector3.new

return table.freeze({
	AUTOSAVE_INTERVAL = 60,
	DATASTORE_NAME = "TrashHunter_v1",

	Search = table.freeze({
		TIME = 2, -- seconds for the first dig
		DEEPER_TIME = 1.5,
		MAX_DEEPER = 2,
		COOLDOWN = 90, -- per player, per dumpster
		RANGE = 10, -- studs from dumpster to start
		KEEP_RANGE = 14, -- studs allowed while digging
		SWEET_WIDTH = 0.16, -- fraction of the dig bar
		SWEET_MIN = 0.45,
		SWEET_MAX = 0.75,
		TAP_GRACE = 0.25, -- seconds of network latency allowed after the sweet spot
		CHOICE_TIMEOUT = 20, -- auto-resolve an ignored reveal
	}),

	-- Rarity weight for tier i is base * (1 + BIAS_STEP * boost) ^ i.
	Boost = table.freeze({
		BIAS_STEP = 0.55,
		RED_ZONE = 1,
		PER_DEEPER = 1,
		PERFECT = 0.5,
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
		PATROL_SPEED = 9,
		CHASE_SPEED = 15, -- default player walk speed is 16
		VISION_RANGE = 40,
		VISION_HALF_ANGLE = 35, -- degrees
		CATCH_RANGE = 4.5,
		CATCH_TIME = 0.5,
		LOSE_DISTANCE = 70,
		LOSE_TIME = 3,
		LEASH = 85, -- studs from the red zone center
		IMMUNITY_AFTER_CAPTURE = 5,
		IMMUNITY_AFTER_DROP = 3,
		SUSPICION_AFTER_DROP = 30,
	}),

	Guard = table.freeze({
		MAX_SPEED = 48, -- studs/s horizontal; anything faster counts as a teleport
		FLAG_SECONDS = 2,
	}),

	World = table.freeze({
		HIDEOUT_CENTER = v3(0, 0, 0),
		HIDEOUT_SIZE = 44,
		HIDEOUT_RADIUS = 24, -- "inside the Hideout" for selling and ending chases
		SELL_POINT = v3(-12, 0, -12),
		SHOP_POINT = v3(12, 0, -12),
		RED_CENTER = v3(0, 0, 120),
		RED_SIZE = Vector2.new(80, 60),
		Dumpsters = table.freeze({
			table.freeze({ pos = v3(0, 0, 32), zone = "Green", tutorial = true }),
			table.freeze({ pos = v3(-55, 0, 30), zone = "Green" }),
			table.freeze({ pos = v3(55, 0, 30), zone = "Green" }),
			table.freeze({ pos = v3(-60, 0, -50), zone = "Green" }),
			table.freeze({ pos = v3(60, 0, -50), zone = "Green" }),
			table.freeze({ pos = v3(-18, 0, 128), zone = "Red" }),
			table.freeze({ pos = v3(18, 0, 116), zone = "Red" }),
		}),
		PATROL = table.freeze({
			v3(-30, 0, 100),
			v3(30, 0, 100),
			v3(30, 0, 142),
			v3(-30, 0, 142),
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
	}),
})
