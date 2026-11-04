--!strict
-- Long-term progress: lifetime stats, the daily login streak, the daily
-- quests handed out by quest givers, and the permit missions: each district's
-- dumpsters stay locked until the player finds that district's contact,
-- takes their mission, finishes it and reports back.
-- Other systems report what happened through Progress.track.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Quests = require(Shared.Quests)
local Types = require(Shared.Types)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Npc = require(script.Parent.Parent.Npc)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)

local Q = Config.Quests

export type Event = {
	district: string?, -- district id of the searched dumpster
	red: boolean?, -- searched inside the Meridian yard
	city: string?, -- city of the searched dumpster
	rarity: number?, -- rarity of the picked bag
	amount: number?, -- cash earned
}

local Progress = {}

local function districtName(id: string): string
	for _, d in Config.Districts do
		if d.id == id then
			return d.name
		end
	end
	return id
end

-- How much one event moves a quest of this definition forward.
local function stepFor(def: any, kind: string, e: Event): number
	if kind == "search" then
		if def.kind == "search" then
			return 1
		elseif def.kind == "find" and (e.rarity or 0) >= def.rarity then
			return 1
		elseif def.kind == "district" and e.district == def.district then
			return 1
		elseif def.kind == "yard" and e.red then
			return 1
		elseif def.kind == "city" and e.city == def.city then
			return 1
		end
	elseif kind == "earn" and def.kind == "earn" then
		return e.amount or 0
	end
	return 0
end

-- kind: "search" | "earn". Callers push the state afterwards.
function Progress.track(player: Player, kind: string, e: Event)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local stats = profile.stats
	if kind == "search" then
		stats.searches += 1
		if (e.rarity or 0) >= 3 then
			stats.rares += 1
		end
	elseif kind == "earn" then
		stats.earned += math.max(e.amount or 0, 0)
	end

	local day = Quests.today()
	for _, giver in Q.givers do
		local quest = profile.quests[giver.id]
		local def = quest and Q.pool[quest.q]
		if quest and def and quest.day == day and not quest.claimed and quest.progress < def.n then
			local step = stepFor(def, kind, e)
			if step > 0 then
				quest.progress = math.min(def.n, quest.progress + step)
				if quest.progress >= def.n then
					Router.send(player, "questReady", { giver = giver.name, text = def.text })
				end
			end
		end
	end

	-- The permit mission in progress.
	local active = profile.mission
	local m = active and Quests.missionById(active.id)
	if active and m and active.progress < m.n then
		local searched = kind == "search"
			and (
				(m.kind == "search" and (m.inDistrict == nil or e.district == m.inDistrict))
				or (m.kind == "find" and (e.rarity or 0) >= m.rarity)
			)
		local step = if searched
			then 1
			elseif kind == "earn" and m.kind == "earn" then e.amount or 0
			else 0
		if step > 0 then
			active.progress = math.min(m.n, active.progress + step)
			if active.progress >= m.n then
				local contact = Config.Contacts[m.contact]
				Router.send(
					player,
					"missionReady",
					{ contact = contact.name, district = districtName(m.district) }
				)
			end
		end
	end
end

-- Locked dumpsters say whom to talk to for the permit.
function Progress.gateMessage(player: Player, districtId: string?): string?
	local profile = Data.get(player)
	if not profile or Quests.permitted(profile.permits, districtId) then
		return nil
	end
	local m = Quests.missionFor(districtId)
	local contact = Config.Contacts[m.contact]
	local nextUp = Quests.nextMission(profile.permits)
	if nextUp and nextUp.id ~= m.id then
		return `{districtName(districtId :: string)} is locked. Earn the permits before it first.`
	end
	return `{districtName(districtId :: string)} is locked. Find {contact.name} for a permit mission (marked on your map).`
end

-- ─── permit missions ──────────────────────────────────────────────────────

local function contactAt(player: Player, id: any): (any, string?)
	if typeof(id) ~= "string" then
		return nil, nil
	end
	local contact = Config.Contacts[id]
	if not contact then
		return nil, nil
	end
	if Guard.isFlagged(player) or Guard.distance(player, contact.pos) > Config.CONTACT_RANGE then
		return nil, `Talk to {contact.name} up close.`
	end
	return contact, nil
end

