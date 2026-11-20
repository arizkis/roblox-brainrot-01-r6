-- PlayerSessions: join/leave lifecycle. Creates the GameState entry, claims a booth,
-- keeps the leaderstats-style attributes the client reads up to date, and cleans up on leave.

local Players = game:GetService("Players")
local GameState = require(script.Parent.GameState)

local PlayerSessions = {}

local booths = nil -- world booths, set by Init
local boothOwners: { [number]: Player? } = {}
local playerBooth: { [Player]: number } = {}

local function signText(booth, text: string)
	local face = booth.Sign:FindFirstChild("SignFace")
	local label = face and face:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = text
	end
end

function PlayerSessions.Init(world)
	booths = world.Booths
	for i = 1, #booths do
		boothOwners[i] = nil
	end
	Players.PlayerAdded:Connect(PlayerSessions.BindPlayer)
	Players.PlayerRemoving:Connect(PlayerSessions.ReleasePlayer)
end

-- The player's claimed booth table, or nil.
function PlayerSessions.GetBooth(player: Player)
	local index = playerBooth[player]
	return if index then booths[index] else nil
end

function PlayerSessions.GetBoothIndex(player: Player): number?
	return playerBooth[player]
end

-- Who owns this booth (nil when unclaimed).
function PlayerSessions.GetBoothOwner(boothIndex: number): Player?
	return boothOwners[boothIndex]
end

-- Claim the first free booth for the player. Returns the booth table or nil when all are taken.
function PlayerSessions.ClaimBooth(player: Player)
	if playerBooth[player] then
		return booths[playerBooth[player]]
	end
	for i, booth in ipairs(booths) do
		if not boothOwners[i] then
			boothOwners[i] = player
			playerBooth[player] = i
			signText(booth, "BOOTH " .. i .. "  ·  " .. player.Name)
			return booth
		end
	end
	return nil
end

-- Attributes the client HUD reads. Call after anything that changes cash, pads, income or finds.
function PlayerSessions.RefreshAttributes(player: Player)
	local state = GameState.Get(player)
	local indexFound = 0
	for _, entry in state.Index do
		if entry.Found then
			indexFound += 1
		end
	end
	player:SetAttribute("Cash", state.Cash)
	player:SetAttribute("IncomePerSec", GameState.TotalIncomeRate(player) * state.Multiplier)
	player:SetAttribute("Rebirths", state.Rebirths)
	player:SetAttribute("Multiplier", state.Multiplier)
	player:SetAttribute("PadsUsed", #state.Placed)
	player:SetAttribute("PadsMax", state.PadsOwned)
	player:SetAttribute("IndexFound", indexFound)
end

-- Swift Feet: base walk speed 16 + 2 per level, applied on every spawn.
local function applyWalkSpeed(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.WalkSpeed = 16 + 2 * GameState.GetUpgrade(player, "swift")
	end
end

function PlayerSessions.BindPlayer(player: Player)
	GameState.Get(player) -- creates the entry: cash 50, multiplier 1, 6 pads
	PlayerSessions.ClaimBooth(player)
	PlayerSessions.RefreshAttributes(player)
	player.CharacterAdded:Connect(function(character)
		applyWalkSpeed(player, character)
	end)
	if player.Character then
		applyWalkSpeed(player, player.Character)
	else
		player:LoadCharacter()
	end
end

function PlayerSessions.ReleasePlayer(player: Player)
	local state = GameState.Get(player)
	for _, entry in state.Placed do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	if state.Carrying and state.Carrying.Model then
		state.Carrying.Model:Destroy()
	end
	local index = playerBooth[player]
	if index then
		boothOwners[index] = nil
		playerBooth[player] = nil
		signText(booths[index], "BOOTH " .. index .. "  ·  CLAIM ME")
	end
	GameState.Remove(player)
end

return PlayerSessions
