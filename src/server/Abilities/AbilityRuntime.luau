--!strict
-- Adjudicates AbilityRequest events: looks up the spec, checks class
-- match + cooldown + stamina, runs the effect, applies cooldown +
-- pushes the new cooldown deadline to the client for HUD rendering.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local ClassRegistry = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("ClassRegistry"))
local StaminaService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("StaminaService"))
local AbilityLibrary = require(script.Parent:WaitForChild("AbilityLibrary"))

local remotes = Remotes.get()

local AbilityRuntime = {}

-- per-player per-ability cooldown ledger: clockReady = os.clock() when
-- the ability becomes castable again.
local cooldowns: {[number]: {[string]: number}} = {}

local function readyAt(userId: number, abilityId: string): number
    local map = cooldowns[userId]
    if not map then return 0 end
    return map[abilityId] or 0
end

local function setReadyAt(userId: number, abilityId: string, when: number)
    local map = cooldowns[userId]
    if not map then
        map = {}
        cooldowns[userId] = map
    end
    map[abilityId] = when
end

-- Resolve a slot index for a given (classId, abilityId) so the client
-- can pick the right Ability_SlotN_Cast animation key. Returns 1 by
-- default if the ability doesn't appear in the class list (defensive).
local function resolveSlotIndex(classId: string, abilityId: string): number
    local list = AbilityLibrary.BY_CLASS[classId]
    if not list then return 1 end
    for i, s in ipairs(list) do
        if s.id == abilityId then return i end
    end
    return 1
end

remotes.AbilityRequest.OnServerEvent:Connect(function(player: Player, requestId: any)
    if typeof(requestId) ~= "string" then return end
    local now = os.clock()

    -- The client may pass either a raw ability id ("striker_dash") OR a
    -- positional slot ("ability_1"…"ability_4"). Resolve slots against
    -- the player's current class so the input layer doesn't need to
    -- know which abilities the player has.
    local abilityId = requestId
    local slotIndex = tonumber((requestId:match("^ability_(%d+)$")))
    if slotIndex then
        local class = ClassRegistry.classFor(player.UserId)
        local list = AbilityLibrary.BY_CLASS[class.id]
        if not list or not list[slotIndex] then return end
        abilityId = list[slotIndex].id
    end

    local spec = AbilityLibrary.BY_ID[abilityId]
    if not spec then return end

    -- Class-gate: only fire abilities the player's current class owns.
    local class = ClassRegistry.classFor(player.UserId)
    if spec.classId ~= class.id then return end

    -- Cooldown check.
    if now < readyAt(player.UserId, abilityId) then return end

    -- Stamina check (consume up-front).
    if not StaminaService.tryConsume(player, spec.staminaCost) then return end

    -- Run effect. If the effect returns false, refund stamina + skip
    -- cooldown (the cast was a "no-op", e.g. double-jump on the ground).
    local ok, result = pcall(spec.effect, player)
    if not ok then
        warn(string.format("[AbilityRuntime] effect %s threw: %s", abilityId, tostring(result)))
        StaminaService.add(player, spec.staminaCost)
        return
    end
    if result == false then
        StaminaService.add(player, spec.staminaCost)
        return
    end

    setReadyAt(player.UserId, abilityId, now + spec.cooldownSec)

    -- Animation broadcast: every client renders the cast animation on
    -- the caster's character. Slot index = position in the class's
    -- ability list so the client maps to Ability_SlotN_Cast in the
    -- AnimationCatalog.
    if not slotIndex then
        slotIndex = resolveSlotIndex(class.id, abilityId)
    end
    remotes.AbilityCast:FireAllClients({
        casterUserId = player.UserId,
        abilityId = abilityId,
        slotIndex = slotIndex,
    })
end)

-- Client query: what abilities + cooldowns does THIS player currently see?
remotes.GetClasses.OnServerInvoke = (function(prior)
    return function(player: Player)
        -- Preserve prior implementation (ClassRegistry sets one) and append
        -- ability info per class for HUD rendering.
        local base = typeof(prior) == "function" and prior(player) or {}
        local out = {}
        for _, entry in ipairs(base) do
            local copy = table.clone(entry)
            local list = AbilityLibrary.BY_CLASS[entry.key] or AbilityLibrary.BY_CLASS[entry.id]
            local cards = {}
            if list then
                for _, spec in ipairs(list) do
                    table.insert(cards, {
                        id = spec.id,
                        displayName = spec.displayName,
                        classId = spec.classId,
                        staminaCost = spec.staminaCost,
                        cooldownSec = spec.cooldownSec,
                        blurb = spec.blurb,
                    })
                end
            end
            copy.abilities = cards
            table.insert(out, copy)
        end
        return out
    end
end)(remotes.GetClasses.OnServerInvoke)

Players.PlayerRemoving:Connect(function(player)
    cooldowns[player.UserId] = nil
end)

return AbilityRuntime
