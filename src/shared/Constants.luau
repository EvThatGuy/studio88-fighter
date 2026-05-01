--!strict
-- Shared tycoon constants. Read by both server and client modules.
-- Bump DATASTORE_VERSION when changing PlayerData shape; load() must migrate.

local Constants = {}

Constants.DATASTORE_VERSION = "v15"
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

-- Pet Boost. A timed 2x multiplier on the equipped-pets contribution to
-- the income stack, purchasable for coins. Stacks with everything (event
-- mult, passes, etc) but ONLY multiplies the pet portion -- so the more
-- pets a player has equipped, the more value they get from a boost. This
-- is the "max your loadout before clicking" loop.
--
-- Coin cost scales with current tier so it stays meaningful late-game.
-- One boost active at a time; buying again extends remaining time.
Constants.PET_BOOST = {
    DURATION_SEC = 900,             -- 15 minutes
    MULTIPLIER = 2.0,
    COST_PER_TIER = {               -- coin cost indexed by upgradeTier
        [1] = 500,
        [2] = 2500,
        [3] = 12000,
        [4] = 60000,
        [5] = 250000,
        [6] = 1000000,
    },
}

-- Streak egg grants. When the daily login streak hits one of these days,
-- ALSO grant a free hatch from the specified egg (no coin cost) on top
-- of the coin bonus. Adds a tangible long-term incentive to maintain
-- the streak and compounds with the pets gacha.
Constants.STREAK_EGG_GRANTS = {
    [7]  = "standard_egg",
    [14] = "luxury_egg",
    [30] = "luxury_egg",
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

-- Achievements. Unlock signals are evaluated against current PlayerData
-- after any system mutates it (currency tick, hatch, rebirth, code, etc).
-- Each unlock fires AchievementUnlocked to the client (toast + Roblox push
-- notification via BadgeService:AwardBadge if badgeId > 0). Coin or token
-- rewards are credited atomically with the unlock write.
--
-- 2026 RFY signal: BadgeService awards trigger Roblox-native push
-- notifications on the player's device, which is the most reliable
-- 24h-return-rate driver Roblox exposes to creators. badgeId = 0 means
-- "no badge wired yet" -- David creates the badge in Creator Hub then
-- pastes the assetId here. Service no-ops the AwardBadge call when 0.
--
-- trigger one of:
--   "lifetime_coins"            data.lifetimeCoins >= threshold
--   "rebirths"                  data.rebirths >= threshold
--   "tier"                      data.upgradeTier >= threshold
--   "pets_owned"                #data.pets >= threshold
--   "pets_collection_complete"  every Constants.PETS id present in inventory
--   "streak"                    data.streak >= threshold
--   "quests_claimed_total"      data.questsClaimedTotal >= threshold
--   "codes_redeemed_count"      count(keys(data.redeemedCodes)) >= threshold
--   "rebirth_shop_owned"        count(keys(data.purchasedRebirthUpgrades)) >= threshold
Constants.ACHIEVEMENT_TRIGGERS = {
    LIFETIME_COINS = "lifetime_coins",
    REBIRTHS = "rebirths",
    TIER = "tier",
    PETS_OWNED = "pets_owned",
    PETS_COLLECTION_COMPLETE = "pets_collection_complete",
    STREAK = "streak",
    QUESTS_CLAIMED_TOTAL = "quests_claimed_total",
    CODES_REDEEMED_COUNT = "codes_redeemed_count",
    REBIRTH_SHOP_OWNED = "rebirth_shop_owned",
}

Constants.ACHIEVEMENTS = {
    -- Currency milestones
    {id = "first_dollar",      name = "First Dollar",       desc = "Earn your first coin",
     trigger = "lifetime_coins", threshold = 1,                rewardCoins = 100,    rewardTokens = 0, badgeId = 0},
    {id = "thousandaire",      name = "Thousandaire",       desc = "Earn 1,000 coins lifetime",
     trigger = "lifetime_coins", threshold = 1000,             rewardCoins = 500,    rewardTokens = 0, badgeId = 0},
    {id = "millionaire",       name = "Millionaire",        desc = "Earn 1M coins lifetime",
     trigger = "lifetime_coins", threshold = 1000000,          rewardCoins = 5000,   rewardTokens = 0, badgeId = 0},
    {id = "billionaire",       name = "Billionaire",        desc = "Earn 1B coins lifetime",
     trigger = "lifetime_coins", threshold = 1000000000,       rewardCoins = 50000,  rewardTokens = 1, badgeId = 0},
    -- Tier milestones
    {id = "tier_climber",      name = "Tier Climber",       desc = "Reach Tier 3",
     trigger = "tier",           threshold = 3,                rewardCoins = 500,    rewardTokens = 0, badgeId = 0},
    {id = "max_tier",          name = "Penthouse Suite",    desc = "Reach the capstone tier",
     trigger = "tier",           threshold = 6,                rewardCoins = 5000,   rewardTokens = 0, badgeId = 0},
    -- Rebirth milestones
    {id = "first_rebirth",     name = "First Rebirth",      desc = "Prestige once",
     trigger = "rebirths",       threshold = 1,                rewardCoins = 0,      rewardTokens = 1, badgeId = 0},
    {id = "prestige_master",   name = "Prestige Master",    desc = "Rebirth 10 times",
     trigger = "rebirths",       threshold = 10,               rewardCoins = 0,      rewardTokens = 5, badgeId = 0},
    {id = "rebirth_legend",    name = "Rebirth Legend",     desc = "Rebirth 50 times",
     trigger = "rebirths",       threshold = 50,               rewardCoins = 0,      rewardTokens = 25, badgeId = 0},
    -- Pets
    {id = "first_hatch",       name = "First Friend",       desc = "Hatch your first pet",
     trigger = "pets_owned",     threshold = 1,                rewardCoins = 200,    rewardTokens = 0, badgeId = 0},
    {id = "pet_enthusiast",    name = "Pet Enthusiast",     desc = "Hatch 10 pets",
     trigger = "pets_owned",     threshold = 10,               rewardCoins = 2000,   rewardTokens = 0, badgeId = 0},
    {id = "pet_collector",     name = "Pet Collector",      desc = "Own one of every pet",
     trigger = "pets_collection_complete", threshold = 1,      rewardCoins = 0,      rewardTokens = 1, badgeId = 0},
    -- Daily engagement (the 24h-return drivers)
    {id = "daily_devotee",     name = "Daily Devotee",      desc = "7-day login streak",
     trigger = "streak",         threshold = 7,                rewardCoins = 2500,   rewardTokens = 0, badgeId = 0},
    {id = "weekly_warrior",    name = "Monthly Maxer",      desc = "30-day login streak",
     trigger = "streak",         threshold = 30,               rewardCoins = 25000,  rewardTokens = 1, badgeId = 0},
    {id = "quest_grinder",     name = "Quest Grinder",      desc = "Claim 10 daily quests",
     trigger = "quests_claimed_total", threshold = 10,         rewardCoins = 1500,   rewardTokens = 0, badgeId = 0},
    -- Long-tail
    {id = "code_collector",    name = "Code Collector",     desc = "Redeem 3 codes",
     trigger = "codes_redeemed_count", threshold = 3,          rewardCoins = 1000,   rewardTokens = 0, badgeId = 0},
    {id = "shopaholic",        name = "Shopaholic",         desc = "Buy 3 rebirth shop items",
     trigger = "rebirth_shop_owned", threshold = 3,            rewardCoins = 0,      rewardTokens = 2, badgeId = 0},
}

-- Friend Codes / Referrals. Each player auto-generates a sharable code on
-- first join. New players can redeem someone else's code (one-shot per
-- account) and BOTH parties get a coin bonus. Compounds with the existing
-- promo CodesService -- if a redeemed string isn't a known promo code,
-- it's checked against the friend-code registry next.
--
-- Cross-session lookup uses a separate DataStore keyed by friend code
-- (FRIEND_CODE_REGISTRY_NAME) -> referrer userId, so referrals work even
-- when the referrer is offline. Referrer's bonus is queued via DataStore
-- update on their record (their next login granular-claims it).
Constants.FRIEND_CODE_REGISTRY_NAME = "FriendCodeRegistry_v1"
Constants.FRIEND_CODE_PREFIX = "STUD-"           -- distinguishes from promo codes
Constants.FRIEND_CODE_SUFFIX_LENGTH = 5           -- 5-char alphanumeric suffix
Constants.REFERRAL_REFERRER_BONUS = 1000          -- per referral, no cap
Constants.REFERRAL_REFERRED_BONUS = 2000          -- one-shot for the new player

