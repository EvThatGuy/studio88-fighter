--!strict
-- Studio 88 Fighter — shared type definitions. Bump
-- Constants.DATASTORE_VERSION whenever PlayerData shape changes; DataStore
-- migrations key off the prior version.

-- Combat ────────────────────────────────────────────────────────────────

export type FighterClassId = string -- references Constants.CLASSES key

export type CombatPhase = "idle" | "attacking" | "blocking" | "stunned" | "dodging"

export type StaminaState = {
    current: number,
    max: number,
    regenPerSec: number,
}

export type HitboxSpec = {
    size: Vector3,
    offset: Vector3,         -- relative to HumanoidRootPart CFrame
    durationSec: number,
}

export type DamageEvent = {
    attackerUserId: number,
    victimUserId: number,
    rawDamage: number,
    blocked: boolean,
    finalDamage: number,
    unix: number,
}

-- Match ─────────────────────────────────────────────────────────────────

export type MatchPhase = "lobby" | "countdown" | "active" | "results"

export type MatchState = {
    phase: MatchPhase,
    mapId: string?,
    startUnix: number?,
    endUnix: number?,
    participants: {number},     -- userIds in current match
    scores: {[number]: number}, -- userId -> KO count
}

-- Persistent player data ────────────────────────────────────────────────
-- Fighter-specific shape. Tycoon fields (coins, lifetimeCoins, upgradeTier,
-- pets, rebirths, etc.) are gone. Money / shop systems will reappear in
-- Phase 4 when monetization is wired.

export type PlayerData = {
    schemaVersion: string,          -- mirrors Constants.DATASTORE_VERSION
    selectedClass: FighterClassId,  -- last-picked class; persists across sessions
    xp: number,
    xpLevel: number,
    wins: number,
    losses: number,
    knockouts: number,              -- lifetime KO count; drives leaderboard
    matchesPlayed: number,
    streak: number,                 -- daily-login streak
    lastLoginUnix: number,
    lastLogoutUnix: number?,
    redeemedDevProducts: {[string]: boolean}?, -- {[PurchaseId] = true} idempotency
}

export type LeaderboardRow = {
    userId: number,
    name: string,
    knockouts: number,
}

-- Remote map. Each entry corresponds to a name in Remotes.luau and is the
-- typed handle returned from Remotes.get() / Remotes.waitFor().
export type RemoteMap = {
    -- Combat (client → server requests)
    PunchRequest: RemoteEvent,
    BlockRequest: RemoteEvent,
    DodgeRequest: RemoteEvent,
    AbilityRequest: RemoteEvent,
    -- Combat (server → client replication)
    HitLanded: RemoteEvent,         -- payload {attackerUserId, victimUserId, finalDamage, blocked}
    StaminaUpdated: RemoteEvent,    -- server → client; payload {current, max}
    CombatPhaseChanged: RemoteEvent,-- server → client; payload {phase: CombatPhase, sourceUserId}
    -- Class selection
    SelectClass: RemoteEvent,       -- client → server; payload {classId}
    ClassSelected: RemoteEvent,     -- server → client; payload {classId}
    GetClasses: RemoteFunction,     -- client → server; returns class registry snapshot
    -- Match flow
    MatchStateChanged: RemoteEvent, -- server → ALL; payload MatchState
    GetMatchState: RemoteFunction,  -- client → server; returns current MatchState
    -- Generic notifications
    NotificationToast: RemoteEvent, -- server → client; payload {kind, title, body}
    -- Daily retention
    DailyBonusGranted: RemoteEvent, -- server → client; payload {streak, xpReward}
    -- Monetization
    GetPassOwnership: RemoteFunction, -- returns {[passKey]: boolean}
    PassPurchased: RemoteEvent,
}

return {}
