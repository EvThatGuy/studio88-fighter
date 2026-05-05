--!strict
-- Procedural arena builder. Constructs a moody, fighter-style stage at
-- server start: octagonal floor, neon ring, four corner pillars, raised
-- outer walls with a neon trim, a low spectator ring, atmospheric SFX
-- (Atmosphere + drift particles + corner SpotLights). Idempotent — the
-- marker folder prevents duplicate construction on hot reload.
--
-- Phase 2 will replace this with authored maps cloned from
-- ServerStorage by MapRotation. Until then this is the canonical stage.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MARKER_NAME = "Studio88_PlaceholderArena"

if Workspace:FindFirstChild(MARKER_NAME) then
    return
end

-- ── palette ───────────────────────────────────────────────────────────
local PINK    = Color3.fromRGB(255, 46, 136)
local CYAN    = Color3.fromRGB(0, 240, 255)
local AMBER   = Color3.fromRGB(255, 176, 0)
local DARK    = Color3.fromRGB(8, 7, 13)
local FLOOR_A = Color3.fromRGB(28, 22, 40)
local FLOOR_B = Color3.fromRGB(20, 16, 32)
local SLATE   = Color3.fromRGB(20, 17, 31)
local PURPLE  = Color3.fromRGB(120, 40, 200)

-- ── geometry ──────────────────────────────────────────────────────────
local FLOOR_RADIUS  = 100        -- outer fighting-area half-width
local WALL_HEIGHT   = 30
local WALL_THICK    = 2
local PILLAR_HEIGHT = 36
local PILLAR_W      = 6
local PILLAR_OFFSET = FLOOR_RADIUS - 6   -- distance from center to pillar center

local arena = Instance.new("Folder")
arena.Name = MARKER_NAME
arena.Parent = Workspace

local function makePart(opts: {
    name: string,
    size: Vector3,
    cframe: CFrame?,
    position: Vector3?,
    color: Color3,
    material: Enum.Material,
    transparency: number?,
    canCollide: boolean?,
    parent: Instance?,
}): BasePart
    local p = Instance.new("Part")
    p.Name = opts.name
    p.Anchored = true
    p.Size = opts.size
    if opts.cframe then
        p.CFrame = opts.cframe
    elseif opts.position then
        p.Position = opts.position
    end
    p.Color = opts.color
    p.Material = opts.material
    p.Transparency = opts.transparency or 0
    p.CanCollide = (opts.canCollide ~= false)
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = opts.parent or arena
    return p
end

-- ── floor: dark concrete base + checkered octagon overlay ────────────
makePart({
    name = "FloorBase",
    size = Vector3.new(FLOOR_RADIUS * 2 + 8, 2, FLOOR_RADIUS * 2 + 8),
    position = Vector3.new(0, 0, 0),
    color = FLOOR_A,
    material = Enum.Material.Concrete,
})

-- Octagonal "ring" floor: 8 trapezoid-ish slats around the center for
-- visual interest. Approximated with rotated rectangular slabs.
local SECTOR_COUNT = 8
local SECTOR_OUTER_LEN = (FLOOR_RADIUS * 2) * math.sin(math.pi / SECTOR_COUNT)
for i = 1, SECTOR_COUNT do
    local angle = (i - 1) * (2 * math.pi / SECTOR_COUNT)
    local cf = CFrame.new(0, 1.05, 0)
        * CFrame.Angles(0, angle, 0)
        * CFrame.new(0, 0, -(FLOOR_RADIUS * 0.7))
    local color = (i % 2 == 0) and FLOOR_A or FLOOR_B
    makePart({
        name = "FloorSlat_" .. i,
        size = Vector3.new(SECTOR_OUTER_LEN * 0.9, 0.2, FLOOR_RADIUS * 0.55),
        cframe = cf,
        color = color,
        material = Enum.Material.SmoothPlastic,
    })
end

-- Center neon ring (logo seam): two crossing thin neon strips form a +
-- with a smaller octagon ring around them.
makePart({
    name = "CenterSeamX",
    size = Vector3.new(34, 0.3, 1),
    position = Vector3.new(0, 1.18, 0),
    color = PINK,
    material = Enum.Material.Neon,
    canCollide = false,
})
makePart({
    name = "CenterSeamZ",
    size = Vector3.new(1, 0.3, 34),
    position = Vector3.new(0, 1.18, 0),
    color = PINK,
    material = Enum.Material.Neon,
    canCollide = false,
})

-- Octagonal neon ring around center
local CENTER_RING_RADIUS = 22
local CENTER_RING_SEGMENTS = 8
local CENTER_RING_LEN = (CENTER_RING_RADIUS * 2) * math.sin(math.pi / CENTER_RING_SEGMENTS)
for i = 1, CENTER_RING_SEGMENTS do
    local angle = (i - 1) * (2 * math.pi / CENTER_RING_SEGMENTS)
    local cf = CFrame.new(0, 1.18, 0)
        * CFrame.Angles(0, angle, 0)
        * CFrame.new(0, 0, -CENTER_RING_RADIUS)
    makePart({
        name = "CenterRingSeg_" .. i,
        size = Vector3.new(CENTER_RING_LEN * 1.02, 0.3, 0.4),
        cframe = cf,
        color = CYAN,
        material = Enum.Material.Neon,
        canCollide = false,
    })
