--!strict
-- OrderedDataStore-backed leaderboard. Top N by lifetime coins (never
-- decreases). Refresh every Constants.LEADERBOARD_REFRESH_SEC; broadcast to
-- all clients via LeaderboardUpdated.
--
-- Why lifetime not balance: a player who hoards never falls off the board
-- after a big upgrade purchase. Lifetime coins == cumulative dedication.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local LB_KEY = "LifetimeCoins_" .. Constants.DATASTORE_VERSION
local odsStore = DataStoreService:GetOrderedDataStore(LB_KEY)

local function publishCurrentPlayers()
    -- Push every active player's lifetime coins to the OrderedDataStore so
    -- they show up on the global leaderboard.
    for _, player in ipairs(Players:GetPlayers()) do
        local data = DataStore.getCached(player.UserId)
        if data then
            local ok, err = pcall(function()
                odsStore:SetAsync(tostring(player.UserId), data.lifetimeCoins)
            end)
            if not ok then
                warn("[Leaderboard] SetAsync failed for " .. player.Name .. ": " .. tostring(err))
            end
        end
    end
end

local function fetchTopN(): {{userId: number, name: string, lifetimeCoins: number}}
    local out = {}
    local ok, page = pcall(function()
        return odsStore:GetSortedAsync(false, Constants.LEADERBOARD_TOP_N)
    end)
    if not ok or not page then
        warn("[Leaderboard] GetSortedAsync failed: " .. tostring(page))
        return out
    end
    local entries = page:GetCurrentPage()
    for _, entry in ipairs(entries) do
        local userId = tonumber(entry.key)
        if userId then
            local nameOk, name = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            table.insert(out, {
                userId = userId,
                name = nameOk and name or ("user:" .. userId),
                lifetimeCoins = entry.value,
            })
        end
    end
    return out
end

local function refreshAndBroadcast()
    publishCurrentPlayers()
    local rows = fetchTopN()
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.LeaderboardUpdated:FireClient(player, rows)
        end)
    end
end

local function loop()
    -- Initial wait so DataStore has loaded everyone joining at t0
    task.wait(5)
    while true do
        refreshAndBroadcast()
        task.wait(Constants.LEADERBOARD_REFRESH_SEC)
    end
end

-- Push the freshly-joined player's most recent leaderboard so they have
-- something to render before the next global refresh tick.
Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        task.wait(2)
        local rows = fetchTopN()
        pcall(function()
            remotes.LeaderboardUpdated:FireClient(player, rows)
        end)
    end)
end)

task.spawn(loop)

print("[Leaderboard] refreshing every " .. Constants.LEADERBOARD_REFRESH_SEC .. "s, top " .. Constants.LEADERBOARD_TOP_N)
