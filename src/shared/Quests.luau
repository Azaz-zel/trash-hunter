--!strict
-- Daily quest offers, shared so the client can show a giver's quest before
-- it is accepted. Everyone gets the same quest from the same giver each day.

local Config = require(script.Parent.Config)

local Quests = {}

function Quests.today(): number
	return math.floor(os.time() / 86400)
end

-- Pool index offered by giver `i` on `day`. Givers are spaced 4 apart in an
-- 11-entry pool (offsets 0, 4, 8, 1, 5, 9), so the six givers never overlap.
function Quests.offer(i: number, day: number): number
	local n = #Config.Quests.pool
	return (day * 7 + (i - 1) * 4) % n + 1
end

-- The permit mission for a district, if it has one.
function Quests.missionFor(districtId: string?): any
	for _, m in Config.Missions do
		if m.district == districtId then
			return m
		end
	end
	return nil
end

-- Whether a district's dumpsters are open (districts without a mission always are).
function Quests.permitted(permits: { [string]: boolean }?, districtId: string?): boolean
	return Quests.missionFor(districtId) == nil
		or (permits ~= nil and permits[districtId :: string] == true)
end

-- The next mission in the chain (the first whose district is still locked).
function Quests.nextMission(permits: { [string]: boolean }?): any
	for _, m in Config.Missions do
		if not (permits and permits[m.district]) then
			return m
		end
	end
	return nil
end

function Quests.missionById(id: string?): any
	for _, m in Config.Missions do
		if m.id == id then
			return m
		end
	end
	return nil
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
	assert(not Quests.permitted({}, "midtown"), "midtown open without a permit")
	assert(Quests.permitted({ midtown = true }, "midtown"), "midtown permit ignored")
	assert(Quests.permitted({}, "southside"), "southside should be open")
	assert(Quests.nextMission({}).district == "eastgate", "mission chain should start at Eastgate")
	for _, m in Config.Missions do
		assert(Config.Contacts[m.contact], `mission {m.id} has no contact`)
	end
end

return Quests
