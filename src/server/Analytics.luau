--!strict
-- Thin wrapper over AnalyticsService so Creator Analytics shows where cash
-- comes from and goes, and what players do. Every call is protected: in
-- Studio or on a hiccup it does nothing rather than erroring.
--   Analytics.source(player, amount, balance, what)  cash earned
--   Analytics.sink(player, amount, balance, what)    cash spent
--   Analytics.event(player, name, value?)            a custom event

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local function economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	amount: number,
	balance: number,
	what: string,
	kind: Enum.AnalyticsEconomyTransactionType
)
	if amount <= 0 then
		return
	end
	pcall(
		AnalyticsService.LogEconomyEvent,
		AnalyticsService,
		player,
		flow,
		"Cash",
		amount,
		balance,
		kind.Name,
		what
	)
end

function Analytics.source(
	player: Player,
	amount: number,
	balance: number,
	what: string,
	iap: boolean?
)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		amount,
		balance,
		what,
		if iap
			then Enum.AnalyticsEconomyTransactionType.IAP
			else Enum.AnalyticsEconomyTransactionType.Gameplay
	)
end

function Analytics.sink(player: Player, amount: number, balance: number, what: string)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		amount,
		balance,
		what,
		Enum.AnalyticsEconomyTransactionType.Shop
	)
end

function Analytics.event(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

return Analytics
