--!strict
-- Weekly Tournament. Tracks per-player "weekly earned coins" with UTC
-- Sunday rollover. Top performers get rebirth tokens at reset.
--
-- Counter is incremented on every Collector credit + DailyLoginBonus +
-- HourlyTribute claim — actually we centralize the increment via a
-- public WeeklyTournament.recordEarn(userId, value). Other services
-- call this when crediting coins.
--
-- This is foundation only — the actual cross-server top-N is held in an
-- OrderedDataStore keyed by week. Reward distribution at reset would
-- run on a single server (election would be next iteration); for now
-- we just track + display the per-player counter, plus persist a
-- "weekly_<weekKey>" OrderedDataStore entry so a future cron can
-- materialize the top-10 + grant rebirth tokens.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local WeeklyTournament = {}

-- Compute the start of the current UTC week (Sunday 00:00). Returns
-- unix seconds.
local function startOfUTCWeek(now: number): number
    -- os.date("!*t", now).wday == 1 means Sunday in Lua's date table
    local t = os.date("!*t", now) :: any
    -- Seconds elapsed since Sunday 00:00 = (wday-1)*86400 + hour*3600 + min*60 + sec
    local elapsedSinceSundayStart = (t.wday - 1) * 86400 + t.hour * 3600 + t.min * 60 + t.sec
    return now - elapsedSinceSundayStart
end

local function weekKey(now: number): string
    local sunday = startOfUTCWeek(now)
    local t = os.date("!*t", sunday) :: any
    return string.format("%04d-W%02d", t.year, math.floor(t.yday / 7) + 1)
end

local odsStore: OrderedDataStore? = nil
do
    local ok, store = pcall(function()
        return DataStoreService:GetOrderedDataStore("Studio88WeeklyEarn")
    end)
    if ok then odsStore = store end
end

local function rolloverIfStale(data, now: number)
    local weekStart = startOfUTCWeek(now)
    if not data.weeklyResetUnix or data.weeklyResetUnix < weekStart then
        data.weeklyResetUnix = weekStart
        data.weeklyEarnedCoins = 0
    end
end

-- Public: called from Collector / DailyLoginBonus / HourlyTribute /
-- IdleReturnBonus on any coin credit so the per-player weekly total
-- reflects all income sources.
function WeeklyTournament.recordEarn(userId: number, value: number)
    if value <= 0 then return end
    local data = DataStore.getCached(userId)
    if not data then return end
    local now = os.time()
    rolloverIfStale(data, now)
    data.weeklyEarnedCoins = (data.weeklyEarnedCoins or 0) + value
    -- Persist to OrderedDataStore async-best-effort. Skip silently on
    -- DataStore disable / quota / network. The per-player counter on
    -- PlayerData is still authoritative for UI.
    if odsStore then
        local key = weekKey(now)
        pcall(function()
            (odsStore :: OrderedDataStore):SetAsync(
                tostring(userId) .. "_" .. key, data.weeklyEarnedCoins
            )
        end)
    end
end

function WeeklyTournament.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return {weeklyEarned = 0, weekStart = startOfUTCWeek(os.time())} end
    rolloverIfStale(data, os.time())
    return {
        weeklyEarned = data.weeklyEarnedCoins or 0,
        weekStart = data.weeklyResetUnix or startOfUTCWeek(os.time()),
        weekKey = weekKey(os.time()),
    }
end

print("[WeeklyTournament] armed (UTC Sunday rollover)")
return WeeklyTournament
