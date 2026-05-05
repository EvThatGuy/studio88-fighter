--!strict
-- 1v1 duel queue. Players opt in via the DuelQueueRequest remote (K key
-- on the client). When two players are queued, this service pairs them
-- and runs an isolated 1v1 first-to-DUEL_KO_TARGET-or-time-expires match
-- concurrent with the global deathmatch.
--
-- Damage gating: while a duel is active, the two duelists can ONLY damage
-- each other (CombatService.canDamage delegates to DuelService.canDamage).
-- KOs between duelists route to duel score, NOT match score (recordKO
-- returns true to tell CombatService it consumed the KO). Lifetime KO
-- counter still ticks for both routes.
--
-- Per-player state push: each duelist gets DuelStateChanged events with
-- their own perspective of the duel (selfScore vs opponentScore, etc.).
-- The HUD client subscribes to render the duel pill.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local Types = require(Modules:WaitForChild("Types"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local DuelService = {}

type Duel = {
    a: Player,
    b: Player,
    aUserId: number,
    bUserId: number,
    aName: string,
    bName: string,
    scores: {[number]: number},   -- userId -> KO count
    startUnix: number,
    endUnix: number,
    finished: boolean,
}

local queue: {Player} = {}
local activeDuels: {Duel} = {}
local userDuel: {[number]: Duel} = {}  -- userId -> duel they're in

-- ── push helpers ──────────────────────────────────────────────────────

local function pushIdle(player: Player)
    if not player.Parent then return end
    remotes.DuelStateChanged:FireClient(player, {
        phase = "idle",
    } :: Types.DuelClientState)
end

local function pushQueued(player: Player)
    if not player.Parent then return end
    remotes.DuelStateChanged:FireClient(player, {
        phase = "queued",
        queueTotal = #queue,
    } :: Types.DuelClientState)
end

local function pushActiveTo(player: Player, duel: Duel)
    if not player.Parent then return end
    local selfId = player.UserId
    local opponentId = (selfId == duel.aUserId) and duel.bUserId or duel.aUserId
    local opponentName = (selfId == duel.aUserId) and duel.bName or duel.aName
    remotes.DuelStateChanged:FireClient(player, {
        phase = "active",
        opponentUserId = opponentId,
        opponentName = opponentName,
        selfScore = duel.scores[selfId] or 0,
        opponentScore = duel.scores[opponentId] or 0,
        endsAtUnix = duel.endUnix,
    } :: Types.DuelClientState)
end

local function pushEndedTo(player: Player, duel: Duel, won: boolean, xp: number)
    if not player.Parent then return end
    local selfId = player.UserId
    local opponentId = (selfId == duel.aUserId) and duel.bUserId or duel.aUserId
    local opponentName = (selfId == duel.aUserId) and duel.bName or duel.aName
    remotes.DuelStateChanged:FireClient(player, {
        phase = "ended",
        opponentUserId = opponentId,
        opponentName = opponentName,
        selfScore = duel.scores[selfId] or 0,
        opponentScore = duel.scores[opponentId] or 0,
        won = won,
        xpAwarded = xp,
    } :: Types.DuelClientState)
end

-- ── queue ─────────────────────────────────────────────────────────────

local function indexInQueue(player: Player): number?
    for i, p in ipairs(queue) do
        if p == player then return i end
    end
    return nil
end

local function broadcastQueueCounts()
    for _, p in ipairs(queue) do
        pushQueued(p)
    end
end

local function pairAndStart(a: Player, b: Player)
    local duel: Duel = {
        a = a, b = b,
        aUserId = a.UserId, bUserId = b.UserId,
        aName = a.Name, bName = b.Name,
        scores = { [a.UserId] = 0, [b.UserId] = 0 },
        startUnix = os.time(),
        endUnix = os.time() + Constants.DUEL_DURATION_SEC,
        finished = false,
    }
    table.insert(activeDuels, duel)
    userDuel[a.UserId] = duel
    userDuel[b.UserId] = duel
    pushActiveTo(a, duel)
    pushActiveTo(b, duel)

    -- Hard time cap. Re-checks finished so the timer doesn't fire after
    -- a score-out has already ended the duel.
    task.delay(Constants.DUEL_DURATION_SEC, function()
        if duel.finished then return end
        DuelService.endDuel(duel, "time")
    end)
end

local function tryPair()
    while #queue >= 2 do
        local a = table.remove(queue, 1)
        local b = table.remove(queue, 1)
        if a and b and a.Parent and b.Parent then
            pairAndStart(a, b)
        else
            -- One left mid-queue; loop continues with whoever's still in.
            if a and a.Parent and not indexInQueue(a) then
                table.insert(queue, 1, a)
            end
            if b and b.Parent and not indexInQueue(b) then
                table.insert(queue, 1, b)
            end
            break
        end
    end
    broadcastQueueCounts()
end

-- ── duel termination ──────────────────────────────────────────────────

-- Picks a winner by score; returns (winnerUserId|nil, loserUserId|nil).
-- Tied scores → no winner, no loser; both treated as draws (loss XP each).
local function resolveOutcome(duel: Duel): (number?, number?)
    local aScore = duel.scores[duel.aUserId] or 0
    local bScore = duel.scores[duel.bUserId] or 0
    if aScore == bScore then return nil, nil end
    if aScore > bScore then return duel.aUserId, duel.bUserId end
    return duel.bUserId, duel.aUserId
end

function DuelService.endDuel(duel: Duel, _reason: string)
    if duel.finished then return end
    duel.finished = true
    -- Remove from active list + per-user index
    for i, d in ipairs(activeDuels) do
        if d == duel then
            table.remove(activeDuels, i)
            break
        end
    end
    userDuel[duel.aUserId] = nil
    userDuel[duel.bUserId] = nil

    local winnerId, _loserId = resolveOutcome(duel)

    local function awardXp(player: Player, amount: number)
        local data = DataStore.getCached(player.UserId)
        if data then
            data.xp += amount
            Leaderstats.refresh(player.UserId)
        end
    end

    -- Both players: push the ended state with their personal won flag.
    -- Winner gets DUEL_WIN_XP, loser/draw both get DUEL_LOSS_XP (so even
    -- a tie / forfeit grants something for queueing up).
    local aWon = winnerId == duel.aUserId
    local bWon = winnerId == duel.bUserId
    local aXp = aWon and Constants.DUEL_WIN_XP or Constants.DUEL_LOSS_XP
    local bXp = bWon and Constants.DUEL_WIN_XP or Constants.DUEL_LOSS_XP
    awardXp(duel.a, aXp)
    awardXp(duel.b, bXp)
    pushEndedTo(duel.a, duel, aWon, aXp)
    pushEndedTo(duel.b, duel, bWon, bXp)

    -- Auto-clear the ended banner after the display window so the HUD
    -- returns to "press K to queue".
    task.delay(Constants.DUEL_RESULTS_DISPLAY_SEC, function()
        if duel.a.Parent then pushIdle(duel.a) end
        if duel.b.Parent then pushIdle(duel.b) end
    end)
end

-- ── public API for CombatService ──────────────────────────────────────

function DuelService.isInDuel(userId: number): boolean
    return userDuel[userId] ~= nil
end

-- Returns true if attacker is allowed to damage victim under duel rules.
-- victimUserId == nil → an NPC (training dummy etc.); always allowed.
function DuelService.canDamage(attackerUserId: number, victimUserId: number?): boolean
    if victimUserId == nil then return true end
    local atkDuel = userDuel[attackerUserId]
    local vicDuel = userDuel[victimUserId]
    if atkDuel == nil and vicDuel == nil then return true end
    -- Either side is in a duel; only allow if it's the SAME duel.
    return atkDuel ~= nil and atkDuel == vicDuel
end

-- Returns true if this KO was consumed by an active duel between the two
-- players. CombatService skips MatchService.recordKO when this returns true,
-- but lifetime KO ticks are still applied here so the career stat keeps moving.
function DuelService.recordKO(attackerUserId: number, victimUserId: number): boolean
    local duel = userDuel[attackerUserId]
    if not duel then return false end
    if userDuel[victimUserId] ~= duel then return false end
    if duel.finished then return false end

    duel.scores[attackerUserId] = (duel.scores[attackerUserId] or 0) + 1

    -- Lifetime KO tick (mirrors MatchService.recordKO).
    local data = DataStore.getCached(attackerUserId)
    if data then
        data.knockouts += 1
        Leaderstats.refresh(attackerUserId)
    end

    -- Push score updates to both duelists.
    pushActiveTo(duel.a, duel)
    pushActiveTo(duel.b, duel)

    -- Score-out check.
    if duel.scores[attackerUserId] >= Constants.DUEL_KO_TARGET then
        DuelService.endDuel(duel, "score")
    end
    return true
end

-- ── queue request handler ─────────────────────────────────────────────

remotes.DuelQueueRequest.OnServerEvent:Connect(function(player: Player, payload: any)
    if typeof(payload) ~= "table" then return end
    local join = payload.join == true

    -- Already in an active duel? Ignore queue toggles.
    if userDuel[player.UserId] then return end

    if join then
        if indexInQueue(player) then return end -- already queued
        table.insert(queue, player)
        broadcastQueueCounts()
        tryPair()
    else
        local idx = indexInQueue(player)
        if not idx then return end
        table.remove(queue, idx)
        pushIdle(player)
        broadcastQueueCounts()
    end
end)

-- ── disconnect cleanup ────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
    -- Remove from queue if present.
    local idx = indexInQueue(player)
    if idx then
        table.remove(queue, idx)
        broadcastQueueCounts()
    end
    -- Forfeit any active duel; remaining player wins.
    local duel = userDuel[player.UserId]
    if duel and not duel.finished then
        -- Pad winner's score to target so resolveOutcome picks them.
        local winnerId = (player.UserId == duel.aUserId) and duel.bUserId or duel.aUserId
        duel.scores[winnerId] = math.max(duel.scores[winnerId] or 0, Constants.DUEL_KO_TARGET)
        DuelService.endDuel(duel, "forfeit")
    end
end)

-- Initial idle push for connected players (handles HotReload restarts).
for _, player in ipairs(Players:GetPlayers()) do
    pushIdle(player)
end
Players.PlayerAdded:Connect(function(player)
    -- Slight delay so the client has had a chance to wait for remotes.
    task.delay(1.5, function()
        if player.Parent then pushIdle(player) end
    end)
end)

return DuelService
