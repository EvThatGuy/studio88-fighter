--!strict
-- Shared type definitions. Keep this file alongside any structural change
-- to the DataStore schema; bump Constants.DATASTORE_VERSION too.

export type OwnedPet = {
    uid: string,                    -- unique instance id (string-encoded incremented counter)
    petId: string,                  -- references Constants.PETS[].id
    rarity: string,                 -- denormalized for snapshot speed
    obtainedUnix: number,           -- when it was hatched
}

export type DailyQuestState = {
    dateKey: string,                -- "YYYY-MM-DD" UTC; rolls over the whole table at midnight
    progress: {[string]: number},   -- questId -> count toward target
    claimed: {[string]: boolean},   -- questId -> claimed flag (one-shot per day)
}

export type PlayerData = {
    coins: number,                  -- spendable balance
    lifetimeCoins: number,          -- never decreases; drives leaderboard
    upgradeTier: number,            -- 1..#Constants.UPGRADE_TIERS
    lastLoginUnix: number,          -- os.time() at last full login
    streak: number,                 -- consecutive days logged in
    starterPackPurchasedUnix: number?, -- for the 30-min Starter Pack window
    rebirths: number,               -- prestige count; permanent across all sessions
    rebirthTokens: number,          -- spendable tokens for the rebirth shop; +1 per rebirth
    purchasedRebirthUpgrades: {[string]: boolean}, -- {[itemId]=true} one-shot ledger
    pets: {OwnedPet},               -- inventory; one entry per hatched pet (duplicates allowed for stack count)
    equippedPetIds: {string},       -- list of OwnedPet.uid currently equipped (length <= PET_MAX_EQUIPPED)
    redeemedCodes: {[string]: boolean}, -- {[UPPERCASE_CODE] = true} for one-shot enforcement
    dailyQuests: DailyQuestState,   -- today's quest progress + claim state
    tutorialStep: number,           -- highest FTUE step completed (0..#FTUE_STEPS); 0 = brand new
    achievementsUnlocked: {[string]: number}, -- {[achievementId] = unlockedUnix}
    questsClaimedTotal: number,     -- monotonic across all days (for "Quest Grinder" achievement)
    lastHourlyTributeUnix: number,  -- last time the hourly-tribute stacks were claimed; used to compute available
    equippedAura: string?,          -- {AURAS[].id} or nil; visible to all players via character Trail
    schemaVersion: string,          -- mirrors Constants.DATASTORE_VERSION at write time
}

export type LeaderboardRow = {
    userId: number,
    name: string,
    lifetimeCoins: number,
}

export type RemoteMap = {
    GetBalance: RemoteFunction,
    PurchaseUpgrade: RemoteEvent,
    BalanceUpdated: RemoteEvent,    -- server -> client push on every tick
    LeaderboardUpdated: RemoteEvent,-- server -> client push every refresh
    TierUpgraded: RemoteEvent,      -- server -> client; payload {newTier, mult}
    DailyBonusGranted: RemoteEvent, -- server -> client; payload {streak, reward}
    PurchaseRejected: RemoteEvent,  -- server -> client; payload {reason, needed?}
    RequestRebirth: RemoteEvent,    -- client -> server; ask to prestige
    RebirthGranted: RemoteEvent,    -- server -> client; payload {rebirths, newMult}
    RebirthRejected: RemoteEvent,   -- server -> client; payload {reason, needed?}
    RequestRedeemCode: RemoteEvent, -- client -> server; payload {code: string}
    CodeRedeemed: RemoteEvent,      -- server -> client; payload {code, reward}
    CodeRejected: RemoteEvent,      -- server -> client; payload {code, reason}
    GetPassOwnership: RemoteFunction, -- client -> server; returns {[passKey]: boolean}
    PassPurchased: RemoteEvent,     -- server -> client; payload {passKey, passId}
    GetDailyQuests: RemoteFunction, -- client -> server; returns {dateKey, quests=[{id,kind,target,reward,label,progress,claimed}], totalRewardClaimable}
    ClaimQuest: RemoteEvent,        -- client -> server; payload {questId}
    QuestProgressed: RemoteEvent,   -- server -> client; payload {questId, progress, target}
    QuestClaimed: RemoteEvent,      -- server -> client; payload {questId, reward}
    QuestRejected: RemoteEvent,     -- server -> client; payload {questId, reason}
    EventStateChanged: RemoteEvent, -- server -> client; payload {active, event?, endsInSec?}
    TutorialStepReached: RemoteEvent, -- server -> client; payload {stepIndex, stepId}
    GetTutorialStep: RemoteFunction,  -- client -> server; returns current step number
    GetRebirthShop: RemoteFunction,   -- client -> server; returns {tokens, items=[{id,title,sub,cost,owned}]}
    BuyRebirthShopItem: RemoteEvent,  -- client -> server; payload {itemId}
    RebirthShopPurchased: RemoteEvent,-- server -> client; payload {itemId, tokensRemaining}
    RebirthShopRejected: RemoteEvent, -- server -> client; payload {itemId, reason, needed?}
    GetPetState: RemoteFunction,      -- client -> server; returns {pets, equippedPetIds, eggs, collectionComplete}
    HatchEgg: RemoteEvent,            -- client -> server; payload {eggId}
    PetHatched: RemoteEvent,          -- server -> client; payload {pet=OwnedPet, petName}
    PetHatchRejected: RemoteEvent,    -- server -> client; payload {eggId, reason, needed?}
    EquipPet: RemoteEvent,            -- client -> server; payload {uid}
    UnequipPet: RemoteEvent,          -- client -> server; payload {uid}
    PetEquipChanged: RemoteEvent,     -- server -> client; payload {equippedPetIds}
    GetAchievements: RemoteFunction,  -- client -> server; returns {entries=[{id,name,desc,unlocked,unlockedUnix?,progress,target,rewardCoins,rewardTokens}], unlockedCount, totalCount}
    AchievementUnlocked: RemoteEvent, -- server -> client; payload {id, name, rewardCoins, rewardTokens}
    FusePets: RemoteEvent,            -- client -> server; payload {rarity}
    PetFuseRejected: RemoteEvent,     -- server -> client; payload {rarity, reason, needed?}
    GetHourlyTribute: RemoteFunction, -- client -> server; returns {available, capped, nextStackInSec, perStackReward}
    ClaimHourlyTribute: RemoteEvent,  -- client -> server; no payload
    HourlyTributeClaimed: RemoteEvent,-- server -> client; payload {stacks, totalReward}
    HourlyTributeRejected: RemoteEvent,-- server -> client; payload {reason}
    GetAuras: RemoteFunction,         -- client -> server; returns {entries=[{id,name,desc,color,rarity,unlocked,equipped,progress,target}], equippedAura, unlockedCount, totalCount}
    EquipAura: RemoteEvent,           -- client -> server; payload {auraId or nil to unequip}
    AuraReplicate: RemoteEvent,       -- server -> ALL clients; payload {userId, auraId or nil} so every client renders trail
    AuraRejected: RemoteEvent,        -- server -> client; payload {auraId, reason}
    GetActivityFeed: RemoteFunction,  -- client -> server; returns {entries=[{kind, userName, detail, unix, agoSec}]}
    ActivityFeedUpdated: RemoteEvent, -- server -> client; payload {entries} (push when feed changes server-side)
}

return {}