local function missionAccept(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local contact, message = contactAt(player, id)
	if not profile or not contact then
		return false, message
	end
	local m = Quests.nextMission(profile.permits)
	if not m or m.contact ~= id then
		return false, `{contact.name} has nothing for you right now.`
	end
	if profile.mission and profile.mission.id == m.id then
		return false, "You're already on it."
	end
	profile.mission = { id = m.id, progress = 0 }
	Data.push(player)
	return true, nil
end

-- "bring" missions hand over the cheapest item that qualifies.
local function cheapestAtLeast(profile: Types.PlayerProfile, rarity: number): Types.BagItem?
	local best: Types.BagItem? = nil
	local bestValue = math.huge
	for _, entry in profile.backpack do
		local item = Items.ById[entry.id]
		if item and item.rarity >= rarity then
			local v = Items.value(entry.id, entry.mutation)
			if v < bestValue then
				best, bestValue = entry, v
			end
		end
	end
	return best
end

local function missionTurnIn(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local contact, message = contactAt(player, id)
	if not profile or not contact then
		return false, message
	end
	local active = profile.mission
	local m = active and Quests.missionById(active.id)
	if not active or not m or m.contact ~= id then
		return false, nil
	end
	if m.kind == "bring" then
		local entry = cheapestAtLeast(profile, m.rarity)
		if not entry then
			return false, "You don't have anything good enough in your backpack."
		end
		Data.removeItem(profile.backpack, entry.uid)
	elseif active.progress < m.n then
		return false, "Not done yet."
	end
	profile.permits[m.district] = true
	profile.mission = nil
	profile.cash += m.reward
	Data.push(player)
	Router.send(player, "permit", { district = districtName(m.district), cash = m.reward })
	return true, nil
end

local function giverAt(player: Player, index: any): (any, string?)
	if typeof(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return nil, nil
	end
	local giver = Q.givers[index]
	if not giver then
		return nil, nil
	end
	if Guard.isFlagged(player) or Guard.distance(player, giver.pos) > Q.RANGE then
		return nil, `Talk to {giver.name} up close.`
	end
	return giver, nil
end

local function accept(player: Player, index: any): (boolean, string?)
	local profile = Data.get(player)
	local giver, message = giverAt(player, index)
	if not profile or not giver then
		return false, message
	end
	local day = Quests.today()
	local current = profile.quests[giver.id]
	if current and current.day == day then
		return false, if current.claimed then "Come back tomorrow." else "You're already on it."
	end
	profile.quests[giver.id] =
		{ day = day, q = Quests.offer(index :: number, day), progress = 0, claimed = false }
	Data.push(player)
	return true, nil
end

local function claim(player: Player, index: any): (boolean, string?)
	local profile = Data.get(player)
	local giver, message = giverAt(player, index)
	if not profile or not giver then
		return false, message
	end
	local quest = profile.quests[giver.id]
	local def = quest and Q.pool[quest.q]
	if not quest or not def or quest.day ~= Quests.today() or quest.claimed then
		return false, nil
	end
	if quest.progress < def.n then
		return false, "Not done yet."
	end
	quest.claimed = true
	profile.cash += def.reward
	Data.push(player)
	Router.send(player, "questDone", { giver = giver.name, cash = def.reward })
	return true, nil
end

-- Streak: +1 for a login the day after the last one, back to 1 after a gap.
local function grantStreak(player: Player, profile: Types.PlayerProfile)
	local day = Quests.today()
	if profile.lastLogin == day then
		return
	end
	profile.streak = if profile.lastLogin == day - 1 then profile.streak + 1 else 1
	profile.lastLogin = day
	local reward = Config.STREAK[(profile.streak - 1) % #Config.STREAK + 1]
	profile.cash += reward
	Data.push(player)
	-- Give the client a moment to build its HUD before the toast.
	task.delay(4, function()
		if player.Parent then
			Router.send(player, "streak", { day = profile.streak, cash = reward })
		end
	end)
end

local function spawnGivers()
	local folder = Instance.new("Folder")
	folder.Name = "QuestGivers"
	folder.Parent = workspace:WaitForChild("Town")
	local rng = Random.new(7)
	for i, giver in Q.givers do
		local cf = CFrame.new(giver.pos + Vector3.new(0, 3.2, 0))
			* CFrame.Angles(0, math.rad(giver.yaw), 0)
		local npc = Npc.new("civilian", giver.name, cf, folder, rng)
		if not npc then
			continue
		end
		npc.root.Anchored = true -- stands at its post; players can't shove it away
		npc.model:SetAttribute("Giver", i)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QuestPrompt"
		prompt.ActionText = "Talk"
		prompt.ObjectText = giver.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Q.RANGE - 2
		prompt.RequiresLineOfSight = false
		prompt.Parent = npc.root
		local tag = Instance.new("BillboardGui")
		tag.Name = "QuestTag"
		tag.Size = UDim2.fromOffset(160, 40)
		tag.StudsOffset = Vector3.new(0, 3.6, 0)
		tag.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 190, 70)
		label.TextStrokeTransparency = 0.3
		label.Text = `{giver.name}\nQuests`
		label.Parent = tag
		tag.Parent = npc.head
	end
end

local function spawnContacts()
	local folder = Instance.new("Folder")
	folder.Name = "Contacts"
	folder.Parent = workspace:WaitForChild("Town")
	local rng = Random.new(19)
	for id, contact in Config.Contacts do
		local npc = Npc.new(
			"civilian",
			contact.name,
			CFrame.new(contact.pos + Vector3.new(0, 3.2, 0)),
			folder,
			rng
		)
		if not npc then
			continue
		end
		npc.root.Anchored = true
		npc.model:SetAttribute("Contact", id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MissionPrompt"
		prompt.ActionText = "Talk"
		prompt.ObjectText = contact.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.CONTACT_RANGE - 2
		prompt.RequiresLineOfSight = false
		prompt.Parent = npc.root
	end
end

function Progress.init()
	Router.on("questAccept", 0.3, accept)
	Router.on("questClaim", 0.3, claim)
	Router.on("missionAccept", 0.3, missionAccept)
	Router.on("missionTurnIn", 0.3, missionTurnIn)
	Data.onLoaded(grantStreak)
end

function Progress.start()
	workspace:SetAttribute("QuestDay", Quests.today())
	task.spawn(spawnGivers)
	task.spawn(spawnContacts)
	task.spawn(function()
		while true do
			task.wait(30)
			workspace:SetAttribute("QuestDay", Quests.today())
		end
	end)
end

return Progress
