-- WorldBuilder: builds the whole bazaar plaza at startup. Bright floor, diagonal conveyor
-- from the spawn arch, a ring of 6 identical booths, fence, river and string lights.
-- BuildWorld() returns the booth and conveyor handles the game logic needs.

local RunService = game:GetService("RunService")

local WorldBuilder = {}

local FLOOR_SIZE = 240
local BOOTH_RADIUS = 44
local BOOTH_COUNT = 6
local PAD_COUNT = 10
local ACTIVE_PADS = 6

local CONVEYOR_START = Vector3.new(-95, 0, -15)
local CONVEYOR_END = Vector3.new(15, 0, 95)

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildFloor(parent: Instance): Part
	local floor = makePart("PlazaFloor", Vector3.new(FLOOR_SIZE, 1, FLOOR_SIZE), CFrame.new(0, -0.5, 0), Color3.fromRGB(245, 235, 215), parent, Enum.Material.Concrete)
	floor.CanCollide = true
	return floor
end

-- The river runs along the west edge; the tsunami rolls in from here.
local function buildRiver(parent: Instance): Part
	local river = makePart("River", Vector3.new(16, 0.6, FLOOR_SIZE), CFrame.new(-FLOOR_SIZE / 2 + 8, 0.25, 0), Color3.fromRGB(50, 120, 220), parent, Enum.Material.Glass)
	river.Transparency = 0.25
	river.CanCollide = false
	return river
end

-- Fence around the plaza with a walk-in gap on the south side.
local function buildFence(parent: Instance)
	local half = FLOOR_SIZE / 2 - 2
	local fenceColor = Color3.fromRGB(120, 90, 60)
	local function run(from: Vector3, to: Vector3, gapCenter: number?, gapWidth: number?)
		local delta = to - from
		local length = delta.Magnitude
		local dir = delta.Unit
		local posts = math.floor(length / 12)
		for i = 0, posts do
			local t = i / posts
			local along = t * length
			if gapCenter and math.abs(along - gapCenter) < gapWidth / 2 then
				continue
			end
			local pos = from + dir * along
			makePart("FencePost", Vector3.new(0.6, 4, 0.6), CFrame.new(pos + Vector3.new(0, 2, 0)), fenceColor, parent)
		end
		for _, height in { 1.4, 3.2 } do
			local segments = if gapCenter then 2 else 1
			for segment = 1, segments do
				local a, b
				if gapCenter then
					if segment == 1 then
						a, b = 0, gapCenter - gapWidth / 2
					else
						a, b = gapCenter + gapWidth / 2, length
					end
				else
					a, b = 0, length
				end
				if b - a < 1 then
					continue
				end
				local mid = from + dir * ((a + b) / 2) + Vector3.new(0, height, 0)
				local yaw = math.atan2(dir.X, dir.Z)
				makePart("FenceRail", Vector3.new(0.35, 0.35, b - a), CFrame.new(mid) * CFrame.Angles(0, yaw, 0), fenceColor, parent)
			end
		end
	end
	run(Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half)) -- north
	run(Vector3.new(half, 0, -half), Vector3.new(half, 0, half)) -- east
	run(Vector3.new(half, 0, half), Vector3.new(-half, 0, half), half, 24) -- south, gap in the middle
	run(Vector3.new(-half, 0, half), Vector3.new(-half, 0, -half)) -- west
end

