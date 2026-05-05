--!strict
-- Cosmetic XP track. Parallel progression metric independent of the
-- income/tier loop, so players who don't engage gacha or rebirth still
-- get a sense of "I'm progressing" from any positive action.
--
-- Other services call XpService.award(userId, kindKey) where kindKey is
-- a key in Constants.XP_REWARDS. award returns the new total XP (for
-- callers who want to render +N).
--
-- Level-up firing: when xpLevel computed from new total > cached
-- data.xpLevel, fire XpLeveledUp remote.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local XpService = {}

-- Compute level from XP total. Walks the threshold table.
local function computeLevel(xp: number): number
    local lvl = 1
    for level, threshold in pairs(Constants.XP_LEVEL_THRESHOLDS) do
        if xp >= threshold and level > lvl then lvl = level end
    end
    return lvl
end

function XpService.award(userId: number, kindKey: string): number
    local data = DataStore.getCached(userId)
    if not data then return 0 end
    local amount = Constants.XP_REWARDS[kindKey] or 0
    if amount <= 0 then return data.xp or 0 end
    data.xp = (data.xp or 0) + amount
    local newLevel = computeLevel(data.xp)
    local prevLevel = data.xpLevel or 1
    if newLevel > prevLevel then
        data.xpLevel = newLevel
        -- Fire level-up remote if player still online
        local p = Players:GetPlayerByUserId(userId)
        if p then
            pcall(function()
                remotes.XpLeveledUp:FireClient(p, {
                    newLevel = newLevel,
                    xp = data.xp,
                    nextThreshold = Constants.XP_LEVEL_THRESHOLDS[newLevel + 1],
                })
            end)
        end
        pcall(function()
            if p then
                AnalyticsService:LogCustomEvent(p, "XpLevelUp", newLevel,
                    {prev_level = prevLevel, new_level = newLevel})
            end
        end)
    end
    return data.xp
end

function XpService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return {xp = 0, level = 1, nextThreshold = 100, prevThreshold = 0} end
    local xp = data.xp or 0
    local level = computeLevel(xp)
    return {
        xp = xp,
        level = level,
        prevThreshold = Constants.XP_LEVEL_THRESHOLDS[level] or 0,
        nextThreshold = Constants.XP_LEVEL_THRESHOLDS[level + 1],  -- nil at max level
    }
end

if remotes.GetXpSnapshot then
    remotes.GetXpSnapshot.OnServerInvoke = function(player: Player)
        return XpService.snapshot(player.UserId)
    end
end

print("[XpService] ready")
return XpService
