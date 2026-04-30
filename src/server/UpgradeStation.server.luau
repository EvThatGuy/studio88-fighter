--!strict
-- Server-side upgrade purchase handler. Two entry points:
--   1. Client RemoteEvent (PurchaseUpgrade) -- legacy / programmatic
--   2. Direct attemptPurchase(player) call from UpgradeButtonProxy -- 3D
--      ProximityPrompt path. Same validation either way.
--
-- Validates funds against the *server's* cached balance, deducts cost,
-- increments tier, fires BalanceUpdated. Never trusts the client's
-- declared tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner.server"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats.server"))

local remotes = Remotes.get()

-- Module-level table so other server scripts can require this file and call
-- the same validated logic. (require() returns this table.)
local UpgradeStation = {}

local function pushRejection(player: Player, reason: string, needed: number?)
    pcall(function()
        remotes.PurchaseRejected:FireClient(player, reason, needed)
    end)
end

function UpgradeStation.attemptPurchase(player: Player): (boolean, string?)
    local data = DataStore.getCached(player.UserId)
    if not data then
        pushRejection(player, "no_data")
        return false, "no_data"
    end
    local nextTier = data.upgradeTier + 1
    local tierSpec = Constants.UPGRADE_TIERS[nextTier]
    if not tierSpec then
        pushRejection(player, "max_tier")
        return false, "max_tier"
    end
    if data.coins < tierSpec.cost then
        pushRejection(player, "insufficient_coins", tierSpec.cost - data.coins)
        return false, "insufficient_coins"
    end
    data.coins -= tierSpec.cost
    data.upgradeTier = nextTier
    -- Push fresh balance immediately so HUD doesn't wait for next tick
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    -- Repaint the plot to match the new tier and fire FX on the client
    local plot = PlotAssigner.getPlotFor(player.UserId)
    if plot then
        PlotAssigner.applyTierArt(plot, nextTier)
        PlotAssigner.updateStatsBoard(plot, nextTier, data.lifetimeCoins)
        -- Burst the upgrade button particle emitter for a celebratory pop
        local btn = plot:FindFirstChild("UpgradeButton") :: BasePart?
        if btn then
            local fx = btn:FindFirstChild("UpgradeFX") :: ParticleEmitter?
            if fx then
                pcall(function() fx:Emit(30) end)
            end
        end
    end
    Leaderstats.refresh(player.UserId)
    pcall(function()
        remotes.TierUpgraded:FireClient(player, nextTier, tierSpec.incomeMult)
    end)
    print(string.format("[UpgradeStation] %s -> tier %d (cost %d paid)",
        player.Name, nextTier, tierSpec.cost))
    return true, nil
end

-- RemoteEvent path (clients can still trigger if they have direct access)
remotes.PurchaseUpgrade.OnServerEvent:Connect(function(player: Player)
    local ok, reason = UpgradeStation.attemptPurchase(player)
    if not ok then
        warn(string.format("[UpgradeStation] %s purchase rejected: %s",
            player.Name, reason or "?"))
    end
end)

print("[UpgradeStation] ready (" .. (#Constants.UPGRADE_TIERS - 1) .. " tier upgrades)")

return UpgradeStation
