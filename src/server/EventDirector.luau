-- EventDirector: ONE rotating event state machine. Between events a 25-40 s countdown
-- shows on the banner; events run 20 s and never overlap the tsunami sweep.
--   GoldenHour: income x2 for everyone (Economy consults IncomeMultiplier())
--   MutationStorm: every spawn mutated, better mutation weights (Conveyor flag)
--   BeltRush: 2 s spawns, belt speed x1.5 (Conveyor flags)

local Remotes = require(script.Parent.Remotes)
local Conveyor = require(script.Parent.Conveyor)
local Tsunami = require(script.Parent.Tsunami)

local EventDirector = {}

local EVENTS = { "GoldenHour", "MutationStorm", "BeltRush" }
local NAMES = { GoldenHour = "GOLDEN HOUR", MutationStorm = "MUTATION STORM", BeltRush = "BELT RUSH" }
local EVENT_DURATION = 20

local currentKind: string? = nil
local nextKind: string = EVENTS[1]
local countdown = 0

function EventDirector.CurrentEvent(): string?
	return currentKind
end

function EventDirector.IncomeMultiplier(): number
	return if currentKind == "GoldenHour" then 2 else 1
end

function EventDirector.NextEventCountdown(): number
	return countdown
end

function EventDirector.RollNextEvent(): string
	return EVENTS[math.random(1, #EVENTS)]
end

function EventDirector.BeginEvent(kind: string)
	currentKind = kind
	Remotes.Banner:FireAllClients(string.format("%s! (%ds)", NAMES[kind], EVENT_DURATION))
	if kind == "MutationStorm" then
		Conveyor.SetMutationStorm(true)
	elseif kind == "BeltRush" then
		Conveyor.SetBeltRush(true)
		Conveyor.SetBeltSpeedMultiplier(1.5)
	end
end

function EventDirector.EndEvent()
	Conveyor.SetMutationStorm(false)
	Conveyor.SetBeltRush(false)
	Conveyor.SetBeltSpeedMultiplier(1)
	currentKind = nil
	Remotes.Banner:FireAllClients("The bazaar calms down...")
end

function EventDirector.StartEventDirector()
	task.spawn(function()
		while true do
			nextKind = EventDirector.RollNextEvent()
			for t = math.random(25, 40), 1, -1 do
				countdown = t
				Remotes.Banner:FireAllClients(string.format("NEXT EVENT: %s in %ds", NAMES[nextKind], t))
				task.wait(1)
			end
			countdown = 0
		 -- Never overlap the tsunami sweep (or its recede): wait until the coast is clear.
			while Tsunami.IsSweeping() or Tsunami.NextSweepAt() - os.clock() < EVENT_DURATION + 2 do
				Remotes.Banner:FireAllClients(string.format("NEXT EVENT: %s starting...", NAMES[nextKind]))
				task.wait(1)
			end
			EventDirector.BeginEvent(nextKind)
			task.wait(EVENT_DURATION)
			EventDirector.EndEvent()
		end
	end)
end

return EventDirector
