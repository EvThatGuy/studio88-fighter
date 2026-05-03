--!strict
-- Daily Spin Wheel. Once per UTC day, the player gets a free spin for a
-- weighted-random reward. Server-authoritative -- the segment is rolled
-- on the server and the client just plays the visual landing animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local Types = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Types"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local SpinService = {}

-- ---- UTC date helpers ---------------------------------------------------

local function utcDateKey(): string
    -- "YYYY-MM-DD" using os.date("!*t") for UTC
    local t = os.date("!*t")
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function secondsUntilUtcMidnight(): number
    local t = os.date("!*t")
    local secsToday = t.hour * 3600 + t.min * 60 + t.sec
    return 86400 - secsToday
end

-- ---- Snapshot -----------------------------------------------------------

function SpinService.snapshot(userId: number)
    local data = DataStore.getCached(userId)
    local segments = {}
    for _, s in ipairs(Constants.SPIN_SEGMENTS) do
        table.insert(segments, {
            id = s.id, label = s.label, color = s.color, weight = s.weight,
        })
    end
    if not data then
        return { available = false, segments = segments,
            nextResetSec = secondsUntilUtcMidnight() }
    end
    local available = data.lastSpinDateKey ~= utcDateKey()
    return {
        available = available,
        segments = segments,
        nextResetSec = secondsUntilUtcMidnight(),
    }
end

-- ---- Roll ---------------------------------------------------------------

local function rollSegment(): any
    local total = 0
    for _, s in ipairs(Constants.SPIN_SEGMENTS) do total += s.weight end
    if total <= 0 then return Constants.SPIN_SEGMENTS[1] end
    local roll = math.random() * total
    local cum = 0
    for _, s in ipairs(Constants.SPIN_SEGMENTS) do
        cum += s.weight
        if roll <= cum then return s end
    end
    return Constants.SPIN_SEGMENTS[#Constants.SPIN_SEGMENTS]
end

-- ---- Reward grants ------------------------------------------------------

local function grantReward(player: Player, data: Types.PlayerData, segment: any): (number, string)
    local kind = segment.reward.kind
    local value = segment.reward.value
    if kind == "coins" then
        local tier = Constants.UPGRADE_TIERS[data.upgradeTier]
        local mult = tier and tier.incomeMult or 1
        local amount = math.floor(value * mult)
        data.coins += amount
        data.lifetimeCoins += amount
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
        return amount, string.format("+%d coins", amount)
    elseif kind == "rebirth_token" then
        data.rebirthTokens = (data.rebirthTokens or 0) + value
        return value, string.format("+%d rebirth token%s", value, value == 1 and "" or "s")
    elseif kind == "boost_seconds" then
        local now = os.time()
        local current = data.petBoostExpiresUnix or 0
        local base = (current > now) and current or now
        data.petBoostExpiresUnix = base + value
        local mins = math.floor(value / 60)
        return value, string.format("+%dm pet boost", mins)
    elseif kind == "free_egg" then
        local PetService = require(script.Parent:WaitForChild("PetService"))
        local owned, def, reason = PetService.grantPetFromEgg(player, value)
        if owned and def then
            pcall(function()
                remotes.PetHatched:FireClient(player, owned, def.name)
            end)
            return 1, string.format("free %s -> %s", value, def.name)
        else
            -- Fallback: 5000c if inventory was full
            local fallback = 5000
            data.coins += fallback
            data.lifetimeCoins += fallback
            pcall(function()
                remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
            end)
            return fallback, string.format("inventory full -> +%d coins instead", fallback)
        end
    end
    return 0, "no reward"
end

-- ---- Claim --------------------------------------------------------------

local function pushReject(player: Player, reason: string)
    pcall(function() remotes.SpinRejected:FireClient(player, reason) end)
end

function SpinService.attemptClaim(player: Player): (boolean, string?)
    local userId = player.UserId
    local data = DataStore.getCached(userId)
    if not data then
        pushReject(player, "no_data")
        return false, "no_data"
    end
    local key = utcDateKey()
    if data.lastSpinDateKey == key then
        pushReject(player, "already_spun")
        return false, "already_spun"
    end
    data.lastSpinDateKey = key
    local segment = rollSegment()
    local valueGranted, message = grantReward(player, data, segment)
    pcall(function()
        remotes.SpinResult:FireClient(player, {
            segmentId = segment.id,
            label = segment.label,
            kind = segment.reward.kind,
            valueGranted = valueGranted,
            message = message,
        })
    end)
    -- Achievement scan -- many spin rewards bump lifetime coins
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(userId)
    end)
    print(string.format("[SpinService] %s spun and got '%s' (%s)",
        player.Name, segment.id, message))
    return true, nil
end

-- ---- Wires --------------------------------------------------------------

remotes.GetSpinState.OnServerInvoke = function(player: Player)
    return SpinService.snapshot(player.UserId)
end

remotes.ClaimSpin.OnServerEvent:Connect(function(player: Player)
    SpinService.attemptClaim(player)
end)

print(string.format("[SpinService] ready (%d segments)", #Constants.SPIN_SEGMENTS))

return SpinService
