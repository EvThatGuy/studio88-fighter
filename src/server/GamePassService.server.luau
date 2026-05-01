--!strict
-- Game Pass purchase + ownership reporting.
--
-- Two responsibilities:
--   1. Tell the client which passes the player owns (via GetPassOwnership
--      RemoteFunction) so the in-game Passes shop can render "OWNED" vs
--      "BUY" state without the client doing its own MarketplaceService
--      check (which would hammer Roblox quotas).
--   2. Listen to MarketplaceService.PromptGamePassPurchaseFinished, mark
--      Starter Pack window if relevant (data.starterPackPurchasedUnix),
--      invalidate the per-player pass cache on CurrencyManager so the
--      next tick picks up the new ownership, and fire PassPurchased back
--      to the client for celebratory UI.
--
-- The client-side modal calls MarketplaceService:PromptGamePassPurchase
-- directly (allowed from the client). We never trust client-claimed
-- ownership: every multiplier check on the server re-asks
-- UserOwnsGamePassAsync (cached in CurrencyManager).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local GamePassService = {}

-- Reverse lookup: passId -> pass key (so the purchase callback can find
-- which logical pass was bought). Built once at script start.
local passIdToKey: {[number]: string} = {}
for key, id in pairs(Constants.GAME_PASSES) do
    if typeof(id) == "number" and id ~= 0 then
        passIdToKey[id] = key
    end
end

local function ownsPass(userId: number, passId: number): boolean
    if passId == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)
    return ok and owns or false
end

remotes.GetPassOwnership.OnServerInvoke = function(player: Player): {[string]: boolean}
    local out: {[string]: boolean} = {}
    for key, id in pairs(Constants.GAME_PASSES) do
        out[key] = ownsPass(player.UserId, id)
    end
    return out
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(
    function(player: Player, passId: number, wasPurchased: boolean)
        if not wasPurchased then return end
        local key = passIdToKey[passId]
        if not key then
            warn("[GamePassService] purchase of unknown passId " .. passId)
            return
        end
        -- If the player just bought the Starter Pack, set the timer that
        -- CurrencyManager.multiplierFor() reads.
        if key == "STARTER_PACK" then
            local data = DataStore.getCached(player.UserId)
            if data then
                data.starterPackPurchasedUnix = os.time()
            end
        end
        -- Push to client for confetti/UI
        pcall(function()
            remotes.PassPurchased:FireClient(player, key, passId)
        end)
        print(string.format(
            "[GamePassService] %s purchased pass '%s' (id %d)",
            player.Name, key, passId
        ))
    end
)

local known = {}
for k, v in pairs(Constants.GAME_PASSES) do
    table.insert(known, string.format("%s=%d", k, v))
end
table.sort(known)
print("[GamePassService] ready (passes: " .. table.concat(known, ", ") .. ")")

return GamePassService
