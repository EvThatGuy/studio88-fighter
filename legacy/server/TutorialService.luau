--!strict
-- First-time User Experience (FTUE) tracker. Roblox's official analytics
-- docs (creator-docs production/analytics/retention.md) name FTUE as one
-- of the three D1 levers; Studio 88's dropper-conveyor metaphor isn't
-- legible to a 2026 first-time player without contextual prompts.
--
-- This module is a tiny event router: other server modules call
-- TutorialService.advance(userId, "step_id") when the player crosses a
-- milestone (touched plot, first coin spawned, first collect, etc.).
-- We bump the player's tutorialStep counter, fire AnalyticsService funnel
-- events for the dashboard, and push TutorialStepReached so the HUD can
-- show the next contextual tooltip.
--
-- Steps are ordered (Constants.FTUE_STEPS); we never decrement and we
-- never skip ahead. If a player hits step 4 before step 3 fires (e.g. a
-- bug), step 3 is implicitly satisfied -- highest-step-reached wins.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local TutorialService = {}

-- Reverse lookup: step id -> 1-based index in FTUE_STEPS
local stepIndex: {[string]: number} = {}
for i, id in ipairs(Constants.FTUE_STEPS) do
    stepIndex[id] = i
end

function TutorialService.advance(userId: number, stepId: string)
    local data = DataStore.getCached(userId)
    if not data then return end
    local idx = stepIndex[stepId]
    if not idx then
        warn("[TutorialService] unknown step id: " .. stepId)
        return
    end
    if (data.tutorialStep or 0) >= idx then return end -- already past this step
    data.tutorialStep = idx
    local player = Players:GetPlayerByUserId(userId)
    if player then
        pcall(function()
            remotes.TutorialStepReached:FireClient(player, idx, stepId)
        end)
        -- Roblox-official onboarding funnel event so the FTUE drop-off
        -- shows up in the Creator Hub analytics retention dashboard.
        pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(player, idx, stepId)
        end)
    end
    print(string.format("[TutorialService] %d advanced to step %d (%s)",
        userId, idx, stepId))
end

remotes.GetTutorialStep.OnServerInvoke = function(player: Player): number
    local data = DataStore.getCached(player.UserId)
    return (data and data.tutorialStep) or 0
end

print(string.format("[TutorialService] ready (%d steps tracked)",
    #Constants.FTUE_STEPS))

return TutorialService
