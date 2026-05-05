--!strict
-- Studio 88 Fighter — shared constants. Read by both server and client.
-- Bump DATASTORE_VERSION when changing PlayerData shape; DataStore.load
-- runs migrations forward.
--
-- Tycoon-era constants (UPGRADE_TIERS, PET_*, REBIRTH_*, etc.) live in
-- legacy/server/ during the pivot. Anything we resurrect must be reviewed
-- and rewritten against the fighter PlayerData shape in Types.luau.

local Constants = {}

Constants.DATASTORE_VERSION = "fighter_v1"
Constants.DATASTORE_NAME = "PlayerData_" .. Constants.DATASTORE_VERSION

-- Combat tuning ─────────────────────────────────────────────────────────
-- Initial values are placeholder; tune in Phase 1 once the elomala combat
-- core is ported and a single class is playable end-to-end.

Constants.BASE_WALKSPEED = 16          -- Roblox default; per-class overrides in CLASSES below
Constants.BASE_JUMP_HEIGHT = 7.2

Constants.STAMINA_MAX = 100
Constants.STAMINA_REGEN_PER_SEC = 12   -- regen out of combat
Constants.STAMINA_REGEN_COMBAT = 4     -- regen while in combat
Constants.STAMINA_PUNCH_COST = 8
Constants.STAMINA_BLOCK_DRAIN_PER_SEC = 6
Constants.STAMINA_DODGE_COST = 25

Constants.PUNCH_DAMAGE = 8
Constants.BLOCK_DAMAGE_REDUCTION = 0.85 -- 85% damage absorbed when blocking
Constants.STUN_DURATION_SEC = 0.6
Constants.HITBOX_SIZE = Vector3.new(4, 5, 5)
Constants.HITBOX_OFFSET = Vector3.new(0, 0, -3) -- in front of HRP
Constants.HIT_RATE_LIMIT_PER_SEC = 6    -- server clamp on PunchRequest

-- Heavy attack (M2). Slower, higher damage, partially block-piercing,
-- longer stun. Telegraphs via M2_WINDUP_SEC so opponents can react.
Constants.M2_DAMAGE = 18
Constants.M2_BLOCK_DAMAGE_REDUCTION = 0.50  -- 50% absorbed (heavy partly pierces block)
Constants.M2_HITBOX_SIZE = Vector3.new(5, 6, 6)
Constants.M2_HITBOX_OFFSET = Vector3.new(0, 0, -3.5)
Constants.M2_WINDUP_SEC = 0.25      -- delay between cast and damage tick (telegraph)
Constants.M2_RECOVERY_SEC = 0.45    -- attacker locked in attacking_heavy after windup
Constants.M2_STUN_DURATION = 1.0    -- victim stun on heavy hit
Constants.STAMINA_M2_COST = 22

-- Slot-2 ability tuning. Per-spec stamina/cooldown live in AbilityLibrary;
-- timings + magnitudes that the CombatService modifier system consults
-- live here so balance changes don't require code edits.
Constants.PARRY_WINDOW_SEC = 0.5            -- Counter Stance: incoming-hit window
Constants.PARRY_ATTACKER_STUN_SEC = 1.2     -- attacker is counter-stunned on parry
Constants.IRON_SKIN_DURATION_SEC = 3.0      -- Iron Skin uptime
Constants.IRON_SKIN_REDUCTION = 0.5         -- multiplier on incoming damage during Iron Skin
Constants.WIND_STEP_DISTANCE = 14           -- studs forward
Constants.WIND_STEP_IFRAME_SEC = 0.25       -- invulnerable window after teleport

-- Class registry. Each class is a fighter style with distinct movement
-- and stamina behaviour. Abilities attach via AbilityRegistry per-class.
-- Phase 1 ships ONE class (Striker) end-to-end; the rest are reserved
-- entries to validate the data shape.
Constants.CLASSES = {
    Striker = {
        id = "striker",
        displayName = "Striker",
        walkspeed = 18,
        staminaMax = 100,
        punchDamage = 8,
        blurb = "balanced fighter; baseline reference class",
    },
    Bruiser = {
        id = "bruiser",
        displayName = "Bruiser",
        walkspeed = 14,
        staminaMax = 130,
        punchDamage = 11,
        blurb = "slow + heavy; big stamina pool",
    },
    Swift = {
        id = "swift",
        displayName = "Swift",
        walkspeed = 22,
        staminaMax = 80,
        punchDamage = 6,
        blurb = "fast + light; thin stamina",
    },
}
Constants.DEFAULT_CLASS = "Striker"

