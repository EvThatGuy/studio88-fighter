--!strict
-- Server-authoritative combat state machine. Owns the per-player
-- CombatPhase ("idle"/"attacking"/"blocking"/"stunned"/"dodging") and
-- adjudicates Punch/Block/Dodge requests against stamina + per-RPC
-- cooldowns.
--
-- Phase 1: ports elomala's combat flow into this adapter. For now this
-- is a minimal punch/block/stun loop using HitboxService + StaminaService.
-- Animations are intentionally absent (Roblox doesn't allow animation
-- sharing); we'll record / commission once the data path is solid.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent.Parent:WaitForChild("Leaderstats"))
local ClassRegistry = require(script.Parent:WaitForChild("ClassRegistry"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))
local HitboxService = require(script.Parent:WaitForChild("HitboxService"))

-- Lazy-required to avoid load-order coupling with Match/. CombatService
-- loads under the Combat folder before Match/ is loaded by Bootstrap.
local _matchService: any = nil
local function matchService(): any
    if not _matchService then
        local matchFolder = script.Parent.Parent:WaitForChild("Match", 5)
        if matchFolder then
            local mod = matchFolder:WaitForChild("MatchService", 5)
            if mod then _matchService = require(mod) end
        end
    end
    return _matchService
end

local _duelService: any = nil
local function duelService(): any
    if not _duelService then
        local matchFolder = script.Parent.Parent:WaitForChild("Match", 5)
        if matchFolder then
            local mod = matchFolder:FindFirstChild("DuelService")
            if mod then _duelService = require(mod) end
        end
    end
    return _duelService
end

local remotes = Remotes.get()

local CombatService = {}

-- per-player state
local phase: {[number]: string} = {}              -- userId -> CombatPhase
local stunUntil: {[number]: number} = {}          -- userId -> os.clock() unstun time
local lastRpc: {[number]: {[string]: number}} = {} -- userId -> {rpcName -> os.clock()}
-- Modifier deadlines applied by Slot-2 abilities. All are os.clock()
-- timestamps that gate damage in applyDamage. Set via the public
-- CombatService.setParry / setIronSkin / setIFrames functions called
-- from AbilityLibrary effects.
type Modifiers = { parryUntil: number?, ironSkinUntil: number?, iframeUntil: number? }
local modifiers: {[number]: Modifiers} = {}

local function modifiersFor(userId: number): Modifiers
    local m = modifiers[userId]
    if not m then
        m = {}
        modifiers[userId] = m
    end
    return m
end

local function setPhase(userId: number, newPhase: string)
    phase[userId] = newPhase
    -- broadcast to everyone so opponents can render the phase
    remotes.CombatPhaseChanged:FireAllClients({
        userId = userId,
        phase = newPhase,
    })
end

local function isStunned(userId: number): boolean
    return (stunUntil[userId] or 0) > os.clock()
end

local function rpcCooldownOk(userId: number, rpc: string, cooldownSec: number): boolean
    local now = os.clock()
    local map = lastRpc[userId]
    if not map then
        map = {}
        lastRpc[userId] = map
    end
    local last = map[rpc] or 0
    if now - last < cooldownSec then return false end
    map[rpc] = now
    return true
end

-- DamageOutcome tags how a hit landed: "hit" baseline, "blocked" when
-- guard reduced damage, "iframed" / "parried" when modifier prevented
-- damage entirely, "iron_skin" when the buff halved it. Callers use
-- this to decide whether to stun the victim, counter-stun the attacker,
-- or skip stun entirely.
local function applyDamage(
    victimUserId: number?,
    humanoid: Humanoid,
    rawDamage: number,
    blockReduction: number?
): (boolean, number, string)
    local now = os.clock()
    local mods = victimUserId and modifiers[victimUserId] or nil

    if mods then
        if mods.iframeUntil and now < mods.iframeUntil then
            return false, 0, "iframed"
        end
        if mods.parryUntil and now < mods.parryUntil then
            mods.parryUntil = nil  -- consume
            return false, 0, "parried"
        end
    end

    local reduction = blockReduction or Constants.BLOCK_DAMAGE_REDUCTION
    local blocked = victimUserId ~= nil and phase[victimUserId] == "blocking"
    local finalDamage = blocked and rawDamage * (1 - reduction) or rawDamage
    local outcome: string = blocked and "blocked" or "hit"

    if mods and mods.ironSkinUntil and now < mods.ironSkinUntil then
        finalDamage = finalDamage * Constants.IRON_SKIN_REDUCTION
        if not blocked then outcome = "iron_skin" end
    end

    humanoid:TakeDamage(finalDamage)
    return blocked, finalDamage, outcome
