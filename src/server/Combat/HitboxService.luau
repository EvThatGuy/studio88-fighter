--!strict
-- Server-authoritative hitbox detection. The CombatService asks for a
-- spatial query in front of an attacker's HumanoidRootPart; this module
-- runs the query, filters by team / friendly-fire rules, and returns the
-- victim characters that overlap.
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

local function characterOf(part: BasePart): Model?
    local model = part:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then
        return model
    end
    return nil
end

-- Run a one-shot box query in front of the attacker. Returns a list of
-- {character, humanoid, victimUserId} for every distinct opponent
-- character that overlaps. Excludes the attacker themselves.
function HitboxService.queryPunchTargets(attacker: Player): {{character: Model, humanoid: Humanoid, victimUserId: number}}
    local results = {}
    local character = attacker.Character
    if not character then return results end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return results end

    local origin = hrp.CFrame * CFrame.new(Constants.HITBOX_OFFSET)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.MaxParts = 32

    local seenUserIds: {[number]: true} = {}
    local parts = workspace:GetPartBoundsInBox(origin, Constants.HITBOX_SIZE, params)
    for _, part in ipairs(parts) do
        local victimChar = characterOf(part)
        if victimChar then
            local victimPlayer = Players:GetPlayerFromCharacter(victimChar)
            if victimPlayer and victimPlayer ~= attacker and not seenUserIds[victimPlayer.UserId] then
                seenUserIds[victimPlayer.UserId] = true
                local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    table.insert(results, {
                        character = victimChar,
                        humanoid = humanoid,
                        victimUserId = victimPlayer.UserId,
                    })
                end
            end
        end
    end
    return results
end

return HitboxService
