--!strict
-- Cosmetic Aura system. Server stores intent (data.equippedAura), client
-- renders Trail on the actual character. Visible to ALL players in the
-- server -- broadcast via AuraReplicate so every client knows every other
-- player's equipped aura and can render it on their character locally.
--
-- Unlocks are predicate-based (no per-aura ledger), reusing the
-- achievement-style trigger vocab. So any time a player asks "is X
-- unlocked?" we evaluate the predicate against current PlayerData.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local AuraService = {}

-- ---- Lookup --------------------------------------------------------------

type AuraDef = {
    id: string, name: string, desc: string,
    color: {number}, rarity: string,
    trigger: string, unlockValue: number,
}

local auraById: {[string]: AuraDef} = {}
for _, a in ipairs(Constants.AURAS) do auraById[a.id] = a end

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

local function evaluatePredicate(aura: AuraDef, data: Types.PlayerData): (boolean, number)
    local t = aura.trigger
    if t == "lifetime_coins" then
        return data.lifetimeCoins >= aura.unlockValue, data.lifetimeCoins
    elseif t == "rebirths" then
        local r = data.rebirths or 0
        return r >= aura.unlockValue, r
    elseif t == "pets_collection_complete" then
        local complete = petCollectionComplete(data)
        return complete, complete and 1 or 0
    elseif t == "achievements_unlocked" then
        local n = tableSize(data.achievementsUnlocked)
        return n >= aura.unlockValue, n
    end
    return false, 0
end

-- ---- Snapshot for HUD ----------------------------------------------------

function AuraService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return { entries = {}, equippedAura = nil, unlockedCount = 0, totalCount = #Constants.AURAS }
    end
    local entries = {}
    local unlockedCount = 0
    for _, aura in ipairs(Constants.AURAS) do
        local unlocked, progress = evaluatePredicate(aura, data)
        if unlocked then unlockedCount += 1 end
        table.insert(entries, {
            id = aura.id,
            name = aura.name,
            desc = aura.desc,
            color = aura.color,
            rarity = aura.rarity,
            unlocked = unlocked,
            equipped = data.equippedAura == aura.id,
            progress = progress,
            target = aura.unlockValue,
            trigger = aura.trigger,
        })
    end
    return {
        entries = entries,
        equippedAura = data.equippedAura,
        unlockedCount = unlockedCount,
        totalCount = #Constants.AURAS,
    }
end

-- ---- Equip / Unequip -----------------------------------------------------

local function pushReject(player: Player, auraId: string, reason: string)
    pcall(function()
        remotes.AuraRejected:FireClient(player, auraId, reason)
    end)
end

local function broadcastEquip(userId: number, auraId: string?)
    -- Send to ALL players so every client renders the trail on the right
    -- character (FireClient pattern -> for each connected player FireClient).
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            remotes.AuraReplicate:FireClient(p, userId, auraId)
        end
    end)
end

function AuraService.attemptEquip(player: Player, auraId: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, tostring(auraId), "no_data")
        return false, "no_data"
    end
    -- nil / empty string -> unequip
    if auraId == nil or auraId == "" then
        data.equippedAura = nil
        broadcastEquip(userId, nil)
        return true, nil
    end
    if typeof(auraId) ~= "string" then
        pushReject(player, "", "bad_request")
        return false, "bad_request"
    end
    local aura = auraById[auraId]
    if not aura then
        pushReject(player, auraId, "unknown_aura")
        return false, "unknown_aura"
    end
    local unlocked = evaluatePredicate(aura, data)
    if not unlocked then
        pushReject(player, auraId, "locked")
        return false, "locked"
    end
    data.equippedAura = auraId
    broadcastEquip(userId, auraId)
    print(string.format("[AuraService] %s equipped aura '%s'", player.Name, auraId))
    -- Activity feed: only legendary auras are flex-worthy enough to
    -- broadcast. Common/rare/epic equips are private.
    if aura.rarity == "legendary" then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService"))
            ActivityFeedService.post(player, "aura_unlock", "equipped " .. aura.name .. " aura")
        end)
    end
    return true, nil
end

-- ---- Replication on join -------------------------------------------------
-- When a new player joins, send them every existing player's current aura
-- so trails render correctly. Also send their own aura to all (so others
-- see the newcomer's aura).

local function syncPlayerJoined(newPlayer: Player)
    -- Wait for data to land
    task.wait(3)
    local newData = DataStore.getCached(newPlayer.UserId)
    if newData and newData.equippedAura then
        broadcastEquip(newPlayer.UserId, newData.equippedAura)
    end
    -- Send all existing auras to the new player so they catch up
    pcall(function()
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= newPlayer then
                local d = DataStore.getCached(other.UserId)
                if d and d.equippedAura then
                    remotes.AuraReplicate:FireClient(newPlayer, other.UserId, d.equippedAura)
                end
            end
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(syncPlayerJoined, player)
end)

-- ---- Wires ---------------------------------------------------------------

remotes.GetAuras.OnServerInvoke = function(player: Player)
    return AuraService.snapshot(player.UserId)
end

remotes.EquipAura.OnServerEvent:Connect(function(player: Player, auraId: any)
    AuraService.attemptEquip(player, auraId)
end)

print(string.format("[AuraService] ready (%d auras)", #Constants.AURAS))

return AuraService
