--!strict
-- One-shot scene builder. Runs on game start; idempotent via a marker tag.
-- Builds:
--   * a 200x200 stud baseplate (sky-colored grid pattern) if missing
--   * a SpawnLocation in the center, neon-pink platform
--   * 6 evenly-spaced plot foundations around the spawn (4 active, 2 reserved)
--   * a Leaderboard sign tower north of spawn
--   * tutorial billboard with the rules
--
-- Per-plot contents are NOT built here; PlotAssigner clones a Plot template
-- on player join. The template is built here once.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))

local BUILD_MARKER_NAME = "Studio88Built"

local PINK = Color3.fromRGB(255, 46, 136)
local CYAN = Color3.fromRGB(0, 240, 255)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local AMBER = Color3.fromRGB(255, 176, 0)
local STEEL = Color3.fromRGB(60, 65, 78)

local function setProps(inst: Instance, props: {[string]: any})
    for k, v in pairs(props) do
        (inst :: any)[k] = v
    end
end

local function part(name: string, parent: Instance, props: {[string]: any}): Part
    local p = Instance.new("Part")
    p.Name = name
    setProps(p, props)
    p.Parent = parent
    return p
end

-- Built-in Roblox sparkle texture; ships with every client install. Falls
-- back invisible if asset is unavailable, so failure mode is "no FX" not crash.
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function makeParticle(parent: BasePart, props: {[string]: any}): ParticleEmitter
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = SPARKLE_TEXTURE
    pe.LightEmission = 1
    pe.Speed = NumberRange.new(0)
    pe.Lifetime = NumberRange.new(0.6, 1.2)
    pe.Rate = 4
    pe.Rotation = NumberRange.new(0, 360)
    pe.RotSpeed = NumberRange.new(-90, 90)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.8),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    setProps(pe, props)
    pe.Parent = parent
    return pe
end

-- --- Baseplate -------------------------------------------------------------

local function buildBaseplate(parent: Instance)
    -- Replace the default Baseplate (if any) with one tuned to the brand
    local existing = Workspace:FindFirstChild("Baseplate")
    if existing then existing:Destroy() end

    local base = Instance.new("Part")
    base.Name = "Baseplate"
    base.Size = Vector3.new(400, 4, 400)
    base.Position = Vector3.new(0, -2, 0)
    base.Anchored = true
    base.Material = Enum.Material.Concrete
    base.Color = DARK
    base.TopSurface = Enum.SurfaceType.Smooth
    base.BottomSurface = Enum.SurfaceType.Smooth
    base.Locked = true
    base.Parent = Workspace

    -- Pink seam grid as visual rhythm
    for x = -200, 200, 50 do
        local seam = part("Seam", Workspace, {
            Size = Vector3.new(0.4, 0.05, 400),
            Position = Vector3.new(x, 0.05, 0),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = PINK,
            CanCollide = false,
            Locked = true,
            Transparency = 0.6,
        })
    end
    for z = -200, 200, 50 do
        local seam = part("Seam", Workspace, {
            Size = Vector3.new(400, 0.05, 0.4),
            Position = Vector3.new(0, 0.05, z),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = PINK,
            CanCollide = false,
            Locked = true,
            Transparency = 0.6,
        })
    end
end

-- --- Spawn -----------------------------------------------------------------

local function buildSpawn()
    -- Remove default SpawnLocation
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("SpawnLocation") then child:Destroy() end
    end

    -- Invisible SpawnLocation under the lobby pedestal — players land on
    -- top of the 3-tier pillar created by LobbyDecor. Keep neutral so the
    -- physical SpawnLocation isn't visible (decor handles the reveal).
    local spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "Studio88Spawn"
    spawnPart.Size = Vector3.new(8, 1, 8)
    spawnPart.Position = Vector3.new(0, 3.6, 0)  -- on top of the pedestal's top tier
    spawnPart.Anchored = true
    spawnPart.Material = Enum.Material.SmoothPlastic
    spawnPart.Color = Color3.fromRGB(20, 17, 31)
    spawnPart.TopSurface = Enum.SurfaceType.Smooth
    spawnPart.BottomSurface = Enum.SurfaceType.Smooth
    spawnPart.Transparency = 1
    spawnPart.CanCollide = true
    spawnPart.Locked = true
    spawnPart.Parent = Workspace

    -- Decor: 3-tier pedestal + rotating sign + 6 perimeter pillars + lights
    local LobbyDecor = require(script.Parent:WaitForChild("Visuals"):WaitForChild("LobbyDecor"))
    LobbyDecor.build()
