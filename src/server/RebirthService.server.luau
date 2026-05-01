--!strict
-- Rebirth (prestige) service. Server-authoritative.
--
-- A player at the max upgrade tier with at least REBIRTH_MIN_LIFETIME_COINS
-- earned can request a rebirth. On accept:
--   - coins reset to 0
--   - upgradeTier reset to 1 (with plot art repainted)
--   - rebirths++ (capped at REBIRTH_MAX)
--   - lifetimeCoins is preserved (rebirth is a soft reset; leaderboard stays)
--   - permanent income multiplier (1 + rebirths * REBIRTH_BONUS_PER) takes
--     effect immediately on the next tick via CurrencyManager.multiplierFor()
--
-- Eligibility is checked server-side; clients can spam RequestRebirth all
-- they want. We never trust client-supplied tier/coin values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner.server"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats.server"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService.server"))

local remotes = Remotes.get()

local RebirthService = {}

local function pushReject(player: Player, reason: string, needed: number?)
    pcall(function()
        remotes.RebirthRejected:FireClient(player, reason, needed)
    end)
end

-- Returns (eligible: boolean, reason: string?, needed: number?). `needed`
-- semantics: for "min_tier" it's the missing tier count, for
-- "insufficient_lifetime" it's the coin shortfall, for "max_rebirths" nil.
function RebirthService.checkEligibility(userId: number): (boolean, string?, number?)
    local data = DataStore.getCached(userId)
    if not data then return false, "no_data", nil end
    local maxTier = #Constants.UPGRADE_TIERS
    if data.upgradeTier < maxTier then
        return false, "min_tier", maxTier - data.upgradeTier
    end
    if data.lifetimeCoins < Constants.REBIRTH_MIN_LIFETIME_COINS then
        return false, "insufficient_lifetime",
            Constants.REBIRTH_MIN_LIFETIME_COINS - data.lifetimeCoins
    end
    if (data.rebirths or 0) >= Constants.REBIRTH_MAX then
        return false, "max_rebirths", nil
    end
    return true, nil, nil
end

function RebirthService.attemptRebirth(player: Player): (boolean, string?)
    local userId = player.UserId
    local ok, reason, needed = RebirthService.checkEligibility(userId)
    if not ok then
        pushReject(player, reason or "?", needed)
        return false, reason
    end
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, "no_data")
        return false, "no_data"
    end
    -- Apply the prestige reset
    data.coins = 0
    data.upgradeTier = 1
    data.rebirths = (data.rebirths or 0) + 1
    -- Rebirth shop currency: 1 token per rebirth (Constants-tunable)
    data.rebirthTokens = (data.rebirthTokens or 0) + Constants.REBIRTH_TOKEN_PER_REBIRTH
    -- Repaint the plot back to tier-1 art so the visual matches
    local plot = PlotAssigner.getPlotFor(userId)
    if plot then
        PlotAssigner.applyTierArt(plot, 1)
        PlotAssigner.updateStatsBoard(plot, 1, data.lifetimeCoins)
    end
    Leaderstats.refresh(userId)
    -- Push fresh balance + the rebirth event
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    local newMult = 1 + data.rebirths * Constants.REBIRTH_BONUS_PER
    pcall(function()
        remotes.RebirthGranted:FireClient(player, data.rebirths, newMult)
    end)
    DailyQuestService.bumpProgress(player.UserId,
        Constants.QUEST_KIND.REBIRTH_TODAY, 1)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService.server"))
        AchievementService.evaluate(player.UserId)
    end)
    print(string.format(
        "[RebirthService] %s rebirthed (#%d, perma-mult x%.2f)",
        player.Name, data.rebirths, newMult
    ))
    return true, nil
end

remotes.RequestRebirth.OnServerEvent:Connect(function(player: Player)
    local ok, reason = RebirthService.attemptRebirth(player)
    if not ok then
        warn(string.format(
            "[RebirthService] %s rebirth rejected: %s", player.Name, reason or "?"
        ))
    end
end)

print(string.format(
    "[RebirthService] ready (gate: tier %d, %d lifetime coins, max %d rebirths)",
    #Constants.UPGRADE_TIERS,
    Constants.REBIRTH_MIN_LIFETIME_COINS,
    Constants.REBIRTH_MAX
))

return RebirthService
