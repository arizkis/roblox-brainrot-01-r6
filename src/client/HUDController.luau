-- HUDController: drives HUDView from player attributes and server remotes,
-- binds the rail buttons, and floats "+$" popups over earning pads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local Remotes = ReplicatedStorage:WaitForChild("BazaarRemotes")

local HUDController = {}

local C = Presentation.Colors
local L = Presentation.HUD

local activePopups = 0
local MAX_POPUPS = 10
local bannerToken = 0

local function watch(player: Player, attribute: string, apply)
	apply(player:GetAttribute(attribute))
	player:GetAttributeChangedSignal(attribute):Connect(function()
		apply(player:GetAttribute(attribute))
	end)
end

function HUDController.Toast(view, text: string, color: Color3?)
	local feed = view.ToastFeed
	if #feed:GetChildren() > 6 then
		local oldest = feed:GetChildren()[1]
		if oldest and oldest:IsA("Frame") then
			oldest:Destroy()
		end
	end
	local toast = Presentation.NewPanel("Toast", UDim2.fromOffset(L.ToastWidth, 44), UDim2.fromOffset(0, 0), feed, color or C.Accent)
	toast.BackgroundTransparency = 0.18
	local label = Presentation.NewLabel("Text", text, UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), toast, 14)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	task.delay(4.5, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			tween:Play()
			for _, child in toast:GetDescendants() do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				elseif child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
			task.delay(0.45, function()
				toast:Destroy()
			end)
		end
	end)
end

local function bindBanner(view)
	Remotes.Banner.OnClientEvent:Connect(function(text: string)
		bannerToken += 1
		local token = bannerToken
		view.BannerText.Text = text
		local accent = if string.find(text, "TSUNAMI") then C.Danger else C.Accent
		view.BannerText.TextColor3 = accent
		local stroke = view.Banner:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = accent
		end
		view.Banner.Visible = true
		if string.find(text, "calms down") then
			task.delay(2.5, function()
				if token == bannerToken then
					view.Banner.Visible = false
				end
			end)
		end
	end)
end

local function bindLock(view)
	Remotes.LockState.OnClientEvent:Connect(function(state)
		if state.Active then
			view.LockButton.State.Text = "LOCKED " .. Presentation.FormatTime(state.TimeLeft)
			view.LockButton.State.TextColor3 = C.Cyan
		elseif state.CooldownLeft > 0 then
			view.LockButton.State.Text = "COOLDOWN " .. Presentation.FormatTime(state.CooldownLeft)
			view.LockButton.State.TextColor3 = C.Dim
		else
			view.LockButton.State.Text = "READY"
			view.LockButton.State.TextColor3 = C.Good
		end
	end)
end

local function bindCarry(view, player: Player)
	watch(player, "Carrying", function(name)
		if name and name ~= "" then
			view.CarryText.Text = "CARRYING: " .. name .. "  →  DROP AT YOUR BOOTH"
			view.CarryBar.Visible = true
		else
			view.CarryBar.Visible = false
		end
	end)
end

local function bindAttributes(view, player: Player)
	watch(player, "Cash", function(value)
		view.CashText.Text = Presentation.FormatCash(value or 0)
	end)
	watch(player, "IncomePerSec", function(value)
		view.IncomeChip.Text = "+" .. Presentation.FormatCash(value or 0) .. "/s"
	end)
	watch(player, "Multiplier", function(value)
		view.MultChip.Text = string.format("x%.2f", value or 1)
	end)
	watch(player, "Rebirths", function(value)
		view.RebirthChip.Text = "REBIRTH " .. tostring(value or 0)
	end)
	watch(player, "IndexFound", function(value)
		view.IndexButton.State.Text = string.format("%d/36", value or 0)
	end)
	watch(player, "RebirthCost", function(value)
		view.RebirthButton.State.Text = Presentation.FormatCash(value or 500)
	end)
end

