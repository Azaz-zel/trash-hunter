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
}

return nil
