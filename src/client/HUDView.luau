-- HUDView: builds the neon night-market ScreenGui tree. No logic lives here;
-- HUDController and friends drive the returned references.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))

local HUDView = {}

local C = Presentation.Colors
local L = Presentation.HUD

local function chip(name: string, text: string, parent: Instance): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(140, 26)
	frame.BackgroundColor3 = C.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local label = Presentation.NewLabel("Text", text, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), frame, 15)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function railButton(name: string, title: string, state: string, accent: Color3, parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(L.RailWidth, L.RailButtonHeight)
	button.BackgroundColor3 = C.Panel
	button.BackgroundTransparency = C.PanelTransparency
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = L.Corner
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = accent
	stroke.Transparency = 0.3
	stroke.Parent = button
	local titleLabel = Presentation.NewLabel("Title", title, UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 4), button, 18, L.TitleFont)
	titleLabel.TextColor3 = accent
	local stateLabel = Presentation.NewLabel("State", state, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 30), button, 13)
	stateLabel.TextColor3 = C.Text
	return { Button = button, Title = titleLabel, State = stateLabel }
end

function HUDView.Build(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BazaarHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top-centre cash plate (never top-left: Roblox's menu lives there).
	local plate = Presentation.NewPanel("CashPlate", UDim2.fromOffset(L.PlateWidth, L.PlateHeight), UDim2.new(0.5, 0, 0, 12), gui)
	plate.AnchorPoint = Vector2.new(0.5, 0)
	local cashText = Presentation.NewLabel("Cash", "$50", UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 4), plate, 42, L.TitleFont)
	cashText.TextColor3 = C.Accent
	local chipRow = Instance.new("Frame")
	chipRow.Name = "Chips"
	chipRow.Size = UDim2.fromOffset(440, 26)
	chipRow.Position = UDim2.new(0.5, 0, 0, 56)
	chipRow.AnchorPoint = Vector2.new(0.5, 0)
	chipRow.BackgroundTransparency = 1
	chipRow.Parent = plate
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chipLayout.Padding = UDim.new(0, 10)
	chipLayout.Parent = chipRow
	local incomeChip = chip("IncomeChip", "+$0/s", chipRow)
	local multChip = chip("MultChip", "x1.00", chipRow)
	local rebirthChip = chip("RebirthChip", "REBIRTH 0", chipRow)

	-- Event banner directly under the plate.
	local banner = Presentation.NewPanel("EventBanner", UDim2.fromOffset(520, L.BannerHeight), UDim2.new(0.5, 0, 0, 12 + L.PlateHeight + 8), gui, C.Pink)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Visible = false
	local bannerText = Presentation.NewLabel("BannerText", "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), banner, 20, L.TitleFont)

	-- Right-side rail of four chunky buttons.
	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(1, 0)
	rail.Position = UDim2.new(1, -L.Margin, 0, 12)
	rail.Size = UDim2.fromOffset(L.RailWidth, 4 * L.RailButtonHeight + 3 * L.RailGap)
	rail.BackgroundTransparency = 1
	rail.Parent = gui
	local railLayout = Instance.new("UIListLayout")
	railLayout.Padding = UDim.new(0, L.RailGap)
	railLayout.Parent = rail
	local lockButton = railButton("LockButton", "LOCK", "READY", C.Cyan, rail)
	local rebirthButton = railButton("RebirthButton", "REBIRTH", "$500", C.Accent, rail)
	local upgradesButton = railButton("UpgradesButton", "UPGRADES", "0/24", C.Pink, rail)
	local indexButton = railButton("IndexButton", "INDEX", "0/36", C.Good, rail)

	-- Quest tracker: top-right, under the rail.
	local tracker = Presentation.NewPanel("QuestTracker", UDim2.fromOffset(250, 158), UDim2.new(1, -L.Margin, 0, 12 + 4 * L.RailButtonHeight + 3 * L.RailGap + 14), gui, C.Pink)
	tracker.AnchorPoint = Vector2.new(1, 0)
	Presentation.NewLabel("Header", "CONTRACTS", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), tracker, 16, L.TitleFont).TextColor3 = C.Pink
	local questRows = {}
	for i = 1, 3 do
		local row = Presentation.NewLabel("Quest" .. i, "—", UDim2.new(1, -16, 0, 38), UDim2.fromOffset(8, 28 + (i - 1) * 42), tracker, 13)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Top
		questRows[i] = row
	end

	-- Bottom-centre carrying bar.
	local carryBar = Presentation.NewPanel("CarryBar", UDim2.fromOffset(560, L.CarryBarHeight), UDim2.new(0.5, 0, 1, -L.Margin), gui, C.Good)
	carryBar.AnchorPoint = Vector2.new(0.5, 1)
	carryBar.Visible = false
	local carryText = Presentation.NewLabel("CarryText", "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), carryBar, 17, L.TitleFont)

	-- Toast feed: bottom-left stack.
	local toastFeed = Instance.new("Frame")
	toastFeed.Name = "ToastFeed"
	toastFeed.AnchorPoint = Vector2.new(0, 1)
	toastFeed.Position = UDim2.new(0, L.Margin, 1, -L.Margin)
	toastFeed.Size = UDim2.fromOffset(L.ToastWidth, 220)
	toastFeed.BackgroundTransparency = 1
	toastFeed.Parent = gui
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.Parent = toastFeed

	-- Join splash, faded out by the controller after 4 s.
	local splash = Presentation.NewPanel("JoinSplash", UDim2.fromOffset(640, 140), UDim2.fromScale(0.5, 0.42), gui)
	splash.AnchorPoint = Vector2.new(0.5, 0.5)
	splash.BackgroundTransparency = 0.15
	local splashTitle = Presentation.NewLabel("Title", "BRAINROT BAZAAR", UDim2.new(1, 0, 0, 64), UDim2.fromOffset(0, 14), splash, 46, L.TitleFont)
	splashTitle.TextColor3 = C.Accent
	Presentation.NewLabel("Subtitle", "buy, carry, place, earn!", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 82), splash, 22)

	-- Upgrades shop panel (hidden until the rail button opens it).
	local shop = Presentation.NewPanel("UpgradesPanel", UDim2.fromOffset(520, 430), UDim2.fromScale(0.5, 0.5), gui, C.Pink)
	shop.AnchorPoint = Vector2.new(0.5, 0.5)
	shop.Visible = false
	shop.BackgroundTransparency = 0.12
	Presentation.NewLabel("Header", "UPGRADES", UDim2.new(1, -60, 0, 36), UDim2.fromOffset(16, 10), shop, 26, L.TitleFont).TextColor3 = C.Pink
	local shopClose = Instance.new("TextButton")
	shopClose.Name = "Close"
	shopClose.Size = UDim2.fromOffset(36, 36)
	shopClose.Position = UDim2.new(1, -46, 0, 10)
	shopClose.BackgroundColor3 = C.Danger
	shopClose.BackgroundTransparency = 0.2
	shopClose.Text = "X"
	shopClose.TextColor3 = C.Text
	shopClose.TextStrokeTransparency = 0
	shopClose.TextSize = 20
	shopClose.Font = L.TitleFont
	shopClose.Parent = shop
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = shopClose
	local shopRows = {}
	for i = 1, 6 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Size = UDim2.new(1, -32, 0, 56)
		row.Position = UDim2.fromOffset(16, 52 + (i - 1) * 62)
		row.BackgroundColor3 = C.Panel
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = shop
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row
		local nameLabel = Presentation.NewLabel("Name", "", UDim2.new(0, 200, 0, 24), UDim2.fromOffset(10, 4), row, 16, L.TitleFont)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		local descLabel = Presentation.NewLabel("Desc", "", UDim2.new(0, 280, 0, 20), UDim2.fromOffset(10, 30), row, 12)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextColor3 = C.Dim
		local levelLabel = Presentation.NewLabel("Level", "", UDim2.fromOffset(70, 24), UDim2.new(1, -190, 0, 16), row, 15)
		local buy = Instance.new("TextButton")
		buy.Name = "Buy"
		buy.Size = UDim2.fromOffset(100, 36)
		buy.Position = UDim2.new(1, -110, 0, 10)
		buy.BackgroundColor3 = C.Accent
		buy.BackgroundTransparency = 0.15
		buy.Text = "$0"
		buy.TextColor3 = Color3.fromRGB(20, 20, 30)
		buy.TextSize = 16
		buy.Font = L.TitleFont
		buy.Parent = row
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buy
		shopRows[i] = { Row = row, Name = nameLabel, Desc = descLabel, Level = levelLabel, Buy = buy }
	end

	return {
		Gui = gui,
		CashText = cashText,
		IncomeChip = incomeChip,
		MultChip = multChip,
		RebirthChip = rebirthChip,
		Banner = banner,
		BannerText = bannerText,
		LockButton = lockButton,
		RebirthButton = rebirthButton,
		UpgradesButton = upgradesButton,
		IndexButton = indexButton,
		QuestRows = questRows,
		CarryBar = carryBar,
		CarryText = carryText,
		ToastFeed = toastFeed,
		JoinSplash = splash,
		UpgradesPanel = shop,
		UpgradesClose = shopClose,
		UpgradesRows = shopRows,
	}
end

return HUDView
