--!strict
-- Shared tycoon constants. Read by both server and client modules.
-- Bump DATASTORE_VERSION when changing PlayerData shape; load() must migrate.

local Constants = {}

Constants.DATASTORE_VERSION = "v4"
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

-- Display metadata for the in-game Passes shop modal. Keys MUST match the
-- keys in GAME_PASSES above. Suggested R$ prices are the *target* — set
-- the real price when creating the Pass in Creator Hub. Suggested mapping
-- per @starmexxx Apr 26 playbook.
Constants.GAME_PASS_DISPLAY = {
    STARTER_PACK = {
        title = "STARTER PACK",
        accent = "amber",
        priceRobux = 75,
        copy = "2x income for 30 minutes",
        sub = "best for new players catching up to friends",
    },
    VIP = {
        title = "VIP",
        accent = "pink",
        priceRobux = 250,
        copy = "1.5x income forever",
        sub = "stacks with all other multipliers",
    },
    PREMIUM = {
        title = "PREMIUM",
        accent = "cyan",
        priceRobux = 600,
        copy = "3x income forever + AFK auto-collect",
        sub = "earn while logged out -- the no-brainer for daily players",
    },
}

-- Display order in the Passes modal. Cheapest first so the eye scans cost
-- before commitment.
Constants.GAME_PASS_ORDER = { "STARTER_PACK", "VIP", "PREMIUM" }

Constants.GAME_PASS_MULT = {
    STARTER_PACK_DURATION_SEC = 30 * 60,
    STARTER_PACK_MULT = 2.0,
    VIP_MULT = 1.5,
    PREMIUM_MULT = 3.0,
}

-- Leaderboard refresh interval (server side). Lifetime coins are the metric.
Constants.LEADERBOARD_REFRESH_SEC = 10
Constants.LEADERBOARD_TOP_N = 10

-- Sound design hooks. Set IDs to a `rbxassetid://N` numeric string after
-- picking assets from Roblox's free sound library. Until set, `playSound`
-- on the client no-ops gracefully (no error, just silence).
Constants.SOUND_IDS = {
    tier_up = "",       -- played on successful upgrade
    daily_bonus = "",   -- played when streak reward lands
    purchase_fail = "", -- played when prompt rejects (insufficient_coins)
}

