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

-- userId -> {
--   activeSeconds = number   -- play time (excluding AFK)
--   claimed = {[tierIdx]=true}
--   lastMoveAt = unix        -- last time HRP moved >0.5 stud
--   lastTickAt = unix        -- last anti-AFK tick
-- }
type Session = {
    activeSeconds: number,
    claimed: {[number]: boolean},
    lastMoveAt: number,
    lastTickAt: number,
}
local sessions: {[number]: Session} = {}
local AFK_THRESHOLD_SEC = 60  -- no movement in 60s = AFK; pause timer

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

-- Anti-AFK: only advance activeSeconds if the player has moved their
-- HumanoidRootPart in the last AFK_THRESHOLD_SEC. Stops AFK farming.
local function isActive(player: Player, sess: Session, now: number): boolean
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if hum.MoveDirection.Magnitude > 0.05 then
        sess.lastMoveAt = now
        return true
    end
    return (now - sess.lastMoveAt) <= AFK_THRESHOLD_SEC
end

local function tick()
    while true do
        task.wait(15)  -- 15s cadence; threshold granularity is fine
        local now = os.time()
        for userId, sess in pairs(sessions) do
            local player = Players:GetPlayerByUserId(userId)
            if not player then continue end
            local delta = now - sess.lastTickAt
            sess.lastTickAt = now
            -- Only credit elapsed time if player wasn't AFK for the window
            if isActive(player, sess, now) then
                sess.activeSeconds += delta
            end
            for i, def in ipairs(Constants.SESSION_TIME_BONUSES) do
                if sess.activeSeconds >= def.seconds and not sess.claimed[i] then
                    sess.claimed[i] = true
                    granted(player, i, def)
                end
            end
        end
    end
end

local function newSession(): Session
    local now = os.time()
    return {activeSeconds = 0, claimed = {}, lastMoveAt = now, lastTickAt = now}
end

Players.PlayerAdded:Connect(function(player)
    sessions[player.UserId] = newSession()
end)
Players.PlayerRemoving:Connect(function(player)
    sessions[player.UserId] = nil
end)
-- Cover players already present
for _, p in ipairs(Players:GetPlayers()) do
    if not sessions[p.UserId] then
        sessions[p.UserId] = newSession()
    end
end

-- ---- Snapshot RemoteFunction ------------------------------------------
-- Client widget polls this every ~5s to render "Next bonus in M:SS".
remotes.GetSessionBonus.OnServerInvoke = function(player: Player)
    local sess = sessions[player.UserId]
    local active = (sess ~= nil) and sess.activeSeconds or 0
    local tiers = {}
    for i, def in ipairs(Constants.SESSION_TIME_BONUSES) do
        table.insert(tiers, {
            tierIdx = i,
            seconds = def.seconds,
            reward = def.reward,
            label = def.label,
            claimed = (sess ~= nil) and (sess.claimed[i] == true) or false,
        })
    end
    return { activeSeconds = active, tiers = tiers }
end

task.spawn(tick)
print("[SessionTimeBonus] armed (" .. #Constants.SESSION_TIME_BONUSES .. " tiers)")
