--!strict
-- Daily Quest service. The single highest-impact retention feature per the
-- 2026 Roblox Recommended-For-You algorithm research: 3 rotating quests per
-- day, claim screen on join, deterministic rotation by UTC date so all
-- servers in this universe show the same quests on the same day. Forces a
-- 24h return to claim -- directly hits the algorithm's primary signal.
--
-- Other server modules report progress via DailyQuestService.bumpProgress(
-- userId, kind, delta) -- this is a thin, fast-path API that does the
-- per-quest bookkeeping + auto-fires QuestProgressed when progress moves
-- toward (or completes) a target. Claim is a separate explicit action by
-- the player; we don't auto-grant on completion so players see the reward
-- land on the claim button.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local DailyQuestService = {}

type QuestDef = {
    id: string,
    kind: string,
    target: number,
    reward: number,
    label: string,
}

-- ---- Date key + deterministic selection ----------------------------------

-- UTC date key. Day-resolution; rotation flips at 00:00 UTC. Same key
-- across all servers so daily quests are consistent for cross-server play.
local function todayKey(): string
    local t = os.date("!*t", os.time()) :: any
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

-- Stable hash of the dateKey + a tier seed -> index into the tier pool.
-- Lua doesn't ship a string hash, so we use a small folding scheme; not
-- cryptographic but good enough for "pick the same index every server".
local function hashKey(s: string, salt: number): number
    local h = salt
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 2147483647
    end
    return h
end

local function pickFromPool(pool: {QuestDef}, dateKey: string, salt: number): QuestDef
    local idx = (hashKey(dateKey, salt) % #pool) + 1
    return pool[idx]
end

function DailyQuestService.todaysQuests(): {QuestDef}
    local key = todayKey()
    return {
        pickFromPool(Constants.DAILY_QUEST_POOL_EASY, key, 11),
        pickFromPool(Constants.DAILY_QUEST_POOL_MEDIUM, key, 17),
        pickFromPool(Constants.DAILY_QUEST_POOL_HARD, key, 23),
    }
end

-- ---- Per-player state ----------------------------------------------------

local function rolloverIfStale(data: Types.PlayerData)
    local key = todayKey()
    if not data.dailyQuests or data.dailyQuests.dateKey ~= key then
        data.dailyQuests = { dateKey = key, progress = {}, claimed = {} }
    end
end

-- Returns the current player-facing snapshot: today's 3 quests, with
-- progress and claimed flags filled in.
function DailyQuestService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return nil end
    rolloverIfStale(data)
    local quests = {}
    for _, def in ipairs(DailyQuestService.todaysQuests()) do
        local progress = data.dailyQuests.progress[def.id] or 0
        local claimed = data.dailyQuests.claimed[def.id] == true
        table.insert(quests, {
            id = def.id,
            kind = def.kind,
            target = def.target,
            reward = def.reward,
            label = (string.gsub(def.label, "{target}", tostring(def.target))),
            progress = math.min(progress, def.target),
            claimed = claimed,
            complete = progress >= def.target,
        })
    end
    return { dateKey = data.dailyQuests.dateKey, quests = quests }
end

-- Find the quest def for a (userId, questId) tuple if it's one of today's
-- quests for this player. Used by claim + bump to validate.
local function findTodayQuestById(questId: string): QuestDef?
    for _, def in ipairs(DailyQuestService.todaysQuests()) do
        if def.id == questId then return def end
    end
    return nil
end

-- ---- Progress hook -------------------------------------------------------

-- Called by other server modules. `kind` should be one of
-- Constants.QUEST_KIND.* values. `delta` defaults to 1 (a "did the thing
-- once" event); pass a larger delta when crediting batches (e.g. earned
-- 50 coins this tick).
function DailyQuestService.bumpProgress(userId: number, kind: string, delta: number?)
    local data = DataStore.getCached(userId)
    if not data then return end
    rolloverIfStale(data)
    local n = delta or 1
    if n <= 0 then return end
    local player = Players:GetPlayerByUserId(userId)
    -- Only bump quests of this kind that are part of today's set
    for _, def in ipairs(DailyQuestService.todaysQuests()) do
        if def.kind ~= kind then continue end
        local prev = data.dailyQuests.progress[def.id] or 0
        if prev >= def.target then continue end -- already complete
        local next_ = math.min(def.target, prev + n)
        data.dailyQuests.progress[def.id] = next_
        if player then
            pcall(function()
                remotes.QuestProgressed:FireClient(player, def.id, next_, def.target)
            end)
        end
        if next_ >= def.target then
            -- Hit completion this bump; analytics tap so we can see funnel
            pcall(function()
                AnalyticsService:LogCustomEvent(player or Players, Constants.ANALYTICS_EVENTS.QUEST_PROGRESSED, 1, {
                    custom_field_1 = def.id,
                })
            end)
        end
    end
end

-- ---- Claim ---------------------------------------------------------------

local function pushReject(player: Player, questId: string, reason: string)
    pcall(function()
        remotes.QuestRejected:FireClient(player, questId, reason)
    end)
end

function DailyQuestService.attemptClaim(player: Player, questId: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, tostring(questId), "no_data")
        return false, "no_data"
    end
    if typeof(questId) ~= "string" then
        pushReject(player, "", "bad_request")
        return false, "bad_request"
    end
    rolloverIfStale(data)
    local def = findTodayQuestById(questId)
    if not def then
        pushReject(player, questId, "not_today")
        return false, "not_today"
    end
    if data.dailyQuests.claimed[questId] then
        pushReject(player, questId, "already_claimed")
        return false, "already_claimed"
    end
    local progress = data.dailyQuests.progress[questId] or 0
    if progress < def.target then
        pushReject(player, questId, "not_complete")
        return false, "not_complete"
    end
    -- Grant
    data.coins += def.reward
    data.lifetimeCoins += def.reward
    data.dailyQuests.claimed[questId] = true
    data.questsClaimedTotal = (data.questsClaimedTotal or 0) + 1
    Leaderstats.refresh(userId)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.QuestClaimed:FireClient(player, questId, def.reward)
    end)
    pcall(function()
        AnalyticsService:LogCustomEvent(player, Constants.ANALYTICS_EVENTS.QUEST_CLAIMED, def.reward, {
            custom_field_1 = def.id,
            custom_field_2 = def.kind,
        })
    end)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(player.UserId)
    end)
    pcall(function()
        local XpService = require(script.Parent:WaitForChild("XpService"))
        XpService.award(player.UserId, "quest_claim")
    end)
    print(string.format("[DailyQuestService] %s claimed '%s' for %d coins",
        player.Name, questId, def.reward))
    return true, nil