-- Rebirth (prestige) system. Resets coins + upgradeTier back to baseline but
-- grants a permanent income multiplier. Standard tycoon retention loop:
-- after capstone tier 6, players hit a wall; rebirth gives them a fresh
-- climb with a tangibly stronger income engine. Without rebirth, average
-- session past first capstone collapses by ~80%.
--
-- Eligibility: must have earned at least REBIRTH_MIN_LIFETIME_COINS lifetime
-- AND be at MAX tier (= #UPGRADE_TIERS). After rebirth, lifetimeCoins is
-- preserved (drives leaderboard) but `coins` resets to 0 and `upgradeTier` to 1.
--
-- Multiplier formula: rebirthMult = 1 + (rebirths * REBIRTH_BONUS_PER).
-- 1st rebirth = 1.10x perma, 2nd = 1.20x, ... 10th = 2.00x. Stacks
-- multiplicatively with tier mult + Game Pass mults inside multiplierFor().
Constants.REBIRTH_MIN_LIFETIME_COINS = 100000  -- gate first rebirth at the tier-6 capstone earnings tier
Constants.REBIRTH_BONUS_PER = 0.10             -- +10% perma per rebirth
Constants.REBIRTH_MAX = 50                     -- soft cap so the formula doesn't blow up

-- Promo codes. David tweets / DMs / pins a code; players type it for free
-- coins. This is the cheapest top-of-funnel retention loop available
-- because every code post forces players to log in within the validity
-- window, and every redeemer adds a follow / DM signal.
--
-- Format per code (string -> table):
--   reward = number of coins granted on redeem
--   expiresUnix = os.time() cutoff after which redeem returns "expired"
--                 (nil = never expires; only use for permanent welcome codes)
--   maxGlobalRedemptions = optional global cap; nil = unlimited per player
--
-- Codes are case-insensitive on input (server uppercases). Keep them short
-- and SMS-typeable. ALWAYS uppercase the keys here.
--
-- Per-player redemption history lives in PlayerData.redeemedCodes; one
-- redeem per code per player is enforced server-side regardless of what
-- the global cap says.
Constants.CODES = {
    LAUNCH = {
        reward = 5000,
        expiresUnix = nil,                         -- evergreen; pinned welcome
        maxGlobalRedemptions = nil,
    },
    STARMEXXX = {
        reward = 2500,
        expiresUnix = nil,                         -- credits the playbook
        maxGlobalRedemptions = nil,
    },
    GTA6HYPE = {
        reward = 7500,
        expiresUnix = 1763510400,                  -- 2025-11-18 (day before GTA6)
        maxGlobalRedemptions = nil,
    },
    THANKYOU = {
        reward = 10000,
        expiresUnix = nil,
        maxGlobalRedemptions = 1000,               -- first 1000 only; FOMO ramp
    },
}

-- Per-player input rate limit on RequestRedeemCode (anti-spam).
Constants.CODE_REDEEM_COOLDOWN_SEC = 3

-- Daily quests. The single highest-leverage feature for D1 / sessions-per-day
-- per the 2026 Roblox algorithm (RFY now rewards 24h return rate over CCU,
-- per the Dec 2025 Recommended-For-You DevForum announcement). Rotation is
-- date-deterministic so every server in this universe shows the same 3
-- quests on the same day -- gives David one "today's quests" Discord post
-- per day and gives players a shared reason to log in.
--
-- Pool format: each entry has id (stable string key for DataStore), kind
-- (one of the QuestKind enum below), target (number to reach), reward
-- (coins on claim), label (player-facing text using {target} placeholder).
--
-- Selection: 3 quests per day, deterministic from the Unix-day index. We
-- pick one easy / one medium / one hard so every player has a 5-min ask
-- and a 30-min ask in the same day.
--
-- Adding new quests: append to the appropriate tier table; the rotation
-- auto-includes them from the next UTC midnight.
Constants.QUEST_KIND = {
    EARN_COINS_TODAY = "earn_coins_today",
    COLLECT_DROPS_TODAY = "collect_drops_today",
    TIER_UPS_TODAY = "tier_ups_today",
    REDEEM_CODE_TODAY = "redeem_code_today",
    REBIRTH_TODAY = "rebirth_today",
    PLAY_MINUTES_TODAY = "play_minutes_today",
}

Constants.DAILY_QUEST_POOL_EASY = {
    {id = "earn_500",     kind = Constants.QUEST_KIND.EARN_COINS_TODAY,    target = 500,   reward = 250,  label = "Earn {target} coins"},
    {id = "collect_25",   kind = Constants.QUEST_KIND.COLLECT_DROPS_TODAY, target = 25,    reward = 200,  label = "Collect {target} coin drops"},
    {id = "play_5min",    kind = Constants.QUEST_KIND.PLAY_MINUTES_TODAY,  target = 5,     reward = 300,  label = "Play for {target} minutes"},
    {id = "redeem_code",  kind = Constants.QUEST_KIND.REDEEM_CODE_TODAY,   target = 1,     reward = 500,  label = "Redeem any code (try LAUNCH)"},
}

Constants.DAILY_QUEST_POOL_MEDIUM = {
    {id = "earn_5000",    kind = Constants.QUEST_KIND.EARN_COINS_TODAY,    target = 5000,  reward = 1500, label = "Earn {target} coins"},
    {id = "tier_up_2",    kind = Constants.QUEST_KIND.TIER_UPS_TODAY,      target = 2,     reward = 1500, label = "Upgrade tier {target} times"},
    {id = "collect_200",  kind = Constants.QUEST_KIND.COLLECT_DROPS_TODAY, target = 200,   reward = 1200, label = "Collect {target} coin drops"},
    {id = "play_15min",   kind = Constants.QUEST_KIND.PLAY_MINUTES_TODAY,  target = 15,    reward = 1500, label = "Play for {target} minutes"},
}

Constants.DAILY_QUEST_POOL_HARD = {
    {id = "earn_50000",   kind = Constants.QUEST_KIND.EARN_COINS_TODAY,    target = 50000, reward = 8000, label = "Earn {target} coins"},
    {id = "tier_up_4",    kind = Constants.QUEST_KIND.TIER_UPS_TODAY,      target = 4,     reward = 7500, label = "Upgrade tier {target} times"},
    {id = "rebirth_1",    kind = Constants.QUEST_KIND.REBIRTH_TODAY,       target = 1,     reward = 10000,label = "Rebirth at least once today"},
    {id = "play_45min",   kind = Constants.QUEST_KIND.PLAY_MINUTES_TODAY,  target = 45,    reward = 8000, label = "Play for {target} minutes"},
}

-- Custom analytics event names. Centralized so we have ONE place to bump
-- versions / rename funnel steps without grepping the codebase. Pulled
-- via AnalyticsService:LogCustomEvent in 2026 instead of legacy CustomEvent.
Constants.ANALYTICS_EVENTS = {
    QUEST_CLAIMED = "QuestClaimed",
    QUEST_PROGRESSED = "QuestProgressed",
    REBIRTH_GRANTED = "RebirthGranted",
    CODE_REDEEMED = "CodeRedeemed",
    PASS_PURCHASED = "PassPurchased",
    TIER_UP = "TierUp",
    EVENT_ACTIVE = "EventActive",
}

-- Limited-time events. Cross-server consistent via os.time(). Each entry:
--   id              stable string key for analytics + HUD copy
--   name            player-facing headline ("WEEKEND 2X")
--   sub             one-line description
--   multiplier      stacks multiplicatively with tier + rebirth + passes
--   startUnix       inclusive
--   endUnix         exclusive
--   color           "pink" | "cyan" | "amber" | "purple" -- HUD accent
--
-- Schedule recurring weekend events as separate entries (one per weekend).
-- For permanent recurring events we'd add a cron-like helper; for v1 the
-- explicit list keeps the feature small and lets David tweet a precise
-- countdown ("2x ends in 4h 22m").
--
-- Times are UTC. Weekend = Fri 16:00 UTC -> Mon 04:00 UTC (covers all
-- timezones for both Friday-evening US and Sunday-evening AU windows).
Constants.LIVE_EVENTS = {
    -- launch weekend (placeholder — actual launch date TBD)
    { id = "launch_weekend", name = "LAUNCH 2X", sub = "double income all weekend",
      multiplier = 2.0, startUnix = 1746115200, endUnix = 1746374400, color = "pink" },
    -- GTA6 hype week (one week before launch)
    { id = "gta6_hype_week", name = "GTA6 HYPE WEEK", sub = "3x income leading to launch",
      multiplier = 3.0, startUnix = 1762905600, endUnix = 1763510400, color = "amber" },
}

-- How often the EventService scans for active events. 30s is plenty —
-- events tick over at minute granularity from the player's perspective.
Constants.EVENT_SCAN_INTERVAL_SEC = 30

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
