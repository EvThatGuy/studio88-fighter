--!strict
-- Friend Code / Referral system. Each player gets an auto-generated
-- shareable code (e.g. "STUD-AB3X4"). New players can redeem someone
-- else's code (one-shot) and BOTH parties get a coin bonus.
--
-- Cross-session resolution: a separate DataStore (FRIEND_CODE_REGISTRY_NAME)
-- maps friendCode -> referrerUserId. So a referrer can be offline and
-- still be credited; their bonus accrues as `pendingReferralBonusCoins`
-- on their PlayerData and is granted on their next session start.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local registry = DataStoreService:GetDataStore(Constants.FRIEND_CODE_REGISTRY_NAME)

local ReferralService = {}

-- ---- Code generation ----------------------------------------------------

local CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no I/O/0/1 to avoid confusion

local function randomSuffix(length: number): string
    local out = {}
    for _ = 1, length do
        local n = math.random(1, #CHARS)
        table.insert(out, CHARS:sub(n, n))
    end
    return table.concat(out)
end

local function generateUniqueCode(userId: number): string?
    -- Try up to 8 times to find a non-colliding code.
    for _ = 1, 8 do
        local candidate = Constants.FRIEND_CODE_PREFIX .. randomSuffix(Constants.FRIEND_CODE_SUFFIX_LENGTH)
        local ok, existing = pcall(function() return registry:GetAsync(candidate) end)
        if ok and not existing then
            local writeOk = pcall(function()
                registry:SetAsync(candidate, userId)
            end)
            if writeOk then return candidate end
        end
    end
    return nil
end

function ReferralService.isFriendCode(code: string): boolean
    return typeof(code) == "string"
        and #code == (#Constants.FRIEND_CODE_PREFIX + Constants.FRIEND_CODE_SUFFIX_LENGTH)
        and code:sub(1, #Constants.FRIEND_CODE_PREFIX):upper() == Constants.FRIEND_CODE_PREFIX
end

-- ---- Lazy code provisioning on join -------------------------------------

local function provisionCode(player: Player)
    local data = DataStore.getCached(player.UserId)
    if not data then return end
    if data.friendCode and data.friendCode ~= "" then return end
    local code = generateUniqueCode(player.UserId)
    if code then
        data.friendCode = code
        print(string.format("[ReferralService] %s assigned code %s", player.Name, code))
    else
        warn(string.format("[ReferralService] could not generate code for %s after retries",
            player.Name))
    end
end

-- ---- Pending bonus claim on session start -------------------------------

local function claimPendingBonus(player: Player)
    local data = DataStore.getCached(player.UserId)
    if not data then return end
    local pending = data.pendingReferralBonusCoins or 0
    if pending <= 0 then return end
    data.coins += pending
    data.lifetimeCoins += pending
    data.pendingReferralBonusCoins = 0
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.ReferralBonusGranted:FireClient(player, math.floor(pending / Constants.REFERRAL_REFERRER_BONUS), pending)
    end)
    print(string.format("[ReferralService] %s claimed %d pending referral coins",
        player.Name, pending))
end

-- ---- Redemption ---------------------------------------------------------

-- Returns (success, reason). Called by CodesService when a redeem string
-- isn't a known promo code but matches the friend-code shape.
function ReferralService.attemptRedeem(player: Player, codeRaw: any): (boolean, string?)
    local data = DataStore.getCached(player.UserId)
    if not data then return false, "no_data" end
    if typeof(codeRaw) ~= "string" then return false, "bad_request" end
    local code = codeRaw:upper()
    if not ReferralService.isFriendCode(code) then return false, "not_friend_code" end
    if data.referredBy and data.referredBy ~= "" then return false, "already_referred" end
    if data.friendCode == code then return false, "cannot_self_refer" end
    -- Look up referrer
    local ok, referrerId = pcall(function() return registry:GetAsync(code) end)
    if not ok or not referrerId then return false, "unknown_friend_code" end
    if referrerId == player.UserId then return false, "cannot_self_refer" end
    -- Apply the redemption
    data.referredBy = code
    data.coins += Constants.REFERRAL_REFERRED_BONUS
    data.lifetimeCoins += Constants.REFERRAL_REFERRED_BONUS
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    -- Credit the referrer. If they're online in this server, mutate cache
    -- directly so they see it instantly. Otherwise update their stored
    -- record via UpdateAsync so it persists across server boundaries.
    local referrerPlayer = Players:GetPlayerByUserId(referrerId)
    if referrerPlayer then
        local rdata = DataStore.getCached(referrerId)
        if rdata then
            rdata.coins += Constants.REFERRAL_REFERRER_BONUS
            rdata.lifetimeCoins += Constants.REFERRAL_REFERRER_BONUS
            rdata.referralCount = (rdata.referralCount or 0) + 1
            pcall(function()
                remotes.BalanceUpdated:FireClient(referrerPlayer, rdata.coins, rdata.lifetimeCoins)
            end)
            pcall(function()
                remotes.ReferralBonusGranted:FireClient(referrerPlayer, 1, Constants.REFERRAL_REFERRER_BONUS)
            end)
        end
    else
        -- Offline: queue the bonus on their persistent record.
        local persistentStore = DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
        pcall(function()
            persistentStore:UpdateAsync(tostring(referrerId), function(old: any): any
                if typeof(old) ~= "table" then return old end
                old.pendingReferralBonusCoins = (old.pendingReferralBonusCoins or 0) + Constants.REFERRAL_REFERRER_BONUS
                old.referralCount = (old.referralCount or 0) + 1
                return old
            end)
        end)
    end
    print(string.format("[ReferralService] %s redeemed %s (referrer %d)",
        player.Name, code, referrerId))
    return true, nil
end

-- ---- Snapshot for HUD ---------------------------------------------------

-- Detect mutual referral presence: which players in this server are
-- linked to the asker via the referral graph (asker referred them OR they
-- referred asker OR they were referred by the same code as asker).
function ReferralService.friendsInServer(userId: number): {string}
    local askerData = DataStore.getCached(userId)
    if not askerData then return {} end
    local out: {string} = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other.UserId ~= userId then
            local odata = DataStore.getCached(other.UserId)
            if odata then
                local linked = false
                -- Asker referred them: their referredBy == asker.friendCode
                if askerData.friendCode and askerData.friendCode ~= ""
                   and odata.referredBy == askerData.friendCode then
                    linked = true
                end
                -- They referred asker: asker.referredBy == their friendCode
                if askerData.referredBy and odata.friendCode == askerData.referredBy then
                    linked = true
                end
                if linked then
                    table.insert(out, other.Name)
                end
            end
        end
    end
    return out
end

function ReferralService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return { friendCode = "", referralCount = 0, referredBy = nil, pendingBonusCoins = 0,
            friendsInServer = {},
            referrerBonus = Constants.REFERRAL_REFERRER_BONUS,
            referredBonus = Constants.REFERRAL_REFERRED_BONUS }
    end
    return {
        friendCode = data.friendCode or "",
        referralCount = data.referralCount or 0,
        referredBy = data.referredBy,
        pendingBonusCoins = data.pendingReferralBonusCoins or 0,
        friendsInServer = ReferralService.friendsInServer(userId),
        referrerBonus = Constants.REFERRAL_REFERRER_BONUS,
        referredBonus = Constants.REFERRAL_REFERRED_BONUS,
    }
end

-- ---- Wires --------------------------------------------------------------

remotes.GetFriendCode.OnServerInvoke = function(player: Player)
    return ReferralService.snapshot(player.UserId)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        for _ = 1, 6 do
            if DataStore.getCached(player.UserId) then
                provisionCode(player)
                claimPendingBonus(player)
                return
            end
            task.wait(0.5)
        end
    end)
end)

print("[ReferralService] ready")

return ReferralService
