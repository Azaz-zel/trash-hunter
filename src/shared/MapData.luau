--!strict
-- Map bounds for the client map. The road graph itself lives in CityPlan.

local CityPlan = require(script.Parent.CityPlan)

return table.freeze({
	BOUNDS = CityPlan.BOUNDS,
})
