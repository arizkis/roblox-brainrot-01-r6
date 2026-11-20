-- Brainrot Bazaar client entry: build the HUD, start every controller.
-- The server owns all game state; this side only renders and requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local HUDView = require(script:WaitForChild("HUDView"))
local HUDController = require(script:WaitForChild("HUDController"))
local PromptController = require(script:WaitForChild("PromptController"))
local NameplateController = require(script:WaitForChild("NameplateController"))
local IndexController = require(script:WaitForChild("IndexController"))
local QuestController = require(script:WaitForChild("QuestController"))

local view = HUDView.Build(player)

IndexController.Init(player)
HUDController.Init(view, player)
QuestController.Init(view)
PromptController.Init(player)
NameplateController.Init()

view.IndexButton.Button.MouseButton1Click:Connect(function()
	IndexController.Toggle()
end)

print(string.format("[BrainrotBazaar] client ready: %d recipes, %d tiers, HUD online", #GameConfig.Cast, #GameConfig.Tiers))