end

-- Damage gate consulted before applying a hit. Currently delegates to
-- the duel system (only duelists can damage each other, non-duelists
-- can't damage them, NPCs always allowed). Exposed so AbilityLibrary
-- AOE effects can also gate before iterating victims.
function CombatService.canDamage(attackerUserId: number, victimUserId: number?): boolean
    local duel = duelService()
    if duel then return duel.canDamage(attackerUserId, victimUserId) end
    return true
end

-- Public modifier setters called from AbilityLibrary effects.
function CombatService.setParry(userId: number, durationSec: number)
    modifiersFor(userId).parryUntil = os.clock() + durationSec
end

function CombatService.setIronSkin(userId: number, durationSec: number)
    modifiersFor(userId).ironSkinUntil = os.clock() + durationSec
end

function CombatService.setIFrames(userId: number, durationSec: number)
    modifiersFor(userId).iframeUntil = os.clock() + durationSec
end

-- Counter-stun helper: applied to attackers who connect on a parrying
-- victim. Used by both M1 and M2 handlers.
local function stunForCounter(userId: number, durationSec: number)
    stunUntil[userId] = os.clock() + durationSec
    setPhase(userId, "stunned")
    task.delay(durationSec, function()
        if (stunUntil[userId] or 0) <= os.clock() then
            setPhase(userId, "idle")
        end
    end)
end

remotes.PunchRequest.OnServerEvent:Connect(function(player: Player)
    if not rpcCooldownOk(player.UserId, "PunchRequest", Constants.RPC_COOLDOWNS.PunchRequest) then return end
    if isStunned(player.UserId) then return end
    if not StaminaService.tryConsume(player, Constants.STAMINA_PUNCH_COST) then return end

    local class = ClassRegistry.classFor(player.UserId)
    local rawDamage = class.punchDamage or Constants.PUNCH_DAMAGE

    setPhase(player.UserId, "attacking")
    local targets = HitboxService.queryPunchTargets(player)
    for _, target in ipairs(targets) do
        -- Duel gate: skip targets the attacker isn't allowed to damage
        -- under the active duel rules (e.g. attacker is dueling someone
        -- else, or victim is in a duel that doesn't include the attacker).
        if not CombatService.canDamage(player.UserId, target.victimUserId) then
            continue
        end
        local blocked, finalDamage, outcome = applyDamage(target.victimUserId, target.humanoid, rawDamage)
        remotes.HitLanded:FireAllClients({
            attackerUserId = player.UserId,
            victimUserId = target.victimUserId,         -- nil for NPCs
            victimCharacter = target.character,         -- always present; client looks up Head
            rawDamage = rawDamage,
            blocked = blocked,
            finalDamage = finalDamage,
            outcome = outcome,
        })
        if outcome == "parried" then
            -- Victim's Counter Stance ate the hit; attacker is counter-stunned.
            stunForCounter(player.UserId, Constants.PARRY_ATTACKER_STUN_SEC)
            -- Skip rest of loop iteration; no victim stun, no KO check (0 dmg).
        elseif not blocked and outcome ~= "iframed" and target.victimUserId then
            stunUntil[target.victimUserId] = os.clock() + Constants.STUN_DURATION_SEC
            setPhase(target.victimUserId, "stunned")
            local stunnedId = target.victimUserId
            task.delay(Constants.STUN_DURATION_SEC, function()
                if (stunUntil[stunnedId] or 0) <= os.clock() then
                    setPhase(stunnedId, "idle")
                end
            end)
        end
        -- Attribute KO if this damage dropped the target. NPCs (no userId)
        -- still die but don't credit a KO toward player stats. Parried /
        -- iframed hits did 0 damage so this naturally never trips.
        if target.humanoid.Health <= 0 and target.victimUserId then
            local duel = duelService()
            local routed = duel and duel.recordKO(player.UserId, target.victimUserId)
            if not routed then
                local match = matchService()
                if match then
                    match.recordKO(player.UserId, target.victimUserId)
                else
                    -- Fallback: tick lifetime KO directly.
                    local data = DataStore.getCached(player.UserId)
                    if data then
                        data.knockouts += 1
                        Leaderstats.refresh(player.UserId)
                    end
                end
            end
        end
    end
    -- attack window auto-resets after a short fixed time; tune in Phase 4
    task.delay(0.3, function()
        if phase[player.UserId] == "attacking" then
            setPhase(player.UserId, "idle")
        end
    end)
end)

-- Heavy attack (M2): slower than punch (~0.7s RPC cooldown), telegraphed
-- by a 0.25s windup before damage applies, partially block-pierces,
-- longer stun (1.0s vs 0.6s for punch). Damage scales off class.heavyDamage
-- if defined, else 2x class.punchDamage. Phase = "attacking_heavy" so
-- the client plays a different animation slot (M2_Heavy in catalog).
remotes.HeavyAttackRequest.OnServerEvent:Connect(function(player: Player)
    if not rpcCooldownOk(player.UserId, "HeavyAttackRequest", Constants.RPC_COOLDOWNS.HeavyAttackRequest) then return end
    if isStunned(player.UserId) then return end
    if not StaminaService.tryConsume(player, Constants.STAMINA_M2_COST) then return end

    setPhase(player.UserId, "attacking_heavy")

    local class = ClassRegistry.classFor(player.UserId)
    local rawDamage = class.heavyDamage or (class.punchDamage or Constants.PUNCH_DAMAGE) * 2

    -- Windup: damage doesn't apply until M2_WINDUP_SEC into the swing.
    -- This is the telegraph that lets opponents block / dodge.
    task.delay(Constants.M2_WINDUP_SEC, function()
        if not player.Parent then return end
        if phase[player.UserId] ~= "attacking_heavy" then return end -- got interrupted
        local targets = HitboxService.queryHeavyTargets(player)
        for _, target in ipairs(targets) do
            if not CombatService.canDamage(player.UserId, target.victimUserId) then
                continue
            end
            local blocked, finalDamage, outcome = applyDamage(
                target.victimUserId, target.humanoid, rawDamage,
                Constants.M2_BLOCK_DAMAGE_REDUCTION
            )
            remotes.HitLanded:FireAllClients({
                attackerUserId = player.UserId,
                victimUserId = target.victimUserId,
                victimCharacter = target.character,
                rawDamage = rawDamage,
                blocked = blocked,
                finalDamage = finalDamage,
                outcome = outcome,
            })
            if outcome == "parried" then
                stunForCounter(player.UserId, Constants.PARRY_ATTACKER_STUN_SEC)
            elseif not blocked and outcome ~= "iframed" and target.victimUserId then
                stunUntil[target.victimUserId] = os.clock() + Constants.M2_STUN_DURATION
                setPhase(target.victimUserId, "stunned")
                local stunnedId = target.victimUserId
                task.delay(Constants.M2_STUN_DURATION, function()
                    if (stunUntil[stunnedId] or 0) <= os.clock() then
                        setPhase(stunnedId, "idle")
                    end
                end)
            end
            if target.humanoid.Health <= 0 and target.victimUserId then
                local duel = duelService()
                local routed = duel and duel.recordKO(player.UserId, target.victimUserId)
                if not routed then
                    local match = matchService()
                    if match then
                        match.recordKO(player.UserId, target.victimUserId)
                    else
                        local data = DataStore.getCached(player.UserId)
                        if data then
                            data.knockouts += 1
                            Leaderstats.refresh(player.UserId)
                        end
                    end
                end
            end
        end
    end)

    -- Recovery: attacker stays in attacking_heavy through the windup +
    -- recovery so they can't immediately chain. Auto-reset to idle.
    task.delay(Constants.M2_WINDUP_SEC + Constants.M2_RECOVERY_SEC, function()
        if phase[player.UserId] == "attacking_heavy" then
            setPhase(player.UserId, "idle")
        end
    end)
end)

remotes.BlockRequest.OnServerEvent:Connect(function(player: Player, raising: any)
    if not rpcCooldownOk(player.UserId, "BlockRequest", Constants.RPC_COOLDOWNS.BlockRequest) then return end
    if isStunned(player.UserId) then return end
    if typeof(raising) ~= "boolean" then return end
    if raising then
        setPhase(player.UserId, "blocking")
    else
        if phase[player.UserId] == "blocking" then
            setPhase(player.UserId, "idle")
        end
    end
end)

remotes.DodgeRequest.OnServerEvent:Connect(function(player: Player)
    if not rpcCooldownOk(player.UserId, "DodgeRequest", Constants.RPC_COOLDOWNS.DodgeRequest) then return end
    if isStunned(player.UserId) then return end
    if not StaminaService.tryConsume(player, Constants.STAMINA_DODGE_COST) then return end
    setPhase(player.UserId, "dodging")
    task.delay(0.4, function()
        if phase[player.UserId] == "dodging" then
            setPhase(player.UserId, "idle")
        end
    end)
end)

Players.PlayerAdded:Connect(function(player)
    setPhase(player.UserId, "idle")
end)

Players.PlayerRemoving:Connect(function(player)
    phase[player.UserId] = nil
    stunUntil[player.UserId] = nil
    lastRpc[player.UserId] = nil
    modifiers[player.UserId] = nil
end)

return CombatService