-- Diagonal conveyor lane with side rails and animated belt stripes.
local function buildConveyor(parent: Instance)
	local delta = CONVEYOR_END - CONVEYOR_START
	local length = delta.Magnitude
	local dir = delta.Unit
	local perp = Vector3.new(dir.Z, 0, -dir.X)
	local mid = (CONVEYOR_START + CONVEYOR_END) / 2
	local yaw = math.atan2(dir.X, dir.Z)
	local laneCF = CFrame.new(mid + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, yaw, 0)

	local belt = makePart("Belt", Vector3.new(8, 0.5, length), laneCF, Color3.fromRGB(50, 50, 55), parent, Enum.Material.SmoothPlastic)
	belt.CanCollide = true
	for _, side in { -1, 1 } do
		makePart("Rail", Vector3.new(0.6, 1.6, length), CFrame.new(mid + perp * (4.3 * side) + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(230, 180, 60), parent)
	end

	local stripes = {}
	local stripeCount = 14
	for i = 1, stripeCount do
		local stripe = makePart("BeltStripe", Vector3.new(7.4, 0.12, 1.6), CFrame.new(CONVEYOR_START), Color3.fromRGB(255, 220, 80), parent, Enum.Material.Neon)
		stripe.CanCollide = false
		table.insert(stripes, { part = stripe, offset = (i - 1) * length / stripeCount })
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, stripe in stripes do
			stripe.offset = (stripe.offset + 6 * dt) % length
			stripe.part.CFrame = CFrame.new(CONVEYOR_START + dir * stripe.offset + Vector3.new(0, 0.56, 0)) * CFrame.Angles(0, yaw, 0)
		end
	end)

	return { Start = CONVEYOR_START, End = CONVEYOR_END, Direction = dir, Length = length, Belt = belt }
end

-- Spawn arch at the conveyor's start, with the giant BRAINROT BAZAAR board on posts above it.
local function buildArchAndSign(parent: Instance, conveyor)
	local start = conveyor.Start
	local dir = conveyor.Direction
	local perp = Vector3.new(dir.Z, 0, -dir.X)
	local archColor = Color3.fromRGB(230, 80, 60)

	for _, side in { -1, 1 } do
		makePart("ArchPost", Vector3.new(1.2, 10, 1.2), CFrame.new(start + perp * (5 * side) + Vector3.new(0, 5, 0)), archColor, parent)
	end
	makePart("ArchBeam", Vector3.new(12.5, 1.5, 1.5), CFrame.new(start + Vector3.new(0, 10.5, 0)) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0), archColor, parent)

	local toCenter = -start
	local signYaw = math.atan2(toCenter.X, toCenter.Z)
	local signCF = CFrame.new(start + Vector3.new(0, 15.5, 0)) * CFrame.Angles(0, signYaw, 0)
	for _, side in { -1, 1 } do
		makePart("SignPost", Vector3.new(0.8, 5, 0.8), CFrame.new(start + perp * (10 * side) + Vector3.new(0, 12.5, 0)), Color3.fromRGB(70, 70, 80), parent)
	end
	local board = makePart("BazaarSign", Vector3.new(34, 8, 0.8), signCF, Color3.fromRGB(30, 30, 40), parent)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1024, 256)
	surface.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "BRAINROT BAZAAR"
	text.TextColor3 = Color3.fromRGB(255, 230, 120)
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = surface
end

