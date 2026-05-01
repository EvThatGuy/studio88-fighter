--!strict
-- Rebirth shop service. Server-authoritative, mirrors the structure of
-- CodesService / DailyQuestService. Players spend Rebirth Tokens (earned
-- 1 per rebirth via RebirthService) on permanent meta-upgrades that
-- stack on top of the rebirth perma-mult. This is the long-tail D30
-- driver per the research-engineer brief: rebirth without a sink
-- flat-lines the dopamine curve at rebirth #4-ish; rebirth WITH a shop
-- restarts the climb dopamine on every prestige.
--
-- All purchases are one-shot (purchasedRebirthUpgrades ledger). The
-- multiplier effect is applied lazily inside CurrencyManager.multiplierFor
-- so the shop service itself is purely transactional.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local RebirthShopService = {}

local function findItem(itemId: string)
    for _, it in ipairs(Constants.REBIRTH_SHOP_ITEMS) do
        if it.id == itemId then return it end
    end
    return nil
end

local function pushReject(player: Player, itemId: string, reason: string, needed: number?)
    pcall(function()
        remotes.RebirthShopRejected:FireClient(player, itemId, reason, needed)
    end)
end

function RebirthShopService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return nil end
    local owned = data.purchasedRebirthUpgrades or {}
    local items = {}
    for _, id in ipairs(Constants.REBIRTH_SHOP_ORDER) do
        local def = findItem(id)
        if def then
            table.insert(items, {
                id = def.id,
                title = def.title,
                sub = def.sub,
                cost = def.cost,
                multAdd = def.multAdd,
                owned = owned[def.id] == true,
            })
        end
    end
    return { tokens = data.rebirthTokens or 0, items = items }
end

function RebirthShopService.attemptPurchase(player: Player, itemId: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, tostring(itemId), "no_data")
        return false, "no_data"
    end
    if typeof(itemId) ~= "string" then
        pushReject(player, "", "bad_request")
        return false, "bad_request"
    end
    local def = findItem(itemId)
    if not def then
        pushReject(player, itemId, "unknown_item")
        return false, "unknown_item"
    end
    local owned = data.purchasedRebirthUpgrades or {}
    if owned[itemId] then
        pushReject(player, itemId, "already_owned")
        return false, "already_owned"
    end
    local tokens = data.rebirthTokens or 0
    if tokens < def.cost then
        pushReject(player, itemId, "insufficient_tokens", def.cost - tokens)
        return false, "insufficient_tokens"
    end
    -- Commit
    data.rebirthTokens = tokens - def.cost
    if not data.purchasedRebirthUpgrades then data.purchasedRebirthUpgrades = {} end
    data.purchasedRebirthUpgrades[itemId] = true
    pcall(function()
        remotes.RebirthShopPurchased:FireClient(player, itemId, data.rebirthTokens)
    end)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService.server"))
        AchievementService.evaluate(player.UserId)
    end)
    print(string.format("[RebirthShopService] %s bought '%s' for %d tokens (remaining %d)",
        player.Name, itemId, def.cost, data.rebirthTokens))
    return true, nil
end

remotes.GetRebirthShop.OnServerInvoke = function(player: Player)
    return RebirthShopService.snapshot(player.UserId) or { tokens = 0, items = {} }
end

remotes.BuyRebirthShopItem.OnServerEvent:Connect(function(player: Player, itemId: any)
    local ok, reason = RebirthShopService.attemptPurchase(player, itemId)
    if not ok then
        warn(string.format("[RebirthShopService] %s buy '%s' failed: %s",
            player.Name, tostring(itemId):sub(1, 32), reason or "?"))
    end
end)

print(string.format("[RebirthShopService] ready (%d items, %d total token cost)",
    #Constants.REBIRTH_SHOP_ITEMS,
    (function()
        local s = 0
        for _, it in ipairs(Constants.REBIRTH_SHOP_ITEMS) do s += it.cost end
        return s
    end)()
))

return RebirthShopService
