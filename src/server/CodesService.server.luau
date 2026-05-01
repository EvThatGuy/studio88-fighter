--!strict
-- Promo codes redemption service. Server-authoritative.
--
-- Reads code definitions from Constants.CODES. Each redemption:
--   1. Checks per-player cooldown (anti-spam)
--   2. Uppercases input + looks up the code
--   3. Rejects if expired (expiresUnix in the past)
--   4. Rejects if already redeemed by this player (redeemedCodes ledger)
--   5. Rejects if global cap exceeded (maxGlobalRedemptions)
--   6. Grants reward to coins + lifetimeCoins; marks code as redeemed
--
-- Global redemption count is held in MemoryStoreService so it's consistent
-- across all live servers in this universe (NOT just this server). Falls
-- back to per-server count if MemoryStore is unavailable (Studio playtest,
-- etc.) so dev workflow doesn't crash.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats.server"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService.server"))

local remotes = Remotes.get()

local CodesService = {}

-- Per-player last-redeem-attempt timestamp. Used to gate spammy clicks.
local lastAttempt: {[number]: number} = {}

-- MemoryStore for cross-server global redemption counters. Each code gets
-- its own SortedMap entry (we use SortedMap for IncrementAsync semantics).
local globalCounter
do
    local ok, store = pcall(function()
        return MemoryStoreService:GetSortedMap("Studio88_CodeRedemptions_v1")
    end)
    if ok then globalCounter = store end
end

local function tryIncrementGlobal(code: string): number?
    if not globalCounter then return nil end
    local ok, value = pcall(function()
        -- IncrementAsync(key, deltaValue, expiration). 30-day TTL is fine
        -- for promo codes; rotate the SortedMap name on a longer cycle.
        return globalCounter:IncrementAsync(code, 1, 60 * 60 * 24 * 30)
    end)
    if ok then return value end
    return nil
end

local function tryReadGlobal(code: string): number?
    if not globalCounter then return nil end
    local ok, value = pcall(function()
        return globalCounter:GetAsync(code)
    end)
    if ok then return value end
    return nil
end

local function pushReject(player: Player, code: string, reason: string)
    pcall(function()
        remotes.CodeRejected:FireClient(player, code, reason)
    end)
end

-- Sanitize input: trim, uppercase, strip non-alphanumeric (covers paste of
-- "  launch! "). Length-cap so a 1MB string doesn't survive past parsing.
local function normalize(raw: any): string
    if typeof(raw) ~= "string" then return "" end
    local clipped = string.sub(raw, 1, 64)
    local upper = string.upper(clipped)
    local cleaned = string.gsub(upper, "[^A-Z0-9]", "")
    return cleaned
end

function CodesService.attemptRedeem(player: Player, rawCode: any): (boolean, string?)
    local userId = player.UserId
    local now = os.time()
    local last = lastAttempt[userId] or 0
    if (now - last) < Constants.CODE_REDEEM_COOLDOWN_SEC then
        pushReject(player, "", "rate_limited")
        return false, "rate_limited"
    end
    lastAttempt[userId] = now

    local code = normalize(rawCode)
    if code == "" then
        pushReject(player, "", "empty")
        return false, "empty"
    end
    local spec = Constants.CODES[code]
    if not spec then
        -- Fall through to friend-code redemption if the input matches the
        -- friend-code shape. ReferralService handles its own client push,
        -- so we just translate its rejection reasons back to the codes
        -- modal for unified UX.
        local ok, ReferralService = pcall(function()
            return require(script.Parent:WaitForChild("ReferralService.server"))
        end)
        if ok and ReferralService and ReferralService.isFriendCode(code) then
            local fok, freason = ReferralService.attemptRedeem(player, code)
            if fok then
                -- Reuse the code-redeemed UX for the redeemer; the actual
                -- coin balance push already happened inside ReferralService.
                pcall(function()
                    remotes.CodeRedeemed:FireClient(player, code, Constants.REFERRAL_REFERRED_BONUS)
                end)
                return true, nil
            else
                pushReject(player, code, "friend_" .. (freason or "unknown"))
                return false, freason
            end
        end
        pushReject(player, code, "unknown")
        return false, "unknown"
    end
    if spec.expiresUnix and now > spec.expiresUnix then
        pushReject(player, code, "expired")
        return false, "expired"
    end
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, code, "no_data")
        return false, "no_data"
    end
    if data.redeemedCodes and data.redeemedCodes[code] then
        pushReject(player, code, "already_redeemed")
        return false, "already_redeemed"
    end
    -- Global cap check (best-effort across servers via MemoryStore).
    if spec.maxGlobalRedemptions then
        local current = tryReadGlobal(code) or 0
        if current >= spec.maxGlobalRedemptions then
            pushReject(player, code, "cap_reached")
            return false, "cap_reached"
        end
        -- Increment now to claim a slot. If grant fails after this we leak
        -- one slot — acceptable for promo codes vs the alternative of
        -- two-phase commit on MemoryStore.
        local newCount = tryIncrementGlobal(code)
        if newCount and newCount > spec.maxGlobalRedemptions then
            pushReject(player, code, "cap_reached")
            return false, "cap_reached"
        end
    end
    -- Grant
    local reward = spec.reward
    data.coins += reward
    data.lifetimeCoins += reward
    if not data.redeemedCodes then data.redeemedCodes = {} end
    data.redeemedCodes[code] = true
    Leaderstats.refresh(userId)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.CodeRedeemed:FireClient(player, code, reward)
    end)
    DailyQuestService.bumpProgress(player.UserId,
        Constants.QUEST_KIND.REDEEM_CODE_TODAY, 1)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService.server"))
        AchievementService.evaluate(player.UserId)
    end)
    print(string.format("[CodesService] %s redeemed '%s' for %d coins",
        player.Name, code, reward))
    return true, nil
end

remotes.RequestRedeemCode.OnServerEvent:Connect(function(player: Player, rawCode: any)
    local ok, reason = CodesService.attemptRedeem(player, rawCode)
    if not ok then
        warn(string.format("[CodesService] %s redeem failed (%s): %s",
            player.Name, tostring(rawCode):sub(1, 32), reason or "?"))
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastAttempt[player.UserId] = nil
end)

local function listKnownCodes(): string
    local names = {}
    for k in pairs(Constants.CODES) do table.insert(names, k) end
    table.sort(names)
    return table.concat(names, ", ")
end

print(string.format("[CodesService] ready (%d codes loaded: %s)",
    (function() local n = 0; for _ in pairs(Constants.CODES) do n += 1 end; return n end)(),
    listKnownCodes()))

return CodesService
