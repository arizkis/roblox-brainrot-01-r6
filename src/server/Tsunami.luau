-- Tsunami: a 90 s cycle. T-10 s: banner + a translucent water wall rises at the river.
-- The wall sweeps the plaza over 8 s; carriers caught outside any booth footprint lose
-- their carry in a splash. Placed characters are always safe. The wall recedes over 2 s.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local GameState = require(script.Parent.GameState)
local PlayerSessions = require(script.Parent.PlayerSessions)
local Quests = require(script.Parent.Quests)
local Remotes = require(script.Parent.Remotes)

local Tsunami = {}

local WALL_START_X = -104 -- river's inner edge
local WALL_END_X = 122 -- past the far fence
local WALL_HEIGHT = 14

local booths = nil
local worldRoot = nil
local wall: Part? = nil
local sweeping = false
local nextSweepAt = 0

-- Injected by init (Carry.DropCarried) to avoid a require cycle.
local dropHandler: ((Player, string) -> ())? = nil

function Tsunami.SetDropHandler(handler: (Player, string) -> ())
	dropHandler = handler
end

function Tsunami.Init(world)
	booths = world.Booths
	worldRoot = world.Root
end

function Tsunami.IsSweeping(): boolean
	return sweeping
end

function Tsunami.NextSweepAt(): number
	return nextSweepAt
end

-- Inside any booth's footprint (the platform, up to awning height)?
function Tsunami.IsSheltered(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, booth in booths do
		local localPos = booth.Root.CFrame:PointToObjectSpace(root.Position)
		if math.abs(localPos.X) <= 8.5 and math.abs(localPos.Z) <= 6.5 and localPos.Y >= -1 and localPos.Y <= 10 then
			return true
		end
	end
	return false
end

local function splash(position: Vector3)
	for _ = 1, 10 do
		local drop = Instance.new("Part")
		drop.Name = "Splash"
		drop.Size = Vector3.new(0.5, 0.5, 0.5)
		drop.Color = Color3.fromRGB(80, 160, 240)
		drop.Material = Enum.Material.Glass
		drop.Transparency = 0.3
		drop.CanCollide = false
		drop.CFrame = CFrame.new(position + Vector3.new(math.random(-2, 2), math.random(0, 3), math.random(-2, 2)))
		drop.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(8, 20), math.random(-12, 12))
		drop.Parent = worldRoot
		Debris:AddItem(drop, 1.2)
	end
end

function Tsunami.StartTsunamiWarning()
	Remotes.Banner:FireAllClients("TSUNAMI INCOMING — GET TO A BOOTH!")
	wall = Instance.new("Part")
	wall.Name = "TsunamiWall"
	wall.Size = Vector3.new(6, WALL_HEIGHT, 240)
	wall.CFrame = CFrame.new(WALL_START_X, WALL_HEIGHT / 2, 0)
	wall.Color = Color3.fromRGB(40, 120, 230)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.45
	wall.Anchored = true
	wall.CanCollide = false
	wall.Parent = worldRoot
end

function Tsunami.SweepTsunami()
	if not wall then
		return
	end
	sweeping = true
	local startTime = os.clock()
	local hit: { [Player]: boolean } = {}
	local sweep = GameConfig.Economy.TsunamiSweep

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local wallX = WALL_START_X + (WALL_END_X - WALL_START_X) * math.min(elapsed / sweep, 1)
		wall.CFrame = CFrame.new(wallX, WALL_HEIGHT / 2, 0)
		for _, player in Players:GetPlayers() do
			if hit[player] then
				continue
			end
			local carrying = GameState.GetCarrying(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if carrying and root and wallX >= root.Position.X then
				hit[player] = true
				if Tsunami.IsSheltered(player) then
					Quests.ReportProgress(player, "survive_tsunami", 1)
				elseif dropHandler then
					dropHandler(player, "tsunami")
					splash(root.Position + Vector3.new(0, 3, 0))
				end
			end
		end
		if elapsed >= sweep then
			connection:Disconnect()
		end
	end)
	while os.clock() - startTime < sweep do
		task.wait(0.1)
	end

	-- Recede over 2 s, then clean up.
	local recedeStart = os.clock()
	while os.clock() - recedeStart < 2 do
		local t = (os.clock() - recedeStart) / 2
		wall.CFrame = CFrame.new(WALL_END_X + (WALL_START_X - WALL_END_X) * t, WALL_HEIGHT / 2, 0)
		task.wait(0.05)
	end
	if wall then
		wall:Destroy()
		wall = nil
	end
	sweeping = false
end

function Tsunami.StartTsunamiCycle()
	task.spawn(function()
		local economy = GameConfig.Economy
		while true do
			nextSweepAt = os.clock() + (economy.TsunamiPeriod - economy.TsunamiWarning)
			task.wait(economy.TsunamiPeriod - economy.TsunamiWarning)
			Tsunami.StartTsunamiWarning()
			task.wait(economy.TsunamiWarning)
			Tsunami.SweepTsunami()
		end
	end)
end

return Tsunami
