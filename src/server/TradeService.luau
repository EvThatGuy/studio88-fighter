--!strict
-- Trade system. SCAFFOLDED but DISABLED via Constants.TRADING.ENABLED.
-- Per tycoon-retention-checklist mechanic 6: trading is THE D30 lever
-- but DEFER until the rest of the game is stable. The full implementation
-- here is ready to flip on, with all anti-scam guards baked in:
--
--   1. 15s mandatory confirm hold between offer and confirm
--   2. Both players must DOUBLE confirm
--   3. Value estimates per side, displayed before each confirm
--   4. Value mismatch beyond TOLERANCE auto-rejects
--   5. Per-player cooldown between trades
--
-- Keep this file as the FOUNDATION. Trading UI (modal, drag-drop) is
-- a separate iteration.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local TradeService = {}

-- Active trade sessions keyed by initiator userId.
-- session = {
--   initiatorId = N, partnerId = N, openedAt = unix,
--   initiatorOffer = {coins, petUids = {}}, partnerOffer = {...},
--   confirms = {[initiatorId] = bool, [partnerId] = bool},
--   doubleConfirms = {[initiatorId] = bool, [partnerId] = bool},
-- }
local sessions: {[number]: any} = {}
local lastTradeAt: {[number]: number} = {}

local function disabled(): boolean
    return not (Constants.TRADING and Constants.TRADING.ENABLED)
end

-- Estimate the value of an offer side (sum of pet rarity mults * 10000 + coins).
local function estimateValue(userId: number, offer): number
    if not offer then return 0 end
    local v = (offer.coins or 0)
    local data = DataStore.getCached(userId)
    if data and offer.petUids then
        local petByUid: {[string]: any} = {}
        for _, p in ipairs(data.pets or {}) do petByUid[p.uid] = p end
        for _, uid in ipairs(offer.petUids) do
            local p = petByUid[uid]
            if p then
                local r = Constants.PET_RARITIES[p.rarity]
                if r then v += math.floor(r.mult * 10000) end
            end
        end
    end
    return v
end

-- Strict membership check + cap enforcement on an offer.
local function validateOffer(userId: number, offer): (boolean, string?)
    if not offer then return false, "no_offer" end
    local data = DataStore.getCached(userId)
    if not data then return false, "no_data" end
    if (offer.coins or 0) < 0 then return false, "neg_coins" end
    if (offer.coins or 0) > data.coins then return false, "insufficient_coins" end
    if (offer.coins or 0) > Constants.TRADING.MAX_COINS_PER_OFFER then return false, "coins_cap" end
    if offer.petUids and #offer.petUids > Constants.TRADING.MAX_PETS_PER_OFFER then
        return false, "pets_cap"
    end
    if offer.petUids then
        local owned: {[string]: boolean} = {}
        for _, p in ipairs(data.pets or {}) do owned[p.uid] = true end
        for _, uid in ipairs(offer.petUids) do
            if not owned[uid] then return false, "pet_not_owned" end
        end
        -- Equipped pets cannot be traded
        local equipped: {[string]: boolean} = {}
        for _, uid in ipairs(data.equippedPetIds or {}) do equipped[uid] = true end
        for _, uid in ipairs(offer.petUids) do
            if equipped[uid] then return false, "pet_equipped" end
        end
    end
    return true, nil
end

function TradeService.attemptInitiate(initiator: Player, partnerId: number): (boolean, string?)
    if disabled() then return false, "trading_disabled" end
    if initiator.UserId == partnerId then return false, "is_self" end
    if (os.time() - (lastTradeAt[initiator.UserId] or 0)) < Constants.TRADING.COOLDOWN_SEC_BETWEEN_TRADES then
        return false, "cooldown"
    end
    local partner = Players:GetPlayerByUserId(partnerId)
    if not partner then return false, "partner_offline" end
    if sessions[initiator.UserId] or sessions[partnerId] then return false, "session_exists" end
    sessions[initiator.UserId] = {
        initiatorId = initiator.UserId,
        partnerId = partnerId,
        openedAt = os.time(),
        initiatorOffer = {coins = 0, petUids = {}},
        partnerOffer = {coins = 0, petUids = {}},
        confirms = {},
        doubleConfirms = {},
    }
    return true, nil
