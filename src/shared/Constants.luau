--!strict
-- Shared tycoon constants. Read by both server and client modules.
-- Bump DATASTORE_VERSION when changing PlayerData shape; load() must migrate.

local Constants = {}

Constants.DATASTORE_VERSION = "v7"
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

-- Rebirth shop. Per /research-engineer brief #5: rebirth needs a SINK
-- to drive long-tail D30 retention -- otherwise rebirth #4 feels
-- identical to rebirth #1 and the dopamine curve flat-lines. Players
-- earn 1 Rebirth Token per rebirth, spent on permanent unlocks that
-- meta-stack with the rebirth perma-mult.
--
-- Each item is a ONE-TIME purchase (idempotent flag in PlayerData.
-- purchasedRebirthUpgrades). Multipliers stack multiplicatively in
-- CurrencyManager.multiplierFor() via REBIRTH_SHOP_MULT_TOTAL().
--
-- Token economy: 50 rebirths cap * 1 token each = 50 tokens lifetime.
-- All items below sum to 47 tokens so a fully-rebirthed player can
-- unlock everything with 3 tokens to spare.
Constants.REBIRTH_TOKEN_PER_REBIRTH = 1

Constants.REBIRTH_SHOP_ITEMS = {
    {id = "spark",       title = "SPARK BOOST",      cost = 2,  multAdd = 0.05, sub = "+5% income forever"},
    {id = "tempo",       title = "TEMPO TURBINE",    cost = 5,  multAdd = 0.15, sub = "+15% income forever"},
    {id = "crystal",     title = "CAPSTONE CRYSTAL", cost = 10, multAdd = 0.30, sub = "+30% income forever"},
    {id = "studio88",    title = "STUDIO 88 BRAND",  cost = 15, multAdd = 0.60, sub = "+60% income forever"},
    {id = "ascension",   title = "GTA6 ASCENSION",   cost = 25, multAdd = 1.00, sub = "+100% income forever"},
}

Constants.REBIRTH_SHOP_ORDER = {"spark", "tempo", "crystal", "studio88", "ascension"}

-- Pets system. Per /research-engineer brief #2: highest interest signal
-- on DevForum 3792525 + the standard hatch-egg gacha loop is the most
-- common tycoon retention extension. Pets are a status object that
-- survives rebirth -> drives D7/D30 by giving long-tail players a
-- collection to fill that doesn't reset on prestige.
--
-- 2026 compliance gate (RESEARCH-ENGINEER FLAGGED, mandatory):
-- PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted
-- must gate any Robux-cost egg with random outcome (Belgium / NL / EU
-- under-13). Coin-cost eggs are unrestricted -- our v1 ships coin-only
-- to skip the policy gate entirely; Robux eggs are a future phase
-- behind an explicit allowed-region check.
--
-- Rarity tiers + drop weights (out of 100). Higher rarity = lower drop
-- chance + higher income multiplier. Each pet adds its multiplier to a
-- per-player "petBonus" stack in CurrencyManager.multiplierFor().
Constants.PET_RARITIES = {
    common    = { weight = 60, mult = 0.05 }, -- +5%
    uncommon  = { weight = 25, mult = 0.15 }, -- +15%
    rare      = { weight = 10, mult = 0.40 }, -- +40%
    epic      = { weight = 4,  mult = 1.00 }, -- +100%
    legendary = { weight = 1,  mult = 2.50 }, -- +250%
}

Constants.PET_RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary" }
Constants.PET_RARITY_COLORS = {
    common = {200, 200, 200},   -- grey
    uncommon = {110, 220, 110}, -- green
    rare = {110, 160, 240},     -- blue
    epic = {200, 100, 240},     -- purple
    legendary = {255, 176, 0},  -- amber
}

-- Pet roster. Each pet has: id (stable key), name (player-facing), rarity.
-- rarity drives drop chance + income multiplier; collection metadata.
-- Add pets here freely; they auto-appear in egg pool + inventory UI.
Constants.PETS = {
    -- common
    {id = "studio_doodle", name = "Studio Doodle",   rarity = "common"},
    {id = "rusty_bot",     name = "Rusty Bot",       rarity = "common"},
    {id = "neon_moth",     name = "Neon Moth",       rarity = "common"},
    -- uncommon
    {id = "clip_phantom",  name = "Clip Phantom",    rarity = "uncommon"},
    {id = "amber_fox",     name = "Amber Fox",       rarity = "uncommon"},
    -- rare
    {id = "render_raven",  name = "Render Raven",    rarity = "rare"},
    {id = "pink_panther",  name = "Pink Panther",    rarity = "rare"},
    -- epic
    {id = "studio_88_owl", name = "Studio 88 Owl",   rarity = "epic"},
    {id = "vault_wolf",    name = "Vault Wolf",      rarity = "epic"},
    -- legendary
    {id = "gta6_dragon",   name = "GTA6 Dragon",     rarity = "legendary"},
}

-- Egg costs. v1 = coin-only to skip PolicyService gating. Robux egg
-- ships in a future phase with PolicyService.ArePaidRandomItemsRestricted
-- check. Higher tiers bias the rarity roll toward better outcomes.
Constants.PET_EGGS = {
    {id = "starter_egg",  name = "STARTER EGG",  cost = 500,    biasTier = 1, sub = "early-game pulls"},
    {id = "standard_egg", name = "STANDARD EGG", cost = 5000,   biasTier = 2, sub = "skips most commons"},
    {id = "luxury_egg",   name = "LUXURY EGG",   cost = 50000,  biasTier = 3, sub = "rare-or-better skewed"},
}

-- biasTier shifts the rarity weight table. Each tier adds bonus weight to
-- higher rarities so a luxury egg is meaningfully better than a starter.
-- Math: effectiveWeight[r] = baseWeight[r] * (1 + (biasTier-1) * RARITY_BIAS[r])
Constants.PET_RARITY_BIAS = {
    common = -0.4,    -- starter: 60w; std: 36w; luxury: 12w
    uncommon = 0.0,   -- flat
    rare = 0.5,       -- starter: 10w; std: 15w; luxury: 20w
    epic = 1.5,       -- starter: 4w; std: 10w; luxury: 16w
    legendary = 2.0,  -- starter: 1w; std: 3w; luxury: 5w
}

-- How many pets a player can have EQUIPPED at once (active boost).
-- Inventory cap is much larger -- pets in the box don't apply boosts
-- but contribute to collection completion bonus.
Constants.PET_MAX_EQUIPPED = 3
Constants.PET_INVENTORY_CAP = 100

-- Collection completion bonus. Once a player has at least 1 of every
-- pet in PETS, they get a permanent 50% income multiplier ("Collector
-- Set"). Encourages repeated egg pulls past the equip slots.
Constants.PET_COLLECTION_COMPLETE_BONUS = 0.5

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

-- FTUE step ids. Server tracks these via AnalyticsService:LogOnboardingFunnelStepEvent
-- (Roblox creator-docs analytics/retention.md names FTUE as one of the
-- three D1 levers). Order matters; client only highlights the next step.
Constants.FTUE_STEPS = {
    "01_arrived_at_plot",
    "02_first_coin_spawned",
    "03_first_coin_collected",
    "04_first_upgrade",
    "05_eligible_for_rebirth",
}

-- AFK auto-collect sweep interval (Premium pass perk). Coin lifetime is
-- 30s on the conveyor, so a 2s sweep means worst-case 2s of unclaimed
-- coins on screen for a Premium player -- effectively instant feedback
-- without per-frame iteration cost.
Constants.AFK_AUTOCOLLECT_INTERVAL_SEC = 2

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
