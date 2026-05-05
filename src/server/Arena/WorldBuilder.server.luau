--!strict
-- Procedural arena builder — underground fight-club aesthetic. Concrete
-- warehouse with a square caged fighting pit at the center, exposed
-- piping along the upper walls, a hanging industrial lamp directly over
-- the ring, and ambient props (crates, barrels, hanging chains) at the
-- perimeter. Idempotent via the marker folder; cleans up the previous
-- neon-octagon build on first run after the redesign.
--
-- Phase 2 will replace this with authored maps cloned from ServerStorage
-- by MapRotation. Until then this is the canonical stage.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MARKER_NAME = "Studio88_FightClubArena"
local LEGACY_MARKER = "Studio88_PlaceholderArena"  -- previous neon-octagon build

-- Demolish the previous build so the redesign actually appears in dev
-- sessions / hot-reload restarts that already had the old arena built.
local legacy = Workspace:FindFirstChild(LEGACY_MARKER)
if legacy then legacy:Destroy() end

if Workspace:FindFirstChild(MARKER_NAME) then
    return
end

-- ── palette ───────────────────────────────────────────────────────────
local CONCRETE_DARK   = Color3.fromRGB(58, 56, 54)
local CONCRETE_MID    = Color3.fromRGB(76, 73, 70)
local CONCRETE_LIGHT  = Color3.fromRGB(96, 92, 88)
local STAIN_DARK      = Color3.fromRGB(34, 30, 28)
local STAIN_BLOOD     = Color3.fromRGB(64, 22, 18)
local METAL_BLACK     = Color3.fromRGB(28, 28, 32)
local METAL_RUST      = Color3.fromRGB(120, 60, 36)
local METAL_GRAY      = Color3.fromRGB(70, 68, 72)
local WOOD_CRATE      = Color3.fromRGB(110, 78, 48)
local LAMP_SHELL      = Color3.fromRGB(50, 48, 50)
local LAMP_GLOW       = Color3.fromRGB(255, 220, 150)

-- ── geometry ──────────────────────────────────────────────────────────
local PIT_HALF        = 50         -- fight pit is 100x100 studs
local CAGE_HEIGHT     = 18         -- bars run from floor to this height
local CAGE_POST_W     = 2.4        -- corner-post side length
local BAR_SPACING     = 4          -- spacing between vertical cage bars
local BAR_THICK       = 0.4
local OUTER_HALF      = 100        -- warehouse outer wall half-width
local WALL_HEIGHT     = 60
local WALL_THICK      = 4
local LAMP_HEIGHT     = 38         -- lamp center y above floor
local CEILING_Y       = 56         -- where pipes / lamp chain attach

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
    shape: Enum.PartType?,
    parent: Instance?,
    reflectance: number?,
}): BasePart
    local p
    if opts.shape == Enum.PartType.Cylinder or opts.shape == Enum.PartType.Ball then
        p = Instance.new("Part")
        p.Shape = opts.shape
    else
        p = Instance.new("Part")
    end
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
    p.Reflectance = opts.reflectance or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = opts.parent or arena
    return p
end

-- ── floor: stained concrete slab + grimy stain patches ───────────────
makePart({
    name = "FloorBase",
    size = Vector3.new(OUTER_HALF * 2 + 8, 2, OUTER_HALF * 2 + 8),
    position = Vector3.new(0, 0, 0),
    color = CONCRETE_DARK,
    material = Enum.Material.Concrete,
})

-- Slightly raised pit floor so the fight surface reads as the ring.
makePart({
    name = "PitFloor",
    size = Vector3.new(PIT_HALF * 2, 0.4, PIT_HALF * 2),
    position = Vector3.new(0, 1.2, 0),
    color = CONCRETE_MID,
    material = Enum.Material.Concrete,
})

-- Stain patches scattered across the pit floor for grime / blood feel.
local STAINS = {
    {pos = Vector3.new(-22,  1.42,  10), size = Vector3.new(14, 0.04, 9),  color = STAIN_DARK},
    {pos = Vector3.new( 18,  1.42, -16), size = Vector3.new(11, 0.04, 7),  color = STAIN_DARK},
    {pos = Vector3.new(  0,  1.42,  28), size = Vector3.new(8,  0.04, 6),  color = STAIN_BLOOD, transparency = 0.55},
    {pos = Vector3.new( 32,  1.42,  22), size = Vector3.new(5,  0.04, 4),  color = STAIN_BLOOD, transparency = 0.6},
    {pos = Vector3.new(-30,  1.42, -28), size = Vector3.new(9,  0.04, 6),  color = STAIN_DARK},
    {pos = Vector3.new( -8,  1.42,  -2), size = Vector3.new(6,  0.04, 4),  color = STAIN_BLOOD, transparency = 0.7},
}
for i, s in ipairs(STAINS) do
    makePart({
        name = "Stain_" .. i,
        size = s.size,
        position = s.pos,
        color = s.color,
        material = Enum.Material.Slate,
        transparency = s.transparency or 0.2,
        canCollide = false,
    })