end

-- --- Plot template ---------------------------------------------------------
-- Built once into ServerStorage.Templates.Plot, cloned on player join.

local function buildPlotTemplate()
    local ServerStorage = game:GetService("ServerStorage")
    local templates = ServerStorage:FindFirstChild("Studio88Templates")
    if not templates then
        templates = Instance.new("Folder")
        templates.Name = "Studio88Templates"
        templates.Parent = ServerStorage
    end
    local existing = templates:FindFirstChild("Plot")
    if existing then existing:Destroy() end

    local plot = Instance.new("Model")
    plot.Name = "Plot"

    -- Foundation
    local foundation = part("Foundation", plot, {
        Size = Vector3.new(50, 1, 50),
        Position = Vector3.new(0, 0.5, 0),
        Anchored = true,
        Material = Enum.Material.SmoothPlastic,
        Color = SURFACE,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
        Locked = true,
    })
    plot.PrimaryPart = foundation

    -- Dropper -- emits coins. Use the procedural model (vending-machine
    -- chassis with glass front, marquee, output spout) instead of a bare
    -- cube. The model's Body part inherits the Studio88Dropper tag so the
    -- existing tag-driven Dropper.server.luau loop still finds it.
    local DropperModel = require(script.Parent:WaitForChild("Visuals"):WaitForChild("DropperModel"))
    local dropperModel = DropperModel.build(Vector3.new(-18, 5, 0), plot)
    local _ = dropperModel

    -- Spawn point for emitted coins (small invisible marker, just below
    -- the dropper's spout so coins exit there)
    local emitter = part("Emitter", plot, {
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(-15.5, 1.5, 0),
        Anchored = true,
        Transparency = 1,
        CanCollide = false,
    })
    emitter.Name = "Emitter"

    -- Collector -- vault-door receptacle. The Catch part inside the model
    -- carries the Studio88Collector tag + a CollectFX particle, so existing
    -- Collector.server.luau Touched bindings + FX:Emit() lookups still work.
    local CollectorModel = require(script.Parent:WaitForChild("Visuals"):WaitForChild("CollectorModel"))
    local collectorModel = CollectorModel.build(Vector3.new(18, 2, 0), plot)
    local _ = collectorModel

    -- Conveyor surface from dropper to collector (tilted slightly)
    local conveyor = part("Conveyor", plot, {
        Size = Vector3.new(36, 1, 4),
        Position = Vector3.new(0, 1.5, 0),
        Anchored = true,
        Material = Enum.Material.Metal,
        Color = DARK,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
        Locked = true,
    })
    -- Surface velocity to push coins along
    local belt = Instance.new("Vector3Value")
    belt.Name = "ConveyorVelocity"
    belt.Value = Vector3.new(8, 0, 0)
    belt.Parent = conveyor

    -- Animated belt texture on the top face. Built-in pattern, scrolls
    -- via OffsetStudsU tween so the eye reads "movement" matching the
    -- physical surface velocity. Uses rbxasset:// built-in chain pattern;
    -- if missing, falls back to invisible (no error).
    local beltTex = Instance.new("Texture")
    beltTex.Name = "BeltTex"
    beltTex.Texture = "rbxasset://textures/SurfacesDefault.png"
    beltTex.Color3 = Color3.fromRGB(60, 65, 78)
    beltTex.StudsPerTileU = 4
    beltTex.StudsPerTileV = 4
    beltTex.Face = Enum.NormalId.Top
    beltTex.Parent = conveyor
    -- Scroll offset loop: shift U coordinate to match velocity
    task.spawn(function()
        local offset = 0
        while beltTex.Parent do
            offset = (offset + 0.4) % 4
            beltTex.OffsetStudsU = -offset
            task.wait(0.05)
        end
    end)

    -- Cyan neon accent strips along the long edges, gives the belt a
    -- "track" feel and ties to brand colors
    for _, side in ipairs({-2.2, 2.2}) do
        local strip = part("BeltStrip", plot, {
            Size = Vector3.new(36, 0.2, 0.3),
            Position = Vector3.new(0, 2.05, side),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = Color3.fromRGB(0, 240, 255),
            Transparency = 0.3,
            CanCollide = false,
            Locked = true,
        })
        local _ = strip
    end

    -- Upgrade button (next-tier purchase). Use the arcade-button model:
    -- pedestal + dome with embedded ProximityPrompt. The Dome part is
    -- tagged Studio88UpgradeButton so existing tag-driven code resolves it.
    local UpgradeButtonModel = require(script.Parent:WaitForChild("Visuals"):WaitForChild("UpgradeButtonModel"))
    local upgradeBtn = UpgradeButtonModel.build(Vector3.new(0, 2, -16), plot)
    local _ = upgradeBtn

    -- Per-plot stats board: tier + income/sec, big and visible across the lot
    local board = part("StatsBoard", plot, {
        Size = Vector3.new(20, 8, 1),
        Position = Vector3.new(0, 12, -22),
        Anchored = true,
        Material = Enum.Material.SmoothPlastic,
        Color = SURFACE,
        Locked = true,
    })
    local boardSg = Instance.new("SurfaceGui")
    boardSg.Adornee = board
    boardSg.CanvasSize = Vector2.new(800, 320)
    boardSg.Face = Enum.NormalId.Front
    boardSg.AlwaysOnTop = false
    boardSg.Parent = board
    local boardFrame = Instance.new("Frame")
    boardFrame.Size = UDim2.new(1, 0, 1, 0)
    boardFrame.BackgroundColor3 = SURFACE
    boardFrame.BackgroundTransparency = 0.05
    boardFrame.BorderSizePixel = 0
    boardFrame.Parent = boardSg
    local boardTier = Instance.new("TextLabel")
    boardTier.Name = "Tier"
    boardTier.Size = UDim2.new(1, -32, 0, 110)
    boardTier.Position = UDim2.new(0, 16, 0, 16)
    boardTier.BackgroundTransparency = 1
    boardTier.Text = "TIER 1"
    boardTier.TextColor3 = PINK
    boardTier.Font = Enum.Font.GothamBold
    boardTier.TextScaled = true
    boardTier.TextXAlignment = Enum.TextXAlignment.Left
    boardTier.Parent = boardFrame
    local boardIncome = Instance.new("TextLabel")
    boardIncome.Name = "Income"
    boardIncome.Size = UDim2.new(1, -32, 0, 60)
    boardIncome.Position = UDim2.new(0, 16, 0, 130)
    boardIncome.BackgroundTransparency = 1
    boardIncome.Text = "+1 / sec"
    boardIncome.TextColor3 = CYAN
    boardIncome.Font = Enum.Font.Code
    boardIncome.TextScaled = true
    boardIncome.TextXAlignment = Enum.TextXAlignment.Left
    boardIncome.Parent = boardFrame
    local boardLifetime = Instance.new("TextLabel")
    boardLifetime.Name = "Lifetime"
    boardLifetime.Size = UDim2.new(1, -32, 0, 60)
    boardLifetime.Position = UDim2.new(0, 16, 0, 200)
    boardLifetime.BackgroundTransparency = 1
    boardLifetime.Text = "lifetime: 0"
    boardLifetime.TextColor3 = Color3.fromRGB(180, 180, 180)
    boardLifetime.Font = Enum.Font.Code
    boardLifetime.TextScaled = true
    boardLifetime.TextXAlignment = Enum.TextXAlignment.Left
    boardLifetime.Parent = boardFrame

    -- Floating label above the upgrade button
    local labelRoot = part("UpgradeLabelRoot", plot, {
        Size = Vector3.new(0.1, 0.1, 0.1),
        Position = Vector3.new(0, 6, -16),
        Anchored = true,
        Transparency = 1,
        CanCollide = false,
    })
    local lbBg = Instance.new("BillboardGui")
    lbBg.Adornee = labelRoot
    lbBg.Size = UDim2.new(0, 200, 0, 50)
    lbBg.AlwaysOnTop = true
    lbBg.Parent = labelRoot
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "UPGRADE"
    lbl.TextColor3 = AMBER
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = DARK
    lbl.TextScaled = true
    lbl.Name = "Label"
    lbl.Parent = lbBg

    -- Rebirth pad. Use the prestige portal model: glowing base pad with
    -- ascending light rings and central beam, visible across the plot as
    -- the endgame goal. The Pad child carries the Studio88RebirthPad tag
    -- and its ProximityPrompt is wired identically (Enabled=false until
    -- RebirthPadProxy enables it on eligibility).
    local RebirthPortalModel = require(script.Parent:WaitForChild("Visuals"):WaitForChild("RebirthPortalModel"))
    local rebirthPortal = RebirthPortalModel.build(Vector3.new(0, 1, 16), plot)
    local _ = rebirthPortal

    -- Floating label above the pad: "REBIRTH" / "Reach Tier N first" etc.
    local rebirthLabelRoot = part("RebirthLabelRoot", plot, {
        Size = Vector3.new(0.1, 0.1, 0.1),
        Position = Vector3.new(0, 5, 16),
        Anchored = true,
        Transparency = 1,
        CanCollide = false,
    })
    local rbBg = Instance.new("BillboardGui")
    rbBg.Adornee = rebirthLabelRoot
    rbBg.Size = UDim2.new(0, 220, 0, 50)
    rbBg.AlwaysOnTop = true
    rbBg.Parent = rebirthLabelRoot
    local rbLbl = Instance.new("TextLabel")
    rbLbl.Size = UDim2.new(1, 0, 1, 0)
    rbLbl.BackgroundTransparency = 1
    rbLbl.Text = "REBIRTH"
    rbLbl.TextColor3 = CYAN
    rbLbl.Font = Enum.Font.GothamBold
    rbLbl.TextStrokeTransparency = 0
    rbLbl.TextStrokeColor3 = DARK
    rbLbl.TextScaled = true
    rbLbl.Name = "Label"
    rbLbl.Parent = rbBg

    plot.Parent = templates
    print("[WorldBuilder] plot template ready in ServerStorage.Studio88Templates.Plot")
end

-- --- Plot ring -- 6 anchor points around spawn -----------------------------

local function buildPlotAnchors()
    local anchorsFolder = Workspace:FindFirstChild("Studio88PlotAnchors")
    if anchorsFolder then anchorsFolder:Destroy() end
    anchorsFolder = Instance.new("Folder")
    anchorsFolder.Name = "Studio88PlotAnchors"
    anchorsFolder.Parent = Workspace

    -- 6 plot positions around a 110-stud-radius ring
    local radius = 110
    for i = 1, 6 do
        local angle = math.rad((i - 1) * 60 - 90)  -- start north, clockwise
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius

        -- Hidden ground marker (carries the tag — PlotAssigner reads anchors
        -- via tag scan + position). Tiny + transparent so the visible
        -- "claim me" beacon below is the actual visual.
        local marker = part("Plot" .. i, anchorsFolder, {
            Size = Vector3.new(2, 0.5, 2),
            Position = Vector3.new(x, 0.25, z),
            Anchored = true,
            Material = Enum.Material.SmoothPlastic,
            Color = SURFACE,
            Transparency = 1,
            CanCollide = false,
            Locked = true,
        })
        CollectionService:AddTag(marker, "Studio88PlotAnchor")
        marker:SetAttribute("PlotIndex", i)

        -- Tall pillar beacon visible from across the lobby. Cyan neon
        -- 12-stud column with a glowing cap and upward sparkle so an
        -- unassigned plot reads as "claim me" from spawn pedestal view.
        local beacon = part("PlotBeacon" .. i, anchorsFolder, {
            Size = Vector3.new(1.4, 12, 1.4),
            Position = Vector3.new(x, 6, z),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = CYAN,
            Transparency = 0.25,
            CanCollide = false,
            Locked = true,
        })
        local cap = part("PlotBeaconCap" .. i, anchorsFolder, {
            Size = Vector3.new(2.5, 0.6, 2.5),
            Position = Vector3.new(x, 12.2, z),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = PINK,
            CanCollide = false,
            Locked = true,
        })
        do
            local mesh = Instance.new("CylinderMesh")
            mesh.Scale = Vector3.new(1, 0.5, 1)
            mesh.Parent = cap
        end
        local light = Instance.new("PointLight")
        light.Brightness = 1.5
        light.Range = 14
        light.Color = CYAN
        light.Parent = beacon
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.LightEmission = 1
        pe.Color = ColorSequence.new(CYAN, PINK)
        pe.Speed = NumberRange.new(2, 4)
        pe.Lifetime = NumberRange.new(1, 2)
        pe.Rate = 6
        pe.SpreadAngle = Vector2.new(20, 20)
        pe.Acceleration = Vector3.new(0, 4, 0)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 1.0),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Parent = beacon

        -- Wayfinding path strip from spawn (origin) to this plot anchor.
        -- Thin, low-profile, cyan neon — enough to lead the eye but not
        -- block movement. Path length = (radius - pedestal radius - 5).
        local pathLen = radius - 22
        local pathMidX = (x / radius) * (22 + pathLen / 2)
        local pathMidZ = (z / radius) * (22 + pathLen / 2)
        local pathPart = part("PathStrip" .. i, anchorsFolder, {
            Size = Vector3.new(1.5, 0.1, pathLen),
            Position = Vector3.new(pathMidX, 0.15, pathMidZ),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = CYAN,
            Transparency = 0.5,
            CanCollide = false,
            Locked = true,
        })
        -- Rotate path to point from spawn to plot
        pathPart.CFrame = CFrame.new(Vector3.new(pathMidX, 0.15, pathMidZ),
                                     Vector3.new(x, 0.15, z))

        -- Beacon visibility wired to anchor ownership: when a player
        -- claims this plot, hide the beacon + cap + particle. When they
        -- leave, restore them. The hidden marker carries OwnerUserId so
        -- we listen via GetAttributeChangedSignal.
        local function refreshBeacon()
            local owned = marker:GetAttribute("OwnerUserId") ~= nil
            beacon.Transparency = owned and 1 or 0.25
            cap.Transparency = owned and 1 or 0
            light.Enabled = not owned
            pe.Enabled = not owned
            pathPart.Transparency = owned and 1 or 0.5
        end
        marker:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshBeacon)
    end