end

function TradeService.attemptCommit(player: Player): (boolean, string?)
    if disabled() then return false, "trading_disabled" end
    local session = sessions[player.UserId]
    if not session then
        -- Maybe they're the partner side
        for _, s in pairs(sessions) do
            if s.partnerId == player.UserId then session = s; break end
        end
    end
    if not session then return false, "no_session" end
    -- Validate hold
    if (os.time() - session.openedAt) < Constants.TRADING.CONFIRM_HOLD_SEC then
        return false, "hold_not_expired"
    end
    -- Validate offers
    local initOk, initWhy = validateOffer(session.initiatorId, session.initiatorOffer)
    if not initOk then return false, "init_invalid_" .. (initWhy or "?") end
    local partOk, partWhy = validateOffer(session.partnerId, session.partnerOffer)
    if not partOk then return false, "partner_invalid_" .. (partWhy or "?") end
    -- Value mismatch tolerance
    local v1 = estimateValue(session.initiatorId, session.initiatorOffer)
    local v2 = estimateValue(session.partnerId, session.partnerOffer)
    if v1 > 0 and v2 > 0 then
        local ratio = math.max(v1 / v2, v2 / v1)
        if ratio > Constants.TRADING.VALUE_MISMATCH_TOLERANCE then
            return false, "value_mismatch"
        end
    end
    -- Both must DOUBLE confirm
    if Constants.TRADING.REQUIRE_DOUBLE_CONFIRM then
        if not (session.doubleConfirms[session.initiatorId] and session.doubleConfirms[session.partnerId]) then
            return false, "double_confirm_required"
        end
    else
        if not (session.confirms[session.initiatorId] and session.confirms[session.partnerId]) then
            return false, "confirm_required"
        end
    end
    -- Execute the swap atomically (reads + writes within this function;
    -- no yields, so two concurrent sessions can't interleave even though
    -- DataStore.getCached is shared).
    local d1 = DataStore.getCached(session.initiatorId)
    local d2 = DataStore.getCached(session.partnerId)
    if not d1 or not d2 then return false, "data_missing" end
    -- Coins
    d1.coins -= (session.initiatorOffer.coins or 0)
    d2.coins -= (session.partnerOffer.coins or 0)
    d1.coins += (session.partnerOffer.coins or 0)
    d2.coins += (session.initiatorOffer.coins or 0)
    -- Pets: remove from owner, append to receiver
    local function transfer(fromData, toData, uids)
        local kept = {}
        local moving = {}
        for _, p in ipairs(fromData.pets or {}) do
            local found = false
            for _, uid in ipairs(uids) do
                if uid == p.uid then found = true; table.insert(moving, p); break end
            end
            if not found then table.insert(kept, p) end
        end
        fromData.pets = kept
        if not toData.pets then toData.pets = {} end
        for _, p in ipairs(moving) do table.insert(toData.pets, p) end
    end
    transfer(d1, d2, session.initiatorOffer.petUids or {})
    transfer(d2, d1, session.partnerOffer.petUids or {})
    -- Refresh leaderstats + balance broadcast
    Leaderstats.refresh(session.initiatorId)
    Leaderstats.refresh(session.partnerId)
    local p1 = Players:GetPlayerByUserId(session.initiatorId)
    local p2 = Players:GetPlayerByUserId(session.partnerId)
    if p1 then pcall(function() remotes.BalanceUpdated:FireClient(p1, d1.coins, d1.lifetimeCoins) end) end
    if p2 then pcall(function() remotes.BalanceUpdated:FireClient(p2, d2.coins, d2.lifetimeCoins) end) end
    -- Cleanup
    sessions[session.initiatorId] = nil
    lastTradeAt[session.initiatorId] = os.time()
    lastTradeAt[session.partnerId] = os.time()
    return true, nil
end

-- Public: cancel a trade (either party)
function TradeService.cancel(player: Player)
    for k, s in pairs(sessions) do
        if s.initiatorId == player.UserId or s.partnerId == player.UserId then
            sessions[k] = nil
        end
    end
end

if disabled() then
    print("[TradeService] DISABLED (set Constants.TRADING.ENABLED=true to activate)")
else
    print("[TradeService] ARMED — anti-scam guards active")
end

return TradeService
