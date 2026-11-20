-- RaccoonThieves: every ~75 s (while someone is online) a part-built raccoon slips through
-- the fence gap, grabs a character from a random UNLOCKED booth (it stops earning), and
-- flees. Whack it to drop the character as a free pickup for its owner; unclaimed for 30 s
-- it returns to its pad. If the raccoon escapes, the character is gone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameState = require(script.Parent.GameState)
local Economy = require(script.Parent.Economy)
local Carry = require(script.Parent.Carry)
local PlayerSessions = require(script.Parent.PlayerSessions)
local StealLock = require(script.Parent.StealLock)
local Quests = require(script.Parent.Quests)
local Remotes = require(script.Parent.Remotes)

local RaccoonThieves = {}

local FENCE_GAP = Vector3.new(0, 0, 118)
local APPROACH_SPEED = 10
local FLEE_SPEED = 14
local PICKUP_WINDOW = 30

local booths = nil
local raccoons: { any } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function raccoonPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Grey body, striped tail, mask band, little sack.
local function buildRaccoon(): Model
	local model = Instance.new("Model")
	model.Name = "RaccoonThief"
	local grey = Color3.fromRGB(130, 130, 135)
	local dark = Color3.fromRGB(60, 60, 65)

	local body = raccoonPart("Body", Vector3.new(1.4, 1.1, 2.2), Vector3.new(0, 0.85, 0), grey, model)
	model.PrimaryPart = body
	model.WorldPivot = CFrame.identity
	raccoonPart("Head", Vector3.new(1.0, 0.9, 1.0), Vector3.new(0, 1.5, 1.2), grey, model)
	raccoonPart("Mask", Vector3.new(1.05, 0.3, 0.2), Vector3.new(0, 1.6, 1.72), dark, model)
	raccoonPart("Snout", Vector3.new(0.4, 0.3, 0.3), Vector3.new(0, 1.35, 1.8), Color3.fromRGB(200, 200, 205), model)
	for _, side in { -1, 1 } do
		raccoonPart("Ear", Vector3.new(0.3, 0.35, 0.2), Vector3.new(0.35 * side, 2.05, 1.1), dark, model)
	end
	for i = 1, 3 do
		local color = if i % 2 == 1 then dark else grey
		raccoonPart("Tail" .. i, Vector3.new(0.5, 0.5, 0.7), Vector3.new(0, 1.0 + i * 0.15, -1.2 - i * 0.6), color, model)
	end
	raccoonPart("Sack", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 1.7, -0.5), Color3.fromRGB(150, 110, 60), model)

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

local function returnToPad(entry)
	local booth = booths[entry.BoothIndex]
	entry.Inactive = false
	entry.Dropped = nil
	entry.Model.Parent = booth.Root.Parent
	entry.Model:PivotTo(booth.Pads[entry.PadIndex])
	local prompt = entry.Model.PrimaryPart and entry.Model.PrimaryPart:FindFirstChild("PickUpPrompt")
	if prompt then
		prompt:Destroy()
	end
	local stealPrompt = entry.Model.PrimaryPart and entry.Model.PrimaryPart:FindFirstChild("StealPrompt")
	if stealPrompt then
		stealPrompt.Enabled = not StealLock.IsLocked(booth)
	end
	local owner = PlayerSessions.GetBoothOwner(entry.BoothIndex)
	if owner then
		PlayerSessions.RefreshAttributes(owner)
		notify(owner, entry.Recipe .. " wandered back to its pad")
	end
end

-- The owner picks the dropped character up and carries it home.
local function attachPickupPrompt(entry, model: Model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpPrompt"
	prompt.ObjectText = entry.Recipe
	prompt.ActionText = "Pick up"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		local owner = PlayerSessions.GetBoothOwner(entry.BoothIndex)
		if player ~= owner then
			notify(player, "Only its owner can pick it up")
			return
		end
		if GameState.GetCarrying(player) then
			notify(player, "Your hands are full")
			return
		end
		prompt:Destroy()
		entry.Dropped = false
		Carry.AttachCarried(player, model)
		local carried = GameState.GetCarrying(player)
		if carried then
			carried.ReturnEntry = entry
		end
	end)
end

function RaccoonThieves.WhackRaccoonThief(player: Player, raccoon)
	if raccoon.Whacked then
		return
	end
	raccoon.Whacked = true
	Quests.ReportProgress(player, "whack", 1)
	if raccoon.Entry then
		local entry = raccoon.Entry
		entry.Dropped = true
		entry.Model.Parent = booths[entry.BoothIndex].Root.Parent
		entry.Model:PivotTo(CFrame.new(raccoon.Pos))
		attachPickupPrompt(entry, entry.Model)
		notify(player, "Whacked! The raccoon dropped " .. entry.Recipe)
		task.delay(PICKUP_WINDOW, function()
			if entry.Dropped and entry.Inactive and entry.Model and entry.Model.Parent then
				returnToPad(entry)
			end
		end)
		raccoon.Entry = nil
	else
		notify(player, "Whacked! But it was already empty-handed")
	end
	raccoon.Phase = "dizzy"
	raccoon.DizzyUntil = os.clock() + 0.8
end

