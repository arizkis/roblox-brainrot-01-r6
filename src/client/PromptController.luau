-- PromptController: replaces the default ProximityPrompt look with a neon card
-- anchored bottom-centre above the carrying bar, themed from the prompt's model
-- attributes (recipe, tier, mutation, price) or its action label.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PromptController = {}

local C = Presentation.Colors
local L = Presentation.HUD

local gui: ScreenGui? = nil
local card: Frame? = nil
local nameLabel: TextLabel? = nil
local bandFrame: Frame? = nil
local bandLabel: TextLabel? = nil
local mutationLabel: TextLabel? = nil
local actionLabel: TextLabel? = nil
local holdBar: Frame? = nil
local currentPrompt: ProximityPrompt? = nil
local holdTween: Tween? = nil

local ACTION_COLORS = {
	STEAL = C.Danger,
	["WHACK!"] = C.Pink,
	LOCK = C.Cyan,
	PLACE = C.Good,
	REBIRTH = C.Accent,
	["PICK UP"] = C.Good,
}

local function buildCard(player: Player)
	gui = Instance.new("ScreenGui")
	gui.Name = "PromptCard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Presentation.NewPanel("Card", UDim2.fromOffset(400, 112), UDim2.new(0.5, 0, 1, -72), gui)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Visible = false

	nameLabel = Presentation.NewLabel("Name", "", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 6), card, 19, L.TitleFont)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	bandFrame = Instance.new("Frame")
	bandFrame.Name = "TierBand"
	bandFrame.Size = UDim2.fromOffset(120, 20)
	bandFrame.Position = UDim2.fromOffset(10, 36)
	bandFrame.BorderSizePixel = 0
	bandFrame.Parent = card
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, 6)
	bandCorner.Parent = bandFrame
	bandLabel = Presentation.NewLabel("Tier", "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), bandFrame, 12, L.TitleFont)

	mutationLabel = Presentation.NewLabel("Mutation", "", UDim2.fromOffset(150, 20), UDim2.fromOffset(140, 36), card, 13)
	mutationLabel.TextXAlignment = Enum.TextXAlignment.Left

	actionLabel = Presentation.NewLabel("Action", "", UDim2.new(0, 180, 0, 44), UDim2.new(1, -190, 0, 30), card, 30, L.TitleFont)
	actionLabel.TextXAlignment = Enum.TextXAlignment.Right

	local holdTrack = Instance.new("Frame")
	holdTrack.Name = "HoldTrack"
	holdTrack.Size = UDim2.new(1, -20, 0, 8)
	holdTrack.Position = UDim2.new(0, 10, 1, -22)
	holdTrack.BackgroundColor3 = C.Panel
	holdTrack.BackgroundTransparency = 0.1
	holdTrack.BorderSizePixel = 0
	holdTrack.Parent = card
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = holdTrack
	holdBar = Instance.new("Frame")
	holdBar.Name = "HoldBar"
	holdBar.Size = UDim2.fromScale(0, 1)
	holdBar.BackgroundColor3 = C.Accent
	holdBar.BorderSizePixel = 0
	holdBar.Parent = holdTrack
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = holdBar

	Presentation.NewLabel("Hint", "hold E / tap", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 1, -14), card, 11).TextColor3 = C.Dim
end

local function showCard(prompt: ProximityPrompt)
	currentPrompt = prompt
	-- Hide the default UI locally; the card replaces it.
	prompt.Style = Enum.ProximityPromptStyle.Custom

	local model = prompt.Parent and prompt.Parent.Parent
	local recipe = model and model:GetAttribute("Recipe")
	local tierName = model and model:GetAttribute("Tier")
	local mutation = model and model:GetAttribute("Mutation")
	local price = model and model:GetAttribute("Price")

	if recipe then
		nameLabel.Text = recipe
		local tier = GameConfig.GetTier(tierName)
		bandFrame.BackgroundColor3 = Presentation.TierColor(tierName)
		bandLabel.Text = string.upper(tierName or "")
		bandFrame.Visible = true
		if mutation then
			mutationLabel.Text = string.upper(mutation) .. " x" .. tostring(GameConfig.GetMutation(mutation).multiplier)
			mutationLabel.TextColor3 = Presentation.MutationColor(mutation)
			mutationLabel.Visible = true
		else
			mutationLabel.Visible = false
		end
		actionLabel.Text = Presentation.FormatCash(price or 0)
		actionLabel.TextColor3 = C.Accent
		local stroke = card:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = Presentation.TierColor(tierName)
		end
	else
		nameLabel.Text = prompt.ObjectText
		bandFrame.Visible = false
		mutationLabel.Visible = false
		local action = string.upper(prompt.ActionText)
		actionLabel.Text = action
		actionLabel.TextColor3 = ACTION_COLORS[action] or C.Accent
		local stroke = card:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = ACTION_COLORS[action] or C.Accent
		end
	end

	holdBar.Size = UDim2.fromScale(0, 1)
	card.Visible = true
end

local function hideCard(prompt: ProximityPrompt)
	if currentPrompt == prompt then
		currentPrompt = nil
		card.Visible = false
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
	end
	prompt.Style = Enum.ProximityPromptStyle.Default
end

function PromptController.Init(player: Player)
	buildCard(player)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		showCard(prompt)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		hideCard(prompt)
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt == currentPrompt and prompt.HoldDuration > 0 then
			holdBar.Size = UDim2.fromScale(0, 1)
			holdTween = TweenService:Create(holdBar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			holdTween:Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == currentPrompt then
			if holdTween then
				holdTween:Cancel()
				holdTween = nil
			end
			holdBar.Size = UDim2.fromScale(0, 1)
		end
	end)
	ProximityPromptService.Triggered:Connect(function(prompt)
		if prompt == currentPrompt then
			holdBar.Size = UDim2.fromScale(1, 1)
		end
	end)
end

return PromptController
