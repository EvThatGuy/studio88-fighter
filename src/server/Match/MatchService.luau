--!strict
-- Match state machine. Cycles: lobby → countdown → active → results → lobby.
-- Holds match scores; awards persistent wins / losses on results phase.
-- Damage attribution arrives via MatchService.recordKO from CombatService.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent.Parent:WaitForChild("Leaderstats"))
local MapRotation = require(script.Parent:WaitForChild("MapRotation"))

local remotes = Remotes.get()

local MatchService = {}

type State = {
    phase: string,           -- "lobby" | "countdown" | "active" | "results"
    mapId: string?,
    startUnix: number?,
    endUnix: number?,
    participants: {number},
    scores: {[number]: number},
    winnerUserId: number?,   -- set when entering "results"; cleared on next "lobby"
}

local state: State = {
    phase = "lobby",
    mapId = nil,
    startUnix = nil,
    endUnix = nil,
    participants = {},
    scores = {},
    winnerUserId = nil,
}

local function broadcast()
    remotes.MatchStateChanged:FireAllClients(state)
end

local function transition(newPhase: string)
    state.phase = newPhase
    broadcast()
end

local function snapshotParticipants(): {number}
    local ids = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(ids, player.UserId)
    end
    return ids
end

local function pickWinner(): number?
    local bestId: number? = nil
    local bestScore = -1
    for userId, score in pairs(state.scores) do
        if score > bestScore then
            bestScore = score
            bestId = userId
        end
    end
    -- Tie or zero scores → no winner
    if bestScore <= 0 then return nil end
    -- Detect ties: more than one player with bestScore = no winner
    local tied = 0
    for _, score in pairs(state.scores) do
        if score == bestScore then tied += 1 end
    end
    if tied > 1 then return nil end
    return bestId
end

local function awardResults()
    local winnerUserId = pickWinner()
    state.winnerUserId = winnerUserId
    for _, userId in ipairs(state.participants) do
        local data = DataStore.getCached(userId)
        if data then
            data.matchesPlayed += 1
            if userId == winnerUserId then
                data.wins += 1
            else
                data.losses += 1
            end
            Leaderstats.refresh(userId)
        end
    end
end

-- Called by CombatService when an attacker drops a victim's health to 0.
function MatchService.recordKO(attackerUserId: number, victimUserId: number)
    -- Lifetime knockouts always tick (regardless of phase / whether
    -- they're a participant). This is the "career KOs" flex stat.
    local attackerData = DataStore.getCached(attackerUserId)
    if attackerData then
        attackerData.knockouts += 1
        Leaderstats.refresh(attackerUserId)
    end
    -- Match scoring only counts during active phase, only if BOTH players
    -- are participants. Lobby brawls don't count toward match score.
    if state.phase ~= "active" then return end
    local isParticipant = false
    for _, id in ipairs(state.participants) do
        if id == attackerUserId then isParticipant = true; break end
    end
    if not isParticipant then return end
    state.scores[attackerUserId] = (state.scores[attackerUserId] or 0) + 1
    broadcast()
end

function MatchService.snapshot(): State
    return state
end

local function loop()
    while true do
        -- Lobby: wait for enough players
        state.mapId = nil
        state.startUnix = nil
        state.endUnix = nil
        state.participants = {}
        state.scores = {}
        state.winnerUserId = nil
        transition("lobby")

        while #Players:GetPlayers() < Constants.LOBBY_MIN_PLAYERS do
            task.wait(1)
        end

        -- Countdown
        state.mapId = MapRotation.pickNext().id
        transition("countdown")
        task.wait(Constants.LOBBY_COUNTDOWN_SEC)

        -- Active
        state.startUnix = os.time()
        state.endUnix = state.startUnix + Constants.MATCH_DURATION_SEC
        state.participants = snapshotParticipants()
        state.scores = {}
        for _, userId in ipairs(state.participants) do
            state.scores[userId] = 0
        end
        transition("active")
        task.wait(Constants.MATCH_DURATION_SEC)

        -- Results
        awardResults()
        transition("results")
        task.wait(Constants.MATCH_RESULTS_SEC)
    end
end

remotes.GetMatchState.OnServerInvoke = function(_player: Player)
    return state
end

task.spawn(loop)

return MatchService
