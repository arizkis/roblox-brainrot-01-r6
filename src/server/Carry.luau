-- Carry: buying off the belt, carrying above the head, and delivering to your own pads.
-- Stolen-flagged carries slow the carrier to 0.75x. DropCarried serves the tsunami/steal systems.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Conveyor = require(script.Parent.Conveyor)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Remotes = require(script.Parent.Remotes)
local Quests = require(script.Parent.Quests)
local IndexBook = require(script.Parent.IndexBook)

local Carry = {}

local BASE_WALK_SPEED = 16
local CARRY_HEIGHT = 3 -- studs above the head root
local DELIVER_RADIUS = 3.5
local booths = nil -- world booths, set by Init

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function padIsFree(player: Player, boothIndex: number, padIndex: number): boolean
	for _, entry in GameState.GetPlaced(player) do
		if entry.BoothIndex == boothIndex and entry.PadIndex == padIndex then
			return false
		end
	end
	return true
end

function Carry.Init(world)
	booths = world.Booths
	-- A "Place" prompt on each booth platform, alongside touch-to-place.
	for _, booth in world.Booths do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PlacePrompt"
		prompt.ObjectText = "Your booth"
		prompt.ActionText = "Place"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = booth.Root
		prompt.Triggered:Connect(function(player)
			Carry.DeliverToPad(player)
		end)
	end

	-- Carry loop: hold the model above the carrier, apply the stolen slow, auto-deliver near a free pad.
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local entry = GameState.GetCarrying(player)
			if not entry then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			entry.Model:PivotTo(CFrame.new(root.Position + Vector3.new(0, CARRY_HEIGHT, 0)))
			-- Swift Feet raises the base; Soft Hands speeds the carry; stolen cargo slows to 0.75x.
			local base = BASE_WALK_SPEED + 2 * GameState.GetUpgrade(player, "swift")
			local speed = base * (1 + 0.08 * GameState.GetUpgrade(player, "soft"))
			setWalkSpeed(player, if entry.Stolen then speed * GameConfig.Economy.StolenCarrySpeedFactor else speed)

			local booth = PlayerSessions.GetBooth(player)
			if booth then
				for padIndex = 1, GameState.GetPadsOwned(player) do
					local padPos = booth.Pads[padIndex].Position
					if (root.Position - padPos).Magnitude < DELIVER_RADIUS and padIsFree(player, booth.Index, padIndex) then
						Carry.DeliverToPad(player)
						break
					end
				end
			end
		end
	end)

	-- Dying drops the carry.
	local function hookDeath(player: Player)
		player.CharacterRemoving:Connect(function()
			if GameState.GetCarrying(player) then
				Carry.DropCarried(player, "death")
			end
		end)
	end
	Players.PlayerAdded:Connect(hookDeath)
	for _, player in Players:GetPlayers() do
		hookDeath(player)
	end
end

function Carry.BuyBeltCharacter(player: Player, beltCharacter: Model)
	if GameState.GetCarrying(player) then
		notify(player, "Your hands are full — place your carry first")
		return
	end
	if not beltCharacter.Parent or not beltCharacter:GetAttribute("BeltCharacter") then
		return
	end
	local price = beltCharacter:GetAttribute("Price")
	if not Economy.CanAfford(player, price) then
		notify(player, "Not enough cash")
		return
	end
	-- Claim it off the belt first so two buyers cannot both win the same character.
	if not Conveyor.RemoveBeltCharacter(beltCharacter) then
		return
	end
	Economy.SpendCash(player, price)
	GameState.RecordFind(player, beltCharacter:GetAttribute("Recipe"), beltCharacter:GetAttribute("Mutation"))
	Carry.AttachCarried(player, beltCharacter)
	PlayerSessions.RefreshAttributes(player)

	-- Contract and index hooks at the moment of ownership.
	IndexBook.RecordIndexFind(player, beltCharacter:GetAttribute("Recipe"))
	local tier = GameConfig.GetTier(beltCharacter:GetAttribute("Tier"))
	if tier and tier.index >= 3 then
		Quests.ReportProgress(player, "buy_rare", 1)
	end
	local mutationName = beltCharacter:GetAttribute("Mutation")
	if mutationName then
		Quests.ReportProgress(player, "buy_mutated", 1)
		local mutation = GameConfig.GetMutation(mutationName)
		local glitchIndex = GameConfig.GetMutation("Glitch").index
		if mutation and mutation.index >= glitchIndex then
			Quests.ReportProgress(player, "catch_glitch", 1)
		end
	end
