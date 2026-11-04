--!strict
-- Global leaderboards: richest (cash ever earned), biggest collection,
-- highest level and best search combo. Every REFRESH seconds each player in
-- the server is written to an OrderedDataStore and the top 10 of each board
-- is read back. Without DataStores (Studio without API access) the boards
-- rank the players in this server instead.
--
-- The tables are published as JSON in ReplicatedStorage.Leaderboards (the
-- Top panel reads them) and drawn on a big board beside the Hideout.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)

local REFRESH = 120
local TOP = 10

type Board = { id: string, title: string, value: (any) -> number, format: (number) -> string }

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local BOARDS: { Board } = {
	{
		id = "earned",
		title = "RICHEST",
		value = function(p)
			return p.stats.earned
		end,
		format = function(n)
			return "$" .. tostring(n)
		end,
	},
	{
		id = "collection",
		title = "COLLECTORS",
		value = function(p)
			return count(p.collection)
		end,
		format = function(n)
			return `{n} items`
		end,
	},
	{
		id = "xp",
		title = "TOP LEVEL",
		value = function(p)
			return p.xp
		end,
		format = function(n)
			return `{n} XP`
		end,
	},
	{
		id = "likes",
		title = "BEST HOUSE",
		value = function(p)
			return p.likes
		end,
		format = function(n)
			return `♥ {n}`
		end,
	},
	{
		id = "combo",
		title = "BEST COMBO",
		value = function(p)
			return p.bestCombo
		end,
		format = function(n)
			return `x{n}`
		end,
	},
}

local Leaderboards = {}

local stores: { [string]: OrderedDataStore } = {}
local names: { [number]: string } = {}
local folder: Folder
local boardLabels: { [string]: TextLabel } = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and typeof(name) == "string" then name else "Player"
	names[userId] = result
	return result
end

-- Top rows for one board: { { name, value } }.
local function read(board: Board): { { name: string, value: number } }
	local rows = {}
	local store = stores[board.id]
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
		if ok and pages then
			for _, entry in (pages :: DataStorePages):GetCurrentPage() do
				local userId = tonumber(string.match(entry.key, "%d+")) or 0
				table.insert(rows, { name = nameOf(userId), value = entry.value })
			end
			return rows
		end
	end
	-- Fallback: this server only.
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			table.insert(rows, { name = player.DisplayName, value = board.value(profile) })
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	while #rows > TOP do
		table.remove(rows)
	end
	return rows
end

local function publish(board: Board, rows: { { name: string, value: number } })
	local value = folder:FindFirstChild(board.id) :: StringValue?
	if not value then
		local v = Instance.new("StringValue")
		v.Name = board.id
		v:SetAttribute("Title", board.title)
		v.Parent = folder
		value = v
	end
	local shown = {}
	for i, row in rows do
		shown[i] = { name = row.name, value = board.format(row.value) }
	end
	(value :: StringValue).Value = HttpService:JSONEncode(shown)
	local label = boardLabels[board.id]
	if label then
		local lines = { `<b>{board.title}</b>` }
		for i, row in shown do
			table.insert(lines, `{i}. {row.name}  <font color="#FFC846">{row.value}</font>`)
		end
		label.Text = table.concat(lines, "\n")
	end
end

local function refresh()
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			for _, board in BOARDS do
				local store = stores[board.id]
				if store then
					pcall(
						store.SetAsync,
						store,
						"u_" .. player.UserId,
						math.floor(board.value(profile))
					)
				end
			end
		end
	end
	for _, board in BOARDS do
		publish(board, read(board))
	end
end

-- The board beside the Hideout: four columns on a dark panel.
local function buildBoard()
	local c = Config.World.HIDEOUT_CENTER
	local at = Vector3.new(c.X + 50, 0, c.Z - 22)
	local look = Vector3.new(c.X + 8, 0, c.Z - 52)
	local cf = CFrame.lookAt(at, Vector3.new(look.X, 0, look.Z))
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	local function part(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = material
		p.Parent = model
		return p
	end
	for _, x in { -11, 11 } do
		part(
			"Post",
			Vector3.new(0.8, 16, 0.8),
			CFrame.new(x, 8, 0.6),
			Color3.fromRGB(40, 42, 48),
			Enum.Material.Metal
		)
	end
	local panel = part(
		"Panel",
		Vector3.new(26, 11, 0.6),
		CFrame.new(0, 10.5, 0),
		Color3.fromRGB(18, 20, 26),
		Enum.Material.SmoothPlastic
	)
	part(
		"Trim",
		Vector3.new(26.4, 0.3, 0.7),
		CFrame.new(0, 16.1, 0),
		Color3.fromRGB(255, 190, 70),
		Enum.Material.Neon
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = gui
	for _, board in BOARDS do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.19, -8, 1, -20)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 22
		label.TextColor3 = Color3.fromRGB(240, 242, 246)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.RichText = true
		label.TextWrapped = true
		label.Text = `<b>{board.title}</b>\nLoading...`
		label.Parent = gui
		boardLabels[board.id] = label
	end
	gui.Parent = panel
	model.Parent = workspace:WaitForChild("Town")
end

function Leaderboards.start()
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = ReplicatedStorage
	for _, board in BOARDS do
		local ok, store =
			pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "LB_" .. board.id)
		if ok and Data.persistent then
			stores[board.id] = store
		end
	end
	buildBoard()
	task.spawn(function()
		task.wait(15)
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return Leaderboards
