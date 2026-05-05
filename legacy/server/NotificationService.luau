--!strict
-- Aggregator that walks every system's "is there something pending for
-- this player" state into one snapshot for the HUD's notification bell.
-- Read-only; never mutates PlayerData. Called whenever the bell modal
-- opens or every 30s as a refresh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local NotificationService = {}

local function utcDateKey(): string
    local t = os.date("!*t")
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

function NotificationService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return { entries = {}, total = 0 } end
    local entries: {any} = {}
    local now = os.time()
    -- Hourly tribute stacks
    do
        local last = data.lastHourlyTributeUnix or 0
        if last > 0 then
            local elapsed = now - last
            local stacks = math.floor(elapsed / Constants.HOURLY_TRIBUTE_INTERVAL_SEC)
            if stacks > Constants.HOURLY_TRIBUTE_STACK_CAP then
                stacks = Constants.HOURLY_TRIBUTE_STACK_CAP
            end
            if stacks > 0 then
                table.insert(entries, {
                    kind = "tribute",
                    label = string.format("%d hourly tribute stack%s ready",
                        stacks, stacks == 1 and "" or "s"),
                    actionHint = "tap TRIBUTE",
                    count = stacks,
                })
            end
        end
    end
    -- Daily spin
    if data.lastSpinDateKey ~= utcDateKey() then
        table.insert(entries, {
            kind = "spin", label = "daily spin available",
            actionHint = "tap DAILY SPIN", count = 1,
        })
    end
    -- Daily quests claimable
    do
        local dq = data.dailyQuests
        if dq and dq.dateKey == utcDateKey() and dq.progress and dq.claimed then
            local n = 0
            -- Count quests that are complete + unclaimed; we walk all pools to
            -- find the def, but that's O(small_constant)
            local pools = {
                Constants.DAILY_QUEST_POOL_EASY,
                Constants.DAILY_QUEST_POOL_MEDIUM,
                Constants.DAILY_QUEST_POOL_HARD,
            }
            for questId, progress in pairs(dq.progress) do
                if not dq.claimed[questId] then
                    -- find def
                    local target = nil
                    for _, pool in ipairs(pools) do
                        for _, def in ipairs(pool) do
                            if def.id == questId then target = def.target; break end
                        end
                        if target then break end
                    end
                    if target and progress >= target then
                        n += 1
                    end
                end
            end
            if n > 0 then
                table.insert(entries, {
                    kind = "quests",
                    label = string.format("%d daily quest%s ready to claim",
                        n, n == 1 and "" or "s"),
                    actionHint = "tap QUESTS",
                    count = n,
                })
            end
        end
    end
    -- Pending referral bonus (queued from offline-time referrals)
    if (data.pendingReferralBonusCoins or 0) > 0 then
        table.insert(entries, {
            kind = "referral_pending",
            label = string.format("+%d coins from offline referrals",
                data.pendingReferralBonusCoins),
            actionHint = "auto-claimed on login",
            count = 1,
        })
    end
    -- Free streak-egg pending? (We can't pre-detect; only granted at the
    -- moment of login when streak hits a threshold). Skip; covered by
    -- DailyBonusGranted event itself
    -- Pity counter close to legendary
    do
        local pity = data.hatchesSinceLastLegendary or 0
        local left = Constants.PET_PITY_THRESHOLD - pity
        if left > 0 and left <= 5 then
            table.insert(entries, {
                kind = "pity_close",
                label = string.format("legendary pity in %d more hatch%s",
                    left, left == 1 and "" or "es"),
                actionHint = "tap PETS",
                count = left,
            })
        end
    end
    -- Rebirth eligibility
    if data.upgradeTier >= #Constants.UPGRADE_TIERS
       and data.lifetimeCoins >= Constants.REBIRTH_MIN_LIFETIME_COINS then
        table.insert(entries, {
            kind = "rebirth_ready",
            label = "rebirth available -- prestige for permanent boost",
            actionHint = "step on rebirth pad",
            count = 1,
        })
    end
    return { entries = entries, total = #entries }
end

remotes.GetNotifications.OnServerInvoke = function(player: Player)
    return NotificationService.snapshot(player.UserId)
end

print("[NotificationService] ready")

return NotificationService
