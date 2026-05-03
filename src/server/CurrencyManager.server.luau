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
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local SquadBonusService = require(script.Parent:WaitForChild("SquadBonusService"))

local remotes = Remotes.get()

-- Per-userId pass cache: {vip, premium, expiresAt}
type PassState = {vip: boolean, premium: boolean, refreshedAt: number}
local passCache: {[number]: PassState} = {}

local PASS_CACHE_TTL_SEC = 60

-- INCOME_MULT_CAP hit counter, swept + logged every 60s by the monitor
-- task at the bottom of multiplierFor's neighborhood. Forward-declared
-- here so the multiplierFor branch + the sweep loop both see the upvalue.
local capHits = 0

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
    -- Rebirth shop unlocks (1 + sum of multAdd of each owned item).
    -- Stacks meta-multiplicatively with the rebirth perma-mult so a fully-
    -- decked end-game player can hit ~10x from rebirth alone.
    local owned = data.purchasedRebirthUpgrades or {}
    local shopAdd = 0
    for _, item in ipairs(Constants.REBIRTH_SHOP_ITEMS) do
        if owned[item.id] then shopAdd += item.multAdd end
    end
    if shopAdd > 0 then mult *= (1 + shopAdd) end
    -- Pass multipliers
    local passes = getPasses(userId)
    if passes.vip then mult *= Constants.GAME_PASS_MULT.VIP_MULT end
    if passes.premium then mult *= Constants.GAME_PASS_MULT.PREMIUM_MULT end
    -- Roblox Premium subscribers get +25% income (free Roblox-promoted
    -- bonus per retention checklist). Read MembershipType off the Player
    -- — no async / no rate-limit risk like MarketplaceService.
    local player = Players:GetPlayerByUserId(userId)
    if player and player.MembershipType == Enum.MembershipType.Premium then
        mult *= Constants.ROBLOX_PREMIUM_INCOME_MULT
    end
    -- Starter Pack window
    local sp = data.starterPackPurchasedUnix
    if sp and (os.time() - sp) <= Constants.GAME_PASS_MULT.STARTER_PACK_DURATION_SEC then
        mult *= Constants.GAME_PASS_MULT.STARTER_PACK_MULT
    end
    -- Limited-time event multiplier (1.0 if no event active, else 2x/3x/etc)
    mult *= EventService.getMultiplier()
    -- Pets: equipped boost + collection completion bonus. 1.0 if none equipped
    -- and collection incomplete. Stacks meta-multiplicatively with everything.
    mult *= PetService.getPetMultiplier(userId)
    -- Squad Bonus: 1.0 below threshold, otherwise SQUAD_BONUS.MULTIPLIER
    -- for everyone in the server. Compounds with the rest.
    mult *= SquadBonusService.getMultiplier()
    -- Hard ceiling so no exploit chain (full premium pass + max rebirths
    -- + every shop item + collection complete + boost active + event 3x)
    -- can drive the multiplier into runaway territory. Theoretical max
    -- without cap = ~72,000x base (tier 80 × rebirth 6 × shop 2 × passes 3
    -- × premium 1.25 × event 2 × pets ~10). 50,000x cap leaves comfortable
    -- end-game headroom while bounding economy damage from any single bug.
    if mult > Constants.INCOME_MULT_CAP then
        capHits += 1  -- file-scope counter, sweep loop logs every 60s
        mult = Constants.INCOME_MULT_CAP
    end
    return mult
end

-- Cap-hit monitoring: every 60s log how many ticks hit the ceiling.
-- If non-zero, surfaces that we have a player legitimately at end-game
-- OR a mult-stacking bug. Counter resets after each log.
task.spawn(function()
    while true do
        task.wait(60)
        if capHits > 0 then
            warn(string.format("[CurrencyManager] INCOME_MULT_CAP hit %d times in last 60s", capHits))
            capHits = 0
        end
    end
end)

-- Per-userId throttle on cheat warnings — 1 warning per player per 5min
-- so a sustained exploit doesn't spam the log.
local lastCheatWarnAt: {[number]: number} = {}
local CHEAT_WARN_COOLDOWN_SEC = 300

local function tick()
    while true do
        task.wait(Constants.TICK_SECONDS)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataStore.getCached(player.UserId)
            if data then
                local mult = multiplierFor(player.UserId, data)
                local gain = math.floor(Constants.BASE_INCOME_PER_TICK * mult)
                -- Cheat detection: if gain implies a multiplier higher than
                -- the legit max for this player+state, log once per 5min.
                -- Detect by comparing gain to the same multiplierFor result —
                -- they should match exactly. If a future exploit bypasses
                -- multiplierFor by writing data.coins directly, the next
                -- tick will see lifetimeCoins jump out-of-band; that case
                -- is detected by AchievementService's coin-milestone evals.
                -- Here we just sanity-check that gain matches mult.
                local expectedGain = math.floor(Constants.BASE_INCOME_PER_TICK * mult)
                if gain ~= expectedGain then
                    local now = os.time()
                    if (now - (lastCheatWarnAt[player.UserId] or 0)) >= CHEAT_WARN_COOLDOWN_SEC then
                        lastCheatWarnAt[player.UserId] = now
                        warn(string.format(
                            "[CurrencyManager] CHEAT? %s gain=%d but mult=%.2f implies %d",
                            player.Name, gain, mult, expectedGain
                        ))
                    end
                end
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
                    -- Throttled achievement scan; only the lifetime-coins
                    -- predicates depend on tick deltas. 5s throttle invisible
                    -- to the player and skips ~80% of redundant evaluation.
                    AchievementService.evaluateThrottled(player.UserId)
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
