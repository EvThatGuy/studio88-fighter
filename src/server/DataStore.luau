--!strict
-- DataStore wrapper for fighter PlayerData. Every read/write goes through
-- pcall + retry-with-backoff. Schema version pinned to
-- Constants.DATASTORE_VERSION; migration logic lives here so a single
-- bump in Constants triggers a compatible upgrade.
--
-- Responsibilities:
--   - Load player data on join (default-fill on first-touch + forward-
--     migrate when stored doc is on an older fighter_vN)
--   - Save on PlayerRemoving and on a periodic timer so a crash loses
--     at most ~60s of progress
--   - Expose getCached / setCached so other services can read/write the
--     in-memory snapshot synchronously between save windows

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Types = require(Modules:WaitForChild("Types"))

-- GetDataStore throws in unpublished Studio places. Degrade to nil +
-- run cache-only so the server still boots; Studio sessions that aren't
-- published are dev-only.
local store: DataStore? = nil
do
    local ok, result = pcall(function()
        return DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
    end)
    if ok then
        store = result
    else
        warn("[DataStore] running cache-only — " .. tostring(result))
    end
end

local DataStore = {}

local cache: {[number]: Types.PlayerData} = {}

local SAVE_RETRY_BUDGET = 4
local SAVE_BACKOFF_BASE = 1.5

local function defaultPlayerData(): Types.PlayerData
    return {
        schemaVersion = Constants.DATASTORE_VERSION,
        selectedClass = Constants.DEFAULT_CLASS,
        hasChosenClass = false,
        xp = 0,
        xpLevel = 1,
        wins = 0,
        losses = 0,
        knockouts = 0,
        matchesPlayed = 0,
        streak = 0,
        lastLoginUnix = os.time(),
        lastLogoutUnix = nil,
        redeemedDevProducts = {},
    }
end

-- Forward migrations. When stored doc.schemaVersion < current, walk through
-- migrations in order. Each fn mutates the doc in place.
local migrations: {[string]: (any) -> ()} = {
    -- Future: ["fighter_v1"] = function(d) ... end (transforms v1 → v2)
}

local function migrate(doc: any): Types.PlayerData
    -- Forward migrations would chain here. For now schema is brand-new;
    -- if a doc is read at a different version we hard-reset to defaults
    -- (no v0 in production yet).
    if doc.schemaVersion ~= Constants.DATASTORE_VERSION then
        local fresh = defaultPlayerData()
        return fresh
    end
    -- Backfill any missing fields (post-deploy field additions) so older
    -- docs don't crash on field access.
    local def = defaultPlayerData()
    for key, value in pairs(def) do
        if doc[key] == nil then
            doc[key] = value
        end
    end
    return doc :: Types.PlayerData
end

local function loadFromStore(userId: number): Types.PlayerData
    if not store then
        return defaultPlayerData()
    end
    local key = "user_" .. tostring(userId)
    local attempt = 0
    while attempt < SAVE_RETRY_BUDGET do
        attempt += 1
        local ok, result = pcall(function()
            return store:GetAsync(key)
        end)
        if ok then
            if result == nil then
                return defaultPlayerData()
            end
            return migrate(result)
        end
        warn(string.format("[DataStore] load attempt %d failed for %d: %s",
            attempt, userId, tostring(result)))
        task.wait(SAVE_BACKOFF_BASE ^ attempt)
    end
    warn(string.format("[DataStore] giving up load for %d; using defaults", userId))
    return defaultPlayerData()
end

local function saveToStore(userId: number, data: Types.PlayerData)
    if not store then return end
    local key = "user_" .. tostring(userId)
    local attempt = 0
    while attempt < SAVE_RETRY_BUDGET do
        attempt += 1
        local ok, err = pcall(function()
            store:SetAsync(key, data)
        end)
        if ok then return end
        warn(string.format("[DataStore] save attempt %d failed for %d: %s",
            attempt, userId, tostring(err)))
        task.wait(SAVE_BACKOFF_BASE ^ attempt)
    end
    warn(string.format("[DataStore] giving up save for %d; %d coins worth of progress lost",
        userId, 0))
end

function DataStore.getCached(userId: number): Types.PlayerData?
    return cache[userId]
end

-- Polls until cached PlayerData is non-nil, since onPlayerAdded yields on
-- GetAsync. Other PlayerAdded handlers that need data should call this
-- instead of getCached so they don't race the load.
function DataStore.waitForCached(userId: number, timeoutSec: number?): Types.PlayerData?
    local timeout = timeoutSec or 10
    local deadline = os.clock() + timeout
    while os.clock() < deadline do
        local data = cache[userId]
        if data then return data end
        task.wait(0.1)
    end
    return cache[userId]
end

function DataStore.setCached(userId: number, data: Types.PlayerData)
    cache[userId] = data
end

local function onPlayerAdded(player: Player)
    local data = loadFromStore(player.UserId)
    data.lastLoginUnix = os.time()
    cache[player.UserId] = data
end

local function onPlayerRemoving(player: Player)
    local data = cache[player.UserId]
    if not data then return end
    data.lastLogoutUnix = os.time()
    saveToStore(player.UserId, data)
    cache[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Periodic autosave so a crash loses at most ~60s.
task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = cache[player.UserId]
            if data then
                saveToStore(player.UserId, data)
            end
        end
    end
end)

-- Server-shutdown drain. game:BindToClose runs before the process exits.
game:BindToClose(function()
    if RunService:IsStudio() then return end
    for _, player in ipairs(Players:GetPlayers()) do
        local data = cache[player.UserId]
        if data then
            saveToStore(player.UserId, data)
        end
    end
end)

return DataStore
