--!strict
-- Quest givers' dialog card, and a small tracker under the stat chips that
-- lists today's quests and the next district permit to earn.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Quests = require(Shared:WaitForChild("Quests"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local Q = Config.Quests
local player = Players.LocalPlayer

local gui: ScreenGui
local tracker: Frame
local dialog: Frame
local dName: TextLabel
local dLine: TextLabel
local dQuest: TextLabel
local dButton: TextButton
local talking: number? = nil -- giver index of the open dialog

local QuestUi = {}

local function day(): number
	return tonumber(workspace:GetAttribute("QuestDay")) or Quests.today()
end

local function amount(def: any, n: number): string
	return if def.kind == "earn" then Ui.money(n) else tostring(n)
end

local function districtName(id: string): string
	for _, d in Config.Districts do
		if d.id == id then
			return d.name
		end
	end
	return id
end

local function renderTracker(state: any)
	for _, child in tracker:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local order = 0
	local function line(text: string, color: Color3)
		order += 1
		Ui.label(text, 14, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			TextStrokeTransparency = 0.5,
			Parent = tracker,
		})
	end
	local today = day()
	for _, giver in Q.givers do
		local quest = state.quests[giver.id]
		local def = quest and Q.pool[quest.q]
		if quest and def and quest.day == today and not quest.claimed then
			if quest.progress >= def.n then
				line(`✓ {def.text}: back to {giver.name}`, C.safe)
			else
				line(`{def.text}  {amount(def, quest.progress)}/{amount(def, def.n)}`, C.cream)
			end
		end
	end
	-- The cheapest permit still locked, so there is always a next goal.
	for _, d in Config.Districts do
		local gate = Config.Gates[d.id]
		if gate and not Quests.permitted(state.stats, d.id) then
			local have = math.min(state.stats[gate.stat] or 0, gate.need)
			local shown = if gate.stat == "earned"
				then `{Ui.money(have)}/{Ui.money(gate.need)}`
				else `{have}/{gate.need}`
			line(`{d.name} permit: {gate.text} {shown}`, C.accent)
			break
		end
	end
end

local function renderDialog(state: any)
	local index = talking
	local giver = index and Q.givers[index]
	if not index or not giver then
		dialog.Visible = false
		return
	end
	dName.Text = giver.name
	dLine.Text = `"{giver.line}"`
	local today = day()
	local quest = state.quests[giver.id]
	local active = quest and quest.day == today
	local def = Q.pool[if active then quest.q else Quests.offer(index, today)]
	local reward = Ui.money(def.reward)
	dButton.Visible = true
	if not active then
		dQuest.Text = `{def.text}\nReward: {reward}`
		dButton.Text = "Accept"
		Ui.setEnabled(dButton, true)
	elseif quest.claimed then
		dQuest.Text = "That's all for today. Come back tomorrow."
		dButton.Visible = false
	elseif quest.progress >= def.n then
		dQuest.Text = `{def.text}\nDone! Reward: {reward}`
		dButton.Text = `Claim {reward}`
		Ui.setEnabled(dButton, true)
	else
		dQuest.Text =
			`{def.text}\n{amount(def, quest.progress)}/{amount(def, def.n)} · Reward: {reward}`
		dButton.Text = "In progress"
		Ui.setEnabled(dButton, false)
	end
	if def.kind == "district" then
		dQuest.Text ..= `\n({districtName(def.district)})`
	end
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Quests",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	tracker = Ui.new("Frame", {
		Name = "Tracker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 110),
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, { Ui.list(Enum.FillDirection.Vertical, 2) })

	dialog = Ui.panel({
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.9, 0, 0, 200),
		Visible = false,
		Parent = gui,
	})
	dialog.BackgroundTransparency = 0.06
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }).Parent = dialog
	dName = Ui.label("", 20, {
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(1, -36, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dialog,
	})
	dLine = Ui.label("", 14, {
		Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(1, -36, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.BODY,
		Parent = dialog,
	})
	dQuest = Ui.label("", 17, {
		Position = UDim2.fromOffset(18, 66),
		Size = UDim2.new(1, -36, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = dialog,
	})
	dButton = Ui.button("Accept", "primary", UDim2.fromOffset(170, 48), function()
		local index = talking
		local state = Store.get()
		if not index or not state then
			return
		end
		local giver = Q.givers[index]
		local quest = state.quests[giver.id]
		local action = if quest and quest.day == day() then "questClaim" else "questAccept"
		Store.action(action, index)
	end)
	dButton.AnchorPoint = Vector2.new(0, 1)
	dButton.Position = UDim2.new(0, 18, 1, -14)
	dButton.Parent = dialog
	local close = Ui.button("Close", "secondary", UDim2.fromOffset(96, 48), function()
		talking = nil
		dialog.Visible = false
	end)
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.new(1, -18, 1, -14)
	close.Parent = dialog
end

function QuestUi.init()
	build()
	Ui.autoScale(gui)
end

function QuestUi.start()
	Store.on("state", function(state)
		renderTracker(state)
		if talking then
			renderDialog(state)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= "QuestPrompt" then
			return
		end
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		local index = model and tonumber(model:GetAttribute("Giver"))
		local state = Store.get()
		if index and Q.givers[index] and state then
			talking = index
			dialog.Visible = true
			Ui.pop(dialog, 0.94)
			renderDialog(state)
		end
	end)
	-- Walking away ends the conversation.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local index = talking
			if index then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root or (root.Position - Q.givers[index].pos).Magnitude > Q.RANGE + 8 then
					talking = nil
					dialog.Visible = false
				end
			end
		end
	end)
	local state = Store.get()
	if state then
		renderTracker(state)
	end
end

return QuestUi