end

-- ── outer warehouse walls (concrete + brick band at the bottom) ──────
local function makeWallBlock(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material)
    return makePart({
        name = name, size = size, position = position,
        color = color, material = material,
    })
end

-- North / South / East / West outer walls
makeWallBlock("WallN", Vector3.new(OUTER_HALF * 2 + WALL_THICK * 2, WALL_HEIGHT, WALL_THICK),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, -OUTER_HALF - WALL_THICK / 2), CONCRETE_DARK, Enum.Material.Concrete)
makeWallBlock("WallS", Vector3.new(OUTER_HALF * 2 + WALL_THICK * 2, WALL_HEIGHT, WALL_THICK),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, OUTER_HALF + WALL_THICK / 2), CONCRETE_DARK, Enum.Material.Concrete)
makeWallBlock("WallE", Vector3.new(WALL_THICK, WALL_HEIGHT, OUTER_HALF * 2),
    Vector3.new(OUTER_HALF + WALL_THICK / 2, WALL_HEIGHT / 2 + 1, 0), CONCRETE_DARK, Enum.Material.Concrete)
makeWallBlock("WallW", Vector3.new(WALL_THICK, WALL_HEIGHT, OUTER_HALF * 2),
    Vector3.new(-OUTER_HALF - WALL_THICK / 2, WALL_HEIGHT / 2 + 1, 0), CONCRETE_DARK, Enum.Material.Concrete)

-- Lower brick band (1/3 of wall height) with a different color/material
-- so the wall isn't a flat concrete slab.
local BRICK_HEIGHT = 14
local BRICK_COLOR = Color3.fromRGB(82, 50, 42)
makeWallBlock("BrickN", Vector3.new(OUTER_HALF * 2 + WALL_THICK * 2, BRICK_HEIGHT, WALL_THICK + 0.4),
    Vector3.new(0, BRICK_HEIGHT / 2 + 1, -OUTER_HALF - WALL_THICK / 2 + 0.2), BRICK_COLOR, Enum.Material.Brick)
makeWallBlock("BrickS", Vector3.new(OUTER_HALF * 2 + WALL_THICK * 2, BRICK_HEIGHT, WALL_THICK + 0.4),
    Vector3.new(0, BRICK_HEIGHT / 2 + 1, OUTER_HALF + WALL_THICK / 2 - 0.2), BRICK_COLOR, Enum.Material.Brick)
makeWallBlock("BrickE", Vector3.new(WALL_THICK + 0.4, BRICK_HEIGHT, OUTER_HALF * 2),
    Vector3.new(OUTER_HALF + WALL_THICK / 2 - 0.2, BRICK_HEIGHT / 2 + 1, 0), BRICK_COLOR, Enum.Material.Brick)
makeWallBlock("BrickW", Vector3.new(WALL_THICK + 0.4, BRICK_HEIGHT, OUTER_HALF * 2),
    Vector3.new(-OUTER_HALF - WALL_THICK / 2 + 0.2, BRICK_HEIGHT / 2 + 1, 0), BRICK_COLOR, Enum.Material.Brick)

-- Ceiling slab (gives the lamp something to hang from + closes the box)
makePart({
    name = "Ceiling",
    size = Vector3.new(OUTER_HALF * 2 + WALL_THICK * 2, 2, OUTER_HALF * 2 + WALL_THICK * 2),
    position = Vector3.new(0, CEILING_Y + 4, 0),
    color = CONCRETE_DARK,
    material = Enum.Material.Concrete,
})

