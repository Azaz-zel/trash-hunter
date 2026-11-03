--!strict
-- Street layout shared by the server (World builds the roads) and the client
-- (the minimap draws them), so both always agree. X roads run east-west at a
-- fixed Z ("at"), Z roads run north-south at a fixed X.

export type Road = { axis: string, at: number, from: number, to: number, name: string? }

local ROADS: { Road } = {
	{ axis = "X", at = 0, from = -1240, to = 1240, name = "Main St" },
	{ axis = "X", at = 300, from = -1240, to = 1240, name = "Industrial Rd" },
	{ axis = "X", at = -240, from = -1240, to = 1240, name = "Maple Ave" },
	{ axis = "X", at = 700, from = -1240, to = 1240, name = "Rail Rd" },
	{ axis = "X", at = -120, from = -1240, to = -640, name = "Elm St" },
	{ axis = "X", at = -120, from = 640, to = 1240, name = "Commerce Ave" },
	{ axis = "X", at = -640, from = -620, to = 620, name = "Hillcrest Dr" },
	{ axis = "X", at = -880, from = -620, to = 620, name = "Ridge Ln" },
	{ axis = "X", at = -640, from = -1240, to = -660, name = "Sunset Ln" },
	{ axis = "X", at = -700, from = 660, to = 1240, name = "Corporate Dr" },
	{ axis = "Z", at = -400, from = -480, to = 300 },
	{ axis = "Z", at = -130, from = -480, to = 300 },
	{ axis = "Z", at = 150, from = -480, to = 300 },
	{ axis = "Z", at = 420, from = -480, to = 300 },
	{ axis = "Z", at = -980, from = -640, to = 300 },
	{ axis = "Z", at = -700, from = -480, to = 300 },
	{ axis = "Z", at = 760, from = -700, to = 300 },
	{ axis = "Z", at = 1040, from = -700, to = 300 },
	{ axis = "Z", at = 0, from = -900, to = -240, name = "Hillcrest Blvd" },
	{ axis = "Z", at = -560, from = 300, to = 820 },
	{ axis = "Z", at = 560, from = 300, to = 820 },
}

return table.freeze({
	ROADS = ROADS,
	ROAD_WIDTH = 34,
	BOUNDS = table.freeze({ x0 = -1300, x1 = 1300, z0 = -1110, z1 = 900 }),
})
