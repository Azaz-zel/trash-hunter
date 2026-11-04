--!strict
-- Story chapters (Config.Story): Big Sal stands outside the Hideout. Talk to
-- him to start the next chapter (a short cutscene with that chapter's boss),
-- do the goal anywhere, then talk to him again for the reward and the next
-- boss's intro. Progress comes from Story.track, called by Progress (search,
-- earn) and Search (perfect, combo).

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Router = require(script.Parent.Parent.Router)
local Analytics = require(script.Parent.Parent.Analytics)
local Npc = require(script.Parent.Parent.Npc)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Ranks = require(script.Parent.Ranks)

local S = Config.Story
local TALK_RANGE = 14

local Story = {}

local function chapterOf(profile: any): any
	return S.CHAPTERS[profile.story.chapter]
end

-- How much one event moves the current goal (combo sets, others add).
local function stepFor(goal: any, kind: string, e: any): number?
	if goal.kind == "search" and kind == "search" then
		return 1
	elseif goal.kind == "yard" and kind == "search" and e.red then
		return 1
	elseif goal.kind == "rare" and kind == "search" and (e.rarity or 0) >= goal.rarity then
		return 1
	elseif goal.kind == "earn" and kind == "earn" then
		return e.amount or 0
	elseif goal.kind == "perfect" and kind == "perfect" then
		return 1
	end
	return nil
end

function Story.track(player: Player, kind: string, e: any)
	local profile = Data.get(player)
	if not profile or not profile.story.started then
		return
	end
	local chapter = chapterOf(profile)
	if not chapter then
		return
	end
	local goal = chapter.goal
	local before = profile.story.progress
	if goal.kind == "combo" and kind == "combo" then
		profile.story.progress = math.max(before, e.n or 0)
	else
		local step = stepFor(goal, kind, e)
		if not step then
			return
		end
		profile.story.progress = math.min(goal.n, before + step)
	end
	if before < goal.n and profile.story.progress >= goal.n then
		Router.send(player, "toast", {
			text = `Story: "{chapter.title}" done! Go back to {S.GIVER.name}.`,
			color = Color3.fromRGB(255, 190, 70),
		})
	end
end

-- Talking to the giver: start, check in, or hand in the current chapter.
local function talk(player: Player): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	if Guard.distance(player, S.GIVER.pos) > TALK_RANGE then
		return false, `Talk to {S.GIVER.name} outside the Hideout.`
	end
	local chapter = chapterOf(profile)
	if not chapter then
		Router.send(player, "storyScene", {
			speaker = S.GIVER.name,
			title = "The End... for now",
			lines = { "You did it all, King. New jobs are coming. Stay sharp." },
		})
		return true, nil
	end
	local story = profile.story
	if not story.started then
		story.started = true
		story.progress = 0
		Data.push(player)
		Router.send(player, "storyScene", {
			speaker = chapter.boss,
			title = `Chapter {story.chapter}: {chapter.title}`,
			lines = chapter.intro,
			goal = chapter.goal.text,
		})
		return true, nil
	end
	if story.progress < chapter.goal.n then
		Router.send(player, "storyScene", {
			speaker = S.GIVER.name,
			title = chapter.title,
			lines = { `Still waiting on you. {chapter.goal.text}.` },
			goal = `{chapter.goal.text} ({story.progress}/{chapter.goal.n})`,
		})
		return true, nil
	end
	-- Hand in.
	profile.cash += chapter.cash
	Analytics.source(player, chapter.cash, profile.cash, "Story")
	Ranks.add(player, chapter.xp)
	story.chapter += 1
	story.started = false
	story.progress = 0
	Data.push(player)
	Router.send(player, "storyScene", {
		speaker = chapter.boss,
		title = `Chapter complete: {chapter.title}`,
		lines = chapter.outro,
		reward = `+${chapter.cash} · +{chapter.xp} XP`,
	})
	Analytics.event(player, "StoryChapter", story.chapter - 1)
	return true, nil
end

function Story.init()
	Router.on("storyTalk", 1, talk)
end

function Story.start()
	local town = workspace:WaitForChild("Town")
	local look = Config.World.HIDEOUT_CENTER
	local npc = Npc.new(
		"civilian",
		"BigSal",
		CFrame.lookAt(S.GIVER.pos + Vector3.new(0, 3, 0), Vector3.new(look.X, 3, look.Z)),
		town,
		Random.new(77)
	)
	if not npc then
		return
	end
	npc.root.Anchored = true
	npc.model:SetAttribute("StoryGiver", true)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(180, 46)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 190, 70)
	label.TextStrokeTransparency = 0.2
	label.Text = `★ {S.GIVER.name}\nStory`
	label.Parent = tag
	tag.Parent = npc.head
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StoryPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = S.GIVER.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = TALK_RANGE - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = npc.root
	prompt.Triggered:Connect(function(player)
		local ok, message = talk(player)
		if not ok and message then
			Router.send(player, "toast", { text = message })
		end
	end)
end

return Story