-- ── caged fight pit: 4 corner posts + vertical bar walls ─────────────
local CORNERS = {
    {name = "PostNE", pos = Vector3.new( PIT_HALF,  CAGE_HEIGHT / 2,  -PIT_HALF)},
    {name = "PostNW", pos = Vector3.new(-PIT_HALF,  CAGE_HEIGHT / 2,  -PIT_HALF)},
    {name = "PostSE", pos = Vector3.new( PIT_HALF,  CAGE_HEIGHT / 2,   PIT_HALF)},
    {name = "PostSW", pos = Vector3.new(-PIT_HALF,  CAGE_HEIGHT / 2,   PIT_HALF)},
}
for _, c in ipairs(CORNERS) do
    makePart({
        name = c.name,
        size = Vector3.new(CAGE_POST_W, CAGE_HEIGHT, CAGE_POST_W),
        position = c.pos,
        color = METAL_BLACK,
        material = Enum.Material.Metal,
        reflectance = 0.05,
    })
end

-- Top rail connecting the four posts (gives the cage a hard edge profile).
local function makeTopRail(name: string, size: Vector3, position: Vector3)
    makePart({
        name = name, size = size, position = position,
        color = METAL_BLACK, material = Enum.Material.Metal,
        canCollide = true,
    })
end
makeTopRail("RailN", Vector3.new(PIT_HALF * 2 + CAGE_POST_W, 0.6, CAGE_POST_W * 0.8),
    Vector3.new(0, CAGE_HEIGHT + 0.3, -PIT_HALF))
makeTopRail("RailS", Vector3.new(PIT_HALF * 2 + CAGE_POST_W, 0.6, CAGE_POST_W * 0.8),
    Vector3.new(0, CAGE_HEIGHT + 0.3, PIT_HALF))
makeTopRail("RailE", Vector3.new(CAGE_POST_W * 0.8, 0.6, PIT_HALF * 2 + CAGE_POST_W),
    Vector3.new(PIT_HALF, CAGE_HEIGHT + 0.3, 0))
makeTopRail("RailW", Vector3.new(CAGE_POST_W * 0.8, 0.6, PIT_HALF * 2 + CAGE_POST_W),
    Vector3.new(-PIT_HALF, CAGE_HEIGHT + 0.3, 0))

-- Vertical bars: stand floor-to-rail along each side, evenly spaced.
-- Bars are non-collidable so combat hitboxes / dodges aren't snagged on
-- them; visual containment only. The corner posts are collidable.
local BAR_COUNT = math.floor((PIT_HALF * 2) / BAR_SPACING) - 1
local function makeBars(side: string)
    local sideAxis = (side == "N" or side == "S") and "x" or "z"
    for i = 1, BAR_COUNT do
        local t = (i / (BAR_COUNT + 1)) - 0.5  -- -0.5..0.5
        local along = t * (PIT_HALF * 2)
        local pos: Vector3
        if side == "N" then
            pos = Vector3.new(along, CAGE_HEIGHT / 2 + 1, -PIT_HALF)
        elseif side == "S" then
            pos = Vector3.new(along, CAGE_HEIGHT / 2 + 1,  PIT_HALF)
        elseif side == "E" then
            pos = Vector3.new( PIT_HALF, CAGE_HEIGHT / 2 + 1, along)
        else -- W
            pos = Vector3.new(-PIT_HALF, CAGE_HEIGHT / 2 + 1, along)
        end
        makePart({
            name = string.format("Bar%s_%d", side, i),
            size = Vector3.new(BAR_THICK, CAGE_HEIGHT, BAR_THICK),
            position = pos,
            color = METAL_BLACK,
            material = Enum.Material.Metal,
            canCollide = false,
            reflectance = 0.04,
        })
    end
end
makeBars("N")
makeBars("S")
makeBars("E")
makeBars("W")

-- Two horizontal mid-bars per side, breaking up the vertical pattern so
-- the cage reads more like chain-link and less like jail bars.
local function makeMidBar(name: string, size: Vector3, position: Vector3)
    makePart({
        name = name, size = size, position = position,
        color = METAL_BLACK, material = Enum.Material.Metal,
        canCollide = false, reflectance = 0.04,
    })
end
local MID_HEIGHTS = { CAGE_HEIGHT * 0.33, CAGE_HEIGHT * 0.66 }
for i, h in ipairs(MID_HEIGHTS) do
    makeMidBar("MidN_" .. i, Vector3.new(PIT_HALF * 2, BAR_THICK, BAR_THICK), Vector3.new(0, h + 1, -PIT_HALF))
    makeMidBar("MidS_" .. i, Vector3.new(PIT_HALF * 2, BAR_THICK, BAR_THICK), Vector3.new(0, h + 1,  PIT_HALF))
    makeMidBar("MidE_" .. i, Vector3.new(BAR_THICK, BAR_THICK, PIT_HALF * 2), Vector3.new( PIT_HALF, h + 1, 0))
    makeMidBar("MidW_" .. i, Vector3.new(BAR_THICK, BAR_THICK, PIT_HALF * 2), Vector3.new(-PIT_HALF, h + 1, 0))
