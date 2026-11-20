-- Quests: 12 contracts, 3 active per player. Owning systems call ReportProgress;
-- completion pays through the injected Economy.AddCash handler, toasts the player,
-- and deals a replacement contract.

local Players = game:GetService("Players")
local GameState = require(script.Parent.GameState)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Remotes = require(script.Parent.Remotes)

local Quests = {}

-- goalType is what ReportProgress matches on; target is the progress needed.
Quests.Pool = {
	{ id = "rare_buy", text = "Buy a Rare or better character", goalType = "buy_rare", target = 1, reward = 300 },
	{ id = "mutated_buy", text = "Buy a mutated character", goalType = "buy_mutated", target = 1, reward = 400 },
	{ id = "place5", text = "Place 5 characters on your pads", goalType = "place", target = 5, reward = 500 },
	{ id = "steal1", text = "Steal a character from another booth", goalType = "steal", target = 1, reward = 600 },
	{ id = "tsunami_survive", text = "Reach shelter with cargo during a tsunami", goalType = "survive_tsunami", target = 1, reward = 800 },
	{ id = "whack1", text = "Whack a raccoon thief", goalType = "whack", target = 1, reward = 450 },
	{ id = "earn5k", text = "Earn $5,000 in total", goalType = "earn", target = 5000, reward = 1000 },
	{ id = "earn50k", text = "Earn $50,000 in total", goalType = "earn", target = 50000, reward = 5000 },
	{ id = "legendary_own", text = "Own a Legendary or better character", goalType = "own_legendary", target = 1, reward = 1500 },
	{ id = "rebirth1", text = "Complete a rebirth", goalType = "rebirth", target = 1, reward = 2000 },
	{ id = "glitch_catch", text = "Catch a Glitch or better mutation", goalType = "catch_glitch", target = 1, reward = 1200 },
	{ id = "fill_pads", text = "Fill all your pads with characters", goalType = "fill_pads", target = 1, reward = 700 },
}

local byId = {}
for _, quest in Quests.Pool do
	byId[quest.id] = quest
end

local payHandler: ((Player, number) -> ())? = nil

local function push(player: Player)
	Remotes.QuestUpdate:FireClient(player, Quests.ActiveQuests(player))
end

function Quests.SetPayHandler(handler: (Player, number) -> ())
	payHandler = handler
end

local function randomQuest(excluding: { string })
	local candidates = {}
	for _, quest in Quests.Pool do
		if not table.find(excluding, quest.id) then
			table.insert(candidates, quest)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

-- Deal 3 distinct contracts to the player.
function Quests.AssignQuests(player: Player)
	local quests = GameState.Get(player).Quests
	quests.Active = {}
	quests.Progress = {}
	for _ = 1, 3 do
		local quest = randomQuest(quests.Active)
		if quest then
			table.insert(quests.Active, quest.id)
		end
	end
	push(player)
end

function Quests.Init()
	Players.PlayerAdded:Connect(Quests.AssignQuests)
end

function Quests.ActiveQuests(player: Player)
	local result = {}
	for _, id in GameState.Get(player).Quests.Active do
		local quest = byId[id]
		if quest then
			table.insert(result, { Quest = quest, Progress = GameState.GetQuestProgress(player, id) })
		end
	end
	return result
end

function Quests.CompleteQuest(player: Player, quest)
	local quests = GameState.Get(player).Quests
	local slot = table.find(quests.Active, quest.id)
	if not slot then
		return
	end
	if payHandler then
		payHandler(player, quest.reward)
	end
	Remotes.Toast:FireClient(player, string.format("CONTRACT COMPLETE: %s  +$%d", quest.text, quest.reward))
	table.remove(quests.Active, slot)
	quests.Progress[quest.id] = nil
	local replacement = randomQuest(quests.Active)
	if replacement then
		table.insert(quests.Active, replacement.id)
	end
	PlayerSessions.RefreshAttributes(player)
	push(player)
end

-- Owning systems report progress here; amount semantics depend on goalType
-- (counts for actions, dollars for "earn").
function Quests.ReportProgress(player: Player, goalType: string, amount: number)
	local quests = GameState.Get(player).Quests
	for _, id in ipairs(table.clone(quests.Active)) do
		local quest = byId[id]
		if quest and quest.goalType == goalType then
			local progress = (quests.Progress[id] or 0) + amount
			quests.Progress[id] = progress
			if progress >= quest.target then
				Quests.CompleteQuest(player, quest)
			end
		end
	end
	push(player)
end

return Quests