-- A ring of 6 identical booths facing the plaza centre. Local booth space: +Z faces centre.
local function buildBooths(parent: Instance)
	local booths = {}
	for i = 1, BOOTH_COUNT do
		local angle = (i - 1) * 2 * math.pi / BOOTH_COUNT
		local pos = Vector3.new(math.cos(angle) * BOOTH_RADIUS, 0, math.sin(angle) * BOOTH_RADIUS)
		local rootCF = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-pos.X, -pos.Z), 0)
		local booth = Instance.new("Model")
		booth.Name = "Booth" .. i
		booth.Parent = parent

		local function place(name: string, size: Vector3, localPos: Vector3, color: Color3, material: Enum.Material?): Part
			return makePart(name, size, rootCF * CFrame.new(localPos), color, booth, material)
		end

		local platform = place("Platform", Vector3.new(17, 0.6, 13), Vector3.new(0, 0.3, 0), Color3.fromRGB(235, 225, 205))
		platform.CanCollide = true
		platform:SetAttribute("BoothIndex", i)
		place("BackWall", Vector3.new(17, 7, 0.5), Vector3.new(0, 3.5, -6.25), Color3.fromRGB(240, 235, 225))
		for _, side in { -1, 1 } do
			place("AwningPost", Vector3.new(0.5, 5.8, 0.5), Vector3.new(8 * side, 2.9, 5.9), Color3.fromRGB(120, 90, 60))
		end
		for stripe = 1, 9 do
			local color = if stripe % 2 == 1 then Color3.fromRGB(220, 60, 60) else Color3.fromRGB(250, 250, 250)
			place("AwningStripe", Vector3.new(2, 0.3, 7.5), Vector3.new(-8 + (stripe - 0.5) * 2, 5.95, 3.2), color)
		end

		local sign = place("OwnerSign", Vector3.new(12, 2.4, 0.35), Vector3.new(0, 7.4, -6.0), Color3.fromRGB(40, 40, 50))
		local surface = Instance.new("SurfaceGui")
		surface.Name = "SignFace"
		surface.Face = Enum.NormalId.Front
		surface.CanvasSize = Vector2.new(512, 96)
		surface.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "BOOTH " .. i .. "  ·  CLAIM ME"
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		text.TextStrokeTransparency = 0
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.Parent = surface

		local pedestal = place("LockPedestal", Vector3.new(1.3, 2.2, 1.3), Vector3.new(7.2, 1.1, 4.8), Color3.fromRGB(70, 70, 80))
		place("LockLight", Vector3.new(0.8, 0.4, 0.8), Vector3.new(7.2, 2.4, 4.8), Color3.fromRGB(90, 230, 255), Enum.Material.Neon)

		local pads = {}
		for pad = 1, PAD_COUNT do
			local x = (pad - 1) * 1.5 - 6.75
			local active = pad <= ACTIVE_PADS
			local padPart = place("Pad" .. pad, Vector3.new(1.25, 0.25, 1.25), Vector3.new(x, 0.72, 1.5), if active then Color3.fromRGB(120, 230, 210) else Color3.fromRGB(130, 130, 130))
			padPart.Transparency = if active then 0 else 0.5
			padPart:SetAttribute("PadIndex", pad)
			pads[pad] = rootCF * CFrame.new(x, 0.85, 1.5)
		end

		table.insert(booths, { Index = i, Root = platform, Pads = pads, LockPedestal = pedestal, Sign = sign })
	end
	return booths
end

-- String lights strung across the conveyor on post pairs, with a gentle sag.
local function buildStringLights(parent: Instance, conveyor)
	local dir = conveyor.Direction
	local perp = Vector3.new(dir.Z, 0, -dir.X)
	local bulbColor = Color3.fromRGB(255, 220, 140)
	for _, offset in { 20, 55, 90, 125, 160, 195 } do
		local point = conveyor.Start + dir * offset
		local tops = {}
		for _, side in { -1, 1 } do
			local base = point + perp * (5.5 * side)
			makePart("LightPost", Vector3.new(0.3, 9, 0.3), CFrame.new(base + Vector3.new(0, 4.5, 0)), Color3.fromRGB(60, 60, 65), parent)
			table.insert(tops, base + Vector3.new(0, 9, 0))
		end
		local previous = tops[1]
		for j = 0, 6 do
			local t = j / 6
			local pos = tops[1]:Lerp(tops[2], t) - Vector3.new(0, math.sin(t * math.pi) * 1.3, 0)
			makePart("Bulb", Vector3.new(0.35, 0.35, 0.35), CFrame.new(pos), bulbColor, parent, Enum.Material.Neon)
			if j > 0 then
				local wire = makePart("Wire", Vector3.new(0.08, 0.08, (pos - previous).Magnitude), CFrame.lookAt((pos + previous) / 2, pos), Color3.fromRGB(40, 40, 40), parent)
				wire.CanCollide = false
			end
			previous = pos
		end
	end
end

function WorldBuilder.BuildWorld()
	local world = Instance.new("Folder")
	world.Name = "BazaarWorld"
	world.Parent = workspace

	buildFloor(world)
	local river = buildRiver(world)
	buildFence(world)
	local conveyor = buildConveyor(world)
	buildArchAndSign(world, conveyor)
	local booths = buildBooths(world)
	buildStringLights(world, conveyor)

	return { Root = world, Booths = booths, Conveyor = conveyor, River = river }
end

return WorldBuilder
