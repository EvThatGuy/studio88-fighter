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

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService"))

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
    -- First rebirth has soft gates so D1 players can hit it in 10-15min
    -- (per tycoon-retention-checklist). Subsequent rebirths require the
    -- real grind: max tier + 100K lifetime.
    local rebirths = data.rebirths or 0
    local minTier, minLifetime
    if rebirths == 0 then
        minTier = Constants.REBIRTH_FIRST_MIN_TIER
        minLifetime = Constants.REBIRTH_FIRST_MIN_LIFETIME_COINS
    else
        minTier = #Constants.UPGRADE_TIERS
        minLifetime = Constants.REBIRTH_MIN_LIFETIME_COINS
    end
    if data.upgradeTier < minTier then
        return false, "min_tier", minTier - data.upgradeTier
    end
    if data.lifetimeCoins < minLifetime then
        return false, "insufficient_lifetime",
            minLifetime - data.lifetimeCoins
    end
    if rebirths >= Constants.REBIRTH_MAX then
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
    -- Detect first rebirth BEFORE we increment so we can fire the
    -- one-time celebration jackpot
    local isFirstRebirth = (data.rebirths or 0) == 0
    -- Apply the prestige reset
    data.coins = 0
    data.upgradeTier = 1
    data.rebirths = (data.rebirths or 0) + 1
    -- Rebirth shop currency: 1 token per rebirth (Constants-tunable)
    data.rebirthTokens = (data.rebirthTokens or 0) + Constants.REBIRTH_TOKEN_PER_REBIRTH
    -- First-rebirth jackpot: 5000 starter coins + 1 free luxury_egg pet
    -- hatch. THE D1→D7 conversion moment per checklist — make it
    -- memorable so players want to pursue more rebirths.
    if isFirstRebirth then
        data.coins += Constants.FIRST_REBIRTH_BONUS_COINS or 5000
        data.lifetimeCoins += Constants.FIRST_REBIRTH_BONUS_COINS or 5000
        pcall(function()
            local PetService = require(script.Parent:WaitForChild("PetService"))
            local owned, def = PetService.grantPetFromEgg(player, "luxury_egg")
            if owned and def then
                pcall(function()
                    remotes.PetHatched:FireClient(player, owned, def.name)
                end)
            end
        end)
    end
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
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, Constants.ANALYTICS_EVENTS.REBIRTH_GRANTED, data.rebirths,
            { rebirths_total = data.rebirths, tier_at_rebirth = data.upgradeTier or 1 }
        )
    end)
    DailyQuestService.bumpProgress(player.UserId,
        Constants.QUEST_KIND.REBIRTH_TODAY, 1)
    -- FTUE funnel step 6: first_rebirth — the D1→D7 conversion moment.
    -- TutorialService.advance is highest-step-wins so a 2nd rebirth no-ops.
    pcall(function()
        local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
        TutorialService.advance(player.UserId, "06_first_rebirth")
    end)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(player.UserId)
    end)
    -- Activity feed: only milestones (1, 5, 10, 25, 50, 100). A noisy
    -- "rebirth #2" event would clutter the ticker for everyone.
    do
        local milestones = Constants.ACTIVITY_FEED.REBIRTH_MILESTONES
        local hit = false
        for _, m in ipairs(milestones) do
            if data.rebirths == m then hit = true; break end
        end
        if hit then
            pcall(function()
                local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService"))
                ActivityFeedService.post(player, "rebirth_milestone",
                    "hit rebirth #" .. tostring(data.rebirths))
            end)
        end
    end
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
