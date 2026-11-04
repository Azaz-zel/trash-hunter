--!strict
-- Street layout for the client map, traffic and walkers. The city itself is
-- defined in CityPlan; this module keeps the older, smaller interface.

local CityPlan = require(script.Parent.CityPlan)

return table.freeze({
	ROADS = CityPlan.ROADS,
	ROAD_WIDTH = 34, -- arterial width; each road also carries its own `w`
	BOUNDS = CityPlan.BOUNDS,
})
