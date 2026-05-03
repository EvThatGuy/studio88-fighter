--!strict
-- Arcade-button style upgrade pad. Replaces the 4x4x4 amber neon cube.
-- A circular dome on a metal pedestal with a glowing top + ProximityPrompt.
-- Tagged Studio88UpgradeButton on the dome part so existing tag-driven
-- code (UpgradeStation/UpgradeButtonProxy) continues to work.

local CollectionService = game:GetService("CollectionService")

local AMBER   = Color3.fromRGB(255, 176, 0)
local DARK    = Color3.fromRGB(8, 7, 13)
local STEEL   = Color3.fromRGB(60, 65, 78)

local UpgradeButtonModel = {}

local function part(name: string, parent: Instance, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.Locked = true
    p.Parent = parent
    return p
end

function UpgradeButtonModel.build(pos: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "UpgradeButton"

    -- Pedestal base
    local pedestal = part("Pedestal", model, {
        Size = Vector3.new(5, 1.5, 5),
        Position = pos + Vector3.new(0, -0.75, 0),
        Material = Enum.Material.Metal,
        Color = STEEL,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
    })

    -- Stem connecting pedestal to dome
    local stem = part("Stem", model, {
        Size = Vector3.new(2, 1, 2),
        Position = pos + Vector3.new(0, 0.5, 0),
        Material = Enum.Material.Metal,
        Color = DARK,
    })

    -- Dome: glowing amber half-sphere (Ball with bottom hidden by stem)
    local dome = part("Dome", model, {
        Size = Vector3.new(3.5, 3.5, 3.5),
        Position = pos + Vector3.new(0, 1.7, 0),
        Material = Enum.Material.Neon,
        Color = AMBER,
        Shape = Enum.PartType.Ball,
        Transparency = 0.1,
    })
    model.PrimaryPart = dome
    CollectionService:AddTag(dome, "Studio88UpgradeButton")

    -- Inner core for extra brightness
    local core = part("DomeCore", model, {
        Size = Vector3.new(2, 2, 2),
        Position = pos + Vector3.new(0, 1.7, 0),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(255, 230, 130),
        Shape = Enum.PartType.Ball,
        Transparency = 0.0,
    })

    -- Slow upward particle drift
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(AMBER)
    pe.Speed = NumberRange.new(1, 2.5)
    pe.Lifetime = NumberRange.new(0.8, 1.4)
    pe.Rate = 10
    pe.SpreadAngle = Vector2.new(20, 20)
    pe.Acceleration = Vector3.new(0, 4, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = dome

    -- Cast amber light on the surrounding plot floor
    local pl = Instance.new("PointLight")
    pl.Brightness = 2.5
    pl.Range = 12
    pl.Color = AMBER
    pl.Parent = dome

    -- ProximityPrompt: same fields as the V61 prompt so UpgradeStation
    -- code matching by Name still works.
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "UpgradePrompt"
    prompt.ActionText = "Upgrade"
    prompt.ObjectText = "Studio 88 Tier"
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 8
    prompt.Parent = dome

    model.Parent = parent
    return model
end

return UpgradeButtonModel
