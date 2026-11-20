-- QuestController: renders the contract tracker from server snapshots and flashes
-- a row green when a contract completes and is replaced. Completion toasts arrive
-- through the Toast remote (handled by HUDController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Presentation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Presentation"))
local Remotes = ReplicatedStorage:WaitForChild("BazaarRemotes")

local QuestController = {}

local C = Presentation.Colors

local function progressText(entry): string
	local quest = entry.Quest
	local progress = entry.Progress or 0
	if quest.goalType == "earn" then
		return Presentation.FormatCash(progress) .. " / " .. Presentation.FormatCash(quest.target)
	end
	return string.format("%d / %d", math.min(progress, quest.target), quest.target)
end

function QuestController.Init(view)
	local previousIds = { "", "", "" }

	local function render(snapshot)
		if type(snapshot) ~= "table" then
			return
		end
		for i = 1, 3 do
			local row = view.QuestRows[i]
			local entry = snapshot[i]
			if entry and entry.Quest then
				local quest = entry.Quest
				row.Text = string.format("%s\n%s  ·  +$%d", quest.text, progressText(entry), quest.reward)
				row.TextColor3 = C.Text
				if previousIds[i] ~= "" and previousIds[i] ~= quest.id then
					-- A contract just completed and was replaced: flash the row.
					row.TextColor3 = C.Good
					TweenService:Create(row, TweenInfo.new(1.2), { TextColor3 = C.Text }):Play()
				end
				previousIds[i] = quest.id
			else
				row.Text = "—"
				previousIds[i] = ""
			end
		end
	end

	Remotes.QuestUpdate.OnClientEvent:Connect(render)

	local ok, snapshot = pcall(function()
		return Remotes.GetQuests:InvokeServer()
	end)
	if ok then
		render(snapshot)
	end
end

return QuestController
