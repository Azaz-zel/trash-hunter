-- The server Router is the only door from clients into the game: every
-- payload shape an exploiter could send must be rejected before a handler
-- runs, and floods must be rate limited.
local function signal()
	return { Connect = function() end }
end
local fired = {}
FAKES.Net = {
	Action = {},
	Event = {
		FireClient = function(_, player, kind)
			table.insert(fired, kind)
		end,
		FireAllClients = function() end,
	},
}
game = {
	GetService = function(_, name)
		if name == "Players" then
			return { PlayerRemoving = signal() }
		end
		return SHARED_FOLDER
	end,
}
local warned = 0
warn = function()
	warned += 1
end
local Router = load("Router")
local calls = 0
-- A tiny interval so the rate limit never trips during the shape checks.
Router.on("echo", 1e-9, function()
	calls += 1
	return true, nil
end)
Router.on("boom", 0.01, function()
	error("handler crashed")
end)
local invoke = FAKES.Net.Action.OnServerInvoke
local player = { Name = "Tester" }

local function ok(payload)
	local before = calls
	local result = invoke(player, "echo", payload)
	return result == true and calls == before + 1
end

-- Accepted shapes.
check(ok(nil), "nil payload")
check(ok("abc"), "short string")
check(ok(3), "small number")
check(ok(true), "boolean")
check(ok(123456789), "user id")
check(ok({ items = { "1", "2" }, cash = 50 }), "trade offer")
check(ok({ paint = "ff00aa" }), "paint table")
-- Rejected shapes.
check(not ok(string.rep("x", 65)), "long string rejected")
check(not ok(0 / 0), "NaN rejected")
check(not ok(1e13), "huge number rejected")
check(not ok({ a = { b = { c = 1 } } }), "nested tables rejected")
local big = {}
for i = 1, 17 do
	big[i] = i
end
check(not ok(big), "17-entry table rejected")
check(not ok({ [true] = 1 }), "boolean keys rejected")
check(not ok({ f = function() end }), "functions rejected")
check(invoke(player, "nope", nil) == false, "unknown action rejected")
check(invoke(player, 42, nil) == false, "non-string action rejected")
-- A crashing handler returns an error, never throws to the client.
check(invoke(player, "boom", nil) == false, "handler errors are contained")
-- Flooding: a burst passes, a flood is cut off.
Router.on("slow", 10, function()
	return true, nil
end)
local passed = 0
for _ = 1, 20 do
	if invoke(player, "slow", nil) == true then
		passed += 1
	end
end
check(passed <= 3, `rate limit let {passed} of 20 calls through`)
print(`router ok: {passed} of 20 flood calls passed`)
