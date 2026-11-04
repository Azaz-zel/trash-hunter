--!strict
-- Gear bench (tools for cash), car dealer (cars for cash), the garage
-- (switch owned cars anywhere, custom paint), house furniture, player
-- settings, and Robux items: comfort, looks, sell bonuses, cash, skipping a
-- wait, and luck (Lucky Charm, Lucky Hour, Bag Reroll).
-- Receipts are idempotent and saved before they are granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Router = require(script.Parent.Parent.Router)
local Analytics = require(script.Parent.Parent.Analytics)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Avatar = require(script.Parent.Avatar)
local Search = require(script.Parent.Search)
local Wanted = require(script.Parent.Wanted)
local Ranks = require(script.Parent.Ranks)
local Housing = require(script.Parent.Housing)

local R = Config.Robux
local HOME_COOLDOWN = 60
local RECEIPT_MEMORY = 50

local lastHome: { [Player]: number } = {}

local Shop = {}

local function buyTool(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local tool = typeof(id) == "string" and Config.Tools[id]
	if not profile or not tool then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "gear", tool.city or "maple")
	if not ok then
		return false, message
	end
	if profile.tools[id] then
		return false, "You already have that."
	end
	if profile.cash < tool.price then
		return false, `You need ${tool.price - profile.cash} more.`
	end
	profile.cash -= tool.price
	Analytics.sink(player, tool.price, profile.cash, tool.name)
	profile.tools[id] = true
	Avatar.refresh(player)
	Data.push(player)
	Router.send(player, "bought", { name = tool.name })
	return true, nil
end

local function carSpec(id: any)
	for _, car in Config.Cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

-- Pass cars belong to whoever owns the pass.
local function owns(player: Player, profile: any, car: any): boolean
	if car.pass then
		return player:GetAttribute("Pass_" .. car.pass) == true
	end
	return profile.ownedCars[car.id] == true
end

local function useCar(player: Player, profile: any, car: any): (boolean, string?)
	-- A smaller car may not fit what is already in the trunk.
	if #profile.trunk > car.trunk then
		return false, "Empty your trunk first; that car is smaller."
	end
	profile.car = car.id
	Data.push(player)
	return true, nil
end

