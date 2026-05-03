--!strict
-- Lobby spawn decor. New players spawn on the central pink disc and have
-- ~5 seconds before they wander to a plot. That window decides whether
-- they bounce or commit. The default disc + floating text reads as
-- "test build" — this module makes the lobby feel intentional:
--
--   * 3-tier stacked platform (pedestal feel) instead of a flat slab
--   * Rotating "TYCOON" sign with cyan/pink sparkle
--   * 6 directional pillars subtly pointing at plot anchors
--   * Ambient lights cast pink/cyan onto the dark baseplate

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local PINK    = Color3.fromRGB(255, 46, 136)
local CYAN    = Color3.fromRGB(0, 240, 255)
local DARK    = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local STEEL   = Color3.fromRGB(60, 65, 78)

local LobbyDecor = {}

local function part(name: string, parent: Instance, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.Locked = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- Build the lobby decor at the world origin. Idempotent: replaces any
-- existing Studio88LobbyDecor folder so callers can rebuild on Hot Reload.
function LobbyDecor.build()
    local existing = Workspace:FindFirstChild("Studio88LobbyDecor")
    if existing then existing:Destroy() end
    local container = Instance.new("Folder")
    container.Name = "Studio88LobbyDecor"
    container.Parent = Workspace

    -- 3-tier pedestal (each layer narrower than the one below)
    local tiers = {
        {y = 0.5,  diameter = 32, color = SURFACE, material = Enum.Material.SmoothPlastic, transparency = 0},
        {y = 1.4,  diameter = 26, color = STEEL,   material = Enum.Material.Metal,         transparency = 0},
        {y = 2.2,  diameter = 22, color = PINK,    material = Enum.Material.Neon,          transparency = 0.2},
    }
    for i, t in ipairs(tiers) do
        local tier = part("Tier" .. i, container, {
            Size = Vector3.new(t.diameter, 0.8, t.diameter),
            Position = Vector3.new(0, t.y, 0),
            Material = t.material,
            Color = t.color,
            Transparency = t.transparency,
        })
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = tier
    end

    -- Cyan ring outline on top tier (decorative)
    local ring = part("RingAccent", container, {
        Size = Vector3.new(20, 0.2, 20),
        Position = Vector3.new(0, 2.7, 0),
        Material = Enum.Material.Neon,
        Color = CYAN,
        Transparency = 0.3,
        CanCollide = false,
    })
    do
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 0.6, 1)
        mesh.Parent = ring
    end

    -- Brand decal on the very top of the pedestal — players see this when
    -- they spawn and look down. SurfaceGui on the pink top tier with
    -- "STUDIO 88 / TYCOON" stacked text + neon accent ring inside the GUI.
    local topTier = container:FindFirstChild("Tier3")
    if topTier then
        local sg = Instance.new("SurfaceGui")
        sg.Adornee = topTier
        sg.Face = Enum.NormalId.Top
        sg.CanvasSize = Vector2.new(640, 640)
        sg.LightInfluence = 0
        sg.AlwaysOnTop = false
        sg.Parent = topTier

        -- Outer accent ring (rendered as 0px-stroke text for circular feel
        -- via UICorner trick — using an empty TextButton with UICorner)
        local outerRing = Instance.new("Frame")
        outerRing.Size = UDim2.new(0.9, 0, 0.9, 0)
        outerRing.Position = UDim2.new(0.05, 0, 0.05, 0)
        outerRing.BackgroundTransparency = 1
        outerRing.Parent = sg

        local stroke = Instance.new("UIStroke")
        stroke.Color = CYAN
        stroke.Thickness = 6
        stroke.Transparency = 0.2
        stroke.Parent = outerRing
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)  -- circle
        corner.Parent = outerRing

        -- Brand stacked text
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0.45, 0)
        title.Position = UDim2.new(0, 0, 0.15, 0)
        title.BackgroundTransparency = 1
        title.Text = "STUDIO 88"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextStrokeTransparency = 0
        title.TextStrokeColor3 = DARK
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.Rotation = -90  -- so it reads correctly when looking down at the pedestal
        title.Parent = sg

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, 0, 0.25, 0)
        sub.Position = UDim2.new(0, 0, 0.6, 0)
        sub.BackgroundTransparency = 1
        sub.Text = "TYCOON"
        sub.TextColor3 = CYAN
        sub.TextStrokeTransparency = 0.2
        sub.TextStrokeColor3 = DARK
        sub.Font = Enum.Font.Code
        sub.TextScaled = true
        sub.Rotation = -90
        sub.Parent = sg
    end

    -- Floating "TYCOON v1" rotating sign tower
    local pole = part("SignPole", container, {
        Size = Vector3.new(1, 14, 1),
        Position = Vector3.new(0, 9, 0),
        Material = Enum.Material.Metal,
        Color = STEEL,
    })
    local _ = pole

    local sign = part("Sign", container, {
        Size = Vector3.new(8, 3, 0.4),
        Position = Vector3.new(0, 16, 0),
        Material = Enum.Material.Neon,
        Color = PINK,
        Transparency = 0.05,
    })
    -- Rotating sign animation
    task.spawn(function()
        local angle = 0
        while sign.Parent do
            angle += 0.02
            sign.CFrame = CFrame.new(0, 16, 0) * CFrame.Angles(0, angle, 0)
            task.wait(0.05)
        end
    end)
    -- "STUDIO 88" + "TYCOON v1" text on both sides of the sign
    for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local sg = Instance.new("SurfaceGui")
        sg.Adornee = sign
        sg.Face = face
        sg.CanvasSize = Vector2.new(400, 150)
        sg.LightInfluence = 0
        sg.Parent = sign

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.Parent = sg

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0.65, 0)
        title.BackgroundTransparency = 1
        title.Text = "STUDIO 88"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextStrokeTransparency = 0.2
        title.TextStrokeColor3 = DARK
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.Parent = frame

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, 0, 0.35, 0)
        sub.Position = UDim2.new(0, 0, 0.65, 0)
        sub.BackgroundTransparency = 1
        sub.Text = "TYCOON v1"
        sub.TextColor3 = CYAN
        sub.TextStrokeTransparency = 0.3
        sub.TextStrokeColor3 = DARK
        sub.Font = Enum.Font.Code
        sub.TextScaled = true
        sub.Parent = frame
    end

    -- Sparkle drift around the sign
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(CYAN, PINK)
    pe.Speed = NumberRange.new(1, 3)
    pe.Lifetime = NumberRange.new(1.0, 2.0)
    pe.Rate = 12
    pe.SpreadAngle = Vector2.new(60, 60)
    pe.Acceleration = Vector3.new(0, 1, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1.2),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = sign

    -- Strong central light
    local pl = Instance.new("PointLight")
    pl.Brightness = 4
    pl.Range = 36
    pl.Color = PINK
    pl.Parent = sign

    -- Stairs: 4 cardinal-direction stair sets descending from pedestal top
    -- (y=2.6, the top tier surface) to the baseplate (y=0). 4 steps each,
    -- 0.65-stud rise per step, with cyan neon edge lighting.
    local stepHeight = 0.65
    local stepDepth = 1.6
    local stepWidth = 6
    local stepCount = 4
    local pedestalRadius = 11  -- top tier radius is 11 (diameter 22)
    for _, dir in ipairs({
        {x = 1, z = 0, rot = 0},     -- east
        {x = -1, z = 0, rot = 0},    -- west
        {x = 0, z = 1, rot = math.pi/2},     -- north
        {x = 0, z = -1, rot = math.pi/2},    -- south
    }) do
        for i = 1, stepCount do
            -- Each step descends as we move outward from the pedestal
            local outwardOffset = pedestalRadius + (i - 0.5) * stepDepth
            local stepY = 2.6 - (i - 0.5) * stepHeight
            local pos = Vector3.new(dir.x * outwardOffset, stepY, dir.z * outwardOffset)
            local sizeX = (dir.x ~= 0) and stepDepth or stepWidth
            local sizeZ = (dir.z ~= 0) and stepDepth or stepWidth
            part("Step", container, {
                Size = Vector3.new(sizeX, stepHeight, sizeZ),
                Position = pos,
                Material = Enum.Material.Metal,
                Color = STEEL,
            })
            -- Cyan neon edge strip on the leading edge of each step
            local edgeSizeX = (dir.x ~= 0) and 0.2 or stepWidth
            local edgeSizeZ = (dir.z ~= 0) and 0.2 or stepWidth
            local edgePos = Vector3.new(
                pos.X + dir.x * (sizeX/2 - 0.1),
                pos.Y + stepHeight/2 + 0.05,
                pos.Z + dir.z * (sizeZ/2 - 0.1)
            )
            part("StepEdge", container, {
                Size = Vector3.new(edgeSizeX, 0.1, edgeSizeZ),
                Position = edgePos,
                Material = Enum.Material.Neon,
                Color = CYAN,
                Transparency = 0.3,
                CanCollide = false,
            })
        end
    end

    -- 6 directional pillars at the lobby perimeter, each subtly indicating
    -- which way a plot anchor sits. Placed on the same 110-stud radius the
    -- plot anchors use, but at half-height with a small cap so they don't
    -- block the camera. Cyan tone so the eye reads them as wayfinding,
    -- not gameplay objects.
    local pillarRadius = 18  -- close to spawn so they're visible but not in the way
    for i = 1, 6 do
        local angle = math.rad((i - 1) * 60 - 90)
        local x = math.cos(angle) * pillarRadius
        local z = math.sin(angle) * pillarRadius

        local pillar = part("Pillar" .. i, container, {
            Size = Vector3.new(0.8, 6, 0.8),
            Position = Vector3.new(x, 5, z),
            Material = Enum.Material.Neon,
            Color = CYAN,
            Transparency = 0.2,
        })
        local _ = pillar

        local cap = part("PillarCap" .. i, container, {
            Size = Vector3.new(1.6, 0.5, 1.6),
            Position = Vector3.new(x, 8.3, z),
            Material = Enum.Material.Neon,
            Color = PINK,
            Transparency = 0.15,
        })
        local capMesh = Instance.new("CylinderMesh")
        capMesh.Scale = Vector3.new(1, 0.8, 1)
        capMesh.Parent = cap

        -- Small light at each pillar top
        local pcl = Instance.new("PointLight")
        pcl.Brightness = 1.2
        pcl.Range = 8
        pcl.Color = (i % 2 == 0) and PINK or CYAN
        pcl.Parent = cap
    end

    CollectionService:AddTag(container, "Studio88LobbyDecor")
    print("[LobbyDecor] built: 3-tier pedestal + rotating sign + 6 perimeter pillars")
end

return LobbyDecor
