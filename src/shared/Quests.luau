--!strict
-- Daily quest offers, shared so the client can show a giver's quest before
-- it is accepted. Everyone gets the same quest from the same giver each day.

local Config = require(script.Parent.Config)

local Quests = {}

function Quests.today(): number
	return math.floor(os.time() / 86400)
end

-- Pool index offered by giver `i` on `day`. Givers are spaced 4 apart in an
-- 11-entry pool (offsets 0, 4, 8, 1), so the four givers never overlap.
function Quests.offer(i: number, day: number): number
	local n = #Config.Quests.pool
	return (day * 7 + (i - 1) * 4) % n + 1
end

-- Whether the stats unlock a district's permit (true for districts without one).
function Quests.permitted(stats: { [string]: number }, districtId: string?): boolean
	local gate = districtId and Config.Gates[districtId]
	return gate == nil or (stats[gate.stat] or 0) >= gate.need
end

function Quests.selfCheck()
	for day = 0, 30 do
		local seen = {}
		for i = 1, #Config.Quests.givers do
			local q = Quests.offer(i, day)
			assert(not seen[q], "givers offered the same quest")
			seen[q] = true
		end
	end
	assert(not Quests.permitted({ searches = 11 }, "maple"), "maple gate opened early")
	assert(Quests.permitted({ searches = 12 }, "maple"), "maple gate stuck")
	assert(Quests.permitted({}, "town"), "town should be open")
end

return Quests