-- Match flow tuning ─────────────────────────────────────────────────────

Constants.LOBBY_MIN_PLAYERS = 2         -- start countdown at 2; play at 2+
Constants.LOBBY_COUNTDOWN_SEC = 15
Constants.MATCH_DURATION_SEC = 180      -- 3 min hard cap
Constants.MATCH_RESULTS_SEC = 10
Constants.RESPAWN_DELAY_SEC = 3

-- 1v1 Duel queue. Players opt in via K key; server pairs the first two
-- queued and runs an isolated duel concurrent with the deathmatch.
-- Duelists can only damage each other (CombatService gates), KOs route
-- to duel score not match score, lifetime stats still tick.
Constants.DUEL_KO_TARGET = 3            -- first to 3 KOs wins the duel
Constants.DUEL_DURATION_SEC = 90        -- hard time cap; higher score at expiry wins
Constants.DUEL_WIN_XP = 250
Constants.DUEL_LOSS_XP = 75
Constants.DUEL_RESULTS_DISPLAY_SEC = 5  -- how long the win/loss banner stays on the HUD

-- Map rotation. Phase 2 wires real maps; for now a single placeholder.
Constants.MAPS = {
    {id = "placeholder_arena", displayName = "Placeholder Arena"},
}

-- Game Pass IDs — placeholders. Replace with real assetIds after creating
-- the passes in Creator Hub. Server caches ownership per session via
-- GamePassService:UserOwnsGamePassAsync.
Constants.GAME_PASSES = {
    STARTER_PACK = 0,    -- TBD: small XP / cosmetic kit
    VIP = 0,             -- TBD: cosmetic + name color
    PREMIUM = 0,         -- TBD: cosmetic + early class access
}
Constants.GAME_PASS_ORDER = { "STARTER_PACK", "VIP", "PREMIUM" }

-- Dev products — placeholders. Replace with real productIds after creating.
Constants.DEV_PRODUCTS = {}
Constants.DEV_PRODUCT_ORDER = {}

-- Daily login retention. Genre-agnostic; same shape as the tycoon used.
-- Reward kind is "xp" not coins for the fighter.
Constants.DAILY_BONUS_XP_BY_STREAK = {
    [1] = 100,
    [2] = 150,
    [3] = 200,
    [4] = 300,
    [5] = 400,
    [6] = 600,
    [7] = 1000,    -- D7 anchor
    [14] = 2500,
    [21] = 5000,
    [30] = 10000,
}

-- XP track. Combat actions earn XP; XP feeds level + cosmetic unlocks.
-- Tune in Phase 4 alongside ability cooldown costs.
Constants.XP_REWARDS = {
    match_win = 250,
    match_loss = 100,
    knockout = 50,
    daily_login = 200,
    quest_claim = 300,
}

Constants.XP_LEVEL_THRESHOLDS = {
    [1] = 0,
    [2] = 100,
    [3] = 300,
    [4] = 700,
    [5] = 1500,
    [6] = 3000,
    [7] = 6000,
    [8] = 12000,
    [9] = 24000,
    [10] = 50000,
}

-- Anti-exploit caps ─────────────────────────────────────────────────────

-- Server clamps any client-reported position delta against this. If a
-- client claims to have moved more than MAX_MOVE_PER_SEC studs in 1s
-- between two reports, the server treats that as a teleport hack and
-- ignores the input.
Constants.MAX_MOVE_PER_SEC = 60

-- Per-RPC cooldowns. Server tracks last-fired time per (userId, rpc).
Constants.RPC_COOLDOWNS = {
    PunchRequest = 1 / Constants.HIT_RATE_LIMIT_PER_SEC, -- ≈ 0.16s
    HeavyAttackRequest = 0.7,
    BlockRequest = 0.05,
    DodgeRequest = 0.4,
    AbilityRequest = 0.1,    -- abilities have their own cooldown layer too
}

-- Sound design — empty until assets are picked from Roblox library.
Constants.SOUND_IDS = {
    hit = "",
    block = "",
    stun = "",
    match_start = "",
    match_end = "",
    level_up = "",
    daily_bonus = "",
}

return Constants
