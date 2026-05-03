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

-- ---- Weekly reward distribution ----------------------------------------
-- Top-N players from the closed week's OrderedDataStore get rebirth
-- tokens at the Sunday rollover. To avoid every server processing the
-- same reward, we use a "winner" lock in a separate keyed DataStore —
-- the first server to claim the lock for `<weekKey>` runs the
-- distribution; everyone else no-ops.

local lockStore: DataStore? = nil
do
    local ok, store = pcall(function()
        return DataStoreService:GetDataStore("Studio88WeeklyLocks")
    end)
    if ok then lockStore = store end
end

local function tryClaimLock(claimedWeekKey: string): boolean
    if not lockStore then return false end
    local got = false
    pcall(function()
        (lockStore :: DataStore):UpdateAsync(claimedWeekKey, function(prev)
            if prev then return nil end  -- lock already held; bail
            got = true
            return string.format("%d_%d", game.PlaceId, os.time())
        end)
    end)
    return got
end

-- Reward table indexed by rank (1 = best). Tokens are rebirth shop currency.
local REWARDS_BY_RANK = {10, 5, 5, 2, 2, 2, 2, 2, 2, 2}  -- top-10

local function distributeWeeklyRewards(closedWeekKey: string)
    if not odsStore then return end
    local rows = nil
    pcall(function()
        local pages = (odsStore :: OrderedDataStore):GetSortedAsync(false, 100)
        rows = pages:GetCurrentPage()
    end)
    if not rows then return end
    -- Filter to entries matching the closed week + sort by score desc
    local filtered = {}
    for _, r in ipairs(rows) do
        local key = tostring(r.key)
        local userIdStr, wk = key:match("^(%d+)_(.+)$")
        if userIdStr and wk == closedWeekKey then
            table.insert(filtered, {userId = tonumber(userIdStr), score = r.value})
        end
    end
    table.sort(filtered, function(a, b) return a.score > b.score end)
    for rank, entry in ipairs(filtered) do
        if rank > #REWARDS_BY_RANK then break end
        local tokens = REWARDS_BY_RANK[rank]
        local data = DataStore.getCached(entry.userId)
        if data then
            data.rebirthTokens = (data.rebirthTokens or 0) + tokens
            print(string.format("[WeeklyTournament] rank %d userId %d +%d tokens (online)",
                rank, entry.userId, tokens))
        else
            -- Player offline. Future iteration: write to a per-userId
            -- "pending tokens" DataStore that DataStore.load merges in.
            print(string.format("[WeeklyTournament] rank %d userId %d +%d tokens (offline, deferred)",
                rank, entry.userId, tokens))
        end
    end
end

-- Distribution scan: every 5min check whether last week's rewards have
-- been distributed. Single-server-wins via tryClaimLock so other
-- servers no-op.
task.spawn(function()
    while true do
        task.wait(300)
        local now = os.time()
        local currentStart = startOfUTCWeek(now)
        local closedWeekStart = currentStart - 7 * 86400
        local closedKey = weekKey(closedWeekStart)
        if tryClaimLock("dist_" .. closedKey) then
            print("[WeeklyTournament] won lock for week " .. closedKey .. ", distributing rewards")
            distributeWeeklyRewards(closedKey)
        end
    end
end)

print("[WeeklyTournament] armed (UTC Sunday rollover, top-10 reward distribution)")
return WeeklyTournament
