--!strict
-- Level maths, shared so the HUD and the server agree. Total XP is the only
-- thing saved; the level and progress inside it are derived.

local Config = require(script.Parent.Config)

local L = Config.Levels

local Levels = {}

-- XP needed to go from `level` to `level + 1`.
function Levels.toNext(level: number): number
	return L.BASE_XP + L.STEP_XP * (level - 1)
end

-- Level, XP into it, and XP needed for the next one, from total XP.
function Levels.fromXp(xp: number): (number, number, number)
	local level, left = 1, math.max(0, xp)
	while level < L.MAX and left >= Levels.toNext(level) do
		left -= Levels.toNext(level)
		level += 1
	end
	return level, left, Levels.toNext(level)
end

function Levels.title(level: number): string
	local name = L.TITLES[1].name
	for _, t in L.TITLES do
		if level >= t.level then
			name = t.name
		end
	end
	return name
end

-- Cash for reaching `level` (Season Pass doubles it).
function Levels.reward(level: number, premium: boolean): number
	return level * L.REWARD_PER_LEVEL * (if premium then 2 else 1)
end

function Levels.selfCheck()
	assert(Levels.fromXp(0) == 1, "level 1 at 0 xp")
	local lvl, into = Levels.fromXp(Levels.toNext(1))
	assert(lvl == 2 and into == 0, "exactly one level of xp is level 2")
	local top = Levels.fromXp(10 ^ 9)
	assert(top == L.MAX, "capped at MAX")
	assert(Levels.title(1) == L.TITLES[1].name, "first title")
	assert(Levels.reward(3, true) == 2 * Levels.reward(3, false), "season doubles")
end

return Levels
