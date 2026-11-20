-- Brainrot Bazaar server entrypoint: build the world, start every system, bind players.
-- Core loop: conveyor spawns, income tick, carry/delivery.
-- Tension: tsunami cycle, rotating events, steal/lock, raccoon thieves.
-- Progression: rebirth, upgrades, contracts, collection index.

local Players = game:GetService("Players")
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local PlayerSessions = require(script:WaitForChild("PlayerSessions"))
local Quests = require(script:WaitForChild("Quests"))
local Economy = require(script:WaitForChild("Economy"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local Carry = require(script:WaitForChild("Carry"))
local Tsunami = require(script:WaitForChild("Tsunami"))
local EventDirector = require(script:WaitForChild("EventDirector"))
local StealLock = require(script:WaitForChild("StealLock"))
local RaccoonThieves = require(script:WaitForChild("RaccoonThieves"))
local Rebirth = require(script:WaitForChild("Rebirth"))
local Upgrades = require(script:WaitForChild("Upgrades"))
require(script:WaitForChild("CaptureStage")) -- loads the owner-only screenshot staging chat commands

local world = WorldBuilder.BuildWorld()

PlayerSessions.Init(world)
Economy.Init(world)
Conveyor.Init(world)
Carry.Init(world)
Tsunami.Init(world)
StealLock.Init(world)
RaccoonThieves.Init(world)
Rebirth.Init(world)
Quests.Init()

-- Cross-system handlers (injected to keep the require graph acyclic).
Conveyor.SetBuyHandler(Carry.BuyBeltCharacter)
Tsunami.SetDropHandler(Carry.DropCarried)
Quests.SetPayHandler(Economy.AddCash)

-- Client request surface (rail buttons, shop, book, contracts).
local Remotes = require(script:WaitForChild("Remotes"))
local IndexBook = require(script:WaitForChild("IndexBook"))
Remotes.RequestLock.OnServerEvent:Connect(function(player)
	StealLock.RequestLock(player)
end)
Remotes.RequestRebirth.OnServerEvent:Connect(function(player)
	Rebirth.RequestRebirth(player)
end)
Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, trackId)
	if type(trackId) == "string" then
		Upgrades.BuyUpgrade(player, trackId)
	end
end)
Remotes.GetIndex.OnServerInvoke = function(player)
	return IndexBook.FoundSet(player)
end
Remotes.GetQuests.OnServerInvoke = function(player)
	return Quests.ActiveQuests(player)
end
Remotes.GetUpgrades.OnServerInvoke = function(player)
	return Upgrades.UpgradeState(player)
end

Conveyor.StartConveyor()
Economy.StartIncomeLoop()
Tsunami.StartTsunamiCycle()
EventDirector.StartEventDirector()
RaccoonThieves.StartRaccoonCycle()

for _, player in Players:GetPlayers() do
	PlayerSessions.BindPlayer(player)
	Quests.AssignQuests(player)
end

print(string.format(
	"[BrainrotBazaar] ready: %d booths, conveyor %.0f studs, %d upgrade tracks — all systems running",
	#world.Booths,
	world.Conveyor.Length,
	#Upgrades.Tracks
))
