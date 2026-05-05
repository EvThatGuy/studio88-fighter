--!strict
-- Server-authoritative stamina ledger. Each player has a stamina value
-- in [0, classMax]; combat actions deduct, idle time regens. Server
-- pushes state to the owning client via StaminaUpdated. Hits / blocks /
-- dodges call this BEFORE consuming the action.
--
-- Stub: Phase 1 wires actual cost deduction from CombatService and the
-- per-tick regen loop. Until then this just maintains a no-op cache so
-- the dependency graph compiles.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))
local ClassRegistry = require(script.Parent:WaitForChild("ClassRegistry"))

local remotes = Remotes.get()

local StaminaService = {}

local stamina: {[number]: number} = {}        -- current per userId
local maxFor: {[number]: number} = {}          -- max per userId (re-evaluated on class change)
local lastSync: {[number]: number} = {}        -- last os.clock() sent to client (rate-limit pushes)

local SYNC_INTERVAL = 0.1                      -- max client push rate; 10 Hz

local function ensure(player: Player)
    local class = ClassRegistry.classFor(player.UserId)
    maxFor[player.UserId] = class.staminaMax
    if stamina[player.UserId] == nil then
        stamina[player.UserId] = class.staminaMax
    end
end

local function pushIfDue(player: Player)
    local now = os.clock()
    local last = lastSync[player.UserId] or 0
    if now - last < SYNC_INTERVAL then return end
    lastSync[player.UserId] = now
    remotes.StaminaUpdated:FireClient(player, {
        current = stamina[player.UserId],
        max = maxFor[player.UserId],
    })
end

function StaminaService.tryConsume(player: Player, amount: number): boolean
    ensure(player)
    local cur = stamina[player.UserId]
    if cur < amount then
        return false
    end
    stamina[player.UserId] = cur - amount
    pushIfDue(player)
    return true
end

function StaminaService.add(player: Player, amount: number)
    ensure(player)
    local cap = maxFor[player.UserId]
    stamina[player.UserId] = math.min(cap, stamina[player.UserId] + amount)
    pushIfDue(player)
end

function StaminaService.snapshot(userId: number): {current: number, max: number}
    return {
        current = stamina[userId] or Constants.STAMINA_MAX,
        max = maxFor[userId] or Constants.STAMINA_MAX,
    }
end

Players.PlayerAdded:Connect(function(player)
    -- Wait for DataStore cache to fill before we read class.
    task.wait(0.5)
    ensure(player)
end)

Players.PlayerRemoving:Connect(function(player)
    stamina[player.UserId] = nil
    maxFor[player.UserId] = nil
    lastSync[player.UserId] = nil
end)

-- Regen loop. Out-of-combat regen rate; CombatService can later call
-- StaminaService.markInCombat(userId, untilUnix) to switch to the
-- in-combat regen rate. Phase 1 wires that switch.
RunService.Heartbeat:Connect(function(dt: number)
    local regen = Constants.STAMINA_REGEN_PER_SEC * dt
    for _, player in ipairs(Players:GetPlayers()) do
        ensure(player)
        StaminaService.add(player, regen)
    end
end)

return StaminaService
