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
	receipts: { string }, -- recent Robux purchase ids, newest last
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
}

return nil
