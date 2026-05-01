--!strict
-- Achievement system. Each unlock fires AchievementUnlocked to the client
-- (toast + screen flash) and credits coin/token rewards atomically with
-- the unlock write. If the achievement has a non-zero badgeId, also calls
-- BadgeService:AwardBadge which triggers a Roblox-native push notification
-- on the player's device -- the most reliable 24h-return-rate driver
-- Roblox exposes to creators (per Roblox creator-docs analytics/retention).
--
-- BadgeService.AwardBadge requires the asset to be created in Creator Hub
-- first; until David creates the badges, badgeId stays 0 and we no-op the
-- AwardBadge call (achievement still unlocks in-game).
--
-- Architecture:
--   - One scan function `evaluate(userId)` iterates all *locked*
--     achievements and unlocks any whose predicate matches current data
--   - Other systems call `evaluate(userId)` after their own commits
--   - Currency tick calls `evaluateThrottled(userId)` to avoid hammering
--     17 predicates every second per player (5s throttle)
--   - All state lives on data.achievementsUnlocked = {[id] = unlockedUnix}

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local AchievementService = {}

-- ---- Lookup --------------------------------------------------------------

type AchievementDef = {
    id: string, name: string, desc: string,
    trigger: string, threshold: number,
    rewardCoins: number, rewardTokens: number, badgeId: number,
}

local achievementById: {[string]: AchievementDef} = {}
for _, a in ipairs(Constants.ACHIEVEMENTS) do
    achievementById[a.id] = a
end

-- ---- Predicates ----------------------------------------------------------
-- Returns (matched, currentProgress) for HUD display. Progress is the raw
-- numeric counter so the client can render "47 / 50 rebirths" bars.

local function petCollectionComplete(data: Types.PlayerData): boolean
    local seen: {[string]: boolean} = {}
    for _, p in ipairs(data.pets or {}) do seen[p.petId] = true end
    for _, def in ipairs(Constants.PETS) do
        if not seen[def.id] then return false end
    end
    return true
end

local function tableSize(t: {[any]: any}?): number
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

local function evaluatePredicate(achievement: AchievementDef, data: Types.PlayerData): (boolean, number)
    local trigger = achievement.trigger
    local threshold = achievement.threshold
    if trigger == "lifetime_coins" then
        return data.lifetimeCoins >= threshold, data.lifetimeCoins
    elseif trigger == "rebirths" then
        local r = data.rebirths or 0
        return r >= threshold, r
    elseif trigger == "tier" then
        return data.upgradeTier >= threshold, data.upgradeTier
    elseif trigger == "pets_owned" then
        local n = #(data.pets or {})
        return n >= threshold, n
    elseif trigger == "pets_collection_complete" then
        local complete = petCollectionComplete(data)
        return complete, complete and 1 or 0
    elseif trigger == "streak" then
        return (data.streak or 0) >= threshold, data.streak or 0
    elseif trigger == "quests_claimed_total" then
        local n = data.questsClaimedTotal or 0
        return n >= threshold, n
    elseif trigger == "codes_redeemed_count" then
        local n = tableSize(data.redeemedCodes)
        return n >= threshold, n
    elseif trigger == "rebirth_shop_owned" then
        local n = tableSize(data.purchasedRebirthUpgrades)
        return n >= threshold, n
    end
    return false, 0
end

-- ---- Unlock --------------------------------------------------------------

local function awardBadgeAsync(userId: number, badgeId: number)
    if badgeId == 0 then return end -- not yet wired in Creator Hub
    pcall(function()
        BadgeService:AwardBadge(userId, badgeId)
    end)
end

-- Achievements that emit activity-feed events. These are the dopamine-spike
-- ones that other players want to see. Routine first-thousand etc are kept
-- private. Keyed by id for O(1) lookup.
local FEED_WORTHY_ACHIEVEMENTS: {[string]: boolean} = {
    billionaire = true,
    rebirth_legend = true,    -- 50 rebirths
    pet_collector = true,     -- own one of every pet
    weekly_warrior = true,    -- 30-day login streak
    max_tier = true,          -- penthouse suite
    prestige_master = true,   -- 10 rebirths
}

