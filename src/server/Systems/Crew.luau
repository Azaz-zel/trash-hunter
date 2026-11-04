--!strict
-- Crews: groups of up to Config.Crew.MAX players on one server. Ask a player
-- (Players panel), they accept, and you search together: every crewmate
-- within Config.Crew.RANGE raises your odds (Search reads Crew.bonus). The
-- player attribute Crew holds the crew id, so clients can mark crewmates.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Router = require(script.Parent.Parent.Router)
local Guard = require(script.Parent.Guard)

local CC = Config.Crew

type CrewT = { id: string, members: { Player } }

local Crew = {}

local crewOf: { [Player]: CrewT } = {}
local invites: { [Player]: { from: Player, expires: number } } = {}

local function publish(crew: CrewT)
	local names = {}
	for _, m in crew.members do
		table.insert(names, m.DisplayName)
	end
	for _, m in crew.members do
		m:SetAttribute("Crew", crew.id)
		m:SetAttribute("CrewNames", table.concat(names, ", "))
	end
end

local function leave(player: Player)
	local crew = crewOf[player]
	if not crew then
		return
	end
	crewOf[player] = nil
	player:SetAttribute("Crew", nil)
	player:SetAttribute("CrewNames", nil)
	local k = table.find(crew.members, player)
	if k then
		table.remove(crew.members, k)
	end
	if #crew.members == 1 then
		-- A crew of one is no crew.
		local last = crew.members[1]
		crewOf[last] = nil
		last:SetAttribute("Crew", nil)
		last:SetAttribute("CrewNames", nil)
		Router.send(last, "toast", { text = "Your crew broke up." })
	elseif #crew.members > 1 then
		publish(crew)
		for _, m in crew.members do
			Router.send(m, "toast", { text = `{player.DisplayName} left the crew.` })
		end
	end
end

local function invite(player: Player, userId: any): (boolean, string?)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, nil
	end
	local mine = crewOf[player]
	if mine and crewOf[target] == mine then
		return false, "Already in your crew."
	end
	if crewOf[target] then
		return false, `{target.DisplayName} is in another crew.`
	end
	if mine and #mine.members >= CC.MAX then
		return false, `Crews hold {CC.MAX} players.`
	end
	local open = invites[target]
	if open and open.expires > os.clock() then
		return false, `{target.DisplayName} already has an invite open.`
	end
	invites[target] = { from = player, expires = os.clock() + 20 }
	Router.send(target, "crewInvite", { from = player.DisplayName })
	return true, `Crew invite sent to {target.DisplayName}.`
end

local function respond(player: Player, accept: any): (boolean, string?)
	local inv = invites[player]
	invites[player] = nil
	if not inv or inv.expires < os.clock() or not inv.from.Parent then
		return false, "That invite expired."
	end
	if accept ~= true then
		Router.send(inv.from, "toast", { text = `{player.DisplayName} said no.` })
		return true, nil
	end
	leave(player)
	local crew = crewOf[inv.from]
	if not crew then
		crew = { id = HttpService:GenerateGUID(false), members = { inv.from } }
		crewOf[inv.from] = crew
	end
	local c = crew :: CrewT
	if #c.members >= CC.MAX then
		return false, "That crew is full."
	end
	table.insert(c.members, player)
	crewOf[player] = c
	publish(c)
	for _, m in c.members do
		Router.send(m, "toast", {
			text = `{player.DisplayName} joined the crew!`,
			color = Color3.fromRGB(120, 220, 160),
		})
	end
	return true, nil
end

-- Extra loot boost from crewmates standing close by.
function Crew.bonus(player: Player): number
	local crew = crewOf[player]
	if not crew then
		return 0
	end
	local me = Guard.root(player)
	local n = 0
	for _, m in crew.members do
		local root = Guard.root(m)
		if m ~= player and me and root and (root.Position - me.Position).Magnitude <= CC.RANGE then
			n += 1
		end
	end
	return n * CC.BOOST
end

function Crew.init()
	Router.on("crewInvite", 1, invite)
	Router.on("crewRespond", 0.5, respond)
	Router.on("crewLeave", 1, function(player)
		leave(player)
		return true, nil
	end)
end

function Crew.start()
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		leave(player)
	end)
end

return Crew
