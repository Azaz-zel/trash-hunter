--!strict
-- Odds window: the chance of each rarity per bag, without luck, with the
-- Lucky Charm pass, during a Lucky Hour, and with both. Roblox requires
-- published odds for anything paid that changes random rewards, so this
-- opens from the Robux shop's luck items and from the bag picker.
-- Numbers come from the same shared Loot module the server rolls with.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Loot = require(Shared:WaitForChild("Loot"))
local Ui = require(script.Parent.Parent.Ui)
local Store = require(script.Parent.Parent.Store)

local C = Ui.COLORS
local player = Players.LocalPlayer
local LUCK = Config.Robux.LUCK

local OddsUi = {}

local gui: ScreenGui
local window: Frame

local function pct(x: number): string
	local p = x * 100
	if p >= 1 then
		return string.format("%.1f%%", p)
	elseif p >= 0.01 then
		return string.format("%.2f%%", p)
	end
	return string.format("%.4f%%", p)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Odds",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 12,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.03
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(560, 700) }).Parent = window
	Ui.padding(14).Parent = window
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = window
	Ui.label("🎲 Drop odds per bag", 20, {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = window,
	})
	local columns = {
		{ "Normal", 0 },
		{ "Lucky Charm", LUCK.CHARM_BOOST },
		{ "Lucky Hour", LUCK.HOUR_BOOST },
		{ "Both", LUCK.CHARM_BOOST + LUCK.HOUR_BOOST },
	}
	local function row(order: number, cells: { string }, color: Color3?, bold: boolean?)
		local r = Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = window,
		})
		for i, text in cells do
			Ui.label(text, 13, {
				Position = UDim2.new(if i == 1 then 0 else 0.28 + (i - 2) * 0.18, 0, 0, 0),
				Size = UDim2.new(if i == 1 then 0.28 else 0.18, 0, 1, 0),
				TextXAlignment = if i == 1
					then Enum.TextXAlignment.Left
					else Enum.TextXAlignment.Right,
				TextColor3 = if i == 1 and color then color else C.cream,
				Font = if bold then Ui.FONT else Ui.BODY,
				Parent = r,
			})
		end
	end
	local header = { "Rarity" }
	for _, col in columns do
		table.insert(header, col[1])
	end
	row(1, header, C.muted, true)
	local odds = {}
	for k, col in columns do
		odds[k] = Loot.odds(col[2])
	end
	for i, rarity in Items.Rarities do
		local cells = { rarity.name }
		for k in columns do
			table.insert(cells, pct(odds[k][i]))
		end
		row(1 + i, cells, rarity.color)
	end
	local featured = Items.ById[(Loot.featured())]
	Ui.label(
		"Odds shown for a regular dumpster. Richer districts, the guarded yard, digging deeper, heavy bins, "
			.. "fresh drops, combos, Perfect Digs and crewmates all raise them (all bonuses together are capped). "
			.. "You see 3 bags per search (4 with the Crowbar or a Perfect Dig) and pick one. "
			.. "Bag Reroll replaces the bags with a new roll at the same odds. Each item is equally likely within its rarity, "
			.. `except this week's featured item ({if featured then featured.name else "-"}), which is 3x as likely. `
			.. "Mutations: "
			.. (function()
				local parts = {}
				for _, m in Items.Mutations do
					table.insert(parts, `{m.name} {pct(m.chance)}`)
				end
				return table.concat(parts, ", ")
			end)()
			.. ".",
		12,
		{
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 20,
			Parent = window,
		}
	)
	local close = Ui.button("Close", "secondary", UDim2.new(1, 0, 0, 52), function()
		window.Visible = false
	end)
	close.LayoutOrder = 21
	close.Parent = window
end

function OddsUi.init()
	build()
	Ui.autoScale(gui)
end

function OddsUi.start()
	Store.on("openOdds", function()
		window.Visible = true
		Ui.pop(window, 0.92)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			window.Visible = false
		end
	end)
end

return OddsUi
