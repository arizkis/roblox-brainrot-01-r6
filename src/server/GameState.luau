-- GameState: the single home for per-player state. Every other module reads and writes
-- through these functions; no module keeps its own copy of player state.
--
-- State shape per player:
--   Cash: number                       spendable dollars
--   PadsOwned: number                  active pads (StartPads..MaxPads)
--   Placed: { PlacedCharacter }        characters on the player's pads
--     PlacedCharacter = { Recipe: string, Tier: string, Mutation: string?, IncomePerSec: number,
--                         BoothIndex: number, PadIndex: number, Model: Model?,
--                         Inactive: boolean?, Dropped: boolean? }  -- Inactive: raccoon-stolen, not earning
--   Rebirths: number
--   Multiplier: number                 rebirth income multiplier (1.5 ^ Rebirths)
--   TotalEarned: number                lifetime cash earned (quests track this)
--   Lock: { Active: boolean, Until: number, CooldownUntil: number }   booth lock, os.clock() times
--   Carrying: CarriedEntry?            the character being carried, nil when empty-handed
--     CarriedEntry = { CharacterId: string, Model: Model, Recipe: string, Tier: string,
--                      Mutation: string?, IncomePerSec: number, Price: number, Stolen: boolean }
--   Index: { [recipeName]: { Found: boolean, Mutation: string? } }    collection index finds
--   Quests: { Active: { string }, Progress: { [questId]: number } }  3 active contracts + counters
--   Upgrades: { [upgradeId]: number }  upgrade levels

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local GameState = {}

local states: { [Player]: any } = {}

local function newState()
	return {
		Cash = GameConfig.Economy.StartCash,
		PadsOwned = GameConfig.Economy.StartPads,
		Placed = {},
		Rebirths = 0,
		Multiplier = 1,
		TotalEarned = 0,
		Lock = { Active = false, Until = 0, CooldownUntil = 0 },
		Carrying = nil,
		Index = {},
		Quests = { Active = {}, Progress = {} },
		Upgrades = {},
	}
end

-- Get (creating on first touch) the state table for a player.
function GameState.Get(player: Player)
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

function GameState.Remove(player: Player)
	states[player] = nil
end

-- Cash
function GameState.GetCash(player: Player): number
	return GameState.Get(player).Cash
end

function GameState.SetCash(player: Player, amount: number)
	GameState.Get(player).Cash = math.max(0, amount)
end

function GameState.AddCash(player: Player, amount: number)
	local state = GameState.Get(player)
	state.Cash = math.max(0, state.Cash + amount)
	if amount > 0 then
		state.TotalEarned += amount
	end
end

function GameState.GetTotalEarned(player: Player): number
	return GameState.Get(player).TotalEarned
end

-- Pads
function GameState.GetPadsOwned(player: Player): number
	return GameState.Get(player).PadsOwned
end

function GameState.SetPadsOwned(player: Player, count: number)
	GameState.Get(player).PadsOwned = math.clamp(count, GameConfig.Economy.StartPads, GameConfig.Economy.MaxPads)
end

-- Placed characters
function GameState.GetPlaced(player: Player)
	return GameState.Get(player).Placed
end

function GameState.PlaceCharacter(player: Player, entry)
	table.insert(GameState.Get(player).Placed, entry)
end

function GameState.RemoveCharacter(player: Player, boothIndex: number, padIndex: number)
	local placed = GameState.Get(player).Placed
	for i = #placed, 1, -1 do
		local entry = placed[i]
		if entry.BoothIndex == boothIndex and entry.PadIndex == padIndex then
			table.remove(placed, i)
			return entry
		end
	end
	return nil
end

-- Total income rate before rebirth multiplier; the rebirth cost is based on this.
-- Raccoon-stolen (Inactive) characters do not earn.
function GameState.TotalIncomeRate(player: Player): number
	local total = 0
	for _, entry in GameState.Get(player).Placed do
		if not entry.Inactive then
			total += entry.IncomePerSec
		end
	end
	return total
end

-- Rebirths and multiplier
function GameState.GetRebirths(player: Player): number
	return GameState.Get(player).Rebirths
end

function GameState.GetMultiplier(player: Player): number
	return GameState.Get(player).Multiplier
end

-- Rebirth: +1 rebirth, multiplier 1.5^rebirths, +1 pad up to MaxPads.
-- Cash (already deducted by Rebirth) and placed characters are KEPT.
function GameState.DoRebirth(player: Player)
	local state = GameState.Get(player)
	state.Rebirths += 1
	state.Multiplier = GameConfig.Economy.RebirthIncomeMultiplier ^ state.Rebirths
	state.PadsOwned = math.min(GameConfig.Economy.MaxPads, state.PadsOwned + 1)
end

-- Booth lock
function GameState.GetLock(player: Player)
	return GameState.Get(player).Lock
end

function GameState.IsLocked(player: Player): boolean
	local lock = GameState.Get(player).Lock
	return lock.Active and os.clock() < lock.Until
end

function GameState.SetLock(player: Player, active: boolean, untilTime: number, cooldownUntil: number)
	local lock = GameState.Get(player).Lock
	lock.Active = active
	lock.Until = untilTime
	lock.CooldownUntil = cooldownUntil
end

-- Carrying
function GameState.GetCarrying(player: Player)
	return GameState.Get(player).Carrying
end

function GameState.SetCarrying(player: Player, entry)
	GameState.Get(player).Carrying = entry
end

-- Collection index
function GameState.RecordFind(player: Player, recipeName: string, mutationName: string?)
	local index = GameState.Get(player).Index
	local entry = index[recipeName]
	if not entry then
		entry = { Found = true, Mutation = mutationName }
		index[recipeName] = entry
	else
		entry.Found = true
		if mutationName then
			entry.Mutation = mutationName
		end
	end
end

function GameState.GetIndex(player: Player)
	return GameState.Get(player).Index
end

-- Quests
function GameState.GetQuestProgress(player: Player, questId: string): number
	return GameState.Get(player).Quests.Progress[questId] or 0
end

function GameState.SetQuestProgress(player: Player, questId: string, value: number)
	GameState.Get(player).Quests.Progress[questId] = value
end

-- Upgrades
function GameState.GetUpgrade(player: Player, upgradeId: string): number
	return GameState.Get(player).Upgrades[upgradeId] or 0
end

function GameState.SetUpgrade(player: Player, upgradeId: string, level: number)
	GameState.Get(player).Upgrades[upgradeId] = level
end

return GameState
