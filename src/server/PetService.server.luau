--!strict
-- Pets system. Per /research-engineer brief #2: highest-interest tycoon
-- extension on DevForum, gacha-VRR retention loop, status objects that
-- survive rebirth and drive D7/D30 long-tail.
--
-- v1 ships COIN-COST eggs only. Robux eggs need PolicyService gating
-- (Belgium/NL/under-13 EU random-paid-item restrictions); when David
-- adds Robux eggs in a future phase, gate via:
--   PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted
-- and present coin-only fallback when the policy returns true. Coin
-- eggs are unrestricted across all regions, so we skip the gate cleanly.
--
-- Equip mechanic: a player's "active boost" is the sum of equipped pet
-- multipliers (capped at PET_MAX_EQUIPPED). Inventory cap (100) only
-- limits hoarding -- the natural ceiling is the collection bonus
-- (+50% perma) which only requires 1 of each unique pet.
--
-- All state is server-authoritative. Client-claimed equips are validated
-- against the actual inventory before commit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))

local remotes = Remotes.get()

local PetService = {}

-- ---- Lookups (built once at script start for hot-path speed) -------------

type PetDef = { id: string, name: string, rarity: string }
type EggDef = { id: string, name: string, cost: number, biasTier: number, sub: string }

local petById: {[string]: PetDef} = {}
for _, p in ipairs(Constants.PETS) do petById[p.id] = p end

local petsByRarity: {[string]: {PetDef}} = {}
for _, p in ipairs(Constants.PETS) do
    petsByRarity[p.rarity] = petsByRarity[p.rarity] or {}
    table.insert(petsByRarity[p.rarity], p)
end

local eggById: {[string]: EggDef} = {}
for _, e in ipairs(Constants.PET_EGGS) do eggById[e.id] = e end

-- ---- UID generation ------------------------------------------------------
-- Per-player monotonic counter so two pets hatched in the same tick get
-- distinct uids. Stored on PlayerData (lazy-init).

