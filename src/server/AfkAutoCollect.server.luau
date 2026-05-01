--!strict
-- AFK auto-collect for Premium pass holders.
--
-- The Premium Game Pass advertises "3x income forever + AFK auto-collect".
-- Without this module, the "AFK auto-collect" half is false advertising:
-- coins ride the conveyor and despawn after COIN_LIFETIME_SEC if the
-- player isn't standing in front of the Collector. This module sweeps
-- the workspace on a timer and credits any orphan Studio88Coin whose
-- owner has Premium, simulating a synthetic Collector touch.
--
-- Server-authoritative; the client never knows about Premium ownership
-- for this code path. We re-query MarketplaceService:UserOwnsGamePassAsync
-- via a per-player TTL cache (separate from CurrencyManager's pass cache
-- to avoid coupling timer concerns across modules).
--
-- Performance: scan rate is 2s (Constants.AFK_AUTOCOLLECT_INTERVAL_SEC).
-- Coin lifetime is 30s, so a Premium player's coin is collected within
-- at most 2s of spawn -- effectively instant from the player's POV
-- without the cost of per-frame iteration.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats.server"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService.server"))

local remotes = Remotes.get()

local AfkAutoCollect = {}

-- Per-player Premium ownership cache (separate from CurrencyManager's; this
-- module's cadence is different so coupling them would force one to win).
type CacheEntry = { owns: boolean, refreshedAt: number }
local cache: {[number]: CacheEntry} = {}
local CACHE_TTL_SEC = 60

local function ownsPremium(userId: number): boolean
    local entry = cache[userId]
    if entry and (os.time() - entry.refreshedAt) < CACHE_TTL_SEC then
        return entry.owns
    end
    local passId = Constants.GAME_PASSES.PREMIUM
    if passId == 0 then
        cache[userId] = { owns = false, refreshedAt = os.time() }
        return false
    end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)
    local result = (ok and owns) or false
    cache[userId] = { owns = result, refreshedAt = os.time() }
    return result
end

-- Synthetic collect: credits the coin's value to its owner, fires the
-- BalanceUpdated push, refreshes leaderstats, bumps the collect-drops
-- daily quest, then destroys the coin. Mirrors Collector.onCollect but
-- without the touch event (no plot validation needed since we're
-- enforcing "must own Premium" before calling this).
local function syntheticCollect(coin: BasePart, ownerUserId: number)
    local data = DataStore.getCached(ownerUserId)
    if not data then
        coin:Destroy()
        return
    end
    local value = coin:GetAttribute("Value") or 1
    data.coins += value
    data.lifetimeCoins += value
    coin:Destroy()
    Leaderstats.refresh(ownerUserId)
    local player = Players:GetPlayerByUserId(ownerUserId)
    if player then
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
    end
    DailyQuestService.bumpProgress(ownerUserId,
        Constants.QUEST_KIND.COLLECT_DROPS_TODAY, 1)
end

local function sweep()
    local seenOwners: {[number]: boolean} = {}
    for _, coin in ipairs(CollectionService:GetTagged("Studio88Coin")) do
        if not coin:IsA("BasePart") then continue end
        local userId = coin:GetAttribute("OwnerUserId") :: number?
        if not userId then continue end
        -- Cache the eligibility decision per-owner per-sweep so we don't
        -- call ownsPremium() once per coin (could be 50+ coins per sweep).
        if seenOwners[userId] == nil then
            seenOwners[userId] = ownsPremium(userId)
        end
        if seenOwners[userId] then
            syntheticCollect(coin, userId)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(Constants.AFK_AUTOCOLLECT_INTERVAL_SEC or 2)
        local ok, err = pcall(sweep)
        if not ok then
            warn("[AfkAutoCollect] sweep failed: " .. tostring(err))
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    cache[player.UserId] = nil
end)

print("[AfkAutoCollect] online (sweep every " ..
    tostring(Constants.AFK_AUTOCOLLECT_INTERVAL_SEC or 2) .. "s, Premium-only)")

return AfkAutoCollect
