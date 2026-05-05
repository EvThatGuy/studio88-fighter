--!strict
-- Daily Shop. UTC-day-rotating coin sink offering 3 items from
-- Constants.DAILY_SHOP_POOL. Deterministic selection per dateKey so all
-- servers in the universe show the same items + David can announce
-- "today's shop has X" once per day.
--
-- Per-player one-shot: each item can be bought ONCE per day.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local DailyShopService = {}

local function todayKey(): string
    local t = os.date("!*t") :: any
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function hashKey(s: string, salt: number): number
    local h = salt
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 2147483647
    end
    return h
end

-- Deterministic pick of N items from the pool, no duplicates
function DailyShopService.todaysItems(): {any}
    local key = todayKey()
    local pool = Constants.DAILY_SHOP_POOL
    local n = math.min(Constants.DAILY_SHOP_SLOT_COUNT, #pool)
    -- Build an indices list, shuffle deterministically by hash, take first N
    local idx = {}
    for i = 1, #pool do idx[i] = i end
    for i = 1, #pool do
        local j = (hashKey(key, i) % #pool) + 1
        idx[i], idx[j] = idx[j], idx[i]
    end
    local out = {}
    for i = 1, n do
        local item = pool[idx[i]]
        if item then table.insert(out, item) end
    end
    return out
end

-- Snapshot for HUD modal: today's items + which ones THIS player has bought
function DailyShopService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    local items = DailyShopService.todaysItems()
    local key = todayKey()
    local bought = (data and data.dailyShopBought) or {}
    local buyDateKey = (data and data.dailyShopDateKey) or ""
    -- Reset on day rollover
    if data and buyDateKey ~= key then
        data.dailyShopBought = {}
        data.dailyShopDateKey = key
        bought = {}
    end
    local out = {}
    for _, item in ipairs(items) do
        table.insert(out, {
            id = item.id,
            kind = item.kind,
            label = item.label,
            price = item.price,
            bought = bought[item.id] == true,
        })
    end
    return {dateKey = key, items = out, coinsAvailable = data and data.coins or 0}
end

-- Validated buy
function DailyShopService.attemptBuy(player: Player, itemId: any): (boolean, string?)
    local data = DataStore.getCached(player.UserId)
    if not data then return false, "no_data" end
    if typeof(itemId) ~= "string" then return false, "bad_request" end
    local items = DailyShopService.todaysItems()
    local item = nil
    for _, it in ipairs(items) do
        if it.id == itemId then item = it; break end
    end
    if not item then return false, "not_in_today_shop" end
    -- Day rollover sync
    local key = todayKey()
    if data.dailyShopDateKey ~= key then
        data.dailyShopBought = {}
        data.dailyShopDateKey = key
    end
    data.dailyShopBought = data.dailyShopBought or {}
    if data.dailyShopBought[itemId] then return false, "already_bought" end
    if data.coins < item.price then return false, "insufficient_coins" end
    data.coins -= item.price
    data.dailyShopBought[itemId] = true
    -- Apply payload
    if item.kind == "coins" then
        data.coins += item.payload
        data.lifetimeCoins += item.payload
    elseif item.kind == "boost_sec" then
        local now = os.time()
        local current = data.petBoostExpiresUnix or 0
        local base = (current > now) and current or now
        data.petBoostExpiresUnix = base + item.payload
    elseif item.kind == "rebirth_token" then
        data.rebirthTokens = (data.rebirthTokens or 0) + item.payload
    elseif item.kind == "random_pet" then
        pcall(function()
            local PetService = require(script.Parent:WaitForChild("PetService"))
            local owned, def = PetService.grantPetFromEgg(player, item.payload)
            if owned and def then
                pcall(function()
                    remotes.PetHatched:FireClient(player, owned, def.name)
                end)
            end
        end)
    end
    Leaderstats.refresh(player.UserId)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        AnalyticsService:LogCustomEvent(player, "DailyShopPurchase", item.price,
            {item_id = itemId, kind = item.kind})
    end)
    print(string.format("[DailyShopService] %s bought %s for %d", player.Name, itemId, item.price))
    return true, nil
end

if remotes.GetDailyShop then
    remotes.GetDailyShop.OnServerInvoke = function(player: Player)
        return DailyShopService.snapshot(player.UserId)
    end
end
if remotes.BuyDailyShopItem then
    remotes.BuyDailyShopItem.OnServerEvent:Connect(function(player: Player, itemId: any)
        DailyShopService.attemptBuy(player, itemId)
    end)
end

print(string.format("[DailyShopService] ready (%d-item pool, %d slots/day, today: %s)",
    #Constants.DAILY_SHOP_POOL, Constants.DAILY_SHOP_SLOT_COUNT, todayKey()))
return DailyShopService