local function buyCar(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local car = carSpec(id)
	if not profile or not car then
		return false, nil
	end
	if car.pass then
		if not owns(player, profile, car) then
			return false, `The {car.name} comes with its game pass (Robux shop).`
		end
		return useCar(player, profile, car)
	end
	-- Buying needs that city's dealer; switching to an owned car works at any.
	local ok, message = Guard.atStore(
		player,
		"cars",
		if profile.ownedCars[car.id] then nil else car.city or "maple"
	)
	if not ok then
		return false, message
	end
	if not profile.ownedCars[car.id] then
		if profile.cash < car.price then
			return false, `You need ${car.price - profile.cash} more.`
		end
		profile.cash -= car.price
		Analytics.sink(player, car.price, profile.cash, car.name)
		profile.ownedCars[car.id] = true
		Data.advanceTutorial(profile, 4, player)
		Router.send(player, "bought", { name = car.name })
	end
	return useCar(player, profile, car)
end

-- Garage: switch to any car you own, wherever you are (not while driving).
local function selectCar(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local car = carSpec(id)
	if not profile or not car then
		return false, nil
	end
	if not owns(player, profile, car) then
		return false, "You don't own that car."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		return false, "Get out of the car first."
	end
	return useCar(player, profile, car)
end

-- Custom Paint pass: any colour ("rrggbb") and underglow. Neon Runner
-- owners get underglow too.
local function setPaint(player: Player, payload: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile or typeof(payload) ~= "table" then
		return false, nil
	end
	local paintPass = player:GetAttribute("Pass_paint") == true
	if payload.paint ~= nil then
		if not paintPass then
			return false, "Custom paint needs the Custom Paint pass."
		end
		if payload.paint == false then
			profile.paint = nil
		elseif
			typeof(payload.paint) == "string" and string.match(payload.paint, "^%x%x%x%x%x%x$")
		then
			profile.paint = string.lower(payload.paint)
		else
			return false, nil
		end
	end
	if payload.underglow ~= nil then
		if not paintPass and not player:GetAttribute("Pass_neon") then
			return false, "Underglow needs the Custom Paint or Neon Runner pass."
		end
		profile.underglow = payload.underglow == true
	end
	Data.push(player)
	return true, "Respawn your car to see the new look."
end

-- House furniture, bought at Maple Realty.
local function buyDecor(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local decor = nil
	for _, d in Config.Decor do
		if d.id == id then
			decor = d
		end
	end
	if not profile or not decor then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "house", "maple")
	if not ok then
		return false, message
	end

	if profile.decor[decor.id] then
		return false, "You already have that."
	end
	if profile.cash < decor.price then
		return false, `You need ${decor.price - profile.cash} more.`
	end
	profile.cash -= decor.price
	Analytics.sink(player, decor.price, profile.cash, decor.name)
	profile.decor[decor.id] = true
	Data.push(player)
	Router.send(player, "bought", { name = decor.name })
	Housing.refresh(player)
	return true, nil
end

-- Player settings (volumes, minimap, graphics), kept with the save.
local function saveSettings(player: Player, payload: any): (boolean, string?)
	local profile = Data.get(player)
	if not profile or typeof(payload) ~= "table" then
		return false, nil
	end
	local s = profile.settings
	for _, key in { "music", "effects", "ambient" } do
		local v = payload[key]
		if typeof(v) == "number" and v == v then
			(s :: any)[key] = math.clamp(v, 0, 1)
		end
	end
	if typeof(payload.rotateMap) == "boolean" then
		s.rotateMap = payload.rotateMap
	end
	if typeof(payload.low) == "boolean" then
		s.low = payload.low
	end
	return true, nil
end

local function promptRobux(player: Player, key: any): (boolean, string?)
	if typeof(key) ~= "string" then
		return false, nil
	end
	local pass = R.Passes[key]
	local product = R.Products[key]
	local entry = pass or product
	if not entry then
		return false, nil
	end
	if entry.id == 0 then
		return false, "Coming soon."
	end
	if pass then
		if player:GetAttribute("Pass_" .. key) then
			return false, "You already own this."
		end
		MarketplaceService:PromptGamePassPurchase(player, entry.id)
	else
		MarketplaceService:PromptProductPurchase(player, entry.id)
	end
	return true, nil
end

local function homeRun(player: Player): (boolean, string?)
	if not player:GetAttribute("Pass_homerun") then
		return false, nil
	end
	if player:GetAttribute("Chased") then
		return false, "Not while you're being chased."
	end
	local now = os.clock()
	local wait = HOME_COOLDOWN - (now - (lastHome[player] or -math.huge))
	if wait > 0 then
		return false, `Home Run ready in {math.ceil(wait)}s.`
	end
	lastHome[player] = now
	Guard.teleport(player, Config.World.SPAWN + Vector3.new(0, 1, 0))
	return true, nil
end

local function passKeyForId(passId: number): string?
	for key, pass in R.Passes do
		if pass.id ~= 0 and pass.id == passId then
			return key
		end
	end
	return nil
end

local function refreshPasses(player: Player)
	for key, pass in R.Passes do
		if pass.id ~= 0 then
			local ok, ownsPass = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				pass.id
			)
			if ok and ownsPass then
				player:SetAttribute("Pass_" .. key, true)
			end
		end
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and Data.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(receipt.PurchaseId)
	if table.find(profile.receipts, id) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted earlier
	end
	local product = nil
	for _, p in R.Products do
		if p.id ~= 0 and p.id == receipt.ProductId then
			product = p
		end
	end
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local cash = product.cash or 0
	profile.cash += cash
	-- Saved grants (rolled back with the cash if the save fails).
	local luckBefore, rerollsBefore = profile.luckUntil, profile.rerolls
	if product == R.Products.luckyhour then
		profile.luckUntil = math.max(os.time(), profile.luckUntil) + R.LUCK.HOUR_SECONDS
	elseif product == R.Products.reroll then
		profile.rerolls += R.LUCK.REROLLS
	end
	table.insert(profile.receipts, id)
	while #profile.receipts > RECEIPT_MEMORY do
		table.remove(profile.receipts, 1)
	end
	-- Only confirm once the grant is on disk; otherwise Roblox retries later.
	if not Data.saveNow(player) then
		profile.cash -= cash
		profile.luckUntil, profile.rerolls = luckBefore, rerollsBefore
		table.remove(profile.receipts, table.find(profile.receipts, id) :: number)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- One-off effects (the receipt is saved, so they never run twice).
	if product == R.Products.lawyer then
		Wanted.pardon(player)
	elseif product == R.Products.refill then
		Search.refill(player)
	elseif product == R.Products.truckday then
		Search.freshDrop(player.DisplayName, false)
	end
	Data.push(player)
	Analytics.source(player, cash, profile.cash, product.name, true)
	Analytics.event(player, "Robux_" .. product.name)
	Router.send(player, "bought", { name = product.name })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init()
	Router.on("buyTool", 0.5, buyTool)
	Router.on("buyCar", 0.5, buyCar)
	Router.on("selectCar", 0.5, selectCar)
	Router.on("setPaint", 0.3, setPaint)
	Router.on("buyDecor", 0.5, buyDecor)
	Router.on("saveSettings", 1, saveSettings)
	Router.on("robux", 1, promptRobux)
	Router.on("homeRun", 1, homeRun)
	MarketplaceService.ProcessReceipt = processReceipt
end

function Shop.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyForId(passId)
		if purchased and key then
			player:SetAttribute("Pass_" .. key, true)
			Avatar.refresh(player)
			Ranks.refreshTag(player)
			Data.push(player)
		end
	end)
	Data.onLoaded(function(player, profile)
		refreshPasses(player)
		-- Players who finished the old tutorial skip the steps they did.
		if profile.tutorial == 4 and next(profile.ownedCars) ~= nil then
			Data.advanceTutorial(profile, 4, player)
		end
		if profile.tutorial == 5 and #profile.home > 0 then
			Data.advanceTutorial(profile, 5, player)
		end
		Data.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHome[player] = nil
	end)
end

return Shop
