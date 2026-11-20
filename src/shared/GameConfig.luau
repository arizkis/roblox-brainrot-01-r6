-- GameConfig: the single source of truth for every number and recipe in Brainrot Bazaar.
-- Lives in ReplicatedStorage.Shared so server and client read the same data.

local GameConfig = {}

-- Tiers in climbing order. mutationChance is the per-spawn chance a character of this tier is mutated.
GameConfig.Tiers = {
	{ name = "Common", buyPrice = 25, incomePerSec = 1, color = Color3.fromRGB(150, 150, 150), mutationChance = 0.08 },
	{ name = "Uncommon", buyPrice = 100, incomePerSec = 4, color = Color3.fromRGB(60, 200, 90), mutationChance = 0.08 },
	{ name = "Rare", buyPrice = 450, incomePerSec = 14, color = Color3.fromRGB(60, 130, 255), mutationChance = 0.10 },
	{ name = "Epic", buyPrice = 1800, incomePerSec = 45, color = Color3.fromRGB(160, 80, 255), mutationChance = 0.12 },
	{ name = "Legendary", buyPrice = 7500, incomePerSec = 150, color = Color3.fromRGB(255, 200, 40), mutationChance = 0.14 },
	{ name = "Mythic", buyPrice = 30000, incomePerSec = 550, color = Color3.fromRGB(255, 70, 180), mutationChance = 0.18 },
	{ name = "Divine", buyPrice = 150000, incomePerSec = 2400, color = Color3.fromRGB(255, 245, 200), mutationChance = 0.18 },
}