end

-- --- Leaderboard sign ------------------------------------------------------

local function buildLeaderboardSign()
    local existing = Workspace:FindFirstChild("Studio88LeaderboardSign")
    if existing then existing:Destroy() end

    -- Twin support poles instead of one center pole — reads as a real
    -- arcade marquee structure rather than a popsicle stick
    local container = Instance.new("Folder")
    container.Name = "Studio88LeaderboardSign"
    container.Parent = Workspace

    for _, dx in ipairs({-9, 9}) do
        part("Pole", container, {
            Size = Vector3.new(1.5, 30, 1.5),
            Position = Vector3.new(dx, 15, -50),
            Anchored = true,
            Material = Enum.Material.Metal,
            Color = STEEL,
            Locked = true,
        })
    end

    -- Steel frame around the panel (top + bottom + sides)
    for _, frame in ipairs({
        {pos = Vector3.new(0, 36.6, -50), size = Vector3.new(22, 1.2, 1.2)},  -- top
        {pos = Vector3.new(0, 23.4, -50), size = Vector3.new(22, 1.2, 1.2)},  -- bottom
        {pos = Vector3.new(-10.5, 30, -50), size = Vector3.new(1, 14, 1.2)},   -- left
        {pos = Vector3.new( 10.5, 30, -50), size = Vector3.new(1, 14, 1.2)},   -- right
    }) do
        part("Frame", container, {
            Size = frame.size,
            Position = frame.pos,
            Anchored = true,
            Material = Enum.Material.Metal,
            Color = STEEL,
            Locked = true,
        })
    end

    -- Corner marquee bulbs (4 glowing balls at the panel corners)
    for _, corner in ipairs({
        Vector3.new(-10.5, 36.6, -50),
        Vector3.new( 10.5, 36.6, -50),
        Vector3.new(-10.5, 23.4, -50),
        Vector3.new( 10.5, 23.4, -50),
    }) do
        local bulb = part("MarqueeBulb", container, {
            Size = Vector3.new(1.6, 1.6, 1.6),
            Position = corner,
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = AMBER,
            Shape = Enum.PartType.Ball,
            Locked = true,
        })
        local pl = Instance.new("PointLight")
        pl.Brightness = 1.5
        pl.Range = 6
        pl.Color = AMBER
        pl.Parent = bulb
    end

    -- The actual sign panel (carries Studio88LeaderboardPanel tag for
    -- Leaderboard.server.luau to find + populate)
    local panel = part("Panel", container, {
        Size = Vector3.new(20, 12, 0.4),
        Position = Vector3.new(0, 30, -49.7),
        Anchored = true,
        Material = Enum.Material.SmoothPlastic,
        Color = SURFACE,
        Locked = true,
    })
    CollectionService:AddTag(panel, "Studio88LeaderboardPanel")

    -- Animated marquee scroll strip beneath the panel ("LIVE LEADERBOARD")
    local marquee = part("MarqueeStrip", container, {
        Size = Vector3.new(20, 1.6, 0.4),
        Position = Vector3.new(0, 22.4, -49.7),
        Anchored = true,
        Material = Enum.Material.Neon,
        Color = PINK,
        Locked = true,
    })
    local marqueeSg = Instance.new("SurfaceGui")
    marqueeSg.Adornee = marquee
    marqueeSg.Face = Enum.NormalId.Front
    marqueeSg.CanvasSize = Vector2.new(600, 60)
    marqueeSg.LightInfluence = 0
    marqueeSg.Parent = marquee
    local marqueeLbl = Instance.new("TextLabel")
    marqueeLbl.Size = UDim2.new(2, 0, 1, 0)  -- 2x width to allow scroll
    marqueeLbl.BackgroundTransparency = 1
    marqueeLbl.Text = "LIVE LEADERBOARD  ·  LIVE LEADERBOARD  ·  LIVE LEADERBOARD"
    marqueeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    marqueeLbl.TextStrokeTransparency = 0.2
    marqueeLbl.TextStrokeColor3 = DARK
    marqueeLbl.Font = Enum.Font.GothamBold
    marqueeLbl.TextScaled = true
    marqueeLbl.TextXAlignment = Enum.TextXAlignment.Left
    marqueeLbl.Parent = marqueeSg
    -- Scroll loop: shift label left, wrap at -50%
    task.spawn(function()
        local pos = 0
        while marqueeLbl.Parent do
            pos = pos - 0.005
            if pos <= -0.5 then pos = 0 end
            marqueeLbl.Position = UDim2.new(pos, 0, 0, 0)
            task.wait(0.05)
        end
    end)

    local sg = Instance.new("SurfaceGui")
    sg.Adornee = panel
    sg.CanvasSize = Vector2.new(800, 480)
    sg.Face = Enum.NormalId.Front
    sg.AlwaysOnTop = false
    sg.Parent = panel

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = SURFACE
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 60)
    title.Position = UDim2.new(0, 16, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "TOP 10 -- LIFETIME"
    title.TextColor3 = CYAN
    title.Font = Enum.Font.Code
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local rows = Instance.new("Frame")
    rows.Name = "Rows"
    rows.Size = UDim2.new(1, -32, 1, -90)
    rows.Position = UDim2.new(0, 16, 0, 80)
    rows.BackgroundTransparency = 1
    rows.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = rows

    print("[WorldBuilder] leaderboard sign placed at (0, 30, -50)")
end

-- --- Lighting --------------------------------------------------------------

local function tuneLighting()
    -- Daylight tycoon vibe: bright enough to show plot details, with a
    -- warm-tinted Atmosphere instead of opaque fog so distance reads as
    -- depth rather than wall.
    Lighting.Ambient = Color3.fromRGB(70, 65, 80)
    Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 155)
    Lighting.ClockTime = 14
    Lighting.GeographicLatitude = 30
    Lighting.Brightness = 2.5
    Lighting.GlobalShadows = true
    Lighting.EnvironmentDiffuseScale = 0.4
    Lighting.EnvironmentSpecularScale = 0.4
    -- Push fog way out — fog was the "trapped at dusk" feeling. Replace
    -- with Atmosphere haze for a realistic distance falloff.
    Lighting.FogColor = Color3.fromRGB(180, 175, 200)
    Lighting.FogStart = 500
    Lighting.FogEnd = 2500

    -- Atmosphere instance: subtle haze that scatters light, makes the
    -- baseplate edges feel like distance not abrupt cutoff. Replaces any
    -- existing one so re-runs are idempotent.
    local existingAtm = Lighting:FindFirstChildWhichIsA("Atmosphere")
    if existingAtm then existingAtm:Destroy() end
    local atm = Instance.new("Atmosphere")
    atm.Density = 0.3
    atm.Offset = 0.15
    atm.Color = Color3.fromRGB(199, 199, 220)
    atm.Decay = Color3.fromRGB(106, 112, 125)
    atm.Glare = 0.4
    atm.Haze = 1.2
    atm.Parent = Lighting

    -- Subtle vignette for cinematic framing without darkening gameplay
    local existingCC = Lighting:FindFirstChild("Studio88ColorCorrection")
    if existingCC then existingCC:Destroy() end
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "Studio88ColorCorrection"
    cc.Brightness = 0.02
    cc.Contrast = 0.08
    cc.Saturation = 0.12
    cc.TintColor = Color3.fromRGB(255, 248, 240)
    cc.Parent = Lighting

    -- Warm bloom on the neon sources (dropper core, rebirth beam, sign)
    local existingBloom = Lighting:FindFirstChild("Studio88Bloom")
    if existingBloom then existingBloom:Destroy() end
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "Studio88Bloom"
    bloom.Intensity = 0.6
    bloom.Size = 18
    bloom.Threshold = 1.0
    bloom.Parent = Lighting

    -- Custom skybox: brand-tinted color rather than the default Roblox
    -- blue. Use the built-in cubemap face textures with cyan-pink tinting
    -- via SunAngularSize + SkyboxColors via... hm Sky doesn't accept
    -- Color3 — it uses 6 face image assets. Ship with built-in
    -- rbxasset:// purple-night cubemap which works in any place.
    local existingSky = Lighting:FindFirstChildOfClass("Sky")
    if existingSky then existingSky:Destroy() end
    local sky = Instance.new("Sky")
    sky.Name = "Studio88Sky"
    -- Roblox built-in night skybox textures (ship in every client)
    sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
    sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
    sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
    sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
    sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
    sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
    sky.CelestialBodiesShown = true
    sky.SunAngularSize = 21
    sky.MoonAngularSize = 11
    sky.SunTextureId = "rbxasset://sky/sun.jpg"
    sky.MoonTextureId = "rbxasset://sky/moon.jpg"
    sky.StarCount = 3000
    sky.Parent = Lighting
end

-- --- Marker ---------------------------------------------------------------

local function alreadyBuilt(): boolean
    return Workspace:GetAttribute(BUILD_MARKER_NAME) == true
end

local function markBuilt()
    Workspace:SetAttribute(BUILD_MARKER_NAME, true)
end

-- --- Run ------------------------------------------------------------------

if alreadyBuilt() then
    print("[WorldBuilder] world already built (marker present); skipping")
    return
end

print("[WorldBuilder] constructing scene v1...")
buildBaseplate(Workspace)
buildSpawn()
buildPlotTemplate()
buildPlotAnchors()
buildLeaderboardSign()
tuneLighting()
markBuilt()
print("[WorldBuilder] scene complete -- 6 plot anchors + leaderboard + spawn")
