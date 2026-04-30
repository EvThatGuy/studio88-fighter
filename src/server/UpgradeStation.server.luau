--!strict
-- Server-side upgrade purchase handler. Client fires PurchaseUpgrade with no
-- payload (next-tier-up only). Server validates funds, deducts, increments
-- tier, and pushes a BalanceUpdated. Never trusts the client's declared tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local function tryPurchase(player: Player): (boolean, string?)
    local data = DataStore.getCached(player.UserId)
    if not data then return false, "no_data" end
    local nextTier = data.upgradeTier + 1
    local tierSpec = Constants.UPGRADE_TIERS[nextTier]
    if not tierSpec then
        return false, "max_tier"
    end
    if data.coins < tierSpec.cost then
        return false, "insufficient_coins"
    end
    data.coins -= tierSpec.cost
    data.upgradeTier = nextTier
    return true, nil
end

remotes.PurchaseUpgrade.OnServerEvent:Connect(function(player: Player)
    local ok, reason = tryPurchase(player)
    if not ok then
        warn(string.format("[UpgradeStation] %s purchase rejected: %s", player.Name, reason or "?"))
        return
    end
    local data = DataStore.requireCached(player.UserId)
    print(string.format("[UpgradeStation] %s -> tier %d (cost paid)",
        player.Name, data.upgradeTier))
    -- Push fresh balance immediately so the HUD updates without waiting for the next tick
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
end)

print("[UpgradeStation] ready (5 tiers configured)")