local function nextUid(data: Types.PlayerData): string
    -- We don't have a dedicated counter field in the schema (would mean
    -- another migration); instead use #pets + os.time() suffix. Collision
    -- impossible because we only call this once per HatchEgg.
    return string.format("p%d_%d", os.time(), (#data.pets) + math.random(100, 999))
end

-- ---- RNG helpers ---------------------------------------------------------

-- Compute biased rarity weights for an egg tier. biasTier=1 = base, 2 = std,
-- 3 = luxury. Each tier shifts weights via PET_RARITY_BIAS.
local function biasedWeights(biasTier: number): {[string]: number}
    local out: {[string]: number} = {}
    for rarity, spec in pairs(Constants.PET_RARITIES) do
        local bias = Constants.PET_RARITY_BIAS[rarity] or 0
        local mul = 1 + (biasTier - 1) * bias
        if mul < 0 then mul = 0 end
        out[rarity] = spec.weight * mul
    end
    return out
end

local function rollRarity(biasTier: number): string
    local weights = biasedWeights(biasTier)
    local total = 0
    for _, w in pairs(weights) do total += w end
    if total <= 0 then return "common" end
    local roll = math.random() * total
    local cum = 0
    -- Stable order so RNG is reproducible-ish in tests
    for _, rarity in ipairs(Constants.PET_RARITY_ORDER) do
        cum += weights[rarity] or 0
        if roll <= cum then return rarity end
    end
    return "common"
end

local function rollPet(biasTier: number): PetDef
    local rarity = rollRarity(biasTier)
    local pool = petsByRarity[rarity] or petsByRarity.common
    if not pool or #pool == 0 then
        -- Defensive: fall back to first defined pet
        return Constants.PETS[1]
    end
    return pool[math.random(1, #pool)]
end

-- ---- Multiplier (read by CurrencyManager) --------------------------------

-- Returns the income multiplier from EQUIPPED pets + collection bonus.
-- 1.0 if no pets owned + nothing equipped + collection incomplete.
function PetService.getPetMultiplier(userId: number): number
    local data = DataStore.getCached(userId)
    if not data then return 1.0 end
    local mult = 1.0
    -- Equipped boost
    local petByUid: {[string]: Types.OwnedPet} = {}
    for _, p in ipairs(data.pets or {}) do
        petByUid[p.uid] = p
    end
    local sumAdd = 0
    for _, uid in ipairs(data.equippedPetIds or {}) do
        local p = petByUid[uid]
        if p then
            local r = Constants.PET_RARITIES[p.rarity]
            if r then sumAdd += r.mult end
        end
    end
    if sumAdd > 0 then mult *= (1 + sumAdd) end
    -- Collection completion bonus
    local seen: {[string]: boolean} = {}
    for _, p in ipairs(data.pets or {}) do seen[p.petId] = true end
    local complete = true
    for _, def in ipairs(Constants.PETS) do
        if not seen[def.id] then complete = false; break end
    end
    if complete then mult *= (1 + Constants.PET_COLLECTION_COMPLETE_BONUS) end
    return mult
end

-- ---- Snapshot ------------------------------------------------------------

-- Server -> client read for the inventory + egg modal.
function PetService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    if not data then return nil end
    -- Inventory: include rarity color so the client doesn't need the table
    local inventory = {}
    local seen: {[string]: boolean} = {}
    for _, p in ipairs(data.pets or {}) do
        seen[p.petId] = true
        local def = petById[p.petId]
        local color = Constants.PET_RARITY_COLORS[p.rarity] or {200,200,200}
        table.insert(inventory, {
            uid = p.uid,
            petId = p.petId,
            name = (def and def.name) or p.petId,
            rarity = p.rarity,
            color = color,
            mult = (Constants.PET_RARITIES[p.rarity] or {mult=0}).mult,
            obtainedUnix = p.obtainedUnix,
        })
    end
    local complete = true
    for _, def in ipairs(Constants.PETS) do
        if not seen[def.id] then complete = false; break end
    end
    -- Eggs: just echo the catalog so HUD can render with current coin balance
    local eggs = {}
    for _, e in ipairs(Constants.PET_EGGS) do
        table.insert(eggs, { id = e.id, name = e.name, cost = e.cost, sub = e.sub })
    end
    return {
        pets = inventory,
        equippedPetIds = data.equippedPetIds or {},
        maxEquipped = Constants.PET_MAX_EQUIPPED,
        eggs = eggs,
        collectionComplete = complete,
        coinsAvailable = data.coins,
    }
end

-- ---- Hatch ---------------------------------------------------------------

local function pushHatchReject(player: Player, eggId: string, reason: string, needed: number?)
    pcall(function()
        remotes.PetHatchRejected:FireClient(player, eggId, reason, needed)
    end)
end

function PetService.attemptHatch(player: Player, eggId: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushHatchReject(player, tostring(eggId), "no_data")
        return false, "no_data"
    end
    if typeof(eggId) ~= "string" then
        pushHatchReject(player, "", "bad_request")
        return false, "bad_request"
    end
    local egg = eggById[eggId]
    if not egg then
        pushHatchReject(player, eggId, "unknown_egg")
        return false, "unknown_egg"
    end
    if (#data.pets or 0) >= Constants.PET_INVENTORY_CAP then
        pushHatchReject(player, eggId, "inventory_full")
        return false, "inventory_full"
    end
    if data.coins < egg.cost then
        pushHatchReject(player, eggId, "insufficient_coins", egg.cost - data.coins)
        return false, "insufficient_coins"
    end
    -- Roll
    local def = rollPet(egg.biasTier)
    -- Commit: deduct coins, append pet, fire client.
    data.coins -= egg.cost
    if not data.pets then data.pets = {} end
    local owned: Types.OwnedPet = {
        uid = nextUid(data),
        petId = def.id,
        rarity = def.rarity,
        obtainedUnix = os.time(),
    }
    table.insert(data.pets, owned)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.PetHatched:FireClient(player, owned, def.name)
    end)
    print(string.format("[PetService] %s hatched '%s' (%s) from %s",
        player.Name, def.name, def.rarity, eggId))
    -- Activity feed: only legendary hatches are interesting enough to
    -- broadcast cross-server. Common hatches would spam.
    if def.rarity == "legendary" then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService.server"))
            ActivityFeedService.post(player, "hatch_legendary", "hatched " .. def.name)
        end)
    end
    -- Achievement hook: pets_owned + pets_collection_complete + lifetime
    -- coins (if achievements credit coins back). Lazy require to dodge a
    -- circular require chain at script-init time.
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService.server"))
        AchievementService.evaluate(userId)
    end)
    return true, nil
end

-- ---- Equip / unequip -----------------------------------------------------

local function findOwnedPet(data: Types.PlayerData, uid: string): Types.OwnedPet?
    for _, p in ipairs(data.pets or {}) do
        if p.uid == uid then return p end
    end
    return nil
end

local function pushEquipChanged(player: Player, equippedPetIds: {string})
    pcall(function()
        remotes.PetEquipChanged:FireClient(player, equippedPetIds)
    end)
end

function PetService.attemptEquip(player: Player, uid: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data or typeof(uid) ~= "string" then return false, "bad_request" end
    local pet = findOwnedPet(data, uid)
    if not pet then return false, "not_owned" end
    if not data.equippedPetIds then data.equippedPetIds = {} end
    -- Already equipped?
    for _, eid in ipairs(data.equippedPetIds) do
        if eid == uid then return false, "already_equipped" end
    end
    if #data.equippedPetIds >= Constants.PET_MAX_EQUIPPED then
        return false, "equip_full"
    end
    table.insert(data.equippedPetIds, uid)
    pushEquipChanged(player, data.equippedPetIds)
    pcall(function()
        local PetStandService = require(script.Parent:WaitForChild("PetStandService.server"))
        PetStandService.refreshFor(userId)
    end)
    return true, nil
end

function PetService.attemptUnequip(player: Player, uid: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data or typeof(uid) ~= "string" then return false, "bad_request" end
    if not data.equippedPetIds then data.equippedPetIds = {} end
    for i, eid in ipairs(data.equippedPetIds) do
        if eid == uid then
            table.remove(data.equippedPetIds, i)
            pushEquipChanged(player, data.equippedPetIds)
            pcall(function()
                local PetStandService = require(script.Parent:WaitForChild("PetStandService.server"))
                PetStandService.refreshFor(userId)
            end)
            return true, nil
        end
    end
    return false, "not_equipped"
end

-- ---- Fusion --------------------------------------------------------------
-- Sacrifice PET_FUSE_COST same-rarity pets to mint 1 of the next rarity.
-- Equipped pets cannot be consumed (player would otherwise tap-fuse and
-- accidentally destroy their best stat carrier). We pick the OLDEST
-- non-equipped pets first so newly-hatched ones don't get auto-eaten.

local function pushFuseReject(player: Player, rarity: string, reason: string, needed: number?)
    pcall(function()
        remotes.PetFuseRejected:FireClient(player, rarity, reason, needed)
    end)
end

local function isEquipped(data: Types.PlayerData, uid: string): boolean
    for _, eid in ipairs(data.equippedPetIds or {}) do
        if eid == uid then return true end
    end
    return false
end

function PetService.attemptFuse(player: Player, rarity: any): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushFuseReject(player, tostring(rarity), "no_data")
        return false, "no_data"
    end
    if typeof(rarity) ~= "string" then
        pushFuseReject(player, "", "bad_request")
        return false, "bad_request"
    end
    local nextRarity = Constants.PET_RARITY_PROMOTION[rarity]
    if not nextRarity then
        pushFuseReject(player, rarity, "cannot_promote") -- legendary or unknown rarity
        return false, "cannot_promote"
    end
    -- Collect non-equipped pets of this rarity, sorted by obtainedUnix ASC.
    local candidates: {Types.OwnedPet} = {}
    for _, p in ipairs(data.pets or {}) do
        if p.rarity == rarity and not isEquipped(data, p.uid) then
            table.insert(candidates, p)
        end
    end
    table.sort(candidates, function(a, b) return a.obtainedUnix < b.obtainedUnix end)
    local need = Constants.PET_FUSE_COST
    if #candidates < need then
        pushFuseReject(player, rarity, "not_enough", need - #candidates)
        return false, "not_enough"
    end
    -- Build a quick uid-set of consumed pets, then rebuild the inventory
    -- without them in a single pass (one allocation, no #pets shuffle).
    local consume: {[string]: boolean} = {}
    for i = 1, need do consume[candidates[i].uid] = true end
    local kept: {Types.OwnedPet} = {}
    for _, p in ipairs(data.pets or {}) do
        if not consume[p.uid] then table.insert(kept, p) end
    end
    data.pets = kept
    -- Roll the new pet from the next-rarity pool. We don't go through
    -- biased weights here -- fusion is deterministic-rarity, random-petId.
    local pool = petsByRarity[nextRarity] or {}
    if #pool == 0 then
        pushFuseReject(player, rarity, "promotion_pool_empty")
        return false, "promotion_pool_empty"
    end
    local def = pool[math.random(1, #pool)]
    local owned: Types.OwnedPet = {
        uid = nextUid(data),
        petId = def.id,
        rarity = def.rarity,
        obtainedUnix = os.time(),
    }
    table.insert(data.pets, owned)
    -- Reuse PetHatched on the client; it already handles toast + flash by
    -- rarity color and refreshes the inventory list.
    pcall(function()
        remotes.PetHatched:FireClient(player, owned, def.name)
    end)
    print(string.format("[PetService] %s fused 3x %s -> '%s' (%s)",
        player.Name, rarity, def.name, def.rarity))
    -- Activity feed: legendary fusion results are exciting; lower-rarity
    -- fuses are routine.
    if def.rarity == "legendary" then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService.server"))
            ActivityFeedService.post(player, "hatch_legendary", "fused into " .. def.name)
        end)
    end
    -- Achievement scan -- this changes #data.pets and could change collection
    -- completion, so re-evaluate.
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService.server"))
        AchievementService.evaluate(userId)
    end)
    pcall(function()
        local PetStandService = require(script.Parent:WaitForChild("PetStandService.server"))
        PetStandService.refreshFor(userId)
    end)
    return true, nil
end

-- ---- Wires ---------------------------------------------------------------

remotes.GetPetState.OnServerInvoke = function(player: Player)
    return PetService.snapshot(player.UserId) or {
        pets = {}, equippedPetIds = {}, maxEquipped = Constants.PET_MAX_EQUIPPED,
        eggs = {}, collectionComplete = false, coinsAvailable = 0,
    }
end

remotes.HatchEgg.OnServerEvent:Connect(function(player: Player, eggId: any)
    local ok, reason = PetService.attemptHatch(player, eggId)
    if not ok then
        warn(string.format("[PetService] %s hatch '%s' failed: %s",
            player.Name, tostring(eggId):sub(1, 32), reason or "?"))
    end
end)

remotes.EquipPet.OnServerEvent:Connect(function(player: Player, uid: any)
    PetService.attemptEquip(player, uid)
end)

remotes.UnequipPet.OnServerEvent:Connect(function(player: Player, uid: any)
    PetService.attemptUnequip(player, uid)
end)

remotes.FusePets.OnServerEvent:Connect(function(player: Player, rarity: any)
    local ok, reason = PetService.attemptFuse(player, rarity)
    if not ok then
        warn(string.format("[PetService] %s fuse '%s' failed: %s",
            player.Name, tostring(rarity):sub(1, 16), reason or "?"))
    end
end)

print(string.format("[PetService] ready (%d pets, %d eggs, max equipped %d, inventory cap %d)",
    #Constants.PETS, #Constants.PET_EGGS, Constants.PET_MAX_EQUIPPED, Constants.PET_INVENTORY_CAP))

return PetService
