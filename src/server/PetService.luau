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

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

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
    -- Pet Boost: timed multiplier on the pet contribution. Stacks with
    -- equipped + collection bonus and itself. Inactive when expired.
    local boostExpires = data.petBoostExpiresUnix or 0
    if boostExpires > os.time() then
        mult *= Constants.PET_BOOST.MULTIPLIER
    end
    return mult
end

-- ---- Pet Boost ----------------------------------------------------------

local function pushBoostState(player: Player, data: Types.PlayerData)
    local now = os.time()
    local active = (data.petBoostExpiresUnix or 0) > now
    local remaining = active and (data.petBoostExpiresUnix - now) or 0
    pcall(function()
        remotes.PetBoostStateChanged:FireClient(player, {
            active = active,
            remainingSec = remaining,
            multiplier = Constants.PET_BOOST.MULTIPLIER,
        })
    end)
end

local function pushBoostReject(player: Player, reason: string, needed: number?)
    pcall(function()
        remotes.PetBoostRejected:FireClient(player, reason, needed)
    end)
end

function PetService.snapshotBoost(userId: number)
    local data = DataStore.getCached(userId)
    if not data then
        return { active = false, remainingSec = 0,
            multiplier = Constants.PET_BOOST.MULTIPLIER, costForCurrentTier = 0 }
    end
    local now = os.time()
    local active = (data.petBoostExpiresUnix or 0) > now
    local remaining = active and (data.petBoostExpiresUnix - now) or 0
    local cost = Constants.PET_BOOST.COST_PER_TIER[data.upgradeTier] or 0
    return {
        active = active, remainingSec = remaining,
        multiplier = Constants.PET_BOOST.MULTIPLIER,
        costForCurrentTier = cost,
        durationSec = Constants.PET_BOOST.DURATION_SEC,
    }
end

