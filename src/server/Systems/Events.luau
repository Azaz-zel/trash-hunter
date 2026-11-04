--!strict
-- Live events on the UTC clock, the same in every server:
--   weekend    Saturday and Sunday: twice the fresh drops (Search.freshDrop)
--   happyhour  one hour from each Config.Events.HAPPY_HOUR_UTC start: better
--              sell prices (Data.sellValue)
-- workspace attributes: Event (id or ""), EventName, EventEnds (server time).
-- Happy hour wins while both run.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Router = require(script.Parent.Parent.Router)

local E = Config.Events

local Events = {}

local function current(now: number): (string, string, number)
	local t = os.date("!*t", math.floor(now))
	local hour = t.hour
	for _, start in E.HAPPY_HOUR_UTC do
		if hour == start then
			local ends = now - t.min * 60 - t.sec + 3600
			return "happyhour",
				`Happy Hour · sell prices +{math.floor((E.HAPPY_HOUR_SELL - 1) * 100 + 0.5)}%`,
				ends
		end
	end
	-- os.date wday: 1 = Sunday, 7 = Saturday.
	if t.wday == 7 or t.wday == 1 then
		local daysLeft = if t.wday == 7 then 2 else 1
		local ends = now - t.hour * 3600 - t.min * 60 - t.sec + daysLeft * 86400
		return "weekend", "Double Fresh Weekend · twice the fresh drops", ends
	end
	return "", "", 0
end

function Events.start()
	task.spawn(function()
		while true do
			local now = os.time()
			local id, name, ends = current(now)
			if workspace:GetAttribute("Event") ~= id then
				workspace:SetAttribute("Event", id)
				workspace:SetAttribute("EventName", name)
				if id ~= "" then
					Router.broadcast(
						"toast",
						{ text = `Event: {name}!`, color = Color3.fromRGB(255, 190, 70) }
					)
				end
			end
			-- Server clock (GetServerTimeNow) is Unix time too.
			workspace:SetAttribute("EventEnds", ends)
			task.wait(20)
		end
	end)
end

return Events