end

-- ── hanging industrial lamp directly over the ring ───────────────────
-- Chain (skinny gray cylinder) running from ceiling to lamp shell.
local chainLength = CEILING_Y - LAMP_HEIGHT
makePart({
    name = "LampChain",
    size = Vector3.new(0.4, chainLength, 0.4),
    position = Vector3.new(0, LAMP_HEIGHT + chainLength / 2, 0),
    color = METAL_GRAY,
    material = Enum.Material.Metal,
    canCollide = false,
    reflectance = 0.05,
})

-- Lamp shell: dome-ish shape using a flat cylinder oriented so the
-- bottom faces the ring.
local lampShell = makePart({
    name = "LampShell",
    size = Vector3.new(8, 4, 8),
    cframe = CFrame.new(0, LAMP_HEIGHT, 0),
    color = LAMP_SHELL,
    material = Enum.Material.Metal,
    canCollide = false,
    reflectance = 0.08,
})
-- Bulb glow visible underneath the shell (neon cube hidden inside).
makePart({
    name = "LampGlow",
    size = Vector3.new(7, 0.5, 7),
    position = Vector3.new(0, LAMP_HEIGHT - 1.8, 0),
    color = LAMP_GLOW,
    material = Enum.Material.Neon,
    canCollide = false,
})
-- The actual SpotLight projecting onto the ring.
local mainLight = Instance.new("SpotLight")
mainLight.Brightness = 8
mainLight.Range = 90
mainLight.Angle = 110
mainLight.Color = Color3.fromRGB(255, 230, 180)
mainLight.Face = Enum.NormalId.Bottom
mainLight.Shadows = true
mainLight.Parent = lampShell

-- ── exposed pipes along the upper walls ──────────────────────────────
local PIPE_Y_HIGH = WALL_HEIGHT - 6
local PIPE_Y_LOW  = WALL_HEIGHT - 14
local function makePipe(name: string, size: Vector3, position: Vector3, color: Color3)
    makePart({
        name = name, size = size, position = position,
        color = color, material = Enum.Material.Metal,
        canCollide = false, reflectance = 0.08,
    })
end
-- Two horizontal pipes per side (high + low band) running along the inside face.
makePipe("PipeN_High", Vector3.new(OUTER_HALF * 2, 1.4, 1.4), Vector3.new(0, PIPE_Y_HIGH, -OUTER_HALF + 1.2), METAL_GRAY)
makePipe("PipeN_Low",  Vector3.new(OUTER_HALF * 2, 1.0, 1.0), Vector3.new(0, PIPE_Y_LOW,  -OUTER_HALF + 1.6), METAL_RUST)
makePipe("PipeS_High", Vector3.new(OUTER_HALF * 2, 1.4, 1.4), Vector3.new(0, PIPE_Y_HIGH,  OUTER_HALF - 1.2), METAL_GRAY)
makePipe("PipeS_Low",  Vector3.new(OUTER_HALF * 2, 1.0, 1.0), Vector3.new(0, PIPE_Y_LOW,   OUTER_HALF - 1.6), METAL_RUST)
makePipe("PipeE_High", Vector3.new(1.4, 1.4, OUTER_HALF * 2), Vector3.new( OUTER_HALF - 1.2, PIPE_Y_HIGH, 0), METAL_GRAY)
makePipe("PipeE_Low",  Vector3.new(1.0, 1.0, OUTER_HALF * 2), Vector3.new( OUTER_HALF - 1.6, PIPE_Y_LOW,  0), METAL_RUST)
makePipe("PipeW_High", Vector3.new(1.4, 1.4, OUTER_HALF * 2), Vector3.new(-OUTER_HALF + 1.2, PIPE_Y_HIGH, 0), METAL_GRAY)
makePipe("PipeW_Low",  Vector3.new(1.0, 1.0, OUTER_HALF * 2), Vector3.new(-OUTER_HALF + 1.6, PIPE_Y_LOW,  0), METAL_RUST)

-- A few vertical drainage pipes connecting high band to floor for variety.
local function makeVerticalPipe(name: string, position: Vector3)
    makePart({
        name = name,
        size = Vector3.new(1.2, WALL_HEIGHT - 2, 1.2),
        position = position,
        color = METAL_RUST,
        material = Enum.Material.CorrodedMetal,
        canCollide = false,
        reflectance = 0.06,
    })
