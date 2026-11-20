-- IndexController: the collection book. A scrolling 36-slot grid opened from the
-- rail INDEX button; found entries show name, tier colour and $/s, the rest are
-- dark "???" silhouettes. Data: GetIndex remote (IndexBook.FoundSet) + GameConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("BazaarRemotes")

local IndexController = {}

local C = Presentation.Colors
local L = Presentation.HUD

local gui: ScreenGui? = nil
local panel: Frame? = nil
local header: TextLabel? = nil
local slots: { [string]: { Frame: Frame, Name: TextLabel, Income: TextLabel, Question: TextLabel, Stroke: UIStroke } } = {}

local function build(player: Player)
	gui = Instance.new("ScreenGui")
	gui.Name = "IndexBook"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Presentation.NewPanel("Panel", UDim2.fromOffset(660, 500), UDim2.fromScale(0.5, 0.5), gui, C.Good)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false

	header = Presentation.NewLabel("Header", "INDEX 0/36", UDim2.new(1, -70, 0, 36), UDim2.fromOffset(16, 10), panel, 26, L.TitleFont)
	header.TextColor3 = C.Good
	header.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(36, 36)
	close.Position = UDim2.new(1, -46, 0, 10)
	close.BackgroundColor3 = C.Danger
	close.BackgroundTransparency = 0.2
	close.Text = "X"
	close.TextColor3 = C.Text
	close.TextStrokeTransparency = 0
	close.TextSize = 20
	close.Font = L.TitleFont
	close.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.Size = UDim2.new(1, -32, 1, -64)
	scroll.Position = UDim2.fromOffset(16, 54)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = C.Good
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(146, 92)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = scroll

	for _, recipe in ipairs(GameConfig.Cast) do
		local slot = Instance.new("Frame")
		slot.Name = recipe.name
		slot.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
		slot.BackgroundTransparency = 0.15
		slot.BorderSizePixel = 0
		slot.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = slot
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = C.Dim
		stroke.Transparency = 0.5
		stroke.Parent = slot

		local nameLabel = Presentation.NewLabel("Name", recipe.name, UDim2.new(1, -12, 0, 40), UDim2.fromOffset(6, 6), slot, 13)
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		local incomeLabel = Presentation.NewLabel("Income", "", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 1, -26), slot, 14, L.TitleFont)
		local question = Presentation.NewLabel("Question", "???", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), slot, 28, L.TitleFont)
		question.TextColor3 = C.Dim

		slots[recipe.name] = { Frame = slot, Name = nameLabel, Income = incomeLabel, Question = question, Stroke = stroke }
	end
end

local function refresh()
	local ok, found = pcall(function()
		return Remotes.GetIndex:InvokeServer()
	end)
	if not ok or type(found) ~= "table" then
		return
	end
	local foundSet = {}
	for _, name in found do
		foundSet[name] = true
	end
	local count = 0
	for _, recipe in ipairs(GameConfig.Cast) do
		local slot = slots[recipe.name]
		local isFound = foundSet[recipe.name] == true
		if isFound then
			count += 1
			local tier = GameConfig.GetTier(recipe.tier)
			slot.Frame.BackgroundColor3 = C.Panel
			slot.Stroke.Color = tier.color
			slot.Stroke.Transparency = 0.15
			slot.Name.Text = recipe.name
			slot.Name.TextColor3 = C.Text
			slot.Income.Text = string.format("$%d/s", tier.incomePerSec)
			slot.Income.TextColor3 = tier.color
			slot.Income.Visible = true
			slot.Question.Visible = false
		else
			slot.Frame.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
			slot.Stroke.Color = C.Dim
			slot.Stroke.Transparency = 0.5
			slot.Name.Text = ""
			slot.Income.Visible = false
			slot.Question.Visible = true
		end
	end
	header.Text = string.format("INDEX %d/36", count)
end

function IndexController.Init(player: Player)
	build(player)
end

function IndexController.Open()
	refresh()
	panel.Visible = true
end

function IndexController.Close()
	panel.Visible = false
end

function IndexController.Toggle()
	if panel.Visible then
		IndexController.Close()
	else
		IndexController.Open()
	end
end

return IndexController
