--!strict
-- Match state machine. Cycles: lobby → countdown → active → results → lobby.
-- Phase 2 ports the dwmk/RobloxGames "Broken." round-flow patterns into
-- this adapter. Until then this is a tiny state machine that ticks the
-- phases on a fixed schedule so the client + scoreboard can be wired
-- against a real RemoteEvent stream.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

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
}

local state: State = {
    phase = "lobby",
    mapId = nil,
    startUnix = nil,
    endUnix = nil,
    participants = {},
    scores = {},
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

local function loop()
    while true do
        -- Lobby: wait for enough players
        state.mapId = nil
        state.startUnix = nil
        state.endUnix = nil
        state.participants = {}
        state.scores = {}
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
        transition("results")
        task.wait(Constants.MATCH_RESULTS_SEC)
    end
end

remotes.GetMatchState.OnServerInvoke = function(_player: Player)
    return state
end

task.spawn(loop)

return MatchService
