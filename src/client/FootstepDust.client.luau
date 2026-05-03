--!strict
-- Tiny client-side dust puff under the player's feet when they're moving.
-- Throttled to 1 puff per 0.4s and only when MoveDirection has magnitude
-- (i.e. not standing still). Pure local — no remotes, no server load.
-- Adds life to the lobby + plot space without touching the perf budget.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DUST_INTERVAL = 0.4
local lastPuffAt = 0

local function makePuff(pos: Vector3)
    local anchor = Instance.new("Part")
    anchor.Name = "Studio88FootDust"
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = pos
    anchor.Anchored = true
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Massless = true
    anchor.Parent = Workspace

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
    pe.LightEmission = 0
    pe.LightInfluence = 1
    pe.Color = ColorSequence.new(Color3.fromRGB(180, 175, 200))
    pe.Speed = NumberRange.new(0.5, 1.5)
    pe.Lifetime = NumberRange.new(0.4, 0.7)
    pe.Rate = 0
    pe.SpreadAngle = Vector2.new(40, 40)
    pe.Acceleration = Vector3.new(0, 1, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1.4),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = anchor
    pe:Emit(3)

    task.delay(1.0, function() if anchor.Parent then anchor:Destroy() end end)
end

local heartbeatConn: RBXScriptConnection? = nil

local function onCharacter(char: Model)
    local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
    if not hum then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    if not hrp then return end

    if heartbeatConn then heartbeatConn:Disconnect() end
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not hrp.Parent or hum.Health <= 0 then return end
        if hum.MoveDirection.Magnitude < 0.1 then return end
        local now = os.clock()
        if now - lastPuffAt < DUST_INTERVAL then return end
        lastPuffAt = now
        local footPos = hrp.Position - Vector3.new(0, 2.8, 0)
        makePuff(footPos)
    end)
end

if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)

print("[FootstepDust] client ready")
