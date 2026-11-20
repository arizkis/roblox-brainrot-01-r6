-- Rebirth: cost = 15 x current total income rate (minimum $500). Paying it compounds
-- the income multiplier (1.5^rebirths), adds a pad up to 10, and KEEPS placed characters.
-- The conveyor band improves because it reads the highest rebirth count online.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Quests = require(script.Parent.Quests)
local Remotes = require(script.Parent.Remotes)

local Rebirth = {}

local MIN_COST = 500
local booths = nil

function Rebirth.RebirthCost(player: Player): number
	return math.max(MIN_COST, math.floor(GameConfig.Economy.RebirthCostFactor * GameState.TotalIncomeRate(player)))
end

function Rebirth.ApplyRebirth(player: Player)
	GameState.DoRebirth(player)

	-- Light up the newly active pad on the player's booth.
	local booth = PlayerSessions.GetBooth(player)
	if booth then
		local padPart = booth.Root.Parent:FindFirstChild("Pad" .. GameState.GetPadsOwned(player))
		if padPart then
			padPart.Transparency = 0
			padPart.Color = Color3.fromRGB(120, 230, 210)
		end
	end

	PlayerSessions.RefreshAttributes(player)
	Remotes.Celebrate:FireClient(player, GameState.GetRebirths(player))
	Remotes.Notify:FireClient(player, string.format(
		"REBIRTH %d! Income x%.2f, %d pads — your characters stayed put",
		GameState.GetRebirths(player),
		GameState.GetMultiplier(player),
		GameState.GetPadsOwned(player)
	))
	Quests.ReportProgress(player, "rebirth", 1)
end

function Rebirth.RequestRebirth(player: Player)
	local cost = Rebirth.RebirthCost(player)
	if not Economy.CanAfford(player, cost) then
		Remotes.Notify:FireClient(player, string.format("Rebirth costs $%d — keep earning", cost))
		return
	end
	Economy.SpendCash(player, cost)
	Rebirth.ApplyRebirth(player)
end

function Rebirth.Init(world)
	booths = world.Booths
	for _, booth in booths do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RebirthPrompt"
		prompt.ObjectText = "Rebirth"
		prompt.ActionText = "Rebirth"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = booth.Sign
		prompt.Triggered:Connect(function(player)
			if PlayerSessions.GetBoothOwner(booth.Index) == player then
				Rebirth.RequestRebirth(player)
			else
				Remotes.Notify:FireClient(player, "Only the booth owner can rebirth here")
			end
		end)
	end

	-- Keep the price on the sign current.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, booth in booths do
				local owner = PlayerSessions.GetBoothOwner(booth.Index)
				local prompt = booth.Sign:FindFirstChild("RebirthPrompt")
				if owner and prompt then
					prompt.ObjectText = string.format("Rebirth $%d", Rebirth.RebirthCost(owner))
					owner:SetAttribute("RebirthCost", Rebirth.RebirthCost(owner))
				end
			end
		end
	end)
end

return Rebirth
