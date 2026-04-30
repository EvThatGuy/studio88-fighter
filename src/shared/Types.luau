--!strict
-- Shared type definitions. Keep this file alongside any structural change
-- to the DataStore schema; bump Constants.DATASTORE_VERSION too.

export type PlayerData = {
    coins: number,                  -- spendable balance
    lifetimeCoins: number,          -- never decreases; drives leaderboard
    upgradeTier: number,            -- 1..#Constants.UPGRADE_TIERS
    lastLoginUnix: number,          -- os.time() at last full login
    streak: number,                 -- consecutive days logged in
    starterPackPurchasedUnix: number?, -- for the 30-min Starter Pack window
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
}

return {}
