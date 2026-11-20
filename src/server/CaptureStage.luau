-- CaptureStage: stages screenshot scenes on the live server for TOUR.json reviewers.
-- Nothing calls these unprompted, so normal play is untouched. Each public function
-- takes the tour's arg (a Player, or "me"/nil for the first player online) and prints
-- a line naming the stage.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local PlayerSessions = require(script.Parent.PlayerSessions)
local CharacterFactory = require(script.Parent.CharacterFactory)
local Carry = require(script.Parent.Carry)
local Conveyor = require(script.Parent.Conveyor)
local Rebirth = require(script.Parent.Rebirth)
local StealLock = require(script.Parent.StealLock)
local Tsunami = require(script.Parent.Tsunami)
local RaccoonThieves = require(script.Parent.RaccoonThieves)
local IndexBook = require(script.Parent.IndexBook)

local CaptureStage = {}

local function resolvePlayer(arg): Player?
	if typeof(arg) == "Instance" and arg:IsA("Player") then
		return arg
	end
	return Players:GetPlayers()[1]
end

local function ensureBooth(player: Player)
	return PlayerSessions.GetBooth(player) or PlayerSessions.ClaimBooth(player)
end

local function buildStocked(recipe, mutation): Model
	local model = CharacterFactory.BuildCharacter(recipe, mutation)
	model:SetAttribute("CharacterId", HttpService:GenerateGUID(false))
	model:SetAttribute("Price", GameConfig.GetTier(recipe.tier).buyPrice)
	model:SetAttribute("Stolen", false)
	return model
end

-- Clear whatever is placed/carried so a stage always composes the same scene.
local function clearBoard(player: Player)
	if GameState.GetCarrying(player) then
		Carry.DropCarried(player, "stage")
	end
	for _, entry in ipairs(table.clone(GameState.GetPlaced(player))) do
		Economy.RemovePlaced(player, entry.CharacterId)
	end
end

-- The developed booth: $2.5M, 2 rebirths, six showcase characters earning on pads.
local function stageDevelopedBooth(player: Player)
	clearBoard(player)
	ensureBooth(player)
	Economy.AddCash(player, 2500000)
	while GameState.GetRebirths(player) < 2 do
		Rebirth.ApplyRebirth(player)
	end
	local stock = {
		{ GameConfig.CastByTier.Mythic[1], GameConfig.GetMutation("Void") },
		{ GameConfig.CastByTier.Legendary[1], GameConfig.GetMutation("Rainbow") },
		{ GameConfig.CastByTier.Epic[1], GameConfig.GetMutation("Diamond") },
		{ GameConfig.CastByTier.Rare[1], GameConfig.GetMutation("Golden") },
		{ GameConfig.CastByTier.Mythic[2], GameConfig.GetMutation("Glitch") },
		{ GameConfig.CastByTier.Divine[1], nil },
	}
	for padIndex, pair in ipairs(stock) do
		local model = buildStocked(pair[1], pair[2])
		Economy.PlaceOnPad(player, model, padIndex) -- records the index find too
	end
end

-- COVER: developed booth + a Glitch Mythic in hand mid-plaza + the tsunami warning live.
function CaptureStage.StageCoverHeist(arg)
	local player = resolvePlayer(arg)
	if not player then
		print("[CaptureStage] CoverHeist: no player online")
		return
	end
	stageDevelopedBooth(player)

	local carryModel = buildStocked(GameConfig.CastByTier.Mythic[3], GameConfig.GetMutation("Glitch"))
	Carry.AttachCarried(player, carryModel)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(0, 3, 20)) -- mid-plaza; the human walks it home
	end
	Tsunami.StartTsunamiWarning()
	print("[CaptureStage] CoverHeist staged for " .. player.Name)
end

-- CONVEYOR: a fixed parade spaced along the belt.
function CaptureStage.StageConveyorLineup(arg)
	local player = resolvePlayer(arg)
	Conveyor.ClearBelt()
	local parade = {
		{ GameConfig.CastByTier.Common[1], false },
		{ GameConfig.CastByTier.Rare[1], GameConfig.GetMutation("Golden") },
		{ GameConfig.CastByTier.Epic[1], false },
		{ GameConfig.CastByTier.Legendary[1], GameConfig.GetMutation("Diamond") },
		{ GameConfig.CastByTier.Mythic[1], GameConfig.GetMutation("Rainbow") },
		{ GameConfig.CastByTier.Divine[1], false },
	}
	local offsets = { 20, 55, 90, 125, 160, 195 }
	for i, pair in ipairs(parade) do
		Conveyor.SpawnBrainrotOnBelt(pair[1], pair[2], offsets[i])
	end
	print("[CaptureStage] ConveyorLineup staged" .. (if player then " for " .. player.Name else ""))
