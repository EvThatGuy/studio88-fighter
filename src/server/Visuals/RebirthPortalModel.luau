--!strict
-- Glowing prestige portal. Replaces the cyan cylinder pad in WorldBuilder.
-- A vertical torus-ish stack: glowing base ring + 3 ascending light rings +
-- center beam. Visible across the plot as the "endgame goal" carrot.
-- Tagged Studio88RebirthPad on the base ring so RebirthPadProxy continues
-- to find it.

local CollectionService = game:GetService("CollectionService")

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)

local RebirthPortalModel = {}

local function part(name: string, parent: Instance, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.Locked = true
    p.Parent = parent
    return p
end

function RebirthPortalModel.build(pos: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "RebirthPortal"

    -- Base pad (the actual physical "stand here" disc)
    local pad = part("Pad", model, {
        Size = Vector3.new(8, 0.5, 8),
        Position = pos,
        Material = Enum.Material.Neon,
        Color = CYAN,
        Transparency = 0.2,
    })
    do
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = pad
    end
    model.PrimaryPart = pad
    CollectionService:AddTag(pad, "Studio88RebirthPad")

    -- 3 ascending light rings, each smaller diameter, alternating cyan/pink
    local ringSpecs = {
        {y = 3,  diameter = 7,  color = CYAN},
        {y = 6,  diameter = 6,  color = PINK},
        {y = 9,  diameter = 5,  color = CYAN},
    }
    for i, spec in ipairs(ringSpecs) do
        local ring = part("Ring" .. i, model, {
            Size = Vector3.new(spec.diameter, 0.4, spec.diameter),
            Position = pos + Vector3.new(0, spec.y, 0),
            Material = Enum.Material.Neon,
            Color = spec.color,
            Transparency = 0.3,
            CanCollide = false,
            CanQuery = false,
        })
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 0.4, 1)
        mesh.Parent = ring
    end

    -- Vertical center beam: thin tall cylinder, glowing
    local beam = part("Beam", model, {
        Size = Vector3.new(1, 14, 1),
        Position = pos + Vector3.new(0, 7, 0),
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(180, 240, 255),
        Transparency = 0.4,
        CanCollide = false,
        CanQuery = false,
    })
    do
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = beam
    end

    -- Particle shower swirling up
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(CYAN, PINK)
    pe.Speed = NumberRange.new(3, 6)
    pe.Lifetime = NumberRange.new(1.0, 2.0)
    pe.Rate = 18
    pe.SpreadAngle = Vector2.new(20, 20)
    pe.Acceleration = Vector3.new(0, 6, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 1.4),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = pad

    -- Strong upward light from the pad
    local pl = Instance.new("PointLight")
    pl.Brightness = 3
    pl.Range = 24
    pl.Color = CYAN
    pl.Parent = beam

    -- ProximityPrompt: V61-compatible Name + fields so RebirthPadProxy
    -- continues to enable/disable it correctly.
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "RebirthPrompt"
    prompt.ActionText = "Rebirth"
    prompt.ObjectText = "Studio 88 Prestige"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 8
    prompt.Enabled = false  -- proxy enables when eligible
    prompt.Parent = pad

    model.Parent = parent
    return model
end

return RebirthPortalModel