end
makeVerticalPipe("DrainNE", Vector3.new( OUTER_HALF - 2,  WALL_HEIGHT / 2 + 1, -OUTER_HALF + 2))
makeVerticalPipe("DrainNW", Vector3.new(-OUTER_HALF + 2,  WALL_HEIGHT / 2 + 1, -OUTER_HALF + 2))
makeVerticalPipe("DrainSE", Vector3.new( OUTER_HALF - 2,  WALL_HEIGHT / 2 + 1,  OUTER_HALF - 2))
makeVerticalPipe("DrainSW", Vector3.new(-OUTER_HALF + 2,  WALL_HEIGHT / 2 + 1,  OUTER_HALF - 2))

-- ── ambient props: crates, barrels, hanging chains ───────────────────
local function makeCrate(name: string, position: Vector3, sideLen: number)
    makePart({
        name = name,
        size = Vector3.new(sideLen, sideLen, sideLen),
        position = position + Vector3.new(0, sideLen / 2, 0),
        color = WOOD_CRATE,
        material = Enum.Material.WoodPlanks,
    })
end
local function makeBarrel(name: string, position: Vector3)
    local p = makePart({
        name = name,
        size = Vector3.new(4, 4, 4),
        cframe = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
        color = METAL_RUST,
        material = Enum.Material.CorrodedMetal,
        shape = Enum.PartType.Cylinder,
    })
    return p
end

-- Crates clustered against the warehouse walls, outside the cage.
makeCrate("CrateA", Vector3.new(-OUTER_HALF + 8, 1, -OUTER_HALF + 8), 5)
makeCrate("CrateB", Vector3.new(-OUTER_HALF + 14, 1, -OUTER_HALF + 6), 4)
makeCrate("CrateC", Vector3.new(-OUTER_HALF + 8, 6, -OUTER_HALF + 8), 4)
makeCrate("CrateD", Vector3.new( OUTER_HALF - 10, 1, OUTER_HALF - 12), 5)
makeCrate("CrateE", Vector3.new( OUTER_HALF - 18, 1, OUTER_HALF - 8), 4)

-- Barrels in opposite corners.
makeBarrel("BarrelA", Vector3.new( OUTER_HALF - 8, 1, -OUTER_HALF + 10))
makeBarrel("BarrelB", Vector3.new( OUTER_HALF - 14, 1, -OUTER_HALF + 12))
makeBarrel("BarrelC", Vector3.new(-OUTER_HALF + 12, 1, OUTER_HALF - 10))

-- Hanging chains along the ceiling (decorative, not coiled).
local function makeHangingChain(name: string, x: number, z: number, length: number)
    makePart({
        name = name,
        size = Vector3.new(0.3, length, 0.3),
        position = Vector3.new(x, CEILING_Y - length / 2, z),
        color = METAL_GRAY,
        material = Enum.Material.Metal,
        canCollide = false,
        reflectance = 0.05,
    })
end
makeHangingChain("ChainA", -PIT_HALF - 18, -PIT_HALF - 12, 22)
makeHangingChain("ChainB",  PIT_HALF + 16,  PIT_HALF + 18, 26)
makeHangingChain("ChainC",  PIT_HALF + 22, -PIT_HALF - 8, 18)

-- ── perimeter rim lights (dim wall sconces flanking each cage gate) ──
-- Subtle warm light on the corridor side so the warehouse isn't pitch
-- black where the spotlight doesn't reach.
local function makeWallSconce(name: string, position: Vector3)
    local sconce = makePart({
        name = name,
        size = Vector3.new(2, 2, 1),
        position = position,
        color = LAMP_SHELL,
        material = Enum.Material.Metal,
        canCollide = false,
    })
    local glow = Instance.new("PointLight")
    glow.Brightness = 1.6
    glow.Range = 28
    glow.Color = Color3.fromRGB(230, 180, 110)
    glow.Shadows = false
    glow.Parent = sconce
    return sconce