end

function Carry.AttachCarried(player: Player, model: Model)
	local entry = {
		CharacterId = model:GetAttribute("CharacterId"),
		Model = model,
		Recipe = model:GetAttribute("Recipe"),
		Tier = model:GetAttribute("Tier"),
		Mutation = model:GetAttribute("Mutation"),
		IncomePerSec = model:GetAttribute("IncomePerSec"),
		Price = model:GetAttribute("Price"),
		Stolen = model:GetAttribute("Stolen") == true,
	}
	model:SetAttribute("BeltCharacter", false)
	GameState.SetCarrying(player, entry)
	player:SetAttribute("Carrying", entry.Recipe)
	if entry.Stolen then
		notify(player, "That one was stolen — you're moving slower!")
	end
end

-- Place the carried character on the first free pad of the player's booth.
-- A raccoon-dropped character (ReturnEntry) goes back to its original pad instead.
function Carry.DeliverToPad(player: Player): boolean
	local entry = GameState.GetCarrying(player)
	if not entry then
		return false
	end
	local booth = PlayerSessions.GetBooth(player)
	if not booth then
		notify(player, "You don't have a booth yet")
		return false
	end

	if entry.ReturnEntry then
		local home = entry.ReturnEntry
		local homeBooth = booths[home.BoothIndex]
		home.Inactive = false
		home.Dropped = nil
		home.Model.Parent = homeBooth.Root.Parent
		home.Model:PivotTo(homeBooth.Pads[home.PadIndex])
		local stealPrompt = home.Model.PrimaryPart and home.Model.PrimaryPart:FindFirstChild("StealPrompt")
		if stealPrompt then
			stealPrompt.Enabled = true
		end
		GameState.SetCarrying(player, nil)
		player:SetAttribute("Carrying", "")
		setWalkSpeed(player, BASE_WALK_SPEED + 2 * GameState.GetUpgrade(player, "swift"))
		PlayerSessions.RefreshAttributes(player)
		notify(player, home.Recipe .. " is back on its pad")
		return true
	end

	local freePad = nil
	for padIndex = 1, GameState.GetPadsOwned(player) do
		if padIsFree(player, booth.Index, padIndex) then
			freePad = padIndex
			break
		end
	end
	if not freePad then
		notify(player, "No free pads — unlock more or rebirth")
		return false
	end
	if Economy.PlaceOnPad(player, entry.Model, freePad) then
		GameState.SetCarrying(player, nil)
		player:SetAttribute("Carrying", "")
		setWalkSpeed(player, BASE_WALK_SPEED + 2 * GameState.GetUpgrade(player, "swift"))
		return true
	end
	return false
end

-- Release the carry (tsunami, steal, death). The model is destroyed; the entry is returned.
function Carry.DropCarried(player: Player, reason: string?)
	local entry = GameState.GetCarrying(player)
	if not entry then
		return nil
	end
	GameState.SetCarrying(player, nil)
	player:SetAttribute("Carrying", "")
	if entry.ReturnEntry then
		-- A lost return-carry releases its original pad for good.
		local home = entry.ReturnEntry
		local owner = PlayerSessions.GetBoothOwner(home.BoothIndex)
		if owner then
			GameState.RemoveCharacter(owner, home.BoothIndex, home.PadIndex)
			PlayerSessions.RefreshAttributes(owner)
		end
	end
	if entry.Model then
		entry.Model:Destroy()
	end
	setWalkSpeed(player, BASE_WALK_SPEED + 2 * GameState.GetUpgrade(player, "swift"))
	local message = "You dropped your carry"
	if reason == "tsunami" then
		message = "The tsunami swept your carry away!"
	elseif reason == "steal" then
		message = "Your carry was stolen!"
	elseif reason == "death" then
		message = "You dropped your carry when you fell"
	end
	notify(player, message)
	return entry
end

return Carry
