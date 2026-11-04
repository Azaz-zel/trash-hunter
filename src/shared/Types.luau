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
	shelf: { BagItem },
	collection: { [string]: boolean },
	tutorial: number, -- 0 search, 1 sell, 2 upgrade, 3 visit red zone, 4 done
	nextUid: number,
	tools: { [string]: boolean },
	car: string, -- id from Config.Cars
	ownedCars: { [string]: boolean },
	trunk: { BagItem },
	milestones: number, -- collection milestones already paid out
	sinceEpic: number, -- searches since the last Epic+ pick (pity)
	sinceLegendary: number, -- searches since the last Legendary+ pick (pity)
	receipts: { string }, -- recent Robux purchase ids, newest last
	houseLevel: number, -- 0 = no house, else index into Config.Houses
	home: { BagItem }, -- items on the house pedestals
	likes: number, -- likes other players gave the house
	stats: { [string]: number }, -- searches, rares, earned (only grow; permits read them)
	streak: number, -- consecutive login days
	lastLogin: number, -- UTC day number of the last streak reward
	quests: { [string]: Quest }, -- by giver id; only today's entries matter
	permits: { [string]: boolean }, -- districts opened by finishing their mission
	mission: Mission?, -- the permit mission in progress
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
	shelf: { BagItem },
	shelfSlots: number,
	collection: { [string]: boolean },
	tutorial: number,
	tools: { [string]: boolean },
	car: string,
	ownedCars: { [string]: boolean },
	trunk: { BagItem },
	trunkCapacity: number,
	passes: { [string]: boolean },
	houseLevel: number,
	home: { BagItem },
	likes: number,
	stats: { [string]: number },
	streak: number,
	quests: { [string]: Quest },
	permits: { [string]: boolean },
	mission: Mission?,
}

return nil
