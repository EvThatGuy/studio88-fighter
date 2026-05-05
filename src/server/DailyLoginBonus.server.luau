--!strict
-- Daily login streak. On player join, compares lastLoginUnix to today's
-- UTC date. Rewards by streak per Constants.DAILY_BONUS_XP_BY_STREAK
-- (XP, not coins — fighter has no spendable currency yet).
--
-- Streak rules:
--   - Same UTC day as last login: silent skip (already claimed today).
--   - Exactly 1 UTC day later: streak += 1.
--   - 2+ UTC days later: streak resets to 1.
--   - Reward = table[streak], or table[max-day] if streak exceeds.
--
-- Genre-agnostic; lifted from the tycoon's pattern. XP feeds XpLevel
-- via the threshold table in Constants once XpService is reintroduced
-- (Phase 4 — until then, XP just accumulates in PlayerData.xp).

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local ServerScriptService = game:GetService("ServerScriptService")
local container = ServerScriptService:WaitForChild("Studio88")
local DataStore = require(container:WaitForChild("DataStore"))
local Leaderstats = require(container:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local function utcDayIndex(unix: number): number
    -- Unix-day counter: floor(unix / 86400). Same value for every second
    -- in a given UTC day. Lets us compare "is this a new day?" without
    -- constructing date tables.
    return math.floor(unix / 86400)
end

local function rewardForStreak(streak: number): number
    local table_ = Constants.DAILY_BONUS_XP_BY_STREAK
    -- Find the largest threshold <= streak.
    local best = 0
    for day, xp in pairs(table_) do
        if streak >= day and day > best then
            best = day
        end
    end
    return table_[best] or 0
end

local function levelFromXp(xp: number): number
    local thresholds = Constants.XP_LEVEL_THRESHOLDS
    local level = 1
    for lvl, threshold in pairs(thresholds) do
        if xp >= threshold and lvl > level then
            level = lvl
        end
    end
    return level
end

local function processLogin(player: Player)
    local data = DataStore.getCached(player.UserId)
    if not data then return end

    local now = os.time()
    local lastDay = utcDayIndex(data.lastLoginUnix or 0)
    local todayDay = utcDayIndex(now)

    if lastDay == todayDay then
        -- Already claimed in this UTC day; just stamp lastLoginUnix.
        data.lastLoginUnix = now
        return
    end

    local diff = todayDay - lastDay
    if data.lastLoginUnix == 0 or diff > 1 or diff < 0 then
        -- First-ever login OR streak broken. Either way, day-1 reward.
        data.streak = 1
    else
        data.streak += 1
    end
    data.lastLoginUnix = now

    local reward = rewardForStreak(data.streak)
    data.xp += reward
    local newLevel = levelFromXp(data.xp)
    if newLevel > data.xpLevel then
        data.xpLevel = newLevel
    end
    Leaderstats.refresh(player.UserId)

    remotes.DailyBonusGranted:FireClient(player, {
        streak = data.streak,
        xpReward = reward,
    })
    remotes.NotificationToast:FireClient(player, {
        kind = "info",
        title = string.format("DAY %d STREAK", data.streak),
        body = string.format("+%d XP", reward),
    })
end

local function bind(player: Player)
    -- DataStore loads asynchronously on PlayerAdded; wait briefly for
    -- the cache to populate before reading.
    task.wait(1)
    if player.Parent then
        processLogin(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(bind, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(bind, player)
end
