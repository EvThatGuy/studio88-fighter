--!strict
-- Server-side movement sanity check. Samples each player's HumanoidRootPart
-- position once per second; if the implied speed exceeds
-- Constants.MAX_MOVE_PER_SEC repeatedly, kicks the offender.
--
-- Tolerance is generous (1.5×) to absorb legit lag spikes and class
-- walkspeed overshoots. Three violations within VIOLATION_WINDOW_SEC
-- triggers a kick — a single bad sample doesn't.
--
-- Scope: this validates teleport-style position deltas. It does NOT
-- enforce the actual walkspeed (Roblox's Humanoid does that already
-- when WalkSpeed is set server-side). What it catches is exploits that
-- bypass Humanoid by setting CFrame directly client-side, which then
-- replicates through Roblox's character ownership.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local AntiCheat = {}

local SAMPLE_INTERVAL_SEC = 1
local VIOLATION_WINDOW_SEC = 5
local VIOLATIONS_TO_KICK = 3
local TOLERANCE_MULT = 1.5
local MIN_DELTA_STUDS = 2  -- ignore sub-2-stud jitter; cheap floor

type Sample = {
    pos: Vector3,
    clock: number,
}

local lastSample: {[number]: Sample} = {}
local violations: {[number]: {number}} = {}  -- userId → list of os.clock() of violations

local function pruneViolations(userId: number, now: number)
    local list = violations[userId]
    if not list then return end
    local kept = {}
    for _, t in ipairs(list) do
        if now - t < VIOLATION_WINDOW_SEC then
            table.insert(kept, t)
        end
    end
    violations[userId] = kept
end

local function recordViolation(userId: number, now: number, observed: number, allowed: number)
    local list = violations[userId]
    if not list then
        list = {}
        violations[userId] = list
    end
    table.insert(list, now)
    pruneViolations(userId, now)
    warn(string.format(
        "[AntiCheat] userId=%d position-delta exceeded: observed %.1f studs/s vs allowed %.1f (%d/%d)",
        userId, observed, allowed, #list, VIOLATIONS_TO_KICK
    ))
    if #list >= VIOLATIONS_TO_KICK then
        local player = Players:GetPlayerByUserId(userId)
        if player then
            player:Kick("Disconnected: movement validation failed.")
        end
    end
end

local function sampleOnce(player: Player, now: number)
    local character = player.Character
    if not character then
        lastSample[player.UserId] = nil
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        -- Skip dead / despawning characters; their CFrame can teleport on respawn.
        lastSample[player.UserId] = nil
        return
    end
    local prev = lastSample[player.UserId]
    lastSample[player.UserId] = {pos = hrp.Position, clock = now}
    if not prev then return end
    local dt = now - prev.clock
    if dt <= 0 then return end
    local delta = (hrp.Position - prev.pos).Magnitude
    if delta < MIN_DELTA_STUDS then return end
    local speed = delta / dt
    local allowed = Constants.MAX_MOVE_PER_SEC * TOLERANCE_MULT
    if speed > allowed then
        recordViolation(player.UserId, now, speed, allowed)
    end
end

task.spawn(function()
    while true do
        task.wait(SAMPLE_INTERVAL_SEC)
        local now = os.clock()
        for _, player in ipairs(Players:GetPlayers()) do
            sampleOnce(player, now)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastSample[player.UserId] = nil
    violations[player.UserId] = nil
end)

return AntiCheat
