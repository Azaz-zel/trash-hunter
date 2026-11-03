--!strict
-- Long-term progress: lifetime stats (which unlock district permits), the
-- daily login streak and the daily quests handed out by NPC quest givers.
-- Other systems report what happened through Progress.track.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Quests = require(Shared.Quests)
local Types = require(Shared.Types)
local Router = require(script.Parent.Parent.Router)
local Npc = require(script.Parent.Parent.Npc)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)

local Q = Config.Quests

export type Event = {
	district: string?, -- district id of the searched dumpster
	red: boolean?, -- searched inside the Meridian yard
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
	local before: { [string]: boolean } = {}
	for id in Config.Gates do
		before[id] = Quests.permitted(profile.stats, id)
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

	for id in Config.Gates do
		if not before[id] and Quests.permitted(profile.stats, id) then
			Router.send(player, "permit", { district = districtName(id) })
		end
	end
end

-- Locked dumpsters say what the permit needs and how far along the player is.
function Progress.gateMessage(player: Player, districtId: string?): string?
	local profile = Data.get(player)
	local gate = districtId and Config.Gates[districtId]
	if not profile or not gate or Quests.permitted(profile.stats, districtId) then
		return nil
	end
	local have = math.min(profile.stats[gate.stat] or 0, gate.need)
	local shown = if gate.stat == "earned" then `${have}/${gate.need}` else `{have}/{gate.need}`
	return `{districtName(districtId :: string)} permit needed: {gate.text} ({shown}).`
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

function Progress.init()
	Router.on("questAccept", 0.3, accept)
	Router.on("questClaim", 0.3, claim)
	Data.onLoaded(grantStreak)
end

function Progress.start()
	workspace:SetAttribute("QuestDay", Quests.today())
	task.spawn(spawnGivers)
	task.spawn(function()
		while true do
			task.wait(30)
			workspace:SetAttribute("QuestDay", Quests.today())
		end
	end)
end

return Progress
