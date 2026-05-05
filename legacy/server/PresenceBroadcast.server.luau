--!strict
-- Broadcasts player count + squad-active state to all clients on
-- PlayerAdded/Removing transitions. Lets the HUD render a "👥 N online"
-- badge that updates in real-time without per-client polling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.get()

local function broadcast()
    local count = #Players:GetPlayers()
    local squadActive = count >= (Constants.SQUAD_BONUS and Constants.SQUAD_BONUS.THRESHOLD or 3)
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.ServerPresenceChanged:FireClient(p, {
                count = count,
                squadActive = squadActive,
                squadThreshold = (Constants.SQUAD_BONUS and Constants.SQUAD_BONUS.THRESHOLD) or 3,
            })
        end)
    end
end

Players.PlayerAdded:Connect(function(p)
    -- Slight delay so the new player has finished bootstrap before
    -- receiving the broadcast (otherwise their PlayerGui isn't ready)
    task.wait(2)
    broadcast()
end)
Players.PlayerRemoving:Connect(function(p)
    task.wait(0.5)
    broadcast()
end)

print("[PresenceBroadcast] armed")