-- The cast: 36 character recipes. family picks the blocky body plan in CharacterFactory;
-- features are two short notes describing the distinguishing parts built from the accent colour.
GameConfig.Cast = {
	-- Common
	{ name = "Wet Floor Sign", tier = "Common", family = "Sign", color = Color3.fromRGB(255, 210, 40), accent = Color3.fromRGB(40, 40, 40), features = { "own puddle disc", "warning triangle face" } },
	{ name = "Expired Yogurt Cup", tier = "Common", family = "Cup", color = Color3.fromRGB(255, 200, 210), accent = Color3.fromRGB(230, 120, 140), features = { "bulging lid", "drips" } },
	{ name = "Moldy Muffin", tier = "Common", family = "Food", color = Color3.fromRGB(140, 90, 50), accent = Color3.fromRGB(90, 160, 70), features = { "fungus crown", "green spots" } },
	{ name = "Soggy Cereal Box", tier = "Common", family = "Food", color = Color3.fromRGB(240, 150, 50), accent = Color3.fromRGB(200, 110, 30), features = { "soggy sagging corners", "spoon" } },
	{ name = "Possessed Parking Cone", tier = "Common", family = "Sign", color = Color3.fromRGB(255, 120, 30), accent = Color3.fromRGB(255, 240, 240), features = { "glowing eyes", "little horns" } },
	{ name = "Sticky Flypaper Fairy", tier = "Common", family = "Critter", color = Color3.fromRGB(230, 170, 60), accent = Color3.fromRGB(120, 90, 30), features = { "spiral wings", "stuck flies" } },
	-- Uncommon
	{ name = "Roomba With A Knife", tier = "Uncommon", family = "Machine", color = Color3.fromRGB(190, 195, 200), accent = Color3.fromRGB(120, 125, 130), features = { "round disc body", "taped knife" } },
	{ name = "Radical Garden Gnome", tier = "Uncommon", family = "Critter", color = Color3.fromRGB(200, 50, 50), accent = Color3.fromRGB(240, 230, 210), features = { "tiny picket sign", "beard" } },
	{ name = "Rusty Clippy", tier = "Uncommon", family = "Tech", color = Color3.fromRGB(160, 160, 165), accent = Color3.fromRGB(140, 90, 60), features = { "bent paperclip body", "one big eye" } },
	{ name = "Vengeful Vending Machine", tier = "Uncommon", family = "Machine", color = Color3.fromRGB(200, 40, 40), accent = Color3.fromRGB(180, 220, 240), features = { "glass front with snacks", "claw arm" } },
	{ name = "Turbo Hamster Wheel", tier = "Uncommon", family = "Vehicle", color = Color3.fromRGB(40, 190, 190), accent = Color3.fromRGB(220, 220, 220), features = { "big wheel body", "motion lines" } },
	{ name = "Sentient Bubble Tea", tier = "Uncommon", family = "Cup", color = Color3.fromRGB(210, 180, 140), accent = Color3.fromRGB(60, 40, 30), features = { "boba pearls inside", "straw antenna" } },
	-- Rare
	{ name = "Inflatable Tube Man", tier = "Rare", family = "Sign", color = Color3.fromRGB(230, 60, 60), accent = Color3.fromRGB(255, 220, 60), features = { "tall wavy body", "flailing arms" } },
	{ name = "Grandma Turbo", tier = "Rare", family = "Vehicle", color = Color3.fromRGB(190, 160, 230), accent = Color3.fromRGB(230, 90, 120), features = { "rocket wheelchair", "scarf" } },
	{ name = "Caffeinated Cactus", tier = "Rare", family = "Plant", color = Color3.fromRGB(70, 170, 80), accent = Color3.fromRGB(120, 80, 50), features = { "coffee-cup head", "jitter lines" } },
	{ name = "Pirate Fax Machine", tier = "Rare", family = "Machine", color = Color3.fromRGB(40, 60, 120), accent = Color3.fromRGB(240, 240, 230), features = { "paper tongue", "eye patch" } },
	{ name = "Kung Fu Kettle", tier = "Rare", family = "Food", color = Color3.fromRGB(170, 180, 190), accent = Color3.fromRGB(200, 40, 40), features = { "headband", "steam puffs" } },
	{ name = "Vampire Umbrella", tier = "Rare", family = "Ghost", color = Color3.fromRGB(40, 20, 25), accent = Color3.fromRGB(180, 30, 40), features = { "fanged canopy", "cape collar" } },
	-- Epic
	{ name = "Disco Potato", tier = "Epic", family = "Food", color = Color3.fromRGB(210, 215, 225), accent = Color3.fromRGB(90, 90, 100), features = { "mirror-ball facets", "sunglasses" } },
	{ name = "Neon Ninja Noodle", tier = "Epic", family = "Snack", color = Color3.fromRGB(240, 255, 60), accent = Color3.fromRGB(30, 30, 30), features = { "glowing ramen swirl", "katana" } },
	{ name = "Celestial Sushi Roll", tier = "Epic", family = "Food", color = Color3.fromRGB(250, 245, 235), accent = Color3.fromRGB(255, 140, 60), features = { "orbits a tiny sun", "star sprinkles" } },
	{ name = "Mech Mozzarella", tier = "Epic", family = "Machine", color = Color3.fromRGB(255, 245, 205), accent = Color3.fromRGB(200, 170, 60), features = { "robot arms", "cheese pull" } },
	{ name = "Ghost Pepper DJ", tier = "Epic", family = "Plant", color = Color3.fromRGB(220, 50, 40), accent = Color3.fromRGB(255, 160, 40), features = { "headphones", "flame hair" } },
	{ name = "Haunted Slot Machine", tier = "Epic", family = "Machine", color = Color3.fromRGB(130, 60, 180), accent = Color3.fromRGB(230, 220, 120), features = { "three skull reels", "lever arm" } },
	-- Legendary
	{ name = "Buff Goldfish", tier = "Legendary", family = "Sea", color = Color3.fromRGB(255, 140, 50), accent = Color3.fromRGB(255, 220, 180), features = { "tank top", "flexing arms" } },
	{ name = "Temporal Tuba", tier = "Legendary", family = "Machine", color = Color3.fromRGB(200, 160, 70), accent = Color3.fromRGB(120, 200, 220), features = { "rewind swirls", "clock face" } },
	{ name = "Drama Laser Llama", tier = "Legendary", family = "Critter", color = Color3.fromRGB(255, 130, 180), accent = Color3.fromRGB(90, 220, 255), features = { "laser shades", "dramatic scarf" } },
	{ name = "Tsunami Toucan", tier = "Legendary", family = "Sea", color = Color3.fromRGB(40, 160, 220), accent = Color3.fromRGB(255, 200, 40), features = { "wave crest beak", "surfboard" } },
	{ name = "King Crab Accountant", tier = "Legendary", family = "Sea", color = Color3.fromRGB(210, 70, 50), accent = Color3.fromRGB(255, 215, 80), features = { "tiny crown", "calculator claw" } },
	-- Mythic
	{ name = "Solar Samurai Squirrel", tier = "Mythic", family = "Critter", color = Color3.fromRGB(255, 200, 60), accent = Color3.fromRGB(255, 120, 40), features = { "golden armour", "sun crest" } },
	{ name = "Velvet Void Vortex", tier = "Mythic", family = "Ghost", color = Color3.fromRGB(35, 20, 50), accent = Color3.fromRGB(150, 80, 220), features = { "cape", "swirling core" } },
	{ name = "Chrono Cheeseburger", tier = "Mythic", family = "Food", color = Color3.fromRGB(210, 160, 80), accent = Color3.fromRGB(120, 180, 90), features = { "clock bun", "orbiting fries" } },
	{ name = "Moonlight Milkshake Kraken", tier = "Mythic", family = "Sea", color = Color3.fromRGB(200, 180, 235), accent = Color3.fromRGB(240, 240, 255), features = { "tentacles", "glowing moon cherry" } },
	-- Divine
	{ name = "The Blue Screen", tier = "Divine", family = "Tech", color = Color3.fromRGB(30, 120, 255), accent = Color3.fromRGB(220, 235, 255), features = { "floating CRT", "FATAL ERROR face" } },
	{ name = "Ascended Shopping Cart", tier = "Divine", family = "Vehicle", color = Color3.fromRGB(255, 240, 190), accent = Color3.fromRGB(255, 215, 90), features = { "golden wheels", "halo" } },
	{ name = "Seraphim Server Rack", tier = "Divine", family = "Tech", color = Color3.fromRGB(235, 250, 255), accent = Color3.fromRGB(80, 220, 240), features = { "angel wings and halo", "glowing screens" } },
}

