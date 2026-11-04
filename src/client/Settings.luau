--!strict
-- Player settings on the client: volumes per sound group, minimap rotation
-- and low graphics. Values come from the save (state.settings) and are sent
-- back by Controllers/SettingsUi. Other controllers read Settings.get() and
-- listen with Settings.changed().
--
-- Sound groups live in SoundService: "Music" (chase music, radio), "Effects"
-- (finds, horns, crashes, UI) and "Ambient" (city, crowds, rain). Put new
-- sounds in one with Settings.group(name).

local SoundService = game:GetService("SoundService")

export type Values = {
	music: number,
	effects: number,
	ambient: number,
	rotateMap: boolean,
	low: boolean,
}

local Settings = {}

local values: Values = { music = 0.7, effects = 0.8, ambient = 0.7, rotateMap = true, low = false }
local listeners: { (Values) -> () } = {}
local groups: { [string]: SoundGroup } = {}

for _, name in { "Music", "Effects", "Ambient" } do
	local g = SoundService:FindFirstChild(name)
	if not g or not g:IsA("SoundGroup") then
		local made = Instance.new("SoundGroup")
		made.Name = name
		made.Parent = SoundService
		g = made
	end
	groups[name] = g :: SoundGroup
end

local function apply()
	groups.Music.Volume = values.music
	groups.Effects.Volume = values.effects
	groups.Ambient.Volume = values.ambient
	for _, fn in listeners do
		task.spawn(fn, values)
	end
end

function Settings.get(): Values
	return values
end

function Settings.set(key: string, value: any)
	(values :: any)[key] = value
	apply()
end

-- Replaces every value (from the save).
function Settings.load(saved: any)
	if typeof(saved) ~= "table" then
		return
	end
	for key in values do
		if saved[key] ~= nil and typeof(saved[key]) == typeof((values :: any)[key]) then
			(values :: any)[key] = saved[key]
		end
	end
	apply()
end

function Settings.changed(fn: (Values) -> ())
	table.insert(listeners, fn)
end

function Settings.group(name: string): SoundGroup
	return groups[name] or groups.Effects
end

apply()

return Settings
