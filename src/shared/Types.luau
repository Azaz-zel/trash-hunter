--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema) live here so both sides agree.

export type BagItem = {
	uid: string,
	id: string,
	mutation: string?,
}

export type PlayerProfile = {
	version: number,
	cash: number,
	backpackLevel: number,
	backpack: { BagItem },
	shelf: { BagItem }, -- old Hideout shelf; moved into house storage on load
	collection: { [string]: boolean },
	tutorial: number, -- 0 search, 1 sell, 2 upgrade, 3 visit red zone, 4 done
	nextUid: number,
	tools: { [string]: boolean },
	car: string, -- id from Config.Cars, "" = no car yet
	ownedCars: { [string]: boolean },
	trunk: { BagItem },
	paint: string?, -- custom car colour "rrggbb" (Custom Paint pass)
	underglow: boolean,
	xp: number,
	bestCombo: number,
	luckUntil: number, -- Unix time a Lucky Hour runs until
	rerolls: number, -- Bag Rerolls left
	decor: { [string]: boolean }, -- owned house furniture, by Config.Decor id
	settings: Settings,
	milestones: number, -- collection milestones already paid out
	sinceEpic: number, -- searches since the last Epic+ pick (pity)
	sinceLegendary: number, -- searches since the last Legendary+ pick (pity)
	receipts: { string }, -- recent Robux purchase ids, newest last
	house: string, -- id of the Config.Houses type you live in
	houses: { [string]: boolean }, -- house types owned (always the Trailer)
	home: { BagItem }, -- house storage; the best of it stands on the pedestals
	likes: number, -- likes other players gave the house
	stats: { [string]: number }, -- searches, rares, earned (only grow; permits read them)
	streak: number, -- consecutive login days
	lastLogin: number, -- UTC day number of the last streak reward
	quests: { [string]: Quest }, -- by giver id; only today's entries matter
	permits: { [string]: boolean }, -- districts opened by finishing their mission
	mission: Mission?, -- the permit mission in progress
}

export type Settings = {
	music: number, -- 0..1
	effects: number,
	ambient: number,
	rotateMap: boolean,
	low: boolean, -- low graphics
}

export type Mission = {
	id: string,
	progress: number,
}

export type Quest = {
	day: number,
	q: number, -- index into Config.Quests.pool
	progress: number,
	claimed: boolean,
}

-- Snapshot pushed to the owning client after every change.
export type State = {
	cash: number,
	backpack: { BagItem },
	capacity: number,
	backpackLevel: number,
	nextUpgrade: { capacity: number, price: number }?,
	collection: { [string]: boolean },
	tutorial: number,
	tools: { [string]: boolean },
	car: string,
	ownedCars: { [string]: boolean },
	trunk: { BagItem },
	trunkCapacity: number,
	passes: { [string]: boolean },
	house: string,
	houses: { [string]: boolean },
	home: { BagItem },
	storage: number, -- capacity of the current house
	likes: number,
	stats: { [string]: number },
	streak: number,
	quests: { [string]: Quest },
	permits: { [string]: boolean },
	mission: Mission?,
	xp: number,
	paint: string?,
	underglow: boolean,
	decor: { [string]: boolean },
	settings: Settings,
	bestCombo: number,
	luckUntil: number,
	rerolls: number,
}

return nil