end

-- THIEF RAID: the booth's shield is up for exactly 6 s (LOCKED frame), then it
-- drops and a raccoon slips in aimed at this booth.
function CaptureStage.StageThiefRaid(arg)
	local player = resolvePlayer(arg)
	if not player then
		print("[CaptureStage] ThiefRaid: no player online")
		return
	end
	local booth = ensureBooth(player)
	if not booth then
		print("[CaptureStage] ThiefRaid: no free booth")
		return
	end

	-- Something worth stealing.
	local hasStock = false
	for _, entry in GameState.GetPlaced(player) do
		if not entry.Inactive then
			hasStock = true
			break
		end
	end
	if not hasStock then
		Economy.AddCash(player, 5000)
		for padIndex, recipe in { GameConfig.CastByTier.Common[1], GameConfig.CastByTier.Uncommon[1], GameConfig.CastByTier.Rare[1] } do
			Economy.PlaceOnPad(player, buildStocked(recipe, nil), padIndex)
		end
	end

	-- Raise the shield, then shorten it to exactly 6 s; StealLock's own tick
	-- lowers the dome and flips the state when it expires.
	GameState.SetLock(player, false, 0, 0)
	StealLock.RequestLock(player)
	local now = os.clock()
	GameState.SetLock(player, true, now + 6, now + 6 + GameConfig.Economy.LockCooldown)

	task.delay(7, function()
		RaccoonThieves.SpawnRaccoonThief(booth)
	end)
	print("[CaptureStage] ThiefRaid staged for " .. player.Name)
end

-- INDEX + REBIRTH: exactly 19 index entries and cash $1,000 short of the rebirth price.
function CaptureStage.StageIndexAndRebirth(arg)
	local player = resolvePlayer(arg)
	if not player then
		print("[CaptureStage] IndexAndRebirth: no player online")
		return
	end
	ensureBooth(player)

	GameState.Get(player).Index = {}
	for i = 1, 19 do
		IndexBook.RecordIndexFind(player, GameConfig.Cast[i].name)
	end

	-- Give the rebirth price some weight behind it.
	if GameState.TotalIncomeRate(player) == 0 then
		clearBoard(player)
		Economy.AddCash(player, 5000)
		for padIndex, recipe in { GameConfig.CastByTier.Rare[1], GameConfig.CastByTier.Epic[1], GameConfig.CastByTier.Legendary[1] } do
			Economy.PlaceOnPad(player, buildStocked(recipe, nil), padIndex)
		end
	end

	local target = math.max(0, Rebirth.RebirthCost(player) - 1000)
	local current = GameState.GetCash(player)
	if target > current then
		Economy.AddCash(player, target - current)
	elseif current > target then
		Economy.SpendCash(player, current - target)
	end
	print("[CaptureStage] IndexAndRebirth staged for " .. player.Name)
end

-- Owner-only chat triggers for the staging functions above (screenshot capture). The whole hookup
-- sits in pcall: a chat-API failure must never break the module or the game.
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	local stages = {
		{ name = "StageCoverCommand", alias = "!cover", stage = CaptureStage.StageCoverHeist },
		{ name = "StageConveyorCommand", alias = "!conveyor", stage = CaptureStage.StageConveyorLineup },
		{ name = "StageRaidCommand", alias = "!raid", stage = CaptureStage.StageThiefRaid },
		{ name = "StageIndexCommand", alias = "!index", stage = CaptureStage.StageIndexAndRebirth },
	}
	local function runIfOwner(player, stage)
		if player and player.Name == "0xcing" then
			stage(player)
		end
	end
	for _, entry in stages do
		local command = Instance.new("TextChatCommand")
		command.Name = entry.name
		command.PrimaryAlias = entry.alias
		command.Parent = TextChatService
		command.Triggered:Connect(function(textSource)
			pcall(function()
				runIfOwner(Players:GetPlayerByUserId(textSource.UserId), entry.stage)
			end)
		end)
	end
	-- Legacy chat fallback: the trimmed message must exactly equal an alias.
	Players.PlayerChatted:Connect(function(player, message)
		pcall(function()
			local trimmed = message:match("^%s*(.-)%s*$")
			for _, entry in stages do
				if trimmed == entry.alias then
					runIfOwner(player, entry.stage)
					break
				end
			end
		end)
	end)
end)

return CaptureStage
