--!strict
-- Consumable Dev Product handler. Wires MarketplaceService.ProcessReceipt
-- so when a player buys a coin pack or token pack, the server credits
-- their balance + acks Roblox so the receipt isn't double-processed.
--
-- Per monetization audit: dev products are the recurring revenue lever.
-- Players who already own all gamepasses still buy coin packs.
--
-- Receipt idempotency: Roblox guarantees ProcessReceipt is called once
-- per purchase, but we still write `redeemedDevProducts[purchaseId]=true`
-- on PlayerData to defend against the rare double-fire edge case.

local AnalyticsService = game:GetService("AnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local DevProductService = {}

-- Build a map productId -> {key, def} from Constants.DEV_PRODUCTS
local productIndex: {[number]: {key: string, def: any}} = {}
local function rebuildIndex()
    productIndex = {}
    for key, def in pairs(Constants.DEV_PRODUCTS) do
        if def.productId and def.productId > 0 then
            productIndex[def.productId] = {key = key, def = def}
        end
    end
end
rebuildIndex()

local function applyReward(player: Player, def: any)
    local data = DataStore.getCached(player.UserId)
    if not data then return false end
    local credited = false
    if def.coinAmount and def.coinAmount > 0 then
        data.coins += def.coinAmount
        data.lifetimeCoins += def.coinAmount
        credited = true
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
    end
    if def.tokenAmount and def.tokenAmount > 0 then
        data.rebirthTokens = (data.rebirthTokens or 0) + def.tokenAmount
        credited = true
    end
    if credited then
        Leaderstats.refresh(player.UserId)
    end
    return credited
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player left before we could credit. Returning NotProcessedYet
        -- means Roblox will retry next time the receipt is ack'd. Safe.
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local entry = productIndex[receiptInfo.ProductId]
    if not entry then
        -- Unknown productId — log + ack so Roblox doesn't retry
        warn(string.format("[DevProductService] unknown productId %d for %s",
            receiptInfo.ProductId, player.Name))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Idempotency check
    local data = DataStore.getCached(player.UserId)
    if not data then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    data.redeemedDevProducts = data.redeemedDevProducts or {}
    if data.redeemedDevProducts[tostring(receiptInfo.PurchaseId)] then
        -- Already credited; ack so Roblox stops retrying
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    data.redeemedDevProducts[tostring(receiptInfo.PurchaseId)] = true

    local ok = applyReward(player, entry.def)
    if not ok then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, Constants.ANALYTICS_EVENTS.PURCHASE_COMPLETED or "PurchaseCompleted",
            entry.def.priceRobux or 0,
            {product_id = receiptInfo.ProductId, key = entry.key}
        )
    end)
    print(string.format("[DevProductService] %s bought %s (%dR$)",
        player.Name, entry.key, entry.def.priceRobux or 0))
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Public snapshot for HUD shop modal
function DevProductService.snapshot()
    local out = {}
    for _, key in ipairs(Constants.DEV_PRODUCT_ORDER) do
        local def = Constants.DEV_PRODUCTS[key]
        if def then
            table.insert(out, {
                key = key,
                productId = def.productId,
                priceRobux = def.priceRobux,
                coinAmount = def.coinAmount,
                tokenAmount = def.tokenAmount,
                title = def.title,
                sub = def.sub,
                purchasable = (def.productId or 0) > 0,
            })
        end
    end
    return out
end

if remotes.GetDevProducts then
    remotes.GetDevProducts.OnServerInvoke = function(_player: Player)
        return DevProductService.snapshot()
    end
end

print(string.format("[DevProductService] ready (%d products configured, %d active)",
    #Constants.DEV_PRODUCT_ORDER, (function() local n=0; for _ in pairs(productIndex) do n+=1 end; return n end)()))
return DevProductService