-- Mutations in order of power. weight is the relative spawn weight among mutation rolls; Void is the rarest.
GameConfig.Mutations = {
	{ name = "Golden", multiplier = 3, weight = 40 },
	{ name = "Diamond", multiplier = 5, weight = 25 },
	{ name = "Glitch", multiplier = 8, weight = 15 },
	{ name = "Rainbow", multiplier = 10, weight = 10 },
	{ name = "Cosmic", multiplier = 12, weight = 6 },
	{ name = "Void", multiplier = 15, weight = 4 },
}

-- Every economy knob in one place. Times are seconds, money is dollars.
GameConfig.Economy = {
	StartCash = 50,
	StartPads = 6,
	MaxPads = 10,
	ConveyorSpawnInterval = 4,
	IncomeTick = 1,
	TsunamiPeriod = 90,
	TsunamiWarning = 10,
	TsunamiSweep = 8,
	LockDuration = 60,
	LockCooldown = 90,
	StolenCarrySpeedFactor = 0.75,
	RebirthCostFactor = 15, -- rebirth cost = factor x current total income rate
	RebirthIncomeMultiplier = 1.5,
}

-- Lookups, built once at require time.
local tierByName = {}
for index, tier in ipairs(GameConfig.Tiers) do
	tier.index = index
	tierByName[tier.name] = tier
end

local mutationByName = {}
local totalWeight = 0
for index, mutation in ipairs(GameConfig.Mutations) do
	mutation.index = index
	mutationByName[mutation.name] = mutation
	totalWeight += mutation.weight
end

GameConfig.CastByTier = {}
for _, recipe in ipairs(GameConfig.Cast) do
	local list = GameConfig.CastByTier[recipe.tier]
	if not list then
		list = {}
		GameConfig.CastByTier[recipe.tier] = list
	end
	table.insert(list, recipe)
end

function GameConfig.GetTier(name: string)
	return tierByName[name]
end

function GameConfig.GetMutation(name: string)
	return mutationByName[name]
end

-- Roll a mutation for a spawning character of the given tier. Returns a mutation table or nil.
-- rng is optional (defaults to math.random); pass a Random.new() for seeded rolls.
-- chanceBonus adds to the tier's base chance (Lucky Charm upgrades).
function GameConfig.RollMutation(tierName: string, rng: Random?, chanceBonus: number?)
	local tier = tierByName[tierName]
	if not tier then
		return nil
	end
	local roll = if rng then rng:NextNumber() else math.random()
	if roll >= tier.mutationChance + (chanceBonus or 0) then
		return nil
	end
	local pick = (if rng then rng:NextNumber() else math.random()) * totalWeight
	for _, mutation in ipairs(GameConfig.Mutations) do
		pick -= mutation.weight
		if pick <= 0 then
			return mutation
		end
	end
	return GameConfig.Mutations[#GameConfig.Mutations]
end

return GameConfig
