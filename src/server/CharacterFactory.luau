-- CharacterFactory: turns a GameConfig recipe into a blocky welded Model with a mutation
-- treatment and a 3-line nameplate. Server-side; the client only ever sees the finished model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local CharacterFactory = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldTo(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

-- Body plans per family: a base body (the root) plus family flavour parts.
-- Everything sits on y = 0 and faces +Z. Returns the root part.
local function buildBody(model: Model, recipe): Part
	local color = recipe.color
	local accent = recipe.accent
	local family = recipe.family
	local root: Part

	if family == "Sign" then
		makePart("Post", Vector3.new(0.5, 1.6, 0.5), Vector3.new(0, 0.8, 0), accent, model)
		root = makePart("Body", Vector3.new(2.6, 2.6, 0.35), Vector3.new(0, 2.9, 0), color, model)
	elseif family == "Cup" then
		root = makePart("Body", Vector3.new(1.9, 2.4, 1.9), Vector3.new(0, 1.2, 0), color, model)
		makePart("Lid", Vector3.new(2.1, 0.5, 2.1), Vector3.new(0, 2.65, 0), accent, model)
	elseif family == "Food" then
		root = makePart("Body", Vector3.new(2.3, 1.9, 2.3), Vector3.new(0, 0.95, 0), color, model)
	elseif family == "Machine" then
		root = makePart("Body", Vector3.new(2.1, 2.9, 1.7), Vector3.new(0, 1.45, 0), color, model)
		makePart("Panel", Vector3.new(1.5, 0.9, 0.12), Vector3.new(0, 2.2, 0.9), accent, model)
	elseif family == "Critter" then
		root = makePart("Body", Vector3.new(1.9, 1.5, 2.5), Vector3.new(0, 0.75, 0), color, model)
		makePart("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 2.0, 0.7), color, model)
	elseif family == "Plant" then
		root = makePart("Pot", Vector3.new(1.7, 1.0, 1.7), Vector3.new(0, 0.5, 0), accent, model)
		makePart("Body", Vector3.new(1.2, 2.2, 1.2), Vector3.new(0, 2.1, 0), color, model)
	elseif family == "Vehicle" then
		root = makePart("Body", Vector3.new(2.6, 1.0, 3.6), Vector3.new(0, 0.9, 0), color, model)
		for _, x in { -1.3, 1.3 } do
			for _, z in { -1.2, 1.2 } do
				makePart("Wheel", Vector3.new(0.5, 0.9, 0.9), Vector3.new(x, 0.45, z), accent, model)
			end
		end
	elseif family == "Ghost" then
		root = makePart("Body", Vector3.new(2.1, 2.7, 1.5), Vector3.new(0, 1.75, 0), color, model)
		root.Transparency = 0.15
	elseif family == "Snack" then
		root = makePart("Body", Vector3.new(1.7, 2.3, 1.1), Vector3.new(0, 1.15, 0), color, model)
	elseif family == "Sea" then
		root = makePart("Body", Vector3.new(2.5, 1.7, 2.9), Vector3.new(0, 0.85, 0), color, model)
		makePart("Fin", Vector3.new(0.3, 1.0, 1.2), Vector3.new(0, 2.1, -0.4), accent, model)
	elseif family == "Royal" then
		root = makePart("Body", Vector3.new(2.1, 2.7, 1.7), Vector3.new(0, 1.35, 0), color, model)
		makePart("Crown", Vector3.new(1.2, 0.6, 1.2), Vector3.new(0, 3.0, 0), accent, model, Enum.Material.Metal)
	elseif family == "Tech" then
		root = makePart("Body", Vector3.new(2.3, 2.1, 1.3), Vector3.new(0, 1.05, 0), color, model)
		makePart("Screen", Vector3.new(1.7, 1.2, 0.15), Vector3.new(0, 1.4, 0.7), accent, model, Enum.Material.Neon)
	else
		root = makePart("Body", Vector3.new(2, 2, 2), Vector3.new(0, 1, 0), color, model)
	end

	return root
end

-- Two accent parts standing in for the recipe's feature notes, plus a simple face.
local function addFeatures(model: Model, root: Part, recipe)
	local topY = root.Position.Y + root.Size.Y / 2
	local frontZ = root.Position.Z + root.Size.Z / 2

	local featureTop = makePart("Feature1", Vector3.new(0.9, 0.7, 0.9), Vector3.new(0, topY + 0.35, 0), recipe.accent, model)
	featureTop:SetAttribute("FeatureNote", recipe.features[1])
	local featureSide = makePart("Feature2", Vector3.new(0.7, 0.7, 0.7), Vector3.new(root.Size.X / 2 + 0.45, root.Position.Y, 0), recipe.accent, model)
	featureSide:SetAttribute("FeatureNote", recipe.features[2])

	local eyeY = root.Position.Y + root.Size.Y * 0.18
	for _, x in { -0.4, 0.4 } do
		makePart("Eye", Vector3.new(0.3, 0.36, 0.1), Vector3.new(x, eyeY, frontZ + 0.05), Color3.fromRGB(255, 255, 255), model)
		makePart("Pupil", Vector3.new(0.12, 0.16, 0.06), Vector3.new(x, eyeY, frontZ + 0.11), Color3.fromRGB(20, 20, 20), model)
	end
end

-- Mutation treatments. mutation is a GameConfig.Mutations entry or nil.
function CharacterFactory.ApplyMutationTreatment(model: Model, mutation)
	if not mutation then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local name = mutation.name

	if name == "Golden" then
		local trim = makePart("GoldTrim", root.Size + Vector3.new(0.2, 0.22, 0.2), root.Position, Color3.fromRGB(255, 200, 60), model, Enum.Material.Metal)
		weldTo(root, trim)
	elseif name == "Diamond" then
		local glint = makePart("DiamondGlint", root.Size + Vector3.new(0.25, 0.25, 0.25), root.Position, Color3.fromRGB(140, 240, 255), model, Enum.Material.Glass)
		glint.Transparency = 0.55
		weldTo(root, glint)
	elseif name == "Glitch" then
		for _, shell in { { "GlitchShellR", Color3.fromRGB(255, 60, 60), 0.14 }, { "GlitchShellB", Color3.fromRGB(60, 120, 255), -0.14 } } do
			local copy = makePart(shell[1], root.Size, root.Position + Vector3.new(shell[3], 0, 0), shell[2], model, Enum.Material.Neon)
			copy.Transparency = 0.6
			weldTo(root, copy)
		end
	elseif name == "Rainbow" then
		local trim = makePart("RainbowTrim", root.Size + Vector3.new(0.2, 0.22, 0.2), root.Position, Color3.fromRGB(255, 80, 80), model, Enum.Material.Neon)
		trim:SetAttribute("RainbowTrim", true)
		weldTo(root, trim)
	elseif name == "Cosmic" then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Eye" and part.Name ~= "Pupil" then
				part.Color = Color3.fromRGB(15, 15, 40)
			end
		end
		makePart("CosmicCore", Vector3.new(0.6, 0.6, 0.6), root.Position, Color3.fromRGB(255, 240, 180), model, Enum.Material.Neon)
		for i = 1, 4 do
			local angle = i * math.pi / 2
			local offset = Vector3.new(math.cos(angle), 0.3 * (i % 2 - 0.5), math.sin(angle)) * (root.Size.X / 2 + 0.3)
			makePart("Star" .. i, Vector3.new(0.16, 0.16, 0.16), root.Position + offset, Color3.fromRGB(255, 255, 255), model, Enum.Material.Neon)
		end
	elseif name == "Void" then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Eye" and part.Name ~= "Pupil" then
				part.Color = Color3.fromRGB(12, 8, 18)
			end
		end
		local aura = makePart("VoidAura", root.Size * 1.6, root.Position, Color3.fromRGB(120, 50, 200), model, Enum.Material.Neon)
		aura.Transparency = 0.75
		weldTo(root, aura)
	end

	model:SetAttribute("Mutation", name)
end

-- 3-line nameplate: name / rarity on a tier-coloured band / $income per second (+ mutation).
-- White text with a black stroke throughout.
function CharacterFactory.MakeNameplate(name: string, tier, incomePerSec: number, mutation): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Size = UDim2.fromOffset(210, 76)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 140

	local function label(text: string, y: number, height: number, textSize: number): TextLabel
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 0, height)
		textLabel.Position = UDim2.fromOffset(0, y)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = text
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		textLabel.TextStrokeTransparency = 0
		textLabel.TextSize = textSize
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextTruncate = Enum.TextTruncate.AtEnd
		textLabel.Parent = billboard
		return textLabel
	end

	label(name, 0, 24, 18)

	local band = Instance.new("Frame")
	band.Name = "RarityBand"
	band.Size = UDim2.new(1, 0, 0, 22)
	band.Position = UDim2.fromOffset(0, 26)
	band.BackgroundColor3 = tier.color
	band.BorderSizePixel = 0
	band.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = band
	local bandText = label(string.upper(tier.name), 26, 22, 14)
	bandText.Parent = band
	bandText.Position = UDim2.fromOffset(0, 0)
	bandText.Size = UDim2.new(1, 0, 1, 0)

	local incomeText = string.format("$%d/s", incomePerSec)
	if mutation then
		incomeText ..= "  " .. mutation.name
	end
	label(incomeText, 52, 22, 14)

	return billboard
end

-- Build a full character Model from a recipe, optionally mutated.
function CharacterFactory.BuildCharacter(recipe, mutation): Model
	local tier = GameConfig.GetTier(recipe.tier)
	local model = Instance.new("Model")
	model.Name = recipe.name

	local root = buildBody(model, recipe)
	model.PrimaryPart = root
	model.WorldPivot = CFrame.identity -- pivot at the character's feet, so PivotTo places it on surfaces
	addFeatures(model, root, recipe)

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			weldTo(root, part)
		end
	end

	CharacterFactory.ApplyMutationTreatment(model, mutation)

	local incomePerSec = tier.incomePerSec * (if mutation then mutation.multiplier else 1)
	local nameplate = CharacterFactory.MakeNameplate(recipe.name, tier, incomePerSec, mutation)
	nameplate.Adornee = root
	nameplate.Parent = root

	model:SetAttribute("Recipe", recipe.name)
	model:SetAttribute("Tier", recipe.tier)
	model:SetAttribute("Family", recipe.family)
	model:SetAttribute("IncomePerSec", incomePerSec)

	return model
end

return CharacterFactory
