--!strict
-- Lazily creates the RemoteEvent / RemoteFunction folder under
-- ReplicatedStorage and exposes typed accessors. Server scripts call
-- Remotes.get() at startup; client scripts call Remotes.waitFor() since
-- replication may not have happened yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local Remotes = {}

local FOLDER_NAME = "Studio88Remotes"

local REMOTE_NAMES = {
    {name = "GetBalance", class = "RemoteFunction"},
    {name = "PurchaseUpgrade", class = "RemoteEvent"},
    {name = "BalanceUpdated", class = "RemoteEvent"},
    {name = "LeaderboardUpdated", class = "RemoteEvent"},
    {name = "TierUpgraded", class = "RemoteEvent"},
    {name = "DailyBonusGranted", class = "RemoteEvent"},
    {name = "PurchaseRejected", class = "RemoteEvent"},
    {name = "RequestRebirth", class = "RemoteEvent"},
    {name = "RebirthGranted", class = "RemoteEvent"},
    {name = "RebirthRejected", class = "RemoteEvent"},
    {name = "RequestRedeemCode", class = "RemoteEvent"},
    {name = "CodeRedeemed", class = "RemoteEvent"},
    {name = "CodeRejected", class = "RemoteEvent"},
    {name = "GetPassOwnership", class = "RemoteFunction"},
    {name = "PassPurchased", class = "RemoteEvent"},
    {name = "GetDailyQuests", class = "RemoteFunction"},
    {name = "ClaimQuest", class = "RemoteEvent"},
    {name = "QuestProgressed", class = "RemoteEvent"},
    {name = "QuestClaimed", class = "RemoteEvent"},
    {name = "QuestRejected", class = "RemoteEvent"},
    {name = "EventStateChanged", class = "RemoteEvent"},
    {name = "TutorialStepReached", class = "RemoteEvent"},
    {name = "GetTutorialStep", class = "RemoteFunction"},
    {name = "GetRebirthShop", class = "RemoteFunction"},
    {name = "BuyRebirthShopItem", class = "RemoteEvent"},
    {name = "RebirthShopPurchased", class = "RemoteEvent"},
    {name = "RebirthShopRejected", class = "RemoteEvent"},
    {name = "GetPetState", class = "RemoteFunction"},
    {name = "HatchEgg", class = "RemoteEvent"},
    {name = "PetHatched", class = "RemoteEvent"},
    {name = "PetHatchRejected", class = "RemoteEvent"},
    {name = "EquipPet", class = "RemoteEvent"},
    {name = "UnequipPet", class = "RemoteEvent"},
    {name = "PetEquipChanged", class = "RemoteEvent"},
    {name = "GetAchievements", class = "RemoteFunction"},
    {name = "AchievementUnlocked", class = "RemoteEvent"},
    {name = "FusePets", class = "RemoteEvent"},
    {name = "PetFuseRejected", class = "RemoteEvent"},
    {name = "GetHourlyTribute", class = "RemoteFunction"},
    {name = "ClaimHourlyTribute", class = "RemoteEvent"},
    {name = "HourlyTributeClaimed", class = "RemoteEvent"},
    {name = "HourlyTributeRejected", class = "RemoteEvent"},
    {name = "GetAuras", class = "RemoteFunction"},
    {name = "EquipAura", class = "RemoteEvent"},
    {name = "AuraReplicate", class = "RemoteEvent"},
    {name = "AuraRejected", class = "RemoteEvent"},
    {name = "GetActivityFeed", class = "RemoteFunction"},
    {name = "ActivityFeedUpdated", class = "RemoteEvent"},
    {name = "GetFriendCode", class = "RemoteFunction"},
    {name = "ReferralBonusGranted", class = "RemoteEvent"},
    {name = "AutoEquipPets", class = "RemoteEvent"},
    {name = "StreakEggGranted", class = "RemoteEvent"},
    {name = "GetPetBoost", class = "RemoteFunction"},
    {name = "BuyPetBoost", class = "RemoteEvent"},
    {name = "PetBoostStateChanged", class = "RemoteEvent"},
    {name = "PetBoostRejected", class = "RemoteEvent"},
    {name = "SquadBonusChanged", class = "RemoteEvent"},
    {name = "GetTitles", class = "RemoteFunction"},
    {name = "EquipTitle", class = "RemoteEvent"},
    {name = "TitleReplicate", class = "RemoteEvent"},
    {name = "TitleRejected", class = "RemoteEvent"},
    {name = "GetSpinState", class = "RemoteFunction"},
    {name = "ClaimSpin", class = "RemoteEvent"},
    {name = "SpinResult", class = "RemoteEvent"},
    {name = "SpinRejected", class = "RemoteEvent"},
    {name = "GetNotifications", class = "RemoteFunction"},
    {name = "VisitPlayer", class = "RemoteEvent"},
    {name = "VisitRejected", class = "RemoteEvent"},
    {name = "VisitedByPlayer", class = "RemoteEvent"},
    {name = "GetPlayerStats", class = "RemoteFunction"},
    {name = "WelcomeBanner", class = "RemoteEvent"},  -- 3s join banner with player + tier + lifetime coins
    {name = "CoinCollectedFx", class = "RemoteEvent"}, -- floating "+N" text at collector position on every collect
    {name = "GetDailyStreakSchedule", class = "RemoteFunction"}, -- HUD modal preview of upcoming days + jackpot tags
    {name = "SessionBonusGranted", class = "RemoteEvent"}, -- 15/30/60min play bonus auto-granted in session
    {name = "RebirthReadyNudge", class = "RemoteEvent"}, -- one-shot toast when rebirth eligibility flips false->true
    {name = "IdleReturnBonusGranted", class = "RemoteEvent"}, -- one-shot toast on rejoin with offline-earnings bonus
    {name = "GetWeeklyTournament", class = "RemoteFunction"}, -- HUD widget: "MY WEEK $X (rank Y)" current week status
    {name = "GetWeeklyTournamentTopN", class = "RemoteFunction"}, -- modal: top N {userId, name, weeklyEarned} for current week
    {name = "GetDevProducts", class = "RemoteFunction"}, -- HUD shop: returns dev product catalog with productIds
    {name = "VaultRaidSpawned", class = "RemoteEvent"}, -- broadcast when raid boss spawns
    {name = "VaultRaidEnded", class = "RemoteEvent"}, -- broadcast with reward distribution results
}

