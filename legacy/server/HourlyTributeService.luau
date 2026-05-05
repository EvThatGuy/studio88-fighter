--!strict
-- Hourly Tribute. A coin reward stack that accrues every
-- HOURLY_TRIBUTE_INTERVAL_SEC seconds up to HOURLY_TRIBUTE_STACK_CAP.
-- Player taps "claim" -> all stacks credited as coins, scaled by current
-- tier income mult so the reward stays meaningful as they progress.
--
-- Designed to move the 2026 RFY signal #2 (sessions/user/day). Cap means
-- leaving for 5+ hours pays the same as leaving for 4 -- if you want max
-- value you must come back within 4-hour windows.
--
-- All state derives from a single field (lastHourlyTributeUnix), so the
-- snapshot is stateless and computed on-demand. Save cost is the same
-- as a regular tier-up commit.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local HourlyTributeService = {}

-- ---- Math ---------------------------------------------------------------

local function tierMult(data: Types.PlayerData): number
    local tier = Constants.UPGRADE_TIERS[data.upgradeTier]
    if tier then return tier.incomeMult end
    return 1
end

-- Returns (availableStacks, secondsUntilNextStack)
-- availableStacks is clamped to HOURLY_TRIBUTE_STACK_CAP.
-- For a brand-new player (lastHourlyTributeUnix == 0) we treat their
-- account creation moment as "now" -- they wait the full interval for
-- the first stack rather than getting a free one on join. Fair, and
-- avoids a free coin dump at character spawn.
local function computeStacks(data: Types.PlayerData): (number, number)
    local now = os.time()
    local last = data.lastHourlyTributeUnix or 0
    if last == 0 then
        -- Initialize so the timer starts "now" the first time we ask
        data.lastHourlyTributeUnix = now
        return 0, Constants.HOURLY_TRIBUTE_INTERVAL_SEC
    end
    local elapsed = now - last
    local stacks = math.floor(elapsed / Constants.HOURLY_TRIBUTE_INTERVAL_SEC)
    if stacks < 0 then stacks = 0 end
    if stacks > Constants.HOURLY_TRIBUTE_STACK_CAP then
        stacks = Constants.HOURLY_TRIBUTE_STACK_CAP
    end
    local nextIn = Constants.HOURLY_TRIBUTE_INTERVAL_SEC - (elapsed % Constants.HOURLY_TRIBUTE_INTERVAL_SEC)
    return stacks, nextIn
end

local function rewardPerStack(data: Types.PlayerData): number
    return Constants.HOURLY_TRIBUTE_BASE_REWARD * tierMult(data)
end

-- ---- Snapshot -----------------------------------------------------------

function HourlyTributeService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return {
            available = 0, capped = false,
            nextStackInSec = Constants.HOURLY_TRIBUTE_INTERVAL_SEC,
            perStackReward = 0,
            cap = Constants.HOURLY_TRIBUTE_STACK_CAP,
        }
    end
    local stacks, nextIn = computeStacks(data)
    return {
        available = stacks,
        capped = stacks >= Constants.HOURLY_TRIBUTE_STACK_CAP,
        nextStackInSec = nextIn,
        perStackReward = rewardPerStack(data),
        cap = Constants.HOURLY_TRIBUTE_STACK_CAP,
    }
end

-- ---- Claim --------------------------------------------------------------

local function pushReject(player: Player, reason: string)
    pcall(function()
        remotes.HourlyTributeRejected:FireClient(player, reason)
    end)
end

function HourlyTributeService.attemptClaim(player: Player): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, "no_data")
        return false, "no_data"
    end
    local stacks = computeStacks(data)
    if stacks <= 0 then
        pushReject(player, "no_stacks")
        return false, "no_stacks"
    end
    local perStack = rewardPerStack(data)
    local reward = math.floor(perStack * stacks)
    -- Roll the lastHourlyTributeUnix forward by exactly stacks * interval
    -- (NOT to os.time()) so leftover sub-interval time is preserved.
    -- Otherwise a player who's 3h59m past would lose 59m of progress on
    -- claim. With this approach, they get 3 stacks now + only have to
    -- wait 1 hour for the 4th.
    local consumed = stacks * Constants.HOURLY_TRIBUTE_INTERVAL_SEC
    data.lastHourlyTributeUnix = (data.lastHourlyTributeUnix or os.time()) + consumed
    -- Defensive: if the player was capped (>= 4 stacks worth of elapsed),
    -- the addition above might still leave them >cap stacks behind. Snap
    -- to "now - 0" in that case so the clock resets cleanly.
    local check = computeStacks(data)
    if check >= Constants.HOURLY_TRIBUTE_STACK_CAP then
        data.lastHourlyTributeUnix = os.time()
    end
    -- Credit
    data.coins += reward
    data.lifetimeCoins += reward
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.HourlyTributeClaimed:FireClient(player, stacks, reward)
    end)
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, Constants.ANALYTICS_EVENTS.TRIBUTE_CLAIMED, reward,
            { stacks = stacks, value = reward }
        )
    end)
    -- Achievement scan -- lifetime coins changed
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(userId)
    end)
    print(string.format("[HourlyTribute] %s claimed %d stacks for %d coins",
        player.Name, stacks, reward))
    return true, nil
end

-- ---- Wires --------------------------------------------------------------

remotes.GetHourlyTribute.OnServerInvoke = function(player: Player)
    return HourlyTributeService.snapshot(player.UserId)
end

remotes.ClaimHourlyTribute.OnServerEvent:Connect(function(player: Player)
    HourlyTributeService.attemptClaim(player)
end)

print(string.format("[HourlyTribute] ready (interval %ds, cap %d, base %d)",
    Constants.HOURLY_TRIBUTE_INTERVAL_SEC,
    Constants.HOURLY_TRIBUTE_STACK_CAP,
    Constants.HOURLY_TRIBUTE_BASE_REWARD))

return HourlyTributeService