end

-- ---- Wires ---------------------------------------------------------------

remotes.GetDailyQuests.OnServerInvoke = function(player: Player)
    return DailyQuestService.snapshot(player.UserId) or { dateKey = todayKey(), quests = {} }
end

remotes.ClaimQuest.OnServerEvent:Connect(function(player: Player, questId: any)
    local ok, reason = DailyQuestService.attemptClaim(player, questId)
    if not ok then
        warn(string.format("[DailyQuestService] %s claim '%s' failed: %s",
            player.Name, tostring(questId):sub(1, 32), reason or "?"))
    end
end)

-- Per-player play-time tracker. The PLAY_MINUTES_TODAY quest kind needs a
-- ticker that adds session minutes. Cheaper than per-frame heartbeats: we
-- bump 1 minute every 60s while the player is in-server.
local function startPlayTimeTicker(player: Player)
    task.spawn(function()
        while player.Parent do
            task.wait(60)
            if not player.Parent then return end
            DailyQuestService.bumpProgress(player.UserId,
                Constants.QUEST_KIND.PLAY_MINUTES_TODAY, 1)
        end
    end)
end

Players.PlayerAdded:Connect(startPlayTimeTicker)
for _, p in ipairs(Players:GetPlayers()) do startPlayTimeTicker(p) end

local function questNames(): string
    local out = {}
    for _, q in ipairs(DailyQuestService.todaysQuests()) do
        table.insert(out, q.id)
    end
    return table.concat(out, ", ")
end

print(string.format("[DailyQuestService] ready (today %s: %s)",
    todayKey(), questNames()))

return DailyQuestService
