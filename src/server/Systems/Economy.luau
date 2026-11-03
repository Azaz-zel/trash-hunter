--!strict
-- Hideout actions: sell, put on / take off the display shelf, buy the
-- backpack upgrade. All of them require standing inside the Hideout.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Avatar = require(script.Parent.Avatar)

local stations: { Model } = {}
local assigned: { [Player]: Model } = {}

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

local function renderShelf(player: Player)
	local station = assigned[player]
	local profile = Data.get(player)
	if not station then
		return
	end
	local board = station:FindFirstChild("Board") :: BasePart
	for _, child in board:GetChildren() do
		if child.Name == "Display" then
			child:Destroy()
		end
	end
	local back = station:FindFirstChild("Back") :: BasePart
	local tag = back:FindFirstChild("OwnerTag") :: BillboardGui
	tag.Enabled = true;
	(tag:FindFirstChild("Label") :: TextLabel).Text = player.DisplayName .. "'s Shelf"
	if not profile then
		return
	end
	for i, entry in profile.shelf do
		local slot = board:FindFirstChild("Slot" .. i) :: Attachment?
		local item = Items.ById[entry.id]
		if not slot or not item then
			continue
		end
		local rarity = Items.Rarities[item.rarity]
		local display = Instance.new("Part")
		display.Name = "Display"
		display.Anchored = true
		display.CanCollide = false
		display.Size = Vector3.new(1.4, 1.4, 1.4)
		display.Material = if entry.mutation == "golden"
			then Enum.Material.Foil
			else Enum.Material.Neon
		display.Color = if entry.mutation == "golden"
			then Color3.fromRGB(255, 216, 0)
			else rarity.color
		display.CFrame = CFrame.new(slot.WorldPosition)
			* CFrame.Angles(0, math.rad(45), math.rad(20))
		local tagGui = Instance.new("BillboardGui")
		tagGui.Size = UDim2.fromOffset(160, 44)
		tagGui.StudsOffset = Vector3.new(0, 3.4, 0) -- clears the shelf back board
		tagGui.MaxDistance = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = rarity.color
		label.TextStrokeTransparency = 0.2
		label.Text = Items.label(entry.id, entry.mutation)
		label.Parent = tagGui
		tagGui.Parent = display
		display.Parent = board
	end
end

local function clearShelf(station: Model)
	local board = station:FindFirstChild("Board") :: BasePart
	for _, child in board:GetChildren() do
		if child.Name == "Display" then
			child:Destroy()
		end
	end
	local back = station:FindFirstChild("Back") :: BasePart;
	(back:FindFirstChild("OwnerTag") :: BillboardGui).Enabled = false
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
	profile.cash += earned
	Data.advanceTutorial(profile, 1, player)
	Data.push(player)
	Router.send(player, "sold", { amount = earned, count = count })
	return true, nil
end

local function display(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local ok, message = atHideout(player)
	if not ok then
		return false, message
	end
	if #profile.shelf >= Config.SHELF_SLOTS then
		return false, "Your shelf is full."
	end
	local entry = Data.removeItem(profile.backpack, uid)
	if not entry then
		return false, "That item is gone."
	end
	table.insert(profile.shelf, entry)
	renderShelf(player)
	Data.push(player)
	return true, nil
end

local function undisplay(player: Player, uid: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile then
		return false, nil
	end
	local ok, message = atHideout(player)
	if not ok then
		return false, message
	end
	if #profile.backpack >= Data.capacity(profile, player) then
		return false, "Backpack full."
	end
	local entry = Data.removeItem(profile.shelf, uid)
	if not entry then
		return false, "That item is gone."
	end
	table.insert(profile.backpack, entry)
	renderShelf(player)
	Data.push(player)
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
	Router.on("display", 0.2, display)
	Router.on("undisplay", 0.2, undisplay)
	Router.on("buyUpgrade", 0.5, buyUpgrade)

	-- Registered in init so no player can finish loading before this exists.
	Data.onLoaded(function(player)
		if #stations == 0 then
			local folder =
				workspace:WaitForChild("Town"):WaitForChild("Hideout"):WaitForChild("Shelves")
			for i = 1, #folder:GetChildren() do
				local station = folder:FindFirstChild("Shelf" .. i)
				if station and station:IsA("Model") then
					table.insert(stations, station)
				end
			end
		end
		for _, station in stations do
			local taken = false
			for _, owned in assigned do
				if owned == station then
					taken = true
					break
				end
			end
			if not taken then
				assigned[player] = station
				break
			end
		end
		renderShelf(player)
	end)
end

function Economy.start()
	Players.PlayerRemoving:Connect(function(player)
		local station = assigned[player]
		assigned[player] = nil
		if station then
			clearShelf(station)
		end
	end)
end

return Economy