function PetService.attemptBuyBoost(player: Player): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushBoostReject(player, "no_data")
        return false, "no_data"
    end
    local baseCost = Constants.PET_BOOST.COST_PER_TIER[data.upgradeTier]
    if not baseCost then
        pushBoostReject(player, "no_cost_tier")
        return false, "no_cost_tier"
    end
    -- Loyalty discount: if a boost is already active when buying again,
    -- charge 25% less. Rewards engaged players who keep boosting back-to-back
    -- and reduces the "do I bother re-buying" friction.
    local now = os.time()
    local current = data.petBoostExpiresUnix or 0
    local boostActive = current > now
    local cost = boostActive and math.floor(baseCost * 0.75) or baseCost
    if data.coins < cost then
        pushBoostReject(player, "insufficient_coins", cost - data.coins)
        return false, "insufficient_coins"
    end
    data.coins -= cost
    -- Extend if already active, else start fresh from now.
    local base = boostActive and current or now
    data.petBoostExpiresUnix = base + Constants.PET_BOOST.DURATION_SEC
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pushBoostState(player, data)
    print(string.format("[PetService] %s bought boost for %d coins (active until %d)",
        player.Name, cost, data.petBoostExpiresUnix))
    return true, nil
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
    -- Compute unique-pets-owned + total-pets so HUD can render
    -- "OWNED 7/10 — collection bonus +50% on 3 more"
    local uniquePetCount = 0
    for _ in pairs(seen) do uniquePetCount += 1 end
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
        pity = data.hatchesSinceLastLegendary or 0,
        pityThreshold = Constants.PET_PITY_THRESHOLD,
        uniquePetCount = uniquePetCount,
        totalPetCount = #Constants.PETS,
        collectionBonusPct = math.floor(Constants.PET_COLLECTION_COMPLETE_BONUS * 100),
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
    -- Roll. Apply pity force-promotion: if this player is at the threshold
    -- without a legendary, force a legendary roll regardless of egg tier.
    local def = rollPet(egg.biasTier)
    local pity = data.hatchesSinceLastLegendary or 0
    if def.rarity ~= "legendary" and pity >= (Constants.PET_PITY_THRESHOLD - 1) then
        local legendaryPool = petsByRarity["legendary"] or {}
        if #legendaryPool > 0 then
            def = legendaryPool[math.random(1, #legendaryPool)]
        end
    end
    -- Update pity: reset on any legendary, increment otherwise
    if def.rarity == "legendary" then
        data.hatchesSinceLastLegendary = 0
    else
        data.hatchesSinceLastLegendary = pity + 1
    end
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
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, Constants.ANALYTICS_EVENTS.PET_HATCHED, 1,
            { rarity = def.rarity, egg_id = eggId, pity_hit = (pity >= Constants.PET_PITY_THRESHOLD), pity_count = pity }
        )
    end)
    print(string.format("[PetService] %s hatched '%s' (%s) from %s",
        player.Name, def.name, def.rarity, eggId))
    -- Activity feed: only legendary hatches are interesting enough to
    -- broadcast cross-server. Common hatches would spam.
    if def.rarity == "legendary" then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService"))
            ActivityFeedService.post(player, "hatch_legendary", "hatched " .. def.name)
        end)
        pcall(function()
            local DiscordHook = require(script.Parent:WaitForChild("DiscordHook"))
            DiscordHook.publishLegendaryHatch(player.Name, def.name, eggId)
        end)
    end
    -- Achievement hook: pets_owned + pets_collection_complete + lifetime
    -- coins (if achievements credit coins back). Lazy require to dodge a
    -- circular require chain at script-init time.
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(userId)
    end)
    -- FTUE funnel step 7: first_egg_hatched — gacha entry point.
    -- TutorialService.advance is highest-step-wins so subsequent hatches
    -- no-op (cheap noop call cost is fine).
    pcall(function()
        local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
        TutorialService.advance(userId, "07_first_egg_hatched")
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
        local PetStandService = require(script.Parent:WaitForChild("PetStandService"))
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
                local PetStandService = require(script.Parent:WaitForChild("PetStandService"))
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
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService"))
            ActivityFeedService.post(player, "hatch_legendary", "fused into " .. def.name)
        end)
    end
    -- Achievement scan -- this changes #data.pets and could change collection
    -- completion, so re-evaluate.
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(userId)
    end)
    pcall(function()
        local PetStandService = require(script.Parent:WaitForChild("PetStandService"))
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

-- Cost-bypass hatch path used by free-grant systems (login streak, future
-- gift codes, etc). Validates only inventory cap; no coin debit, no
-- "insufficient_coins" check. Returns the rolled OwnedPet on success
-- so the caller can fire its own bespoke notify event. Inventory-cap
-- failures still reject so we don't silently drop a granted pet.
function PetService.grantPetFromEgg(player: Player, eggId: string): (Types.OwnedPet?, any?, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then return nil, nil, "no_data" end
    local egg = eggById[eggId]
    if not egg then return nil, nil, "unknown_egg" end
    if (#data.pets or 0) >= Constants.PET_INVENTORY_CAP then
        return nil, nil, "inventory_full"
    end
    local def = rollPet(egg.biasTier)
    -- Free grants also respect + advance pity (otherwise streak grants
    -- would skew the counter without paying it back).
    local pity = data.hatchesSinceLastLegendary or 0
    if def.rarity ~= "legendary" and pity >= (Constants.PET_PITY_THRESHOLD - 1) then
        local legendaryPool = petsByRarity["legendary"] or {}
        if #legendaryPool > 0 then
            def = legendaryPool[math.random(1, #legendaryPool)]
        end
    end
    if def.rarity == "legendary" then
        data.hatchesSinceLastLegendary = 0
    else
        data.hatchesSinceLastLegendary = pity + 1
    end
    if not data.pets then data.pets = {} end
    local owned: Types.OwnedPet = {
        uid = nextUid(data),
        petId = def.id,
        rarity = def.rarity,
        obtainedUnix = os.time(),
    }
    table.insert(data.pets, owned)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(userId)
    end)
    if def.rarity == "legendary" then
        pcall(function()
            local ActivityFeedService = require(script.Parent:WaitForChild("ActivityFeedService"))
            ActivityFeedService.post(player, "hatch_legendary", "got " .. def.name .. " from a free grant")
        end)
    end
    print(string.format("[PetService] %s GRANT '%s' (%s) from %s",
        player.Name, def.name, def.rarity, eggId))
    return owned, def, nil
end

-- Server-side auto-equip: clear current loadout, pick the top
-- PET_MAX_EQUIPPED pets by rarity multiplier (descending), and equip
-- those. Cheaper UX than tap-each-card and prevents the dupe-then-
-- forget-to-swap trap that comes with fusion.
function PetService.attemptAutoEquip(player: Player): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then return false, "no_data" end
    if not data.pets or #data.pets == 0 then return false, "no_pets" end
    -- Score every pet by its rarity multiplier (denormalized via PET_RARITIES)
    type Scored = { uid: string, score: number }
    local scored: {Scored} = {}
    for _, p in ipairs(data.pets) do
        local r = Constants.PET_RARITIES[p.rarity]
        local score = r and r.mult or 0
        table.insert(scored, { uid = p.uid, score = score })
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    -- Build the new equipped list (top N)
    local newEquipped: {string} = {}
    for i = 1, math.min(Constants.PET_MAX_EQUIPPED, #scored) do
        table.insert(newEquipped, scored[i].uid)
    end
    -- Detect a no-op so we don't broadcast for nothing
    local sameAsCurrent = (#newEquipped == #(data.equippedPetIds or {}))
    if sameAsCurrent then
        local was: {[string]: boolean} = {}
        for _, uid in ipairs(data.equippedPetIds) do was[uid] = true end
        for _, uid in ipairs(newEquipped) do
            if not was[uid] then sameAsCurrent = false; break end
        end
    end
    if sameAsCurrent then return false, "already_optimal" end
    data.equippedPetIds = newEquipped
    pushEquipChanged(player, data.equippedPetIds)
    pcall(function()
        local PetStandService = require(script.Parent:WaitForChild("PetStandService"))
        PetStandService.refreshFor(userId)
    end)
    print(string.format("[PetService] %s auto-equipped %d pets", player.Name, #newEquipped))
    return true, nil
end

remotes.AutoEquipPets.OnServerEvent:Connect(function(player: Player)
    PetService.attemptAutoEquip(player)
end)

remotes.GetPetBoost.OnServerInvoke = function(player: Player)
    return PetService.snapshotBoost(player.UserId)
end

remotes.BuyPetBoost.OnServerEvent:Connect(function(player: Player)
    PetService.attemptBuyBoost(player)
end)

-- Sweep every 30s and push state-change to anyone whose boost just expired
-- so the HUD can flip "INACTIVE" without polling.
task.spawn(function()
    while true do
        task.wait(30)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataStore.getCached(player.UserId)
            if data then
                pushBoostState(player, data)
            end
        end
    end
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