local function ensureFolder(): Folder
    local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if existing then
        assert(existing:IsA("Folder"), FOLDER_NAME .. " exists but isn't a Folder")
        return existing
    end
    if not RunService:IsServer() then
        error(FOLDER_NAME .. " not yet replicated; call Remotes.waitFor() on client")
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = ReplicatedStorage
    return folder
end

local function ensureRemote(folder: Folder, spec: {name: string, class: string}): Instance
    local existing = folder:FindFirstChild(spec.name)
    if existing then return existing end
    if not RunService:IsServer() then
        error("Remote '" .. spec.name .. "' missing on client; server hasn't created it yet")
    end
    local remote = Instance.new(spec.class)
    remote.Name = spec.name
    remote.Parent = folder
    return remote
end

-- Server entry point: synchronously creates folder + remotes if missing.
function Remotes.get(): Types.RemoteMap
    local folder = ensureFolder()
    local map = {}
    for _, spec in ipairs(REMOTE_NAMES) do
        map[spec.name] = ensureRemote(folder, spec)
    end
    return map :: any
end

-- Client entry point: yields until folder + every remote replicates.
function Remotes.waitFor(timeoutSec: number?): Types.RemoteMap
    local timeout = timeoutSec or 10
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, timeout)
    if not folder then error("Studio88Remotes folder never replicated") end
    local map = {}
    for _, spec in ipairs(REMOTE_NAMES) do
        local r = folder:WaitForChild(spec.name, timeout)
        if not r then error("Remote '" .. spec.name .. "' never replicated") end
        map[spec.name] = r
    end
    return map :: any
end

return Remotes
