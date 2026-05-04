--!strict
-- Stuck character rescue. Two safety nets:
--   1. Dead-and-stuck: Humanoid.Health = 0 for >5s without auto-respawn
--      → force LoadCharacter
--   2. Under-the-map: HRP Y position < -50 for >3s → teleport to plot
--      Foundation (or origin if no plot yet)
--
-- Prevents the "I fell off and the game won't let me play" frustration
-- that's a common D1 bounce trigger.

local Players = game:GetService("Players")

local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner"))

local DEAD_GRACE_SEC = 5
local UNDER_MAP_Y = -50
local UNDER_MAP_GRACE_SEC = 3

local function rescueLoop(player: Player)
    local deadSince: number? = nil
    local underSince: number? = nil
    while true do
        task.wait(1)
        if not player.Parent then return end
        local char = player.Character
        if not char then deadSince = nil; underSince = nil; continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local now = os.time()

        -- 1. Dead-and-stuck
        if hum and hum.Health <= 0 then
            if not deadSince then deadSince = now end
            if (now - deadSince) >= DEAD_GRACE_SEC then
                print(string.format("[StuckRescue] %s dead %ds, forcing LoadCharacter",
                    player.Name, now - deadSince))
                pcall(function() player:LoadCharacter() end)
                deadSince = nil
            end
        else
            deadSince = nil
        end

        -- 2. Under-the-map
        if hrp and hrp.Position.Y < UNDER_MAP_Y then
            if not underSince then underSince = now end
            if (now - underSince) >= UNDER_MAP_GRACE_SEC then
                local plot = PlotAssigner.getPlotFor(player.UserId)
                local foundation = plot and plot:FindFirstChild("Foundation") :: BasePart?
                local landingPos = foundation
                    and (foundation.Position + Vector3.new(0, foundation.Size.Y / 2 + 6, 0))
                    or Vector3.new(0, 12, 0)  -- spawn pedestal fallback
                pcall(function()
                    hrp.CFrame = CFrame.new(landingPos)
                end)
                print(string.format("[StuckRescue] %s under map (Y=%d), teleported to plot",
                    player.Name, math.floor(hrp.Position.Y)))
                underSince = nil
            end
        else
            underSince = nil
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    task.spawn(rescueLoop, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(rescueLoop, p)
end

print("[StuckCharacterRescue] armed (5s dead-grace, 3s under-map-grace)")
