-- Runs the client traffic logic for five simulated minutes on the real road
-- graph and checks the driving rules: nobody enters a junction on red
-- (unless committed during amber), crossing phases never share a junction,
-- and no car stays stuck for a minute.
local CityPlan = load("CityPlan")
local SIM = { t = 0 }
local function signal()
	return { Connect = function() end }
end
local function inst()
	return { FindFirstChildOfClass = function() return nil end }
end
FAKES.Settings = {
	get = function()
		return { low = false }
	end,
	group = function()
		return {}
	end,
	changed = function() end,
}
FAKES.Config = { Sounds = { HORN = "", SIREN = "", CRASH = "" } }
local services = {
	Players = { LocalPlayer = { Character = nil, GetAttribute = function() return nil end }, GetPlayers = function() return {} end },
	ReplicatedStorage = SHARED_FOLDER,
	RunService = { Heartbeat = signal() },
	CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return signal() end },
}
-- Globals the controller touches.
game = { GetService = function(_, name) return services[name] end }
workspace = {
	GetServerTimeNow = function() return SIM.t end,
	FindFirstChild = function() return nil end,
	GetAttribute = function() return nil end,
}
Instance = { new = inst }
Enum = { Material = {}, NormalId = {}, HumanoidStateType = {} }
-- Traffic's Config is the fake above; CityPlan is the real one.
local Traffic = load("Traffic")
local probe = Traffic._test
check(probe ~= nil, "Traffic exposes _test")
local function model()
	local root = { CFrame = CFrame.new(0, 0, 0) }
	local m = { PrimaryPart = root }
	function m:GetDescendants() return {} end
	function m:FindFirstChildWhichIsA() return root end
	function m:GetBoundingBox() return CFrame.new(0, 2, 0), Vector3.new(6, 4, 12) end
	function m:GetPivot() return root.CFrame end
	function m:Clone() return model() end
	return m
end
Traffic.init()
probe.spawn({ model() }, nil)
local dt = 1 / 20
local still, redRuns, conflicts, worst = {}, 0, 0, 0
for _ = 1, 20 * 300 do
	SIM.t += dt
	for _, car in probe.cars do
		local before, lane, committed = car.turn, car.lane, car.committed
		probe.step(car, dt, SIM.t, SIM.t, false)
		if not before and car.turn and lane.to.signal then
			if CityPlan.signalState(lane.group, SIM.t) == "red" and not committed then
				redRuns += 1
			end
		end
		still[car] = if car.speed < 0.1 then (still[car] or 0) + dt else 0
		worst = math.max(worst, still[car])
	end
	for node, list in probe.inside do
		if node.signal then
			local seen = {}
			for _, entry in list do
				seen[entry.group] = true
			end
			if seen.A and seen.B then
				conflicts += 1
			end
		end
	end
end
check(redRuns == 0, `{redRuns} cars ran a red light`)
check(conflicts == 0, `{conflicts} frames with crossing phases in one junction`)
check(worst < 60, `a car was stuck for {math.floor(worst)} s`)
print(`traffic ok: longest wait {math.floor(worst)} s`)