-- targetBooth (optional) aims the raid at a specific booth (capture staging).
function RaccoonThieves.SpawnRaccoonThief(targetBooth)
	local booth = targetBooth
	if not booth then
		-- Pick a random unlocked booth with earning characters.
		local candidates = {}
		for _, candidate in booths do
			local owner = PlayerSessions.GetBoothOwner(candidate.Index)
			if owner and not StealLock.IsLocked(candidate) then
				for _, entry in GameState.GetPlaced(owner) do
					if entry.BoothIndex == candidate.Index and not entry.Inactive then
						table.insert(candidates, candidate)
						break
					end
				end
			end
		end
		if #candidates == 0 then
			return nil
		end
		booth = candidates[math.random(1, #candidates)]
	end

	local model = buildRaccoon()
	model.Parent = workspace
	local raccoon = {
		Model = model,
		Pos = FENCE_GAP,
		Yaw = math.pi,
		Phase = "approach",
		Target = (booth.Root.CFrame * CFrame.new(0, 0, 2)).Position,
		Booth = booth,
		Entry = nil,
		Victim = nil,
		Whacked = false,
		DizzyUntil = 0,
	}
	model:PivotTo(CFrame.new(raccoon.Pos) * CFrame.Angles(0, raccoon.Yaw, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WhackPrompt"
	prompt.ObjectText = "Raccoon thief"
	prompt.ActionText = "Whack!"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		RaccoonThieves.WhackRaccoonThief(player, raccoon)
	end)

	table.insert(raccoons, raccoon)
	return raccoon
end

-- Grab a character from the target booth: it stops earning at once and rides the raccoon.
function RaccoonThieves.StealForRaccoon(raccoon)
	local victim = PlayerSessions.GetBoothOwner(raccoon.Booth.Index)
	if not victim then
		raccoon.Phase = "flee"
		raccoon.Target = FENCE_GAP
		return
	end
	local candidates = {}
	for _, entry in GameState.GetPlaced(victim) do
		if entry.BoothIndex == raccoon.Booth.Index and not entry.Inactive then
			table.insert(candidates, entry)
		end
	end
	if #candidates == 0 then
		raccoon.Phase = "flee"
		raccoon.Target = FENCE_GAP
		return
	end
	local entry = candidates[math.random(1, #candidates)]
	entry.Inactive = true
	local stealPrompt = entry.Model.PrimaryPart and entry.Model.PrimaryPart:FindFirstChild("StealPrompt")
	if stealPrompt then
		stealPrompt.Enabled = false
	end
	raccoon.Entry = entry
	raccoon.Victim = victim
	raccoon.Phase = "flee"
	raccoon.Target = FENCE_GAP
	PlayerSessions.RefreshAttributes(victim)
	notify(victim, "A raccoon is making off with your " .. entry.Recipe .. "! Whack it!")
end

local function stepRaccoon(raccoon, dt: number): boolean
	if raccoon.Phase == "dizzy" then
		raccoon.Yaw += 12 * dt
		raccoon.Model:PivotTo(CFrame.new(raccoon.Pos) * CFrame.Angles(0, raccoon.Yaw, 0))
		if os.clock() >= raccoon.DizzyUntil then
			raccoon.Phase = "flee"
			raccoon.Target = FENCE_GAP
		end
		return true
	end

	local delta = raccoon.Target - raccoon.Pos
	local dist = delta.Magnitude
	local speed = if raccoon.Phase == "flee" then FLEE_SPEED else APPROACH_SPEED
	if dist < 1 then
		if raccoon.Phase == "approach" then
			if StealLock.IsLocked(raccoon.Booth) then
				-- Turned away by the shield.
				raccoon.Phase = "flee"
				raccoon.Target = FENCE_GAP
			else
				RaccoonThieves.StealForRaccoon(raccoon)
			end
		else
			-- Escaped through the fence: the character is gone.
			if raccoon.Entry and raccoon.Victim then
				local name = raccoon.Entry.Recipe
				Economy.RemovePlaced(raccoon.Victim, raccoon.Entry.CharacterId)
				notify(raccoon.Victim, "The raccoon got away with your " .. name .. "...")
			end
			raccoon.Model:Destroy()
			return false
		end
	else
		local step = delta.Unit * math.min(speed * dt, dist)
		raccoon.Pos += step
		raccoon.Yaw = math.atan2(delta.X, delta.Z)
		raccoon.Model:PivotTo(CFrame.new(raccoon.Pos) * CFrame.Angles(0, raccoon.Yaw, 0))
		if raccoon.Entry and raccoon.Entry.Model then
			raccoon.Entry.Model:PivotTo(CFrame.new(raccoon.Pos + Vector3.new(0, 2.2, 0)))
		end
	end
	return true
end

function RaccoonThieves.Init(world)
	booths = world.Booths
	RunService.Heartbeat:Connect(function(dt)
		for i = #raccoons, 1, -1 do
			if not stepRaccoon(raccoons[i], dt) then
				table.remove(raccoons, i)
			end
		end
	end)
end

function RaccoonThieves.StartRaccoonCycle()
	task.spawn(function()
		while true do
			task.wait(75)
			if #Players:GetPlayers() > 0 then
				RaccoonThieves.SpawnRaccoonThief()
			end
		end
	end)
end

return RaccoonThieves
