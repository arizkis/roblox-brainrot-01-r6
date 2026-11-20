-- Upgrades: 6 tracks x 4 levels. Cost of the next level = (current level + 1) x base.
-- Effects are read live from GameState by the owning systems:
--   swift  -> PlayerSessions/Carry walk speed (+2 per level)
--   greedy -> Economy income (+10% per level)
--   lucky  -> Conveyor mutation chance (+2% per level, best online)
--   soft   -> Carry carry speed (+8% per level)
--   locks  -> StealLock lock duration (+15 s per level)
--   polish -> Economy placed income (+5% per level)

local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local Upgrades = {}

Upgrades.Tracks = {
	{ id = "swift", name = "Swift Feet", desc = "+2 walk speed per level", base = 150, maxLevel = 4 },
	{ id = "greedy", name = "Greedy Gloves", desc = "+10% income per level", base = 400, maxLevel = 4 },
	{ id = "lucky", name = "Lucky Charm", desc = "+2% mutation chance per level", base = 600, maxLevel = 4 },
	{ id = "soft", name = "Soft Hands", desc = "+8% carry speed per level", base = 200, maxLevel = 4 },
	{ id = "locks", name = "Thick Locks", desc = "+15s lock duration per level", base = 350, maxLevel = 4 },
	{ id = "polish", name = "Pad Polish", desc = "+5% placed income per level", base = 500, maxLevel = 4 },
}

local byId = {}
for _, track in Upgrades.Tracks do
	byId[track.id] = track
end

function Upgrades.NextCost(player: Player, trackId: string): number?
	local track = byId[trackId]
	if not track then
		return nil
	end
	local level = GameState.GetUpgrade(player, trackId)
	if level >= track.maxLevel then
		return nil
	end
	return (level + 1) * track.base
end

function Upgrades.BuyUpgrade(player: Player, trackId: string): boolean
	local track = byId[trackId]
	if not track then
		return false
	end
	local level = GameState.GetUpgrade(player, trackId)
	if level >= track.maxLevel then
		Remotes.Notify:FireClient(player, track.name .. " is already maxed")
		return false
	end
	local cost = (level + 1) * track.base
	if not Economy.CanAfford(player, cost) then
		Remotes.Notify:FireClient(player, string.format("%s costs $%d", track.name, cost))
		return false
	end
	Economy.SpendCash(player, cost)
	GameState.SetUpgrade(player, trackId, level + 1)
	Remotes.Notify:FireClient(player, string.format("%s → level %d", track.name, level + 1))

	-- Swift Feet applies to the current character immediately.
	if trackId == "swift" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 + 2 * (level + 1)
		end
	end
	return true
end

-- Shop view for the client: one row per track with level and next cost.
function Upgrades.UpgradeState(player: Player)
	local rows = {}
	for _, track in Upgrades.Tracks do
		table.insert(rows, {
			Id = track.id,
			Name = track.name,
			Desc = track.desc,
			Level = GameState.GetUpgrade(player, track.id),
			MaxLevel = track.maxLevel,
			NextCost = Upgrades.NextCost(player, track.id),
		})
	end
	return rows
end

return Upgrades
