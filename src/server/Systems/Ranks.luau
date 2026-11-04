--!strict
-- Levels and titles. XP comes from searching (more for rarer finds), selling,
-- Perfect Digs, quests and missions (callers use Ranks.add). Each level-up
-- pays cash (twice with the Season Pass). The level and title float over the
-- player's head, with a VIP tag for pass owners, and show in the player list.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Router = require(script.Parent.Parent.Router)
local Analytics = require(script.Parent.Parent.Analytics)
local Data = require(script.Parent.Data)

local Ranks = {}

local function tag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local profile = Data.get(player)
	if not head or not profile then
		return
	end
	local gui = head:FindFirstChild("RankTag") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "RankTag"
		g.Size = UDim2.fromOffset(200, 22)
		g.StudsOffset = Vector3.new(0, 3.1, 0)
		g.MaxDistance = 80
		g.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.RichText = true
		label.Parent = g
		g.Parent = head
		gui = g
	end
	local level = Levels.fromXp(profile.xp)
	local vip = if player:GetAttribute("Pass_vip")
		then `<font color="#FFD24A">[VIP]</font> `
		else ""
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = `{vip}Lv {level} · {Levels.title(level)}`
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
end

local function publish(player: Player, level: number)
	player:SetAttribute("Level", level)
	player:SetAttribute("Title", Levels.title(level))
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Level")
	if value and value:IsA("IntValue") then
		value.Value = level
	end
	tag(player)
end

-- Adds XP; pays and announces every level crossed.
function Ranks.add(player: Player, xp: number)
	local profile = Data.get(player)
	if not profile or xp <= 0 then
		return
	end
	local before = Levels.fromXp(profile.xp)
	profile.xp += math.floor(xp + 0.5)
	local after = Levels.fromXp(profile.xp)
	if after > before then
		local premium = player:GetAttribute("Pass_season") == true
		local cash = 0
		for level = before + 1, after do
			cash += Levels.reward(level, premium)
		end
		profile.cash += cash
		Analytics.source(player, cash, profile.cash, "LevelUp")
		Analytics.event(player, "LevelUp", after)
		publish(player, after)
		Router.send(player, "levelUp", {
			level = after,
			title = Levels.title(after),
			cash = cash,
			newTitle = Levels.title(after) ~= Levels.title(before),
		})
		Data.push(player)
	end
end

-- XP for a find of this rarity.
function Ranks.searchXp(rarity: number): number
	local list = Config.Levels.SEARCH_XP
	return list[math.clamp(rarity, 1, #list)]
end

Ranks.refreshTag = tag

function Ranks.start()
	Data.onLoaded(function(player, profile)
		publish(player, (Levels.fromXp(profile.xp)))
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			tag(player)
		end)
		if player.Character then
			task.defer(tag, player)
		end
		player:GetAttributeChangedSignal("Pass_vip"):Connect(function()
			tag(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Ranks
