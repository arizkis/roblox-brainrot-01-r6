-- Economy: all money flow. Every cash change goes through GameState; attributes are
-- refreshed through PlayerSessions so the client HUD stays in sync. TickIncome runs the
-- 1-second income loop and fires the floating "+$" popup event at each earning pad.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Remotes = require(script.Parent.Remotes)
local EventDirector = require(script.Parent.EventDirector)
local Quests = require(script.Parent.Quests)
local IndexBook = require(script.Parent.IndexBook)

local Economy = {}

local booths = nil -- world booths, set by Init

function Economy.Init(world)
	booths = world.Booths
end

function Economy.CanAfford(player: Player, price: number): boolean
	return GameState.GetCash(player) >= price
end

-- Returns true when the spend happened, false when refused.
function Economy.SpendCash(player: Player, price: number): boolean
	if not Economy.CanAfford(player, price) then
		return false
	end
	GameState.SetCash(player, GameState.GetCash(player) - price)
	PlayerSessions.RefreshAttributes(player)
	return true
end

function Economy.AddCash(player: Player, amount: number)
	GameState.AddCash(player, amount)
	PlayerSessions.RefreshAttributes(player)
	if amount > 0 then
		Quests.ReportProgress(player, "earn", amount)
	end
end

-- Record a carried character on the player's pad and start its income.
-- Returns true on success, false when the pad is invalid or occupied.
function Economy.PlaceOnPad(player: Player, characterModel: Model, padIndex: number): boolean
	local booth = PlayerSessions.GetBooth(player)
	if not booth or padIndex < 1 or padIndex > GameState.GetPadsOwned(player) then
		return false
	end
	for _, entry in GameState.GetPlaced(player) do
		if entry.BoothIndex == booth.Index and entry.PadIndex == padIndex then
			return false
		end
	end

	local entry = {
		CharacterId = characterModel:GetAttribute("CharacterId") or HttpService:GenerateGUID(false),
		Model = characterModel,
		Recipe = characterModel:GetAttribute("Recipe"),
		Tier = characterModel:GetAttribute("Tier"),
		Mutation = characterModel:GetAttribute("Mutation"),
		IncomePerSec = characterModel:GetAttribute("IncomePerSec"),
		BoothIndex = booth.Index,
		PadIndex = padIndex,
	}
	characterModel.Parent = booth.Root.Parent
	characterModel:PivotTo(booth.Pads[padIndex])
	GameState.PlaceCharacter(player, entry)
	PlayerSessions.RefreshAttributes(player)

	IndexBook.RecordIndexFind(player, entry.Recipe)
	Quests.ReportProgress(player, "place", 1)
	local tier = GameConfig.GetTier(entry.Tier)
	if tier and tier.index >= 5 then
		Quests.ReportProgress(player, "own_legendary", 1)
	end
	if #GameState.GetPlaced(player) >= GameState.GetPadsOwned(player) then
		Quests.ReportProgress(player, "fill_pads", 1)
	end
	return true
end

-- Remove a placed character by id (sell, tsunami, steal). Returns the removed entry or nil.
function Economy.RemovePlaced(player: Player, characterId: string)
	local placed = GameState.GetPlaced(player)
	for i, entry in ipairs(placed) do
		if entry.CharacterId == characterId then
			table.remove(placed, i)
			if entry.Model then
				entry.Model:Destroy()
			end
			PlayerSessions.RefreshAttributes(player)
			return entry
		end
	end
	return nil
end

-- One income tick: every placed character pays its owner
-- income x rebirth multiplier x event multiplier x Greedy Gloves x Pad Polish.
-- Raccoon-stolen (Inactive) characters do not earn.
function Economy.TickIncome()
	for _, player in Players:GetPlayers() do
		local state = GameState.Get(player)
		local greedy = 1 + 0.10 * GameState.GetUpgrade(player, "greedy")
		local polish = 1 + 0.05 * GameState.GetUpgrade(player, "polish")
		local total = 0
		for _, entry in state.Placed do
			if not entry.Inactive then
				local gain = entry.IncomePerSec * state.Multiplier * EventDirector.IncomeMultiplier() * greedy * polish
				total += gain
				local booth = booths[entry.BoothIndex]
				if booth then
					Remotes.CashPopup:FireAllClients(booth.Pads[entry.PadIndex].Position, gain)
				end
			end
		end
		if total > 0 then
			Economy.AddCash(player, total)
		end
	end
end

function Economy.StartIncomeLoop()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Economy.IncomeTick)
			Economy.TickIncome()
		end
	end)
end

return Economy
