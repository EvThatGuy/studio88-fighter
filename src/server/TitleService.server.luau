--!strict
-- Player Titles. Tags shown over the character (BillboardGui rendered
-- by TitleRenderer.client.luau). Server stores the equip choice; client
-- picks up the broadcast and renders. Predicate-based unlock (no per-
-- title ledger), reusing the achievement/aura predicate vocab.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local TitleService = {}

type TitleDef = {
    id: string, name: string, color: {number},
    trigger: string, unlockValue: any,
}

local titleById: {[string]: TitleDef} = {}
for _, t in ipairs(Constants.PLAYER_TITLES) do titleById[t.id] = t end

local function tableSize(t: {[any]: any}?): number
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

local function petCollectionComplete(data: Types.PlayerData): boolean
    local seen: {[string]: boolean} = {}
    for _, p in ipairs(data.pets or {}) do seen[p.petId] = true end
    for _, def in ipairs(Constants.PETS) do
        if not seen[def.id] then return false end
    end
    return true
end

local function evaluatePredicate(title: TitleDef, data: Types.PlayerData): (boolean, number)
    local t = title.trigger
    if t == "lifetime_coins" then
        return data.lifetimeCoins >= title.unlockValue, data.lifetimeCoins
    elseif t == "rebirths" then
        local r = data.rebirths or 0
        return r >= title.unlockValue, r
    elseif t == "pets_collection_complete" then
        local complete = petCollectionComplete(data)
        return complete, complete and 1 or 0
    elseif t == "achievements_unlocked" then
        local n = tableSize(data.achievementsUnlocked)
        return n >= title.unlockValue, n
    elseif t == "aura_equipped" then
        local matches = data.equippedAura == title.unlockValue
        return matches, matches and 1 or 0
    end
    return false, 0
end

function TitleService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return { entries = {}, equippedTitle = nil }
    end
    local entries = {}
    for _, title in ipairs(Constants.PLAYER_TITLES) do
        local unlocked, progress = evaluatePredicate(title, data)
        table.insert(entries, {
            id = title.id, name = title.name, color = title.color,
            trigger = title.trigger,
            target = (typeof(title.unlockValue) == "number") and title.unlockValue or 1,
            progress = progress,
            unlocked = unlocked,
            equipped = data.equippedTitle == title.id,
        })
    end
    return { entries = entries, equippedTitle = data.equippedTitle }
end

local function broadcastTitle(userId: number, titleId: string?)
    local def = titleId and titleById[titleId] or nil
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            remotes.TitleReplicate:FireClient(p, userId, titleId,
                def and def.name or nil,
                def and def.color or nil)
        end
    end)
end

local function pushReject(player: Player, titleId: string, reason: string)
    pcall(function()
        remotes.TitleRejected:FireClient(player, titleId, reason)
    end)
end

function TitleService.attemptEquip(player: Player, titleId: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, tostring(titleId), "no_data")
        return false, "no_data"
    end
    if titleId == nil or titleId == "" then
        data.equippedTitle = nil
        broadcastTitle(userId, nil)
        return true, nil
    end
    if typeof(titleId) ~= "string" then
        pushReject(player, "", "bad_request")
        return false, "bad_request"
    end
    local title = titleById[titleId]
    if not title then
        pushReject(player, titleId, "unknown_title")
        return false, "unknown_title"
    end
    local unlocked = evaluatePredicate(title, data)
    if not unlocked then
        pushReject(player, titleId, "locked")
        return false, "locked"
    end
    data.equippedTitle = titleId
    broadcastTitle(userId, titleId)
    print(string.format("[TitleService] %s equipped title '%s'", player.Name, titleId))
    return true, nil
end

-- ---- Replication on join ------------------------------------------------

local function syncPlayerJoined(newPlayer: Player)
    task.wait(3)
    local newData = DataStore.getCached(newPlayer.UserId)
    if newData and newData.equippedTitle then
        broadcastTitle(newPlayer.UserId, newData.equippedTitle)
    end
    -- Send all existing titles to the new player so they catch up
    pcall(function()
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= newPlayer then
                local d = DataStore.getCached(other.UserId)
                if d and d.equippedTitle then
                    local def = titleById[d.equippedTitle]
                    remotes.TitleReplicate:FireClient(newPlayer, other.UserId,
                        d.equippedTitle, def and def.name or nil, def and def.color or nil)
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(syncPlayerJoined, player)
end)

remotes.GetTitles.OnServerInvoke = function(player: Player)
    return TitleService.snapshot(player.UserId)
end

remotes.EquipTitle.OnServerEvent:Connect(function(player: Player, titleId: any)
    TitleService.attemptEquip(player, titleId)
end)

print(string.format("[TitleService] ready (%d titles)", #Constants.PLAYER_TITLES))

return TitleService
