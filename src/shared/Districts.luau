--!strict
-- District lookup shared by server (loot boost) and client (HUD banner).

local Config = require(script.Parent.Config)

export type District = {
	id: string,
	name: string,
	tier: number,
	boost: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
}

local Districts = {}

Districts.MAX_TIER = 5

function Districts.at(pos: Vector3): District?
	for _, d in Config.Districts do
		if pos.X >= d.x0 and pos.X <= d.x1 and pos.Z >= d.z0 and pos.Z <= d.z1 then
			return d :: any
		end
	end
	return nil
end

return Districts