-- Live Activity Feed. A cross-server-synced ticker of recent "wow"
-- moments (legendary hatches, rebirth milestones, aura unlocks, code
-- redemptions). MemoryStoreService SortedMap keyed by unix-timestamp so
-- recency comes for free. Ticker shows latest 8 entries on the HUD.
--
-- Each event has:
--   kind     "hatch_legendary" | "rebirth_milestone" | "aura_unlock" | "achievement_legendary"
--   userName display name (FilterStringAsync'd before broadcast)
--   detail   short string ("hatched Cosmic Drake", "rebirth #25", "Apex aura", etc)
--   unix     server time the event fired
Constants.ACTIVITY_FEED = {
    SORTED_MAP_KEY = "Studio88ActivityFeed_v1",
    ENTRY_TTL_SEC = 600,        -- 10 min; SortedMap auto-expires
    MAX_ENTRIES_VISIBLE = 8,
    POLL_INTERVAL_SEC = 15,     -- server polls Memory every 15s; client polls server every 30s
    -- Rebirth milestones that emit feed events. Anything else gets filtered.
    REBIRTH_MILESTONES = {1, 5, 10, 25, 50, 100},
}

-- Cosmetic Auras. Equip a single aura that attaches a Trail to the player's
-- character. Visible to all other players in the server -- creates social
-- proof ("that player has the legendary aura, I want it") and TikTok-bait
-- screenshots. No income effect; pure flex.
--
-- Unlock triggers reuse the achievement predicate vocab:
--   "lifetime_coins"        data.lifetimeCoins >= unlockValue
--   "rebirths"              data.rebirths >= unlockValue
--   "pets_collection_complete"  every PET id present (unlockValue ignored)
--   "achievements_unlocked" count(data.achievementsUnlocked) >= unlockValue
--
-- Trail params (lifetime, widths, transparency) are global -- per-aura
-- variation is via color only. Keeps the system simple and predictable.
Constants.AURA_TRAIL = {
    LIFETIME = 0.6,                -- seconds the trail particles persist
    WIDTH_START = 1.2,             -- studs at attachment0
    WIDTH_END = 0.0,               -- studs at attachment1 (fades to point)
    TRANSPARENCY_START = 0.05,
    TRANSPARENCY_END = 1.0,
    ATTACHMENT_OFFSET = Vector3.new(0, 1.5, 0), -- top attachment offset from HRP
    -- bottom attachment is at -OFFSET (mirrored)
}

Constants.AURA_TRIGGERS = {
    LIFETIME_COINS = "lifetime_coins",
    REBIRTHS = "rebirths",
    PETS_COLLECTION_COMPLETE = "pets_collection_complete",
    ACHIEVEMENTS_UNLOCKED = "achievements_unlocked",
}

Constants.AURAS = {
    {id = "spark",      name = "Spark",      desc = "your first taste of style",
     color = {255, 240, 180}, rarity = "common",
     trigger = "lifetime_coins", unlockValue = 10000},
    {id = "ember",      name = "Ember",      desc = "warm, hungry, unstoppable",
     color = {255, 130,  30}, rarity = "common",
     trigger = "lifetime_coins", unlockValue = 100000},
    {id = "frost",      name = "Frost",      desc = "the chill of your first prestige",
     color = {130, 200, 255}, rarity = "rare",
     trigger = "rebirths", unlockValue = 1},
    {id = "phoenix",    name = "Phoenix",    desc = "rise five times, burn brighter",
     color = {255,  60,  90}, rarity = "epic",
     trigger = "rebirths", unlockValue = 5},
    {id = "void",       name = "Void",       desc = "ten rebirths in, the universe answers",
     color = {120,  40, 200}, rarity = "epic",
     trigger = "rebirths", unlockValue = 10},
    {id = "galaxy",     name = "Galaxy",     desc = "twenty-five rebirths -- the cosmos is yours",
     color = {200, 130, 255}, rarity = "legendary",
     trigger = "rebirths", unlockValue = 25},
    {id = "eclipse",    name = "Eclipse",    desc = "complete the pet collection",
     color = {255, 207,  64}, rarity = "legendary",
     trigger = "pets_collection_complete", unlockValue = 1},
    {id = "apex",       name = "Apex",       desc = "every trophy on the wall",
     color = {255, 255, 255}, rarity = "legendary",
     trigger = "achievements_unlocked", unlockValue = 17},
}

-- Hourly Tribute. Targets the 2026 RFY signal #2 (sessions/user/day) by
-- giving players a reason to log in multiple times per day, separate from
-- the once-per-day Daily Login Bonus and the once-per-day Daily Quests.
--
-- Mechanic: a stack accrues every HOURLY_TRIBUTE_INTERVAL_SEC seconds up
-- to HOURLY_TRIBUTE_STACK_CAP. Player taps "claim" -> all stacks credited
-- as coins, scaled by current tier income mult so reward stays meaningful
-- as the player progresses. Cap means leaving for 5+ hours pays the same
-- as leaving for 4 -- the design forces "log in within 4 hours or leave
-- coins on the table" which moves the sessions/user/day metric.
Constants.HOURLY_TRIBUTE_INTERVAL_SEC = 3600
Constants.HOURLY_TRIBUTE_STACK_CAP = 4
Constants.HOURLY_TRIBUTE_BASE_REWARD = 500 -- multiplied by current tier incomeMult

-- Daily Spin Wheel. Once per UTC day, the player gets one free spin for
-- a random reward. Variable-reward interactive moment that drives
-- dopamine more reliably than the deterministic daily-login bonus.
-- Rewards are coin-only at low weights + special slots at higher weights;
-- weight tuned so the "exciting" rewards land roughly 1-in-5 spins.
--
-- Each segment has:
--   id        stable string for analytics + HUD
--   label     player-facing tag
--   color     {r,g,b} for the wheel slice
--   weight    relative probability (totals don't need to sum to anything)
--   reward    {kind, value} where kind in:
--             "coins"          coin amount = value scaled by tier mult
--             "rebirth_token"  flat number of tokens
--             "boost_seconds"  pet-boost duration extension (no cost)
--             "free_egg"       free hatch from value (eggId)
Constants.SPIN_SEGMENTS = {
    {id = "coins_small",  label = "+250c",          color = {180, 220, 255}, weight = 22,
     reward = {kind = "coins", value = 250}},
    {id = "coins_med",    label = "+1000c",         color = {130, 200, 255}, weight = 18,
     reward = {kind = "coins", value = 1000}},
    {id = "coins_big",    label = "+5000c",         color = {110, 220, 220}, weight = 12,
     reward = {kind = "coins", value = 5000}},
    {id = "coins_huge",   label = "+25000c",        color = {255, 207,  64}, weight = 6,
     reward = {kind = "coins", value = 25000}},
    {id = "boost_5m",     label = "+5m PetBoost",   color = {255, 176,   0}, weight = 8,
     reward = {kind = "boost_seconds", value = 300}},
    {id = "boost_15m",    label = "+15m PetBoost",  color = {255, 130,  60}, weight = 4,
     reward = {kind = "boost_seconds", value = 900}},
    {id = "free_starter", label = "FREE Starter Egg", color = {200, 255, 200}, weight = 10,
     reward = {kind = "free_egg", value = "starter_egg"}},
    {id = "free_standard",label = "FREE Standard Egg", color = {130, 220, 130}, weight = 5,
     reward = {kind = "free_egg", value = "standard_egg"}},
    {id = "free_luxury",  label = "FREE Luxury Egg", color = {255, 130, 200}, weight = 1,
     reward = {kind = "free_egg", value = "luxury_egg"}},
    {id = "rebirth_token",label = "+1 RebirthToken", color = {200, 130, 255}, weight = 3,
     reward = {kind = "rebirth_token", value = 1}},
}

-- Player Titles. Earned tags shown over the character (BillboardGui)
-- visible to all players. Pure flex; no income effect. Predicates reuse
-- the same vocabulary as achievements/auras so a single PlayerData scan
-- can determine eligibility.
--
-- triggers:
--   "lifetime_coins"            data.lifetimeCoins >= unlockValue
--   "rebirths"                  data.rebirths >= unlockValue
--   "pets_collection_complete"  every PETS id present (unlockValue ignored)
--   "achievements_unlocked"     count(data.achievementsUnlocked) >= unlockValue
--   "aura_equipped"             data.equippedAura == unlockValue (string)
Constants.PLAYER_TITLES = {
    {id = "newcomer",     name = "Newcomer",       color = {200, 200, 210},
     trigger = "lifetime_coins",          unlockValue = 0},
    {id = "thousandaire", name = "Thousandaire",   color = {180, 220, 255},
     trigger = "lifetime_coins",          unlockValue = 1000},
    {id = "millionaire",  name = "Millionaire",    color = {255, 207, 64},
     trigger = "lifetime_coins",          unlockValue = 1000000},
    {id = "billionaire",  name = "Billionaire",    color = {255, 130, 60},
     trigger = "lifetime_coins",          unlockValue = 1000000000},
    {id = "reborn",       name = "Reborn",         color = {130, 200, 255},
     trigger = "rebirths",                unlockValue = 1},
    {id = "ascended",     name = "Ascended",       color = {200, 130, 255},
     trigger = "rebirths",                unlockValue = 25},
    {id = "godlike",      name = "Godlike",        color = {255, 60, 90},
     trigger = "rebirths",                unlockValue = 50},
    {id = "collector",    name = "Pet Collector",  color = {110, 220, 110},
     trigger = "pets_collection_complete", unlockValue = 1},
    {id = "trophy_hunter", name = "Trophy Hunter", color = {255, 207, 64},
     trigger = "achievements_unlocked",   unlockValue = 10},
    {id = "completionist", name = "Completionist", color = {255, 255, 255},
     trigger = "achievements_unlocked",   unlockValue = 17},
    {id = "cosmic",       name = "Cosmic",         color = {200, 130, 255},
     trigger = "aura_equipped",           unlockValue = "galaxy"},
    {id = "apex",         name = "Apex Predator",  color = {255, 255, 255},
     trigger = "aura_equipped",           unlockValue = "apex"},
}

-- Visit Plot. Tap a leaderboard row to teleport to that player's plot.
-- See their pet stand, aura, title, etc -- the social-proof payoff for
-- the whole cosmetic system. Cooldown prevents abuse.
Constants.VISIT_COOLDOWN_SEC = 30
Constants.VISIT_HEIGHT_OFFSET = 8 -- studs above the foundation, so you don't clip in
Constants.VISIT_OWNER_TIP_COINS = 50  -- scaled by owner's tier mult; pos feedback for being visited

-- Squad Bonus. When the server has SQUAD_THRESHOLD or more concurrent
-- players, EVERYONE in that server gets a flat income multiplier. Gives
-- players a reason to stay in busier servers (Roblox session-length
-- signal) and compounds directly with Referrals (invite friends ->
-- friends join your server -> bonus activates for both of you).
Constants.SQUAD_BONUS = {
    THRESHOLD = 3,
    MULTIPLIER = 1.25,
}

-- Pet pity counter. Standard gacha mechanic: after PET_PITY_THRESHOLD
-- hatches WITHOUT a legendary roll, the next hatch is GUARANTEED to be
-- legendary (force-promotion). Counter resets on each legendary (whether
-- rolled or pity-forced). Hatched-via-fusion does NOT count toward pity
-- (fusion is its own deterministic system; counting it would let players
-- pity-farm by chain-fusing trash to commons to standards).
--
-- The published counter is what makes this a retention loop -- players
-- see "47 / 50, guaranteed legendary in 3 hatches" and chase the chain.
Constants.PET_PITY_THRESHOLD = 50

-- Pet fusion. Sacrifice N pets of the same rarity to mint 1 random pet of
-- the next rarity up. Solves the dead-dupe-inventory problem and gives
-- gacha-VRR a continuous engagement loop instead of a one-shot collection.
-- Legendary cannot be fused up (it's the cap). Equipped pets cannot be
-- consumed -- player must explicitly unequip first, prevents accidental
-- destruction of their best stat carrier.
Constants.PET_FUSE_COST = 3
Constants.PET_RARITY_PROMOTION = {
    common = "uncommon",
    uncommon = "rare",
    rare = "epic",
    epic = "legendary",
    -- legendary intentionally absent (cap)
}

-- How often a single user's achievement scan is allowed to run, regardless
-- of how many systems hook into it. Currency tick fires every 1s and
-- AchievementService is called from there, so without throttling we'd
-- evaluate 17 predicates every second per player. 5s is invisible to the
-- player and slashes work 80%.
Constants.ACHIEVEMENT_SCAN_THROTTLE_SEC = 5

-- Per-tier obelisk. A vertical glowing pillar above each plot foundation
-- that grows + brightens per tier. Visible from far across the map; the
-- "money skyscraper" you build through tier-ups. Compounds with the
-- foundation paint job (TIER_PLOT_ART) so high-tier plots are
-- unmistakable at TikTok-screenshot distance.
-- Indexed identically to UPGRADE_TIERS. Each entry: {height, width, color}.
Constants.TIER_OBELISK = {
    [1] = {height =  6, width = 1.5, color = Color3.fromRGB( 80,  80, 100)},  -- tiny gray rod
    [2] = {height = 10, width = 2.0, color = Color3.fromRGB(120, 120, 200)},  -- short blue
    [3] = {height = 16, width = 2.5, color = Color3.fromRGB(180, 100, 220)},  -- mid purple
    [4] = {height = 22, width = 3.0, color = Color3.fromRGB(220,  80, 200)},  -- tall pink
    [5] = {height = 28, width = 3.5, color = Color3.fromRGB(255, 180,  60)},  -- amber gold
    [6] = {height = 36, width = 4.0, color = Color3.fromRGB(255, 255, 255)},  -- white capstone
}

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
