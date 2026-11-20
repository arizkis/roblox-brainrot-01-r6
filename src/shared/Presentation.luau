-- Presentation: shared neon night-market design tokens and helpers.
-- Dark translucent panels, bright saturated accents, tier colours from GameConfig,
-- big rounded white text with black stroke. Nothing important lives in the top-left
-- (Roblox's own menu sits there).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(script.Parent.GameConfig)

local Presentation = {}

Presentation.Colors = {
	Panel = Color3.fromRGB(16, 16, 28),
	PanelTransparency = 0.28,
	Stroke = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(255, 210, 80), -- neon gold
	Pink = Color3.fromRGB(255, 70, 180),
	Cyan = Color3.fromRGB(80, 230, 255),
	Danger = Color3.fromRGB(255, 70, 70),
	Good = Color3.fromRGB(120, 255, 160),
	Dim = Color3.fromRGB(150, 150, 165),
}

-- HUD layout constants both sides need.
Presentation.HUD = {
	Margin = 16,
	PlateWidth = 460,
	PlateHeight = 92,
	BannerHeight = 40,
	RailWidth = 176,
	RailButtonHeight = 56,
	RailGap = 10,
	CarryBarHeight = 44,
	ToastWidth = 320,
	Corner = UDim.new(0, 12),
	TitleFont = Enum.Font.GothamBlack,
	BodyFont = Enum.Font.GothamBold,
}

-- "$1.25M" style cash formatting.
function Presentation.FormatCash(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("$%.1fK", n / 1e3)
	end
	return string.format("$%d", n)
end

-- tier may be a name string or a tier table.
function Presentation.TierColor(tier): Color3
	local resolved = if type(tier) == "string" then GameConfig.GetTier(tier) else tier
	return if resolved then resolved.color else Presentation.Colors.Dim
end

local MUTATION_COLORS = {
	Golden = Color3.fromRGB(255, 200, 60),
	Diamond = Color3.fromRGB(140, 240, 255),
	Glitch = Color3.fromRGB(255, 80, 120),
	Rainbow = Color3.fromRGB(255, 120, 255),
	Cosmic = Color3.fromRGB(150, 120, 255),
	Void = Color3.fromRGB(130, 60, 220),
}

function Presentation.MutationColor(mutation): Color3
	local name = if type(mutation) == "table" then mutation.name else mutation
	return MUTATION_COLORS[name] or Presentation.Colors.Text
end

-- A dark rounded panel with a neon edge.
function Presentation.NewPanel(name: string, size: UDim2, position: UDim2, parent: Instance, accent: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Presentation.Colors.Panel
	frame.BackgroundTransparency = Presentation.Colors.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Presentation.HUD.Corner
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = accent or Presentation.Colors.Accent
	stroke.Transparency = 0.35
	stroke.Parent = frame
	return frame
end

-- Big rounded white text with a black stroke.
function Presentation.NewLabel(name: string, text: string, size: UDim2, position: UDim2, parent: Instance, textSize: number, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Presentation.Colors.Text
	label.TextStrokeColor3 = Presentation.Colors.Stroke
	label.TextStrokeTransparency = 0
	label.TextSize = textSize
	label.Font = font or Presentation.HUD.BodyFont
	label.TextWrapped = true
	label.Parent = parent
	return label
end

function Presentation.FormatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Presentation
