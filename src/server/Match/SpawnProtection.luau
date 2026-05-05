--!strict
-- Attaches a 3-second ForceField to every freshly-spawned character.
-- ForceField makes Humanoid:TakeDamage no-op, blocking spawn-camping
-- between respawns. Removed automatically when the player moves
-- (interpreted as "ready to fight") OR when the timer runs out,
-- whichever comes first.

local Players = game:GetService("Players")

local SpawnProtection = {}

local PROTECTION_SEC = 3
local MOVE_THRESHOLD_STUDS = 6  -- moves more than this → protection ends

local function attach(player: Player, character: Model)
    local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    if not hrp then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Prior force fields from previous spawns can stick around in edge
    -- cases (BindToClose, hot reload). Clear before adding ours.
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("ForceField") then child:Destroy() end
    end

    local field = Instance.new("ForceField")
    field.Name = "Studio88_SpawnProtection"
    field.Visible = true
    field.Parent = character

    local startPos = hrp.Position
    local removed = false

    local function remove()
        if removed then return end
        removed = true
        if field.Parent then field:Destroy() end
    end

    -- Movement-based cancellation: once you've stepped off the spawn pad,
    -- protection lifts so you can't kite-with-immunity.
    local moveConn: RBXScriptConnection? = nil
    moveConn = hrp:GetPropertyChangedSignal("Position"):Connect(function()
        if removed then
            if moveConn then moveConn:Disconnect() end
            return
        end
        if (hrp.Position - startPos).Magnitude > MOVE_THRESHOLD_STUDS then
            if moveConn then moveConn:Disconnect() end
            remove()
        end
    end)

    -- Hard timeout regardless of movement.
    task.delay(PROTECTION_SEC, function()
        if moveConn then moveConn:Disconnect() end
        remove()
    end)

    -- Death cancels protection (no need to keep a field on a corpse).
    humanoid.Died:Connect(remove)
end

local function bindPlayer(player: Player)
    if player.Character then attach(player, player.Character) end
    player.CharacterAdded:Connect(function(character)
        attach(player, character)
    end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end

return SpawnProtection
