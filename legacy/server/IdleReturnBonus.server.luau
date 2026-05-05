--!strict
-- Idle return bonus. When a player rejoins after being offline, credit
-- a prorated income bonus for up to 1 hour of offline time. Counters
-- the "I went away and came back to nothing" feeling for casual players
-- who don't have Premium AfkAutoCollect.
--
-- Computation: offlineSeconds = clamp(now - lastLogoutUnix, 0, 3600)
-- bonus = floor(offlineSeconds * baseIncomePerSec * tierMult * pets / 4)
-- (1/4 reduction so it doesn't trivialize active play)
--
-- Toast fires only if bonus > 0. New players (no lastLogoutUnix) get nil
-- and skip silently.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local MAX_OFFLINE_SEC = 3600  -- 1 hour cap so 1-week offline doesn't grant 168x
local IDLE_REDUCTION = 4       -- 1/4 of natural rate so active play stays the path

local function grantIfDue(player: Player)
    local data = DataStore.getCached(player.UserId)
    if not data then return end
    local lastLogout = data.lastLogoutUnix
    if not lastLogout or lastLogout <= 0 then return end
    local now = os.time()
    local offline = math.min(now - lastLogout, MAX_OFFLINE_SEC)
    if offline < 60 then return end  -- skip <1min "alt-tab" cases
    -- Compute the player's per-second income at their current tier
    local tierSpec = Constants.UPGRADE_TIERS[data.upgradeTier] or Constants.UPGRADE_TIERS[1]
    local perSec = (Constants.BASE_INCOME_PER_TICK * tierSpec.incomeMult) / Constants.TICK_SECONDS
    local bonus = math.floor(offline * perSec / IDLE_REDUCTION)
    if bonus <= 0 then return end
    data.coins += bonus
    data.lifetimeCoins += bonus
    Leaderstats.refresh(player.UserId)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.IdleReturnBonusGranted:FireClient(player, {
            offlineSec = offline,
            bonus = bonus,
            tier = data.upgradeTier,
        })
    end)
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, "IdleReturnBonus", bonus,
            {offline_sec = offline, tier = data.upgradeTier}
        )
    end)
    print(string.format("[IdleReturnBonus] %s +%d coins (offline %ds, tier %d)",
        player.Name, bonus, offline, data.upgradeTier))
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        -- Wait for DataStore.getCached to populate (5 retries x 0.5s)
        for _ = 1, 5 do
            if DataStore.getCached(player.UserId) then
                grantIfDue(player)
                return
            end
            task.wait(0.5)
        end
    end)
end)

print("[IdleReturnBonus] armed (max " .. MAX_OFFLINE_SEC .. "s, reduction 1/" .. IDLE_REDUCTION .. ")")
