--!strict
-- Server-authoritative hitbox detection. The CombatService asks for a
-- spatial query in front of an attacker's HumanoidRootPart; this module
-- runs the query, filters by team / friendly-fire rules, and returns
-- the victim characters that overlap. Includes NPCs (training dummies,
-- future bosses) — they have a Humanoid but no Player.
--
-- Phase 1 ports the elomala MuchachoHitbox-style flow into here under a
-- typed adapter. For now this is an OverlapParams query that's good
-- enough to validate the data path end-to-end.
--
-- IMPORTANT: never trust client-reported hit positions. The server runs
-- the query from the server's view of the attacker's CFrame.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local HitboxService = {}

export type HitTarget = {
    character: Model,
    humanoid: Humanoid,
    victimUserId: number?,    -- nil for NPC / dummy targets
}

local function characterOf(part: BasePart): Model?
    local model = part:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return model
    end
    return nil
end

function HitboxService.queryPunchTargets(attacker: Player): {HitTarget}
    local results: {HitTarget} = {}
    local character = attacker.Character
    if not character then return results end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return results end

    local origin = hrp.CFrame * CFrame.new(Constants.HITBOX_OFFSET)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.MaxParts = 32

    local seenChars: {[Model]: true} = {}
    local parts = workspace:GetPartBoundsInBox(origin, Constants.HITBOX_SIZE, params)
    for _, part in ipairs(parts) do
        local victimChar = characterOf(part)
        if victimChar and not seenChars[victimChar] then
            seenChars[victimChar] = true
            local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local victimPlayer = Players:GetPlayerFromCharacter(victimChar)
                if victimPlayer == attacker then
                    -- self-hit; skip (filter should already cover this, but
                    -- belt-and-braces in case the attacker's char is in two
                    -- places mid-respawn).
                else
                    table.insert(results, {
                        character = victimChar,
                        humanoid = humanoid,
                        victimUserId = victimPlayer and victimPlayer.UserId or nil,
                    })
                end
            end
        end
    end
    return results
end

return HitboxService
