--!strict
-- Live Activity Feed. Cross-server "wow moment" ticker backed by
-- MemoryStoreService SortedMap. Every server posts events; every server
-- reads the rolling tail and pushes it to its own clients.
--
-- We intentionally only log a NARROW set of events (legendary hatches,
-- rebirth milestones, aura unlocks, codes redeemed) so the feed stays
-- exciting and not spammy. Common-pet hatches and tier-ups are skipped.
--
-- SortedMap key format: "<unix>_<userId>" -> { kind, userName, detail }.
-- Reads are GetRangeAsync(SortDirection.Descending, MAX_ENTRIES_VISIBLE).
-- Per-key TTL keeps the map self-cleaning at ENTRY_TTL_SEC seconds.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.get()

local ActivityFeedService = {}

-- MemoryStoreService throws in unpublished Studio places. Degrade to nil + the
-- service runs as a no-op locally so Bootstrap can still complete its load.
local feed: MemoryStoreSortedMap? = nil
do
    local ok, result = pcall(function()
        return MemoryStoreService:GetSortedMap(Constants.ACTIVITY_FEED.SORTED_MAP_KEY)
    end)
    if ok then
        feed = result
    else
        warn("[ActivityFeed] disabled in this place -- " .. tostring(result))
    end
end

-- ---- Cache ---------------------------------------------------------------
-- Latest read from MemoryStore. Pushed to clients when it changes.

type Entry = { kind: string, userName: string, detail: string, unix: number }
local latest: {Entry} = {}

local function entriesEqual(a: {Entry}, b: {Entry}): boolean
    if #a ~= #b then return false end
    for i, ea in ipairs(a) do
        local eb = b[i]
        if ea.kind ~= eb.kind or ea.unix ~= eb.unix or ea.userName ~= eb.userName or ea.detail ~= eb.detail then
            return false
        end
    end
    return true
end

-- ---- Posting -------------------------------------------------------------

local function safeFilteredName(player: Player): string
    -- DisplayName is already moderated by Roblox, but we run through
    -- TextService:FilterStringAsync defensively in case display names get
    -- abuse-vectored. Fall back to plain DisplayName if the call errors.
    local raw = player.DisplayName or player.Name
    local ok, filtered = pcall(function()
        local result = TextService:FilterStringAsync(raw, player.UserId)
        return result:GetNonChatStringForBroadcastAsync()
    end)
    if ok and typeof(filtered) == "string" and filtered ~= "" then
        return filtered
    end
    return raw
end

function ActivityFeedService.post(player: Player, kind: string, detail: string)
    local name = safeFilteredName(player)
    local unix = os.time()
    local key = string.format("%d_%d", unix, player.UserId)
    local payload = {
        kind = kind, userName = name, detail = detail, unix = unix,
    }
    pcall(function()
        feed:SetAsync(key, payload, Constants.ACTIVITY_FEED.ENTRY_TTL_SEC)
    end)
    -- Optimistically reflect on this server immediately so the poster
    -- sees their own event without waiting for the next poll.
    table.insert(latest, 1, payload :: any)
    while #latest > Constants.ACTIVITY_FEED.MAX_ENTRIES_VISIBLE do
        table.remove(latest)
    end
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            remotes.ActivityFeedUpdated:FireClient(p, latest)
        end
    end)
end

-- ---- Reading -------------------------------------------------------------

local function readFeed()
    local ok, items = pcall(function()
        return feed:GetRangeAsync(
            Enum.SortDirection.Descending,
            Constants.ACTIVITY_FEED.MAX_ENTRIES_VISIBLE
        )
    end)
    if not ok or typeof(items) ~= "table" then return end
    local fresh: {Entry} = {}
    for _, item in ipairs(items) do
        local v = item.value
        if typeof(v) == "table" and v.kind and v.userName and v.detail and v.unix then
            table.insert(fresh, v :: any)
        end
    end
    if not entriesEqual(latest, fresh) then
        latest = fresh
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                remotes.ActivityFeedUpdated:FireClient(p, latest)
            end
        end)
    end
end

function ActivityFeedService.snapshot()
    return { entries = latest }
end

-- ---- Wires ---------------------------------------------------------------

remotes.GetActivityFeed.OnServerInvoke = function(_player: Player)
    return ActivityFeedService.snapshot()
end

-- Send the current feed to a player as soon as they join + remotes warm.
Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    pcall(function()
        remotes.ActivityFeedUpdated:FireClient(player, latest)
    end)
end)

-- Background poll: every POLL_INTERVAL_SEC, refresh from MemoryStore.
task.spawn(function()
    while true do
        readFeed()
        task.wait(Constants.ACTIVITY_FEED.POLL_INTERVAL_SEC)
    end
end)

print(string.format("[ActivityFeed] ready (poll %ds, ttl %ds, visible %d)",
    Constants.ACTIVITY_FEED.POLL_INTERVAL_SEC,
    Constants.ACTIVITY_FEED.ENTRY_TTL_SEC,
    Constants.ACTIVITY_FEED.MAX_ENTRIES_VISIBLE))

return ActivityFeedService
