--!strict
-- Server-only currency tick. Mutates cached PlayerData in place; pushes
-- BalanceUpdated to the client every tick. Game Pass + Starter Pack
-- multipliers are checked once per minute (cached) to avoid spamming
-- MarketplaceService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService.server"))
local EventService = require(script.Parent:WaitForChild("EventService.server"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService.server"))

local remotes = Remotes.get()

-- Per-userId pass cache: {vip, premium, expiresAt}
type PassState = {vip: boolean, premium: boolean, refreshedAt: number}
local passCache: {[number]: PassState} = {}

local PASS_CACHE_TTL_SEC = 60

local function ownsPass(userId: number, passId: number): boolean
    if passId == 0 then return false end -- unset placeholder
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)
    return ok and owns or false
end

local function refreshPasses(userId: number): PassState
    local entry = {
        vip = ownsPass(userId, Constants.GAME_PASSES.VIP),
        premium = ownsPass(userId, Constants.GAME_PASSES.PREMIUM),
        refreshedAt = os.time(),
    }
    passCache[userId] = entry
    return entry
end

local function getPasses(userId: number): PassState
    local cached = passCache[userId]
    if cached and (os.time() - cached.refreshedAt) < PASS_CACHE_TTL_SEC then
        return cached
    end
    return refreshPasses(userId)
end

local function multiplierFor(userId: number, data): number
    local mult = 1.0
    -- Tier multiplier
    local tier = Constants.UPGRADE_TIERS[data.upgradeTier]
    if tier then mult *= tier.incomeMult end
    -- Rebirth permanent multiplier (1 + rebirths * REBIRTH_BONUS_PER)
    local rb = data.rebirths or 0
    if rb > 0 then mult *= (1 + rb * Constants.REBIRTH_BONUS_PER) end
    -- Pass multipliers
    local passes = getPasses(userId)
    if passes.vip then mult *= Constants.GAME_PASS_MULT.VIP_MULT end
    if passes.premium then mult *= Constants.GAME_PASS_MULT.PREMIUM_MULT end
    -- Starter Pack window
    local sp = data.starterPackPurchasedUnix
    if sp and (os.time() - sp) <= Constants.GAME_PASS_MULT.STARTER_PACK_DURATION_SEC then
        mult *= Constants.GAME_PASS_MULT.STARTER_PACK_MULT
    end
    -- Limited-time event multiplier (1.0 if no event active, else 2x/3x/etc)
    mult *= EventService.getMultiplier()
    return mult
end

local function tick()
    while true do
        task.wait(Constants.TICK_SECONDS)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataStore.getCached(player.UserId)
            if data then
                local gain = math.floor(Constants.BASE_INCOME_PER_TICK * multiplierFor(player.UserId, data))
                if gain > 0 then
                    data.coins += gain
                    data.lifetimeCoins += gain
                    pcall(function()
                        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
                    end)
                    -- Daily quest hook: every coin earned counts toward
                    -- earn-N-coins-today quests. Tick rate is 1s so a
                    -- single bump per tick is fine.
                    DailyQuestService.bumpProgress(player.UserId,
                        Constants.QUEST_KIND.EARN_COINS_TODAY, gain)
                    -- Tutorial step 5: lifetime crossed the rebirth gate
                    -- AND player is at max tier (eligibility). Advance
                    -- best-effort; TutorialService no-ops if past.
                    if data.lifetimeCoins >= Constants.REBIRTH_MIN_LIFETIME_COINS
                        and data.upgradeTier >= #Constants.UPGRADE_TIERS then
                        TutorialService.advance(player.UserId, "05_eligible_for_rebirth")
                    end
                end
            end
        end
    end
end

-- Server-authoritative balance read for the client (RemoteFunction).
remotes.GetBalance.OnServerInvoke = function(player: Player): {coins: number, lifetimeCoins: number, upgradeTier: number, rebirths: number}
    local data = DataStore.getCached(player.UserId)
    if not data then
        return {coins = 0, lifetimeCoins = 0, upgradeTier = 1, rebirths = 0}
    end
    return {coins = data.coins, lifetimeCoins = data.lifetimeCoins, upgradeTier = data.upgradeTier, rebirths = data.rebirths or 0}
end

-- Drop pass cache when a player leaves so memory doesn't bloat
Players.PlayerRemoving:Connect(function(player)
    passCache[player.UserId] = nil
end)

task.spawn(tick)

print("[CurrencyManager] tick started @ " .. Constants.TICK_SECONDS .. "s")
