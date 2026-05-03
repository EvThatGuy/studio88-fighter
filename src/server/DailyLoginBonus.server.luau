--!strict
-- Daily login streak. Reads lastLoginUnix from PlayerData on join, compares
-- against today (UTC day-of-year), grants the streak reward, increments
-- streak by 1 if the player came back yesterday or breaks streak otherwise.
--
-- This is the single highest-impact retention feature for Creator Rewards
-- payout (return-rate weighted higher than CCU). Default escalation: Day 1
-- = 500, Day 7 = 5000, Day 30 = 50000.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

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
        Leaderstats.refresh(player.UserId)
        print(string.format("[DailyLoginBonus] %s +%d coins (streak %d)",
            player.Name, reward, data.streak))
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
        pcall(function()
            remotes.DailyBonusGranted:FireClient(player, data.streak, reward)
        end)
        pcall(function()
            AnalyticsService:LogCustomEvent(
                player, Constants.ANALYTICS_EVENTS.STREAK_CLAIMED, reward,
                { day = data.streak, streak_total = data.streak }
            )
        end)
    end

    data.lastLoginUnix = now
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(player.UserId)
    end)
    -- Streak egg grant: at threshold streak days, the player ALSO gets a
    -- free hatch from a designated egg on top of the coin bonus. Bypasses
    -- coin cost via PetService.grantPetFromEgg.
    local eggId = Constants.STREAK_EGG_GRANTS[data.streak]
    if eggId then
        pcall(function()
            local PetService = require(script.Parent:WaitForChild("PetService"))
            local owned, def, reason = PetService.grantPetFromEgg(player, eggId)
            if owned and def then
                pcall(function()
                    remotes.StreakEggGranted:FireClient(player, data.streak, eggId, owned, def.name)
                end)
            elseif reason == "inventory_full" then
                -- Fallback: don't lose the streak grant silently. Drop a
                -- coin-equivalent so the player isn't punished for being
                -- a hoarder.
                local fallback = 5000
                data.coins += fallback
                data.lifetimeCoins += fallback
                pcall(function()
                    remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
                end)
                warn(string.format("[DailyLoginBonus] %s streak-egg %s denied (inventory full); +%d coin fallback",
                    player.Name, eggId, fallback))
            end
        end)
    end
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

-- Schedule preview remote — HUD modal calls this to render the upcoming
-- 14 days so the day-7 MYTHIC jackpot is visible from day 1, pulling
-- new players through the day 3-4 trough per retention playbook.
remotes.GetDailyStreakSchedule.OnServerInvoke = function(player: Player)
    local data = DataStore.getCached(player.UserId)
    local currentStreak = (data and data.streak) or 0
    -- Build a schedule of relevant days: every defined entry +
    -- intermediates currentStreak..currentStreak+13. Sort ascending.
    local seenDays: {[number]: boolean} = {}
    local days: {number} = {}
    local function add(d: number)
        if d > 0 and not seenDays[d] then
            seenDays[d] = true
            table.insert(days, d)
        end
    end
    for d in pairs(Constants.DAILY_BONUS_BY_STREAK) do add(d) end
    for d = currentStreak + 1, currentStreak + 14 do add(d) end
    table.sort(days)

    local schedule = {}
    for _, d in ipairs(days) do
        local label = Constants.DAILY_BONUS_LABELS[d]
        local eggGrant = Constants.STREAK_EGG_GRANTS[d]
        table.insert(schedule, {
            day = d,
            coins = rewardForStreak(d),
            tag = label and label.tag or ("DAY " .. d),
            jackpot = label and label.jackpot or false,
            eggGrant = eggGrant,
            claimed = d <= currentStreak,
            current = d == currentStreak + 1,  -- next-up day
        })
    end
    return {
        currentStreak = currentStreak,
        nextDay = currentStreak + 1,
        schedule = schedule,
    }
end

-- Streak-risk warning. Players with 3+ day streak who haven't claimed
-- today by 22:00 UTC get a "your streak resets in Xh" toast. Surfaces
-- the loss-aversion that drives streak retention.
task.spawn(function()
    while true do
        task.wait(300)  -- check every 5min
        local t = os.date("!*t") :: any
        if t.hour < 22 then continue end  -- only fire after 22:00 UTC
        for _, p in ipairs(Players:GetPlayers()) do
            local d = DataStore.getCached(p.UserId)
            if not d then continue end
            local streak = d.streak or 0
            if streak < 3 then continue end
            local todayStart = startOfUTCDay(os.time())
            local lastStart = startOfUTCDay(d.lastLoginUnix or 0)
            if todayStart == lastStart then continue end  -- already claimed today
            local hoursLeft = 24 - t.hour
            pcall(function()
                remotes.NotificationToast:FireClient(p, {
                    kind = "streak_risk",
                    title = "⚠️ STREAK AT RISK",
                    body = string.format("Your %d-day streak resets in %dh — claim today's reward!", streak, hoursLeft),
                })
            end)
        end
    end
end)

print("[DailyLoginBonus] armed (schedule preview live + streak-risk warning)")