end
makeWallSconce("SconceN1", Vector3.new(-30, 14, -OUTER_HALF + 2.5))
makeWallSconce("SconceN2", Vector3.new( 30, 14, -OUTER_HALF + 2.5))
makeWallSconce("SconceS1", Vector3.new(-30, 14,  OUTER_HALF - 2.5))
makeWallSconce("SconceS2", Vector3.new( 30, 14,  OUTER_HALF - 2.5))
makeWallSconce("SconceE1", Vector3.new( OUTER_HALF - 2.5, 14, -30))
makeWallSconce("SconceE2", Vector3.new( OUTER_HALF - 2.5, 14,  30))
makeWallSconce("SconceW1", Vector3.new(-OUTER_HALF + 2.5, 14, -30))
makeWallSconce("SconceW2", Vector3.new(-OUTER_HALF + 2.5, 14,  30))

-- ── dim, hazy lighting (overrides the project.json purple theme) ────
Lighting.Ambient = Color3.fromRGB(28, 26, 24)
Lighting.OutdoorAmbient = Color3.fromRGB(20, 18, 16)
Lighting.Brightness = 0.8
Lighting.ClockTime = 0  -- midnight; sun contributes nothing to the indoor box
Lighting.ColorShift_Top = Color3.fromRGB(80, 70, 60)
Lighting.ColorShift_Bottom = Color3.fromRGB(40, 30, 20)
Lighting.EnvironmentDiffuseScale = 0.2
Lighting.EnvironmentSpecularScale = 0.15
Lighting.FogColor = Color3.fromRGB(35, 30, 26)
Lighting.FogStart = 80
Lighting.FogEnd = 380
Lighting.ExposureCompensation = 0.05

-- Atmosphere: dusty, smoky air rather than the prior magenta haze.
local existingAtmos = Lighting:FindFirstChildOfClass("Atmosphere")
if existingAtmos then existingAtmos:Destroy() end
local atmos = Instance.new("Atmosphere")
atmos.Density = 0.42
atmos.Offset = 0.15
atmos.Color = Color3.fromRGB(120, 105, 90)
atmos.Decay = Color3.fromRGB(60, 50, 42)
atmos.Glare = 0.25
atmos.Haze = 1.8
atmos.Parent = Lighting

-- Drift particles: smoky / dusty motes lit by the overhead lamp.
local driftHost = makePart({
    name = "DriftHost",
    size = Vector3.new(PIT_HALF * 2, 24, PIT_HALF * 2),
    position = Vector3.new(0, 18, 0),
    color = CONCRETE_DARK,
    material = Enum.Material.SmoothPlastic,
    transparency = 1,
    canCollide = false,
})
local emitter = Instance.new("ParticleEmitter")
emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
emitter.Color = ColorSequence.new(Color3.fromRGB(180, 160, 140))
emitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.5),
    NumberSequenceKeypoint.new(0.5, 1.4),
    NumberSequenceKeypoint.new(1,   0.3),
})
emitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.85),
    NumberSequenceKeypoint.new(0.5, 0.7),
    NumberSequenceKeypoint.new(1,   1.0),
})
emitter.Rate = 4
emitter.Lifetime = NumberRange.new(5, 9)
emitter.Speed = NumberRange.new(0.5, 1.8)
emitter.SpreadAngle = Vector2.new(180, 180)
emitter.LightEmission = 0.05
emitter.LightInfluence = 1
emitter.Parent = driftHost

-- ── spawn pads (concrete platforms at opposing corners of the cage) ──
local function makeSpawn(name: string, position: Vector3)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = name
    spawn.Anchored = true
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = position
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Material = Enum.Material.Concrete
    spawn.Color = CONCRETE_LIGHT
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Parent = arena
    -- Painted boundary stripe for visibility.
    makePart({
        name = name .. "_Stripe",
        size = Vector3.new(8.4, 0.05, 0.4),
        position = position - Vector3.new(0, 0.5, 0),
        color = Color3.fromRGB(220, 200, 60),
        material = Enum.Material.SmoothPlastic,
        canCollide = false,
    })
end
makeSpawn("SpawnA", Vector3.new(-PIT_HALF + 10, 1.7, 0))
makeSpawn("SpawnB", Vector3.new( PIT_HALF - 10, 1.7, 0))

-- ── strip out the default Baseplate / SpawnLocation ─────────────────-
for _, child in ipairs(Workspace:GetChildren()) do
    if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "SpawnLocation") then
        child:Destroy()
    end
end

print(string.format(
    "[WorldBuilder] fight-club arena built: %d×%d pit inside %d×%d warehouse, " ..
    "caged ring with overhead lamp, exposed pipes, %d wall sconces, %d crates, drift smoke",
    PIT_HALF * 2, PIT_HALF * 2, OUTER_HALF * 2, OUTER_HALF * 2, 8, 5
))