end

-- ── walls: 4 sides, dark slate with neon trim at the top ─────────────
local function makeWall(name: string, size: Vector3, position: Vector3)
    makePart({
        name = name,
        size = size,
        position = position,
        color = SLATE,
        material = Enum.Material.Slate,
    })
end

makeWall("WallN",
    Vector3.new(FLOOR_RADIUS * 2 + WALL_THICK * 2, WALL_HEIGHT, WALL_THICK),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, -FLOOR_RADIUS - WALL_THICK / 2))
makeWall("WallS",
    Vector3.new(FLOOR_RADIUS * 2 + WALL_THICK * 2, WALL_HEIGHT, WALL_THICK),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, FLOOR_RADIUS + WALL_THICK / 2))
makeWall("WallE",
    Vector3.new(WALL_THICK, WALL_HEIGHT, FLOOR_RADIUS * 2),
    Vector3.new(FLOOR_RADIUS + WALL_THICK / 2, WALL_HEIGHT / 2 + 1, 0))
makeWall("WallW",
    Vector3.new(WALL_THICK, WALL_HEIGHT, FLOOR_RADIUS * 2),
    Vector3.new(-FLOOR_RADIUS - WALL_THICK / 2, WALL_HEIGHT / 2 + 1, 0))

-- Neon trim along the top of each wall
local TRIM_THICK = 0.4
local TRIM_HEIGHT = 0.6
local function makeTrim(name: string, size: Vector3, position: Vector3, color: Color3)
    makePart({
        name = name,
        size = size,
        position = position,
        color = color,
        material = Enum.Material.Neon,
        canCollide = false,
    })
end
makeTrim("TrimN",
    Vector3.new(FLOOR_RADIUS * 2 + WALL_THICK * 2, TRIM_HEIGHT, TRIM_THICK),
    Vector3.new(0, WALL_HEIGHT + 1.3, -FLOOR_RADIUS - WALL_THICK / 2),
    PINK)
makeTrim("TrimS",
    Vector3.new(FLOOR_RADIUS * 2 + WALL_THICK * 2, TRIM_HEIGHT, TRIM_THICK),
    Vector3.new(0, WALL_HEIGHT + 1.3, FLOOR_RADIUS + WALL_THICK / 2),
    PINK)
makeTrim("TrimE",
    Vector3.new(TRIM_THICK, TRIM_HEIGHT, FLOOR_RADIUS * 2),
    Vector3.new(FLOOR_RADIUS + WALL_THICK / 2, WALL_HEIGHT + 1.3, 0),
    CYAN)
makeTrim("TrimW",
    Vector3.new(TRIM_THICK, TRIM_HEIGHT, FLOOR_RADIUS * 2),
    Vector3.new(-FLOOR_RADIUS - WALL_THICK / 2, WALL_HEIGHT + 1.3, 0),
    CYAN)

-- ── corner pillars + neon caps + downward SpotLights ─────────────────
local CORNERS = {
    {name = "PillarNE", pos = Vector3.new( PILLAR_OFFSET, PILLAR_HEIGHT / 2, -PILLAR_OFFSET), accent = PINK},
    {name = "PillarNW", pos = Vector3.new(-PILLAR_OFFSET, PILLAR_HEIGHT / 2, -PILLAR_OFFSET), accent = CYAN},
    {name = "PillarSE", pos = Vector3.new( PILLAR_OFFSET, PILLAR_HEIGHT / 2,  PILLAR_OFFSET), accent = CYAN},
    {name = "PillarSW", pos = Vector3.new(-PILLAR_OFFSET, PILLAR_HEIGHT / 2,  PILLAR_OFFSET), accent = PINK},
}

for _, c in ipairs(CORNERS) do
    -- column body
    local pillar = makePart({
        name = c.name,
        size = Vector3.new(PILLAR_W, PILLAR_HEIGHT, PILLAR_W),
        position = c.pos,
        color = SLATE,
        material = Enum.Material.Slate,
    })
    -- neon cap
    local cap = makePart({
        name = c.name .. "_Cap",
        size = Vector3.new(PILLAR_W + 0.4, 0.8, PILLAR_W + 0.4),
        position = c.pos + Vector3.new(0, PILLAR_HEIGHT / 2 + 0.4, 0),
        color = c.accent,
        material = Enum.Material.Neon,
        canCollide = false,
    })
    -- downward spot from cap
    local light = Instance.new("SpotLight")
    light.Brightness = 4
    light.Range = 100
    light.Angle = 75
    light.Color = c.accent
    light.Face = Enum.NormalId.Bottom
    light.Shadows = false
    light.Parent = cap

    -- thin glow strip down the inside face (the side facing arena center)
    local toCenter = (Vector3.new(0, 0, 0) - c.pos).Unit
    local glowOffset = toCenter * (PILLAR_W / 2 + 0.05)
    makePart({
        name = c.name .. "_Glow",
        size = Vector3.new(0.15, PILLAR_HEIGHT - 4, 0.6),
        cframe = CFrame.new(c.pos + glowOffset)
            * CFrame.Angles(0, math.atan2(toCenter.Z, toCenter.X) + math.pi / 2, 0),
        color = c.accent,
        material = Enum.Material.Neon,
        canCollide = false,
    })
