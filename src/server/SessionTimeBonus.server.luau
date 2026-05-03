--!strict
-- Session-time bonus claims. Per tycoon-retention-checklist:
-- session-length engagement is a leading retention indicator. Players
-- who claim a 30/60-min in-session bonus are far more likely to return
-- D2 (Adopt Me / Pet Sim 99 telemetry pattern).
--
-- Each player gets 3 claimable tiers per SESSION (15m, 30m, 60m). State
-- is in-memory + reset on player leave/rejoin — bonuses don't carry
-- across sessions. Server-authoritative; client cannot fake play time.
--
-- Bonuses are auto-granted as soon as the threshold is crossed (no claim
-- button) so players don't miss them. Each fires a SessionBonusGranted
-- remote event the client renders as a toast.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

-- userId -> { joinedAt = unix, claimed = {[tierIndex]=true} }
local sessions: {[number]: {joinedAt: number, claimed: {[number]: boolean}}} = {}

local function granted(player: Player, tierIdx: number, def: any)
    local data = DataStore.getCached(player.UserId)
    if not data then return end
    data.coins += def.reward
    data.lifetimeCoins += def.reward
    Leaderstats.refresh(player.UserId)
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    pcall(function()
        remotes.SessionBonusGranted:FireClient(player, {
            tierIdx = tierIdx,
            seconds = def.seconds,
            reward = def.reward,
            label = def.label,
        })
    end)
    pcall(function()
        AnalyticsService:LogCustomEvent(
            player, "SessionTimeBonus", def.reward,
            {tier_idx = tierIdx, seconds = def.seconds}
        )
    end)
    print(string.format("[SessionTimeBonus] %s tier %d (+%d coins, %d sec)",
        player.Name, tierIdx, def.reward, def.seconds))
end

local function tick()
    while true do
        task.wait(15)  -- check every 15s; threshold granularity is fine
        local now = os.time()
        for userId, sess in pairs(sessions) do
            local player = Players:GetPlayerByUserId(userId)
            if not player then continue end
            local elapsed = now - sess.joinedAt
            for i, def in ipairs(Constants.SESSION_TIME_BONUSES) do
                if elapsed >= def.seconds and not sess.claimed[i] then
                    sess.claimed[i] = true
                    granted(player, i, def)
                end
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    sessions[player.UserId] = {joinedAt = os.time(), claimed = {}}
end)
Players.PlayerRemoving:Connect(function(player)
    sessions[player.UserId] = nil
end)
-- Cover players already present
for _, p in ipairs(Players:GetPlayers()) do
    if not sessions[p.UserId] then
        sessions[p.UserId] = {joinedAt = os.time(), claimed = {}}
    end
end

task.spawn(tick)
print("[SessionTimeBonus] armed (" .. #Constants.SESSION_TIME_BONUSES .. " tiers)")
