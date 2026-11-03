--!strict
-- Friend bonus (a Roblox friend in the same server gives better loot odds)
-- and server-wide announcements for big finds.

local Players = game:GetService("Players")

local Router = require(script.Parent.Parent.Router)

local friends: { [Player]: { [Player]: boolean } } = {}

local Social = {}

function Social.hasFriendHere(player: Player): boolean
	for other, isFriend in friends[player] or {} do
		if isFriend and other.Parent then
			return true
		end
	end
	return false
end

function Social.announce(player: Player, itemId: string, mutation: string?, rarity: number)
	Router.broadcast("announce", {
		name = player.DisplayName,
		itemId = itemId,
		mutation = mutation,
		rarity = rarity,
	})
end

local function onPlayerAdded(player: Player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
		local value = ok and isFriend == true
		friends[player][other] = value
		friends[other] = friends[other] or {}
		friends[other][player] = value
	end
	player:SetAttribute("FriendBonus", Social.hasFriendHere(player))
	for other in friends[player] do
		other:SetAttribute("FriendBonus", Social.hasFriendHere(other))
	end
end

function Social.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local mine = friends[player] or {}
		friends[player] = nil
		for other in mine do
			if friends[other] then
				friends[other][player] = nil
				other:SetAttribute("FriendBonus", Social.hasFriendHere(other))
			end
		end
	end)
end

return Social
