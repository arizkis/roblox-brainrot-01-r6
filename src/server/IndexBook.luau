-- IndexBook: the 36-character collection index. First ownership (buy or steal-delivery)
-- marks the entry found, refreshes the IndexFound attribute and toasts the player.

local GameState = require(script.Parent.GameState)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Remotes = require(script.Parent.Remotes)

local IndexBook = {}

local CAST_SIZE = 36

-- Returns true when this was a new entry.
function IndexBook.RecordIndexFind(player: Player, characterName: string): boolean
	local existing = GameState.GetIndex(player)[characterName]
	if existing and existing.Found then
		return false
	end
	GameState.RecordFind(player, characterName)
	PlayerSessions.RefreshAttributes(player)
	local found = 0
	for _, entry in GameState.GetIndex(player) do
		if entry.Found then
			found += 1
		end
	end
	Remotes.Toast:FireClient(player, string.format("INDEX: new entry %s (%d/%d)", characterName, found, CAST_SIZE))
	return true
end

-- Found recipe names, for the client book UI.
function IndexBook.FoundSet(player: Player): { string }
	local names = {}
	for name, entry in GameState.GetIndex(player) do
		if entry.Found then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

return IndexBook
