-- Module loader for the bundled tests (see tests/run.py). Every module is a
-- function(script, require) in MODULES; `script.Parent.X` and
-- `Shared:WaitForChild("X")` both resolve to X. FAKES stand in for client
-- modules a test does not want to run for real.
MODULES = {}
FAKES = {}
local cache = {}
local handleMeta = {}
local function handle(name)
	return setmetatable({ __module = name }, handleMeta)
end
handleMeta.__index = function(_, key)
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(_, name)
			return handle(name)
		end
	end
	return handle(key)
end
local folder = setmetatable({}, {
	__index = function(_, key)
		if key == "WaitForChild" or key == "FindFirstChild" then
			return function(_, name)
				return handle(name)
			end
		end
		if key == "Parent" then
			return nil
		end
		return handle(key)
	end,
})
local function fakeScript()
	return { Parent = setmetatable({ Parent = folder }, { __index = folder }) }
end
local function loaderRequire(target)
	local name = if type(target) == "table" then target.__module else target
	if FAKES[name] then
		return FAKES[name]
	end
	if cache[name] == nil then
		local fn = MODULES[name]
		assert(fn, "no module " .. tostring(name))
		cache[name] = fn(fakeScript(), loaderRequire)
	end
	return cache[name]
end
function load(name)
	return loaderRequire(name)
end
SHARED_FOLDER = folder

-- Tiny assertion helper: prints FAIL lines (run.py fails the file on them).
function check(ok, message)
	if not ok then
		print("FAIL " .. message)
	end
end
