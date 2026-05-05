--!strict
-- Squad Bonus. When the server has SQUAD_THRESHOLD or more concurrent
-- players, EVERYONE gets a flat income multiplier. CurrencyManager calls
-- getMultiplier() on every tick; this module just tracks count and pushes
-- state changes to clients for the HUD ribbon.
--
-- No persistence. State is server-instance-local; rejoining a different
-- server may flip you in or out of the bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.get()

local SquadBonusService = {}

local function isActive(): boolean
    return #Players:GetPlayers() >= Constants.SQUAD_BONUS.THRESHOLD
end

function SquadBonusService.getMultiplier(): number
    if isActive() then
        return Constants.SQUAD_BONUS.MULTIPLIER
    end
    return 1.0
end

local lastActiveState: boolean? = nil

local function broadcast()
    local count = #Players:GetPlayers()
    local active = count >= Constants.SQUAD_BONUS.THRESHOLD
    if active == lastActiveState then return end
    lastActiveState = active
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            remotes.SquadBonusChanged:FireClient(p, {
                active = active,
                count = count,
                threshold = Constants.SQUAD_BONUS.THRESHOLD,
                multiplier = Constants.SQUAD_BONUS.MULTIPLIER,
            })
        end
    end)
    print(string.format("[SquadBonus] %s (count=%d, threshold=%d)",
        active and "ACTIVE" or "inactive", count, Constants.SQUAD_BONUS.THRESHOLD))
end

-- Even when state doesn't change (e.g. count goes from 4 -> 5 while
-- active), push the new count so the HUD ribbon stays accurate.
local function broadcastForce()
    local count = #Players:GetPlayers()
    local active = count >= Constants.SQUAD_BONUS.THRESHOLD
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            remotes.SquadBonusChanged:FireClient(p, {
                active = active,
                count = count,
                threshold = Constants.SQUAD_BONUS.THRESHOLD,
                multiplier = Constants.SQUAD_BONUS.MULTIPLIER,
            })
        end
    end)
end

Players.PlayerAdded:Connect(function(_player)
    -- Slight debounce so the new player gets the broadcast in the SAME push
    task.wait(1)
    broadcastForce()
    lastActiveState = isActive() -- prime the dedupe
end)

Players.PlayerRemoving:Connect(function(_player)
    task.defer(function()
        broadcastForce()
        lastActiveState = isActive()
    end)
end)

print(string.format("[SquadBonus] ready (threshold %d, mult %.2fx)",
    Constants.SQUAD_BONUS.THRESHOLD, Constants.SQUAD_BONUS.MULTIPLIER))

return SquadBonusService
