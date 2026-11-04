--!strict
-- Story cutscenes and the chapter tracker (server: Systems/Story).
-- A scene: black letterbox bars slide in, the camera frames Big Sal, and the
-- boss's lines type out in a dialogue box; tap / click / Space to go on.
-- The tracker (bottom left) shows the current chapter goal and progress.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local S = Config.Story

local StoryUi = {}

local gui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local box: Frame
local speakerLabel: TextLabel
local titleLabel: TextLabel
local lineLabel: TextLabel
local tracker: TextButton
local advance: BindableEvent
local playing = false

local function giver(): Model?
	local town = workspace:FindFirstChild("Town")
	for _, m in if town then town:GetChildren() else {} do
		if m:IsA("Model") and m:GetAttribute("StoryGiver") then
			return m
		end
	end
	return nil
end

local function renderTracker()
	local state = Store.get()
	local story = state and state.story
	if not story then
		tracker.Visible = false
		return
	end
	local chapter = S.CHAPTERS[story.chapter]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	tracker.Visible = not (humanoid and humanoid.SeatPart) and not playing
	if not chapter then
		tracker.Text = "★ Story complete. Long live the Trash King!"
	elseif not story.started then
		tracker.Text = `★ Story: talk to {S.GIVER.name} outside the Hideout`
	elseif story.progress >= chapter.goal.n then
		tracker.Text = `★ {chapter.title}: done! Back to {S.GIVER.name}`
	else
		local p = if chapter.goal.kind == "earn"
			then Ui.money(story.progress)
			else tostring(story.progress)
		local n = if chapter.goal.kind == "earn"
			then Ui.money(chapter.goal.n)
			else tostring(chapter.goal.n)
		tracker.Text = `★ {chapter.title}: {chapter.goal.text} ({p}/{n})`
	end
end

local function typeOut(text: string)
	lineLabel.Text = text
	lineLabel.MaxVisibleGraphemes = 0
	for i = 1, #text do
		if lineLabel.MaxVisibleGraphemes == -1 then
			return -- skipped
		end
		lineLabel.MaxVisibleGraphemes = i
		task.wait(0.018)
	end
	lineLabel.MaxVisibleGraphemes = -1
end

local function play(scene: {
	speaker: string,
	title: string,
	lines: { string },
	goal: string?,
	reward: string?,
})
	if playing then
		return
	end
	playing = true
	renderTracker()
	local camera = workspace.CurrentCamera
	local saved = camera.CFrame
	local npc = giver()
	local head = npc and npc:FindFirstChild("Head") :: BasePart?
	if head then
		camera.CameraType = Enum.CameraType.Scriptable
		local eye = head.Position + head.CFrame.LookVector * 9 + Vector3.new(2.5, 1, 0)
		Ui.tween(camera, 0.8, { CFrame = CFrame.lookAt(eye, head.Position) }, Enum.EasingStyle.Sine)
	end
	topBar.Visible, bottomBar.Visible = true, true
	Ui.tween(topBar, 0.4, { Size = UDim2.new(1, 0, 0.12, 0) })
	Ui.tween(bottomBar, 0.4, { Size = UDim2.new(1, 0, 0.12, 0) })
	speakerLabel.Text = scene.speaker
	titleLabel.Text = scene.title
	box.Visible = true
	Ui.pop(box, 0.9)
	local lines = table.clone(scene.lines)
	if scene.goal then
		table.insert(lines, `Goal: {scene.goal}`)
	end
	if scene.reward then
		table.insert(lines, `Reward: {scene.reward}`)
	end
	for _, line in lines do
		task.spawn(typeOut, line)
		advance.Event:Wait()
		if lineLabel.MaxVisibleGraphemes ~= -1 then
			lineLabel.MaxVisibleGraphemes = -1 -- first tap finishes the line
			advance.Event:Wait()
		end
	end
	box.Visible = false
	Ui.tween(topBar, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
	Ui.tween(bottomBar, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
	task.wait(0.3)
	topBar.Visible, bottomBar.Visible = false, false
	camera.CFrame = saved
	camera.CameraType = Enum.CameraType.Custom
	playing = false
	renderTracker()
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Story",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Parent = player:WaitForChild("PlayerGui"),
	})
	advance = Instance.new("BindableEvent")
	topBar = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	bottomBar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	box = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.86, -8),
		Size = UDim2.new(0.9, 0, 0, 150),
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	})
	box.BackgroundTransparency = 0.05
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(680, 150) }).Parent = box
	speakerLabel = Ui.label("", 20, {
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(0.5, 0, 0, 24),
		Font = Ui.FONT,
		TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = box,
	})
	titleLabel = Ui.label("", 13, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 14),
		Size = UDim2.new(0.5, -18, 0, 18),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = box,
	})
	lineLabel = Ui.label("", 19, {
		Position = UDim2.fromOffset(18, 40),
		Size = UDim2.new(1, -36, 0, 72),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 2,
		Parent = box,
	})
	Ui.label("Tap to continue ▸", 12, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -8),
		Size = UDim2.fromOffset(160, 16),
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = box,
	})
	local catcher: TextButton = Ui.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = box,
	})
	catcher.Activated:Connect(function()
		advance:Fire()
	end)
	tracker = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -90),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = Color3.fromRGB(40, 32, 14),
		BackgroundTransparency = 0.15,
		Font = Ui.FONT,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 205, 110),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(10),
		Ui.stroke(1, C.accent),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	-- Tapping the tracker routes the GPS to Big Sal.
	tracker.Activated:Connect(function()
		Store.emit("routeTo", { pos = S.GIVER.pos, name = S.GIVER.name })
	end)
end

function StoryUi.init()
	build()
	Ui.autoScale(gui)
end

function StoryUi.start()
	Store.on("storyScene", function(scene)
		task.spawn(play, scene)
	end)
	Store.on("state", renderTracker)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			playing
			and not processed
			and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return)
		then
			advance:Fire()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			renderTracker()
		end
	end)
end

return StoryUi
