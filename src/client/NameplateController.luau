-- NameplateController: keeps character nameplates readable at any distance.
-- Plates scale up with camera distance so text stays ~24 px tall on a 768-wide
-- view, and hide beyond a far distance.

local RunService = game:GetService("RunService")

local NameplateController = {}

local FAR_DISTANCE = 160
local BASE_DISTANCE = 45
local MAX_SCALE = 2.2

local plates: { [BillboardGui]: boolean } = {}

local function track(gui: BillboardGui)
	if gui.Name ~= "Nameplate" or plates[gui] then
		return
	end
	plates[gui] = true
	-- Remember the authored sizes once, before scaling touches them.
	if not gui:GetAttribute("BaseWidth") then
		gui:SetAttribute("BaseWidth", gui.Size.Width.Offset)
		gui:SetAttribute("BaseHeight", gui.Size.Height.Offset)
		for _, child in gui:GetDescendants() do
			if child:IsA("TextLabel") then
				child:SetAttribute("BaseTextSize", child.TextSize)
			end
		end
	end
end

function NameplateController.Init()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			track(descendant)
		end
	end
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BillboardGui") then
			track(descendant)
		end
	end)
	workspace.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BillboardGui") then
			plates[descendant] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPos = camera.CFrame.Position
		for gui in plates do
			if not gui.Parent then
				plates[gui] = nil
				continue
			end
			local adornee = gui.Adornee
			if not adornee then
				continue
			end
			local distance = (cameraPos - adornee.Position).Magnitude
			if distance > FAR_DISTANCE then
				gui.Enabled = false
				continue
			end
			gui.Enabled = true
			local scale = math.clamp(distance / BASE_DISTANCE, 1, MAX_SCALE)
			local baseWidth = gui:GetAttribute("BaseWidth") or 210
			local baseHeight = gui:GetAttribute("BaseHeight") or 76
			gui.Size = UDim2.fromOffset(baseWidth * scale, baseHeight * scale)
			for _, child in gui:GetDescendants() do
				if child:IsA("TextLabel") then
					local baseSize = child:GetAttribute("BaseTextSize")
					if baseSize then
						child.TextSize = baseSize * scale
					end
				end
			end
		end
	end)
end

return NameplateController
