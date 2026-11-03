--!strict
-- Gear bench (tools for cash), car dealer (cars for cash) and Robux
-- convenience items. Robux never buys loot or odds: game passes give
-- comfort (pockets, a ride home), products give cash. Receipts are
-- idempotent and saved before they are granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Router = require(script.Parent.Parent.Router)
local Data = require(script.Parent.Data)
local Guard = require(script.Parent.Guard)
local Avatar = require(script.Parent.Avatar)

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
	local ok, message = Guard.atStore(player, "gear")
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

local function buyCar(player: Player, id: any): (boolean, string?)
	local profile = Data.get(player)
	local car = carSpec(id)
	if not profile or not car then
		return false, nil
	end
	local ok, message = Guard.atStore(player, "cars")
	if not ok then
		return false, message
	end
	if not profile.ownedCars[car.id] then
		if profile.cash < car.price then
			return false, `You need ${car.price - profile.cash} more.`
		end
		profile.cash -= car.price
		profile.ownedCars[car.id] = true
		Router.send(player, "bought", { name = car.name })
	end
	-- A smaller car may not fit what is already in the trunk.
	local capacity = car.trunk
	if #profile.trunk > capacity then
		return false, "Empty your trunk first; that car is smaller."
	end
	profile.car = car.id
	Data.push(player)
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
			local ok, owns = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				pass.id
			)
			if ok and owns then
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
	profile.cash += product.cash
	table.insert(profile.receipts, id)
	while #profile.receipts > RECEIPT_MEMORY do
		table.remove(profile.receipts, 1)
	end
	-- Only confirm once the grant is on disk; otherwise Roblox retries later.
	if not Data.saveNow(player) then
		profile.cash -= product.cash
		table.remove(profile.receipts, table.find(profile.receipts, id) :: number)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.push(player)
	Router.send(player, "bought", { name = product.name })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init()
	Router.on("buyTool", 0.5, buyTool)
	Router.on("buyCar", 0.5, buyCar)
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
			Data.push(player)
		end
	end)
	Data.onLoaded(function(player)
		refreshPasses(player)
		Data.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHome[player] = nil
	end)
end

return Shop
