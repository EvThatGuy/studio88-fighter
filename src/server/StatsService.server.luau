--!strict
-- Career-summary aggregator. Single read-only snapshot the HUD pulls
-- when the player opens the STATS modal. Walks PlayerData + a couple of
-- derived counts (achievement unlocks, codes redeemed, equipped cosmetic
-- names) into a flat table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local StatsService = {}

local function tableSize(t: {[any]: any}?): number
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

-- Friendly title/aura name lookup so the modal doesn't need to ship a
-- second copy of Constants.PLAYER_TITLES / Constants.AURAS.
local titleNameById: {[string]: string} = {}
for _, t in ipairs(Constants.PLAYER_TITLES) do titleNameById[t.id] = t.name end

local auraNameById: {[string]: string} = {}
for _, a in ipairs(Constants.AURAS) do auraNameById[a.id] = a.name end

function StatsService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return { error = "no_data" } end
    return {
        coins = data.coins,
        lifetimeCoins = data.lifetimeCoins,
        upgradeTier = data.upgradeTier,
        maxTier = #Constants.UPGRADE_TIERS,
        rebirths = data.rebirths or 0,
        rebirthTokens = data.rebirthTokens or 0,
        rebirthShopOwned = tableSize(data.purchasedRebirthUpgrades),
        petsOwned = #(data.pets or {}),
        equippedPets = #(data.equippedPetIds or {}),
        maxEquippedPets = Constants.PET_MAX_EQUIPPED,
        petCollectionTotal = #Constants.PETS,
        achievementsUnlocked = tableSize(data.achievementsUnlocked),
        achievementsTotal = #Constants.ACHIEVEMENTS,
        questsClaimedTotal = data.questsClaimedTotal or 0,
        codesRedeemed = tableSize(data.redeemedCodes),
        streak = data.streak or 0,
        friendCode = data.friendCode or "",
        referredBy = data.referredBy,
        referralCount = data.referralCount or 0,
        equippedAuraName = data.equippedAura and auraNameById[data.equippedAura] or nil,
        equippedTitleName = data.equippedTitle and titleNameById[data.equippedTitle] or nil,
        hatchesSinceLastLegendary = data.hatchesSinceLastLegendary or 0,
        pityThreshold = Constants.PET_PITY_THRESHOLD,
    }
end

remotes.GetPlayerStats.OnServerInvoke = function(player)
    return StatsService.snapshot(player.UserId)
end

print("[StatsService] ready")

return StatsService
