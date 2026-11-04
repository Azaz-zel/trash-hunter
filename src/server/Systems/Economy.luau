--!strict
-- Selling at the Hideout and the backpack upgrade at Hank's Hardware.
-- (Storage and the display pedestals live in your house: Housing.luau.)

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Avatar = require(script.Parent.Avatar)
local Progress = require(script.Parent.Progress)

local Economy = {}

local function atHideout(player: Player): (boolean, string?)
	if Guard.isFlagged(player) then
		return false, "Hold on..."
	end
	if not Guard.inHideout(player) then
		return false, "You can only do that in the Hideout."
	end
	return true, nil
end

local function sell(player: Player, payload: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local ok, message = atHideout(player)
	if not ok then
		return false, message
	end
	local earned, count = 0, 0
	if payload == "all" then
		for _, entry in profile.backpack do
			earned += Items.value(entry.id, entry.mutation)
			count += 1
		end
		table.clear(profile.backpack)
	else
		local entry = Data.removeItem(profile.backpack, payload)
		if not entry then
			return false, "That item is gone."
		end
		earned = Items.value(entry.id, entry.mutation)
		count = 1
	end
	if count == 0 then
		return false, "Nothing to sell."
	end
	earned = Data.sellValue(player, earned)
	profile.cash += earned
	Progress.track(player, "earn", { amount = earned })
	Data.advanceTutorial(profile, 1, player)
	Data.push(player)
	Router.send(player, "sold", { amount = earned, count = count })
	return true, nil
end

local function buyUpgrade(player: Player): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "gear") -- bags are sold at Hank's
	if not ok then
		return false, message
	end
	local next = Config.Backpack[profile.backpackLevel + 1]
	if not next then
		return false, "Backpack is maxed out."
	end
	if profile.cash < next.price then
		return false, `You need ${next.price - profile.cash} more.`
	end
	profile.cash -= next.price
	profile.backpackLevel += 1
	Data.advanceTutorial(profile, 2, player)
	Avatar.refresh(player)
	Data.push(player)
	Router.send(player, "upgraded", { capacity = next.capacity })
	return true, nil
end

function Economy.init()
	Router.on("sell", 0.15, sell)
	Router.on("buyUpgrade", 0.5, buyUpgrade)
end

return Economy