-- Floating "+$" over an earning pad: a local invisible part carries a BillboardGui
-- that drifts up and fades. Capped so a full booth cannot flood the screen.
local function bindPopups()
	Remotes.CashPopup.OnClientEvent:Connect(function(position: Vector3, amount: number)
		if activePopups >= MAX_POPUPS then
			return
		end
		activePopups += 1
		local anchor = Instance.new("Part")
		anchor.Name = "CashPopupAnchor"
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.CFrame = CFrame.new(position)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Parent = workspace
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "CashPopup"
		billboard.Size = UDim2.fromOffset(140, 40)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = anchor
		billboard.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "+" .. Presentation.FormatCash(amount)
		label.TextColor3 = C.Good
		label.TextStrokeColor3 = C.Stroke
		label.TextStrokeTransparency = 0
		label.TextSize = 22
		label.Font = L.TitleFont
		label.Parent = billboard
		TweenService:Create(billboard, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1, function()
			anchor:Destroy()
			activePopups -= 1
		end)
	end)
end

local function bindCelebrate(view)
	Remotes.Celebrate.OnClientEvent:Connect(function(rebirths: number)
		local flash = Instance.new("Frame")
		flash.Name = "RebirthFlash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = C.Accent
		flash.BackgroundTransparency = 0.65
		flash.BorderSizePixel = 0
		flash.ZIndex = 50
		flash.Parent = view.Gui
		local text = Presentation.NewLabel("RebirthText", "REBIRTH " .. tostring(rebirths) .. "!", UDim2.fromOffset(600, 90), UDim2.fromScale(0.5, 0.35), view.Gui, 54, L.TitleFont)
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.TextColor3 = C.Accent
		text.ZIndex = 51
		TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1.8, function()
			flash:Destroy()
			text:Destroy()
		end)
	end)
end

local function refreshShop(view)
	local ok, rows = pcall(function()
		return Remotes.GetUpgrades:InvokeServer()
	end)
	if not ok or type(rows) ~= "table" then
		return
	end
	local total = 0
	for i, row in ipairs(rows) do
		local slot = view.UpgradesRows[i]
		if slot then
			slot.Name.Text = row.Name
			slot.Desc.Text = row.Desc
			slot.Level.Text = string.format("Lv %d/%d", row.Level, row.MaxLevel)
			total += row.Level
			if row.NextCost then
				slot.Buy.Text = Presentation.FormatCash(row.NextCost)
				slot.Buy.BackgroundColor3 = C.Accent
			else
				slot.Buy.Text = "MAX"
				slot.Buy.BackgroundColor3 = C.Dim
			end
			slot.Buy:SetAttribute("TrackId", row.Id)
		end
	end
	view.UpgradesButton.State.Text = string.format("%d/24", total)
end

local function bindShop(view)
	view.UpgradesButton.Button.MouseButton1Click:Connect(function()
		view.UpgradesPanel.Visible = not view.UpgradesPanel.Visible
		if view.UpgradesPanel.Visible then
			refreshShop(view)
		end
	end)
	view.UpgradesClose.MouseButton1Click:Connect(function()
		view.UpgradesPanel.Visible = false
	end)
	for _, slot in view.UpgradesRows do
		slot.Buy.MouseButton1Click:Connect(function()
			local trackId = slot.Buy:GetAttribute("TrackId")
			if trackId then
				Remotes.BuyUpgrade:FireServer(trackId)
				task.delay(0.2, function()
					refreshShop(view)
				end)
			end
		end)
	end
end

local function fadeSplash(view)
	task.delay(4, function()
		local splash = view.JoinSplash
		local info = TweenInfo.new(0.6)
		TweenService:Create(splash, info, { BackgroundTransparency = 1 }):Play()
		for _, child in splash:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.7, function()
			splash.Visible = false
		end)
	end)
end

function HUDController.Init(view, player: Player)
	bindAttributes(view, player)
	bindBanner(view)
	bindLock(view)
	bindCarry(view, player)
	bindPopups()
	bindCelebrate(view)
	bindShop(view)
	fadeSplash(view)

	view.LockButton.Button.MouseButton1Click:Connect(function()
		Remotes.RequestLock:FireServer()
	end)
	view.RebirthButton.Button.MouseButton1Click:Connect(function()
		Remotes.RequestRebirth:FireServer()
	end)
	Remotes.Toast.OnClientEvent:Connect(function(text: string)
		HUDController.Toast(view, text)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text: string)
		HUDController.Toast(view, text, C.Danger)
	end)

	refreshShop(view)
end

return HUDController