local function unlock(player: Player, data: Types.PlayerData, achievement: AchievementDef)
    if not data.achievementsUnlocked then data.achievementsUnlocked = {} end
    if data.achievementsUnlocked[achievement.id] then return end
    data.achievementsUnlocked[achievement.id] = os.time()
    -- Credit reward atomically with unlock
    if achievement.rewardCoins > 0 then
        data.coins += achievement.rewardCoins
        data.lifetimeCoins += achievement.rewardCoins
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
    end
    if achievement.rewardTokens > 0 then
        data.rebirthTokens = (data.rebirthTokens or 0) + achievement.rewardTokens
    end
    -- Badge (push notification on player's device) -- async, fire-and-forget
    task.spawn(function()
        awardBadgeAsync(player.UserId, achievement.badgeId)
    end)
    pcall(function()
        remotes.AchievementUnlocked:FireClient(player, {
            id = achievement.id,
            name = achievement.name,
            desc = achievement.desc,
            rewardCoins = achievement.rewardCoins,
            rewardTokens = achievement.rewardTokens,
        })
    end)
    if FEED_WORTHY_ACHIEVEMENTS[achievement.id] then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService.server"))
            ActivityFeedService.post(player, "achievement_legendary",
                "earned the " .. achievement.name .. " trophy")
        end)
    end
    print(string.format("[AchievementService] %s unlocked '%s' (+%d coins, +%d tokens)",
        player.Name, achievement.id, achievement.rewardCoins, achievement.rewardTokens))
end

-- ---- Scan ---------------------------------------------------------------

local lastScanAt: {[number]: number} = {}

function AchievementService.evaluate(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local data = DataStore.getCached(userId)
    if not data then return end
    if not data.achievementsUnlocked then data.achievementsUnlocked = {} end
    for _, achievement in ipairs(Constants.ACHIEVEMENTS) do
        if not data.achievementsUnlocked[achievement.id] then
            local matched = evaluatePredicate(achievement, data)
            if matched then
                unlock(player, data, achievement)
            end
        end
    end
end

-- Throttled wrapper for hot-path callers (currency tick).
function AchievementService.evaluateThrottled(userId: number)
    local now = os.time()
    local last = lastScanAt[userId] or 0
    if (now - last) < Constants.ACHIEVEMENT_SCAN_THROTTLE_SEC then return end
    lastScanAt[userId] = now
    AchievementService.evaluate(userId)
end

-- ---- Snapshot for HUD ----------------------------------------------------

function AchievementService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return { entries = {}, unlockedCount = 0, totalCount = #Constants.ACHIEVEMENTS }
    end
    local entries = {}
    local unlockedCount = 0
    for _, achievement in ipairs(Constants.ACHIEVEMENTS) do
        local matched, progress = evaluatePredicate(achievement, data)
        local unlocked = (data.achievementsUnlocked or {})[achievement.id] ~= nil
        if unlocked then unlockedCount += 1 end
        table.insert(entries, {
            id = achievement.id,
            name = achievement.name,
            desc = achievement.desc,
            unlocked = unlocked,
            unlockedUnix = (data.achievementsUnlocked or {})[achievement.id],
            progress = progress,
            target = achievement.threshold,
            rewardCoins = achievement.rewardCoins,
            rewardTokens = achievement.rewardTokens,
            -- Hide that the predicate already matches if not unlocked yet,
            -- so the client doesn't show a misleading "100%" bar (the next
            -- evaluate call will unlock it within seconds anyway).
            _matched = matched,
        })
    end
    return {
        entries = entries,
        unlockedCount = unlockedCount,
        totalCount = #Constants.ACHIEVEMENTS,
    }
end

-- ---- Wires --------------------------------------------------------------

remotes.GetAchievements.OnServerInvoke = function(player: Player)
    return AchievementService.snapshot(player.UserId)
end

-- Drop throttle ledger when player leaves so memory doesn't bloat
Players.PlayerRemoving:Connect(function(player)
    lastScanAt[player.UserId] = nil
end)

-- Initial scan when a player joins (catches retroactive unlocks for v7->v8
-- migrants and anyone whose achievements lagged behind state).
Players.PlayerAdded:Connect(function(player)
    -- Wait for DataStore to load via tryGet on join
    task.delay(3, function()
        AchievementService.evaluate(player.UserId)
    end)
end)

print(string.format("[AchievementService] ready (%d achievements)", #Constants.ACHIEVEMENTS))

return AchievementService
