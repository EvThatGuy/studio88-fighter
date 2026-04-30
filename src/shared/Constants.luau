--!strict
-- Shared tycoon constants. Read by both server and client modules.
-- Bump DATASTORE_VERSION when changing PlayerData shape; load() must migrate.

local Constants = {}

Constants.DATASTORE_VERSION = "v1"
Constants.DATASTORE_NAME = "PlayerData_" .. Constants.DATASTORE_VERSION

-- Currency tick: every 1s grant `baseIncomePerTick * upgradeMult * passMult`.
Constants.TICK_SECONDS = 1
Constants.BASE_INCOME_PER_TICK = 1

-- Upgrade tiers. Index = tier (1..5). Each entry: {cost, incomeMult}.
-- Cost is what player pays to ENTER that tier from the previous one.
-- incomeMult is the cumulative multiplier on BASE_INCOME_PER_TICK at that tier.
Constants.UPGRADE_TIERS = {
    {cost = 0,      incomeMult = 1},   -- Tier 1 (default, no cost)
    {cost = 250,    incomeMult = 2},   -- Tier 2
    {cost = 1000,   incomeMult = 5},   -- Tier 3
    {cost = 5000,   incomeMult = 12},  -- Tier 4
    {cost = 20000,  incomeMult = 30},  -- Tier 5
    {cost = 100000, incomeMult = 80},  -- Tier 6 (capstone)
}

-- Daily login streak rewards. Index = day-streak (1..30+). Day 1 = 500 coins.
-- Beyond 30, cap at the day-30 reward.
Constants.DAILY_BONUS_BY_STREAK = {
    [1] = 500,
    [2] = 750,
    [3] = 1000,
    [4] = 1500,
    [5] = 2000,
    [6] = 3000,
    [7] = 5000,
    [14] = 15000,
    [21] = 25000,
    [30] = 50000,
}

-- Game Pass IDs (placeholder; replace with real assetIds after creating in
-- Creator Hub). The server only reads these, never trusts client-claimed
-- ownership.
Constants.GAME_PASSES = {
    STARTER_PACK = 0,    -- 2x income for 30 minutes after first server-touch
    VIP = 0,             -- 1.5x permanent
    PREMIUM = 0,         -- 3x permanent + AFK auto-collect
}

Constants.GAME_PASS_MULT = {
    STARTER_PACK_DURATION_SEC = 30 * 60,
    STARTER_PACK_MULT = 2.0,
    VIP_MULT = 1.5,
    PREMIUM_MULT = 3.0,
}

-- Leaderboard refresh interval (server side). Lifetime coins are the metric.
Constants.LEADERBOARD_REFRESH_SEC = 10
Constants.LEADERBOARD_TOP_N = 10

-- Per-tier plot art. Foundation Material + Color paints visible progression
-- so a tier-5 plot looks unmistakably wealthier than a tier-1 plot at a glance.
-- Indexed identically to UPGRADE_TIERS.
Constants.TIER_PLOT_ART = {
    [1] = {material = Enum.Material.Concrete,     color = Color3.fromRGB( 20,  17,  31)}, -- raw concrete
    [2] = {material = Enum.Material.Slate,        color = Color3.fromRGB( 38,  30,  56)}, -- slate
    [3] = {material = Enum.Material.SmoothPlastic,color = Color3.fromRGB( 64,  48,  92)}, -- painted
    [4] = {material = Enum.Material.Marble,       color = Color3.fromRGB(112,  84, 156)}, -- marble
    [5] = {material = Enum.Material.Marble,       color = Color3.fromRGB(184, 124, 220)}, -- bright marble
    [6] = {material = Enum.Material.Neon,         color = Color3.fromRGB(255,  46, 136)}, -- neon pink capstone
}

return Constants
