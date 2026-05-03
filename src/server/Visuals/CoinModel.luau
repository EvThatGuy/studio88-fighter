--!strict
-- 3D coin model. Replaces the 1.2-stud neon sphere in Dropper.server.luau.
-- A flat cylindrical disc with bevelled glow, color-keyed to tier, slowly
-- self-rotating. Visually reads as "money" instead of "ball" within ~1
-- second of camera contact. CFrame-rotation is server-side (Anchored=false
-- so physics still pushes via conveyor belt).

local CollectionService = game:GetService("CollectionService")

local CYAN  = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK  = Color3.fromRGB(255, 46, 136)
local GOLD  = Color3.fromRGB(255, 215, 0)

local CoinModel = {}

local function colorForTier(tier: number): Color3
    if tier >= 5 then return GOLD
    elseif tier >= 4 then return PINK
    elseif tier >= 3 then return AMBER
    else return CYAN end
end

-- Per-tier sound modifiers consumed by Collector via the AmbientAudio
-- spatial play. Higher tier = louder + lower pitch (chunkier "chink").
function CoinModel.soundForTier(tier: number): (number, number)
    local volume = 0.15 + math.min(tier, 6) * 0.04   -- 0.19 .. 0.39
    local pitch  = 1.15 - math.min(tier, 6) * 0.05   -- 1.10 .. 0.85
    return volume, pitch
end

-- Build a coin disc: cylinder body, neon rim, inner face decal (a glowing
-- "$" symbol via TextLabel on a SurfaceGui rather than a Decal asset, so we
-- ship zero external dependencies). Returns the body Part with all visuals
-- parented to it. Caller sets Position, OwnerUserId attribute, Value attribute.
function CoinModel.build(tier: number): BasePart
    local color = colorForTier(tier)

    local coin = Instance.new("Part")
    coin.Name = "Studio88Coin"
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = Vector3.new(0.4, 2.0, 2.0)  -- thin disc, 2 studs across
    coin.Material = Enum.Material.Neon
    coin.Color = color
    coin.TopSurface = Enum.SurfaceType.Smooth
    coin.BottomSurface = Enum.SurfaceType.Smooth
    coin.CanCollide = true
    coin.CFrame = CFrame.Angles(0, 0, math.rad(90))  -- lay flat on conveyor

    -- Inner face: rim ring (slightly smaller cylinder, darker tone) so the
    -- eye reads "minted disc" not "single colour blob".
    local rim = Instance.new("Part")
    rim.Name = "Rim"
    rim.Shape = Enum.PartType.Cylinder
    rim.Size = Vector3.new(0.42, 1.5, 1.5)
    rim.Material = Enum.Material.SmoothPlastic
    rim.Color = Color3.fromRGB(
        math.clamp(math.floor(color.R * 255 * 0.4), 0, 255),
        math.clamp(math.floor(color.G * 255 * 0.4), 0, 255),
        math.clamp(math.floor(color.B * 255 * 0.4), 0, 255)
    )
    rim.CanCollide = false
    rim.CanQuery = false
    rim.CanTouch = false
    rim.Massless = true
    rim.CFrame = coin.CFrame
    rim.Anchored = false

    -- Weld rim to coin so they move together
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = coin
    weld.Part1 = rim
    weld.Parent = coin
    rim.Parent = coin

    -- Note: previous V62 version added 2 SurfaceGuis per coin (one per
    -- cylinder face) for a "$" symbol. PerfBudgetProbe surfaced surfaceGui
    -- count growing 26->68 within 30s of play because coin lifetime is 30s
    -- and spawn rate is 1/s (so up to 30 live coins = 60 guis from coins
    -- alone). Removed: cylinder disc + neon glow + sparkle reads as a coin
    -- without the symbol, and SurfaceGui count stays at the fixed-cost
    -- baseline of ~8 from world fixtures.

    -- Subtle glow trail so the coin reads as moving even on low-end clients
    -- where conveyor velocity is barely visible.
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "Sparkle"
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(color)
    pe.Lifetime = NumberRange.new(0.3, 0.6)
    pe.Rate = 4
    pe.Speed = NumberRange.new(0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = coin

    -- Light streak Trail — gives coins a comet tail along the conveyor.
    -- Higher tiers get longer/brighter trails so the eye reads "this is a
    -- premium coin" before it lands. Trail attaches to two attachments
    -- spanning the cylinder length so it traces the disc edge as it tumbles.
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0,  1.0, 0)
    a0.Parent = coin
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -1.0, 0)
    a1.Parent = coin
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = ColorSequence.new(color)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = (tier >= 5) and 0.45 or 0.25
    trail.LightEmission = 1
    trail.LightInfluence = 0
    trail.MinLength = 0
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.2),
    })
    trail.Parent = coin

    CollectionService:AddTag(coin, "Studio88Coin")

    -- Tumble while in flight: spin around the cylinder's long axis at
    -- ~3 rad/s. We use AlignOrientation + AngularVelocity instead of
    -- CFrame writes because the coin is unanchored (physics-pushed) and
    -- CFrame writes would fight the collision solver.
    local spinAttachment = Instance.new("Attachment")
    spinAttachment.Parent = coin

    local angularVelocity = Instance.new("AngularVelocity")
    angularVelocity.Attachment0 = spinAttachment
    angularVelocity.AngularVelocity = Vector3.new(8, 0, 0)  -- spin around X (cylinder long axis)
    angularVelocity.MaxTorque = math.huge
    angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    angularVelocity.Parent = coin

    return coin
end

return CoinModel
