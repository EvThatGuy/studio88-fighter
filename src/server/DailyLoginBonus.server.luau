--!strict
-- Daily login streak. Reads lastLoginUnix from PlayerData on join, compares
-- against today (UTC day-of-year), grants the streak reward, increments
-- streak by 1 if the player came back yesterday or breaks streak otherwise.
--
-- This is the single highest-impact retention feature for Creator Rewards
-- payout (return-rate weighted higher than CCU). Default escalation: Day 1
-- = 500, Day 7 = 5000, Day 30 = 50000.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local function startOfUTCDay(unix: number): number
    -- Return unix-seconds for the start of the UTC day containing `unix`.
    return unix - (unix % 86400)
end

local function rewardForStreak(streak: number): number
    -- Walk down from 30 to find the largest defined entry <= streak.
    local best = 0
    for day, amount in pairs(Constants.DAILY_BONUS_BY_STREAK) do
        if streak >= day and amount > best then
            best = amount
        end
    end
    return best
end

local function grantBonusIfDue(player: Player)
    local data = DataStore.getCached(player.UserId)
    if not data then return end

    local now = os.time()
    local todayStart = startOfUTCDay(now)
    local lastStart = startOfUTCDay(data.lastLoginUnix or 0)

    if data.lastLoginUnix == 0 then
        -- First-ever login: streak 1, day 1 reward
        data.streak = 1
    elseif todayStart == lastStart then
        -- Same UTC day; no double-reward
        return
    elseif todayStart - lastStart == 86400 then
        -- Came back exactly the next day: extend streak
        data.streak += 1
    else
        -- Missed a day: reset
        data.streak = 1
    end

    local reward = rewardForStreak(data.streak)
    if reward > 0 then
        data.coins += reward
        data.lifetimeCoins += reward
        print(string.format("[DailyLoginBonus] %s +%d coins (streak %d)",
            player.Name, reward, data.streak))
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
    end

    data.lastLoginUnix = now
end

-- Wait for DataStore to populate cache before granting -- DataStore.server's
-- PlayerAdded fires first because it's required earlier in this file's chain.
-- Use a small task.spawn after PlayerAdded so the cache is reliably set.
Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        -- 5 retries x 0.5s = up to 2.5s wait for data to land
        for _ = 1, 5 do
            if DataStore.getCached(player.UserId) then
                grantBonusIfDue(player)
                return
            end
            task.wait(0.5)
        end
        warn("[DailyLoginBonus] data never landed for " .. player.Name)
    end)
end)

print("[DailyLoginBonus] armed")
