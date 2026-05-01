--!strict
-- DataStore wrapper: every read/write goes through pcall + retry-with-backoff.
-- Schema version pinned to Constants.DATASTORE_VERSION; migration logic lives
-- here so a single bump in Constants triggers a compatible upgrade.
--
-- Responsibilities:
--   - Load player data on join (with default fill on first-touch + migration
--     from older schema versions when the stored doc is on an older version)
--   - Save on leave (and on a periodic timer so a crash doesn't lose >60s)
--   - Expose a getter for in-memory cached data so the rest of the server
--     reads/writes synchronously without hitting DataStoreService

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Constants"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Types"))

local store = DataStoreService:GetDataStore(Constants.DATASTORE_NAME)

local DataStore = {}

local cache: {[number]: Types.PlayerData} = {}

local SAVE_RETRY_BUDGET = 4
local SAVE_BACKOFF_BASE = 1.5

local function emptyDailyQuests(): Types.DailyQuestState
    return { dateKey = "", progress = {}, claimed = {} }
end

local function defaultPlayerData(): Types.PlayerData
    return {
        coins = 0,
        lifetimeCoins = 0,
        upgradeTier = 1,
        lastLoginUnix = 0,
        streak = 0,
        starterPackPurchasedUnix = nil,
        rebirths = 0,
        rebirthTokens = 0,
        purchasedRebirthUpgrades = {},
        pets = {},
        equippedPetIds = {},
        redeemedCodes = {},
        dailyQuests = emptyDailyQuests(),
        tutorialStep = 0,
        achievementsUnlocked = {},
        questsClaimedTotal = 0,
        lastHourlyTributeUnix = 0,
        equippedAura = nil,
        friendCode = "",                  -- generated on first join by ReferralService
        referredBy = nil,
        referralCount = 0,
        pendingReferralBonusCoins = 0,
        petBoostExpiresUnix = 0,
        hatchesSinceLastLegendary = 0,
        equippedTitle = nil,
        schemaVersion = Constants.DATASTORE_VERSION,
    }
end

-- Migration table. Adding new versions: add `["vN"] = function(data) ... end`
-- that returns data with schemaVersion bumped to "vN+1", and bump
-- Constants.DATASTORE_VERSION + DATASTORE_NAME.
--
-- v1 -> v2: rebirth system.
-- v2 -> v3: codes system + redeemedCodes ledger.
-- v3 -> v4: daily quests. dailyQuests starts empty; DailyQuestService rolls
--           it forward to today's dateKey on first load post-migration.
local migrations: {[string]: (any) -> Types.PlayerData} = {
    ["v1"] = function(data: any): Types.PlayerData
        data.rebirths = data.rebirths or 0
        data.schemaVersion = "v2"
        return data
    end,
    ["v2"] = function(data: any): Types.PlayerData
        data.redeemedCodes = data.redeemedCodes or {}
        data.schemaVersion = "v3"
        return data
    end,
    ["v3"] = function(data: any): Types.PlayerData
        data.dailyQuests = data.dailyQuests or { dateKey = "", progress = {}, claimed = {} }
        data.schemaVersion = "v4"
        return data
    end,
    -- v4 -> v5: FTUE step tracker. Existing players are presumed past the
    -- tutorial; we set tutorialStep = #FTUE_STEPS so they don't get
    -- onboarding tooltips on next login.
    ["v4"] = function(data: any): Types.PlayerData
        data.tutorialStep = data.tutorialStep or #Constants.FTUE_STEPS
        data.schemaVersion = "v5"
        return data
    end,
    -- v5 -> v6: rebirth shop. Existing players keep their rebirths but
    -- start with zero rebirthTokens (we can't retroactively grant; would
    -- need a backfill ledger). Empty purchasedRebirthUpgrades.
    ["v5"] = function(data: any): Types.PlayerData
        data.rebirthTokens = data.rebirthTokens or 0
        data.purchasedRebirthUpgrades = data.purchasedRebirthUpgrades or {}
        data.schemaVersion = "v6"
        return data
    end,
    -- v6 -> v7: pets. Empty inventory + no equipped pets. Existing
    -- players have an immediate path to first hatch via the starter egg
    -- (500 coins) so the migration doesn't feel like a punishment.
    ["v6"] = function(data: any): Types.PlayerData
        data.pets = data.pets or {}
        data.equippedPetIds = data.equippedPetIds or {}
        data.schemaVersion = "v7"
        return data
    end,
    -- v7 -> v8: achievements. Existing players start with empty unlocks
    -- so AchievementService backfills retroactive milestones (millionaire,
    -- max-tier, first-rebirth, etc) on next login -- a free batch of
    -- coin/token rewards for legacy players, which is intentional. The
    -- monotonic questsClaimedTotal counter starts at 0 since we never
    -- recorded historical claims; players will hit "Quest Grinder" within
    -- ~10 days of normal play. Acceptable cost for keeping migration cheap.
    ["v7"] = function(data: any): Types.PlayerData
        data.achievementsUnlocked = data.achievementsUnlocked or {}
        data.questsClaimedTotal = data.questsClaimedTotal or 0
        data.schemaVersion = "v8"
        return data
    end,
    -- v8 -> v9: hourly tribute. lastHourlyTributeUnix = 0 means existing
    -- players come back to a full stack waiting (cap = 4). Intentional:
    -- legacy players see the new "claim" badge immediately and get a free
    -- chunk of coins, which is exactly the engagement signal the feature
    -- is designed to drive.
    ["v8"] = function(data: any): Types.PlayerData
        data.lastHourlyTributeUnix = data.lastHourlyTributeUnix or 0
        data.schemaVersion = "v9"
        return data
    end,
    -- v9 -> v10: cosmetic auras. equippedAura defaults nil; legacy players
    -- with prior progress will find the auras they qualify for already
    -- "unlocked" in the AURAS modal (predicate-based, no separate ledger).
    ["v9"] = function(data: any): Types.PlayerData
        if data.equippedAura == nil then data.equippedAura = nil end -- explicit no-op for clarity
        data.schemaVersion = "v10"
        return data
    end,
    -- v10 -> v11: friend codes. friendCode = "" means ReferralService will
    -- generate one on next login (lazy because we need a fresh registry
    -- collision check). referredBy stays nil so legacy players can still
    -- redeem someone's code one-shot for the bonus.
    ["v10"] = function(data: any): Types.PlayerData
        data.friendCode = data.friendCode or ""
        data.referralCount = data.referralCount or 0
        data.pendingReferralBonusCoins = data.pendingReferralBonusCoins or 0
        data.schemaVersion = "v11"
        return data
    end,
    -- v11 -> v12: pet boost. petBoostExpiresUnix = 0 means no boost active.
    -- Existing players see no behavioral change; the BUY BOOST UI just
    -- starts working on next login.
    ["v11"] = function(data: any): Types.PlayerData
        data.petBoostExpiresUnix = data.petBoostExpiresUnix or 0
        data.schemaVersion = "v12"
        return data
    end,
    -- v12 -> v13: pet pity. Counter starts at 0 for legacy players, who
    -- effectively get a fresh pity window (good thing -- their next 50
    -- hatches all have a guaranteed legendary at the end). Intentional.
    ["v12"] = function(data: any): Types.PlayerData
        data.hatchesSinceLastLegendary = data.hatchesSinceLastLegendary or 0
        data.schemaVersion = "v13"
        return data
    end,
    -- v13 -> v14: player titles. equippedTitle = nil; legacy players see
    -- "Newcomer" auto-eligible at lifetime>=0 plus whatever else they've
    -- progressed past, ready to equip on next session.
    ["v13"] = function(data: any): Types.PlayerData
        if data.equippedTitle == nil then data.equippedTitle = nil end
        data.schemaVersion = "v14"
        return data
    end,
}

