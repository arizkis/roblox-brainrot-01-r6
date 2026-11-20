-- StealLock: stealing placed characters between players, and booth lock shields.
-- Steal prompts attach to placed models as they land on booths (ChildAdded). A lock
-- raises a translucent dome for 60 s (+15 s per Thick Locks level), disables steals
-- inside and turns raccoons away, then goes on a 90 s cooldown shown on the pedestal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local Carry = require(script.Parent.Carry)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Quests = require(script.Parent.Quests)
local Remotes = require(script.Parent.Remotes)

local StealLock = {}

local booths = nil

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

function StealLock.IsLocked(booth): boolean
	local owner = PlayerSessions.GetBoothOwner(booth.Index)
	return if owner then GameState.IsLocked(owner) else false
end

function StealLock.LockTimeLeft(booth): number
	local owner = PlayerSessions.GetBoothOwner(booth.Index)
	if not owner then
		return 0
	end
	local lock = GameState.GetLock(owner)
	return if lock.Active then math.max(0, lock.Until - os.clock()) else 0
end

local function setStealPromptsEnabled(booth, enabled: boolean)
	for _, child in booth.Root.Parent:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Recipe") then
			local prompt = child.PrimaryPart and child.PrimaryPart:FindFirstChild("StealPrompt")
			if prompt then
				prompt.Enabled = enabled
			end
		end
	end
end

local function raiseDome(booth)
	local dome = Instance.new("Part")
	dome.Name = "LockDome"
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(26, 20, 22)
	dome.CFrame = booth.Root.CFrame + Vector3.new(0, 5, 0)
	dome.Color = Color3.fromRGB(90, 230, 255)
	dome.Material = Enum.Material.ForceField
	dome.Transparency = 0.55
	dome.Anchored = true
	dome.CanCollide = false
	dome.Parent = booth.Root.Parent
end

local function lowerDome(booth)
	local dome = booth.Root.Parent:FindFirstChild("LockDome")
	if dome then
		dome:Destroy()
	end
end

-- Find the placed entry a model belongs to, and its owner.
local function findPlaced(model: Model)
	for _, player in Players:GetPlayers() do
		for _, entry in GameState.GetPlaced(player) do
			if entry.Model == model then
				return player, entry
			end
		end
	end
	return nil, nil
end

-- The thief must have empty hands, a free pad, and the booth must be unlocked.
-- Ownership transfers when the thief delivers the character to their own pad.
function StealLock.StealPlacedBrainrot(player: Player, placedCharacter): boolean
	local victim = PlayerSessions.GetBoothOwner(placedCharacter.BoothIndex)
	if not victim or victim == player then
		notify(player, "That one is already yours")
		return false
	end
	if GameState.GetCarrying(player) then
		notify(player, "Your hands are full")
		return false
	end
	if placedCharacter.Inactive then
		notify(player, "That one is already being carried off!")
		return false
	end
	local booth = booths[placedCharacter.BoothIndex]
	if StealLock.IsLocked(booth) then
		notify(player, "That booth is locked")
		return false
	end
	local thiefBooth = PlayerSessions.GetBooth(player)
	if not thiefBooth or #GameState.GetPlaced(player) >= GameState.GetPadsOwned(player) then
		notify(player, "You need a free pad before you can steal")
		return false
	end

	GameState.RemoveCharacter(victim, placedCharacter.BoothIndex, placedCharacter.PadIndex)
	local prompt = placedCharacter.Model.PrimaryPart and placedCharacter.Model.PrimaryPart:FindFirstChild("StealPrompt")
	if prompt then
		prompt:Destroy()
	end
	PlayerSessions.RefreshAttributes(player)
	PlayerSessions.RefreshAttributes(victim)
	notify(victim, player.Name .. " stole your " .. placedCharacter.Recipe .. "!")

	placedCharacter.Model:SetAttribute("Stolen", true)
	Carry.AttachCarried(player, placedCharacter.Model)
	Quests.ReportProgress(player, "steal", 1)
	return true
end

local function handleStealPrompt(player: Player, model: Model)
	local _, entry = findPlaced(model)
	if entry then
		StealLock.StealPlacedBrainrot(player, entry)
	end
end

local function attachStealPrompt(model: Model, booth)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ObjectText = model.Name
	prompt.ActionText = "Steal"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not StealLock.IsLocked(booth)
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		handleStealPrompt(player, model)
	end)
end

function StealLock.RequestLock(player: Player)
	local booth = PlayerSessions.GetBooth(player)
	if not booth then
		return
	end
	local lock = GameState.GetLock(player)
	local now = os.clock()
	if lock.Active and now < lock.Until then
		notify(player, "Your booth is already locked")
		return
	end
	if now < lock.CooldownUntil then
		notify(player, string.format("Lock on cooldown: %ds", math.ceil(lock.CooldownUntil - now)))
		return
	end
	local duration = GameConfig.Economy.LockDuration + 15 * GameState.GetUpgrade(player, "locks")
	GameState.SetLock(player, true, now + duration, now + duration + GameConfig.Economy.LockCooldown)
	raiseDome(booth)
	setStealPromptsEnabled(booth, false)
	notify(player, string.format("Booth locked for %ds", duration))
end

function StealLock.Init(world)
	booths = world.Booths
	for _, booth in booths do
		-- Lock prompt on the pedestal (owner-only, validated on trigger).
		local lockPrompt = Instance.new("ProximityPrompt")
		lockPrompt.Name = "LockPrompt"
		lockPrompt.ObjectText = "Booth shield"
		lockPrompt.ActionText = "Lock"
		lockPrompt.HoldDuration = 0
		lockPrompt.MaxActivationDistance = 8
		lockPrompt.RequiresLineOfSight = false
		lockPrompt.Parent = booth.LockPedestal
		lockPrompt.Triggered:Connect(function(player)
			if PlayerSessions.GetBoothOwner(booth.Index) == player then
				StealLock.RequestLock(player)
			else
				notify(player, "Only the booth owner can lock it")
			end
		end)

		-- Steal prompts attach as placed characters land on the booth.
		booth.Root.Parent.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child:GetAttribute("Recipe") and child.PrimaryPart then
				attachStealPrompt(child, booth)
			end
		end)
	end

	-- Expiry + pedestal countdown display.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, booth in booths do
				local owner = PlayerSessions.GetBoothOwner(booth.Index)
				local prompt = booth.LockPedestal:FindFirstChild("LockPrompt")
				if owner then
					local lock = GameState.GetLock(owner)
					if lock.Active and os.clock() >= lock.Until then
						GameState.SetLock(owner, false, 0, lock.CooldownUntil)
						lowerDome(booth)
						setStealPromptsEnabled(booth, true)
					end
					Remotes.LockState:FireClient(owner, {
						Active = StealLock.IsLocked(booth),
						TimeLeft = StealLock.LockTimeLeft(booth),
						CooldownLeft = math.max(0, lock.CooldownUntil - os.clock()),
					})
					if prompt then
						if StealLock.IsLocked(booth) then
							prompt.ActionText = string.format("Locked %ds", math.ceil(StealLock.LockTimeLeft(booth)))
						elseif os.clock() < lock.CooldownUntil then
							prompt.ActionText = string.format("Cooldown %ds", math.ceil(lock.CooldownUntil - os.clock()))
						else
							prompt.ActionText = "Lock"
						end
					end
				elseif prompt then
					prompt.ActionText = "Lock"
				end
			end
		end
	end)
end

return StealLock
