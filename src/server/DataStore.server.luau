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

local function defaultPlayerData(): Types.PlayerData
    return {
        coins = 0,
        lifetimeCoins = 0,
        upgradeTier = 1,
        lastLoginUnix = 0,
        streak = 0,
        starterPackPurchasedUnix = nil,
        schemaVersion = Constants.DATASTORE_VERSION,
    }
end

-- Migration table: a no-op for v1 since we have no prior schema. Adding new
-- versions: add `["v1"] = function(data) ... return data end` and bump
-- Constants.DATASTORE_VERSION + DATASTORE_NAME.
local migrations: {[string]: (any) -> Types.PlayerData} = {}

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