local function migrate(raw: any): Types.PlayerData
    local data = raw or defaultPlayerData()
    local version = (typeof(data) == "table" and data.schemaVersion) or "unknown"
    -- run forward migrations in declared order until we hit current version
    local guard = 0
    while version ~= Constants.DATASTORE_VERSION and migrations[version] and guard < 10 do
        data = migrations[version](data)
        version = data.schemaVersion or "unknown"
        guard += 1
    end
    -- backfill any missing keys from default (forward-compat)
    local merged = defaultPlayerData()
    for k, v in pairs(data) do
        merged[k] = v
    end
    merged.schemaVersion = Constants.DATASTORE_VERSION
    return merged
end

local function tryGet(userId: number): Types.PlayerData
    local raw
    local lastErr
    for attempt = 1, SAVE_RETRY_BUDGET do
        local ok, result = pcall(function()
            return store:GetAsync(tostring(userId))
        end)
        if ok then
            raw = result
            break
        end
        lastErr = result
        task.wait(SAVE_BACKOFF_BASE ^ attempt)
    end
    if lastErr and not raw then
        warn("[DataStore] GetAsync failed for " .. userId .. ": " .. tostring(lastErr))
    end
    return migrate(raw)
end

local function trySave(userId: number, data: Types.PlayerData): boolean
    for attempt = 1, SAVE_RETRY_BUDGET do
        local ok, err = pcall(function()
            store:SetAsync(tostring(userId), data)
        end)
        if ok then return true end
        warn(string.format("[DataStore] SetAsync attempt %d failed for %d: %s",
            attempt, userId, tostring(err)))
        task.wait(SAVE_BACKOFF_BASE ^ attempt)
    end
    return false
end

function DataStore.getCached(userId: number): Types.PlayerData?
    return cache[userId]
end

function DataStore.requireCached(userId: number): Types.PlayerData
    local d = cache[userId]
    assert(d, "no cached PlayerData for userId " .. tostring(userId)
        .. "; called before onPlayerAdded?")
    return d
end

function DataStore.markDirty(userId: number)
    -- Hook for a future write-coalescing layer; right now save is on-leave +
    -- periodic timer, so dirty marking is implicit.
end

local function onPlayerAdded(player: Player)
    local userId = player.UserId
    local data = tryGet(userId)
    cache[userId] = data
    print(string.format("[DataStore] loaded %d coins for %s (tier %d, streak %d)",
        data.coins, player.Name, data.upgradeTier, data.streak))
end

local function onPlayerRemoving(player: Player)
    local userId = player.UserId
    local data = cache[userId]
    if not data then return end
    local ok = trySave(userId, data)
    cache[userId] = nil
    if not ok then
        warn("[DataStore] FINAL save failed for " .. player.Name
            .. " -- progress lost from this session")
    end
end

-- Periodic write so a crash doesn't cost >60s of currency tick.
local function periodicSave()
    while true do
        task.wait(60)
        for userId, data in pairs(cache) do
            trySave(userId, data)
        end
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
task.spawn(periodicSave)

-- Save on shutdown (BindToClose has up to 30s before Roblox forces). We try
-- to save every cached player concurrently.
game:BindToClose(function()
    if RunService:IsStudio() then return end
    local jobs = {}
    for userId, data in pairs(cache) do
        table.insert(jobs, task.spawn(function()
            trySave(userId, data)
        end))
    end
    -- best-effort wait; Roblox kills us at 30s anyway
    task.wait(5)
end)

return DataStore