end

-- ── low spectator ring beyond the walls ──────────────────────────────
-- Simple raised silhouette band so the camera doesn't see endless void.
local SPEC_RADIUS = FLOOR_RADIUS + 28
local SPEC_HEIGHT = 12
local SPEC_THICK = 4
makeWall("SpecRingN",
    Vector3.new(SPEC_RADIUS * 2 + SPEC_THICK * 2, SPEC_HEIGHT, SPEC_THICK),
    Vector3.new(0, SPEC_HEIGHT / 2 - 1, -SPEC_RADIUS))
makeWall("SpecRingS",
    Vector3.new(SPEC_RADIUS * 2 + SPEC_THICK * 2, SPEC_HEIGHT, SPEC_THICK),
    Vector3.new(0, SPEC_HEIGHT / 2 - 1, SPEC_RADIUS))
makeWall("SpecRingE",
    Vector3.new(SPEC_THICK, SPEC_HEIGHT, SPEC_RADIUS * 2),
    Vector3.new(SPEC_RADIUS, SPEC_HEIGHT / 2 - 1, 0))
makeWall("SpecRingW",
    Vector3.new(SPEC_THICK, SPEC_HEIGHT, SPEC_RADIUS * 2),
    Vector3.new(-SPEC_RADIUS, SPEC_HEIGHT / 2 - 1, 0))

-- ── ambient drift particles (uses Roblox built-in sparkles texture) ─
local function attachDriftParticles(part: BasePart)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   PINK),
        ColorSequenceKeypoint.new(0.5, PURPLE),
        ColorSequenceKeypoint.new(1,   CYAN),
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.4),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1,   0.2),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.6),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1,   1.0),
    })
    emitter.Rate = 6
    emitter.Lifetime = NumberRange.new(4, 7)
    emitter.Speed = NumberRange.new(1, 3)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.LightEmission = 0.6
    emitter.LightInfluence = 0
    emitter.Parent = part
end

-- Invisible volume parented to attach drift particles to the whole arena
local driftHost = makePart({
    name = "DriftHost",
    size = Vector3.new(FLOOR_RADIUS * 2, 24, FLOOR_RADIUS * 2),
    position = Vector3.new(0, 16, 0),
    color = DARK,
    material = Enum.Material.SmoothPlastic,
    transparency = 1,
    canCollide = false,
})
attachDriftParticles(driftHost)

-- ── Atmosphere instance for moody depth ─────────────────────────────-
local existingAtmos = Lighting:FindFirstChildOfClass("Atmosphere")
if existingAtmos then existingAtmos:Destroy() end
local atmos = Instance.new("Atmosphere")
atmos.Density = 0.32
atmos.Offset = 0.2
atmos.Color = Color3.fromRGB(40, 26, 60)
atmos.Decay = Color3.fromRGB(80, 30, 110)
atmos.Glare = 0.5
atmos.Haze = 1.4
atmos.Parent = Lighting

-- ── spawn pads (cyan / pink to match opposing walls' trim) ───────────
local function makeSpawn(name: string, position: Vector3, color: Color3)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = name
    spawn.Anchored = true
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = position
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Material = Enum.Material.Neon
    spawn.Color = color
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Parent = arena

    -- Glow ring inset for visual flair
    local ring = makePart({
        name = name .. "_Ring",
        size = Vector3.new(11, 0.2, 11),
        position = position - Vector3.new(0, 0.4, 0),
        color = color,
        material = Enum.Material.Neon,
        transparency = 0.4,
        canCollide = false,
    })
    ring.Parent = arena
end

makeSpawn("SpawnA", Vector3.new(-60, 1.5, 0), CYAN)
makeSpawn("SpawnB", Vector3.new( 60, 1.5, 0), PINK)

-- ── strip out the default Baseplate / SpawnLocation so they don't fight us
for _, child in ipairs(Workspace:GetChildren()) do
    if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "SpawnLocation") then
        child:Destroy()
    end
end

print(string.format("[WorldBuilder] arena built: %d×%d octagonal stage with neon trim, 4 corner pillars, drift particles, atmosphere",
    FLOOR_RADIUS * 2, FLOOR_RADIUS * 2))
