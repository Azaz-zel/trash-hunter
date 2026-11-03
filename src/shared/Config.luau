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
		GUARD_COUNT = 3,
		PATROL_SPEED = 8.5, -- each guard gets +-1 of this so they do not move in lockstep
		INVESTIGATE_SPEED = 11,
		CHASE_SPEED = 15, -- default player walk speed is 16
		VISION_RANGE = 55,
		VISION_HALF_ANGLE = 32, -- degrees
		CATCH_RANGE = 4.5,
		CATCH_TIME = 0.5,
		LOSE_DISTANCE = 80,
		LOSE_TIME = 3,
		LEASH = 70, -- studs guards may follow a target outside the compound fence
		BACKUP_RADIUS = 140, -- other guards this close join a chase
		IMMUNITY_AFTER_CAPTURE = 5,
		IMMUNITY_AFTER_DROP = 3,
		SUSPICION_AFTER_DROP = 30,
	}),

	Guard = table.freeze({
		MAX_SPEED = 48, -- studs/s horizontal; anything faster counts as a teleport
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
