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

    local spawnPart = Instance.new("SpawnLocation")
    spawnPart.Name = "Studio88Spawn"
    spawnPart.Size = Vector3.new(20, 1, 20)
    spawnPart.Position = Vector3.new(0, 0.5, 0)
    spawnPart.Anchored = true
    spawnPart.Material = Enum.Material.Neon
    spawnPart.Color = PINK
    spawnPart.TopSurface = Enum.SurfaceType.Smooth
    spawnPart.BottomSurface = Enum.SurfaceType.Smooth
    spawnPart.Transparency = 0.2
    spawnPart.Locked = true
    spawnPart.Parent = Workspace

    -- "STUDIO 88" billboard floating above
    local billboard = part("BrandTotem", Workspace, {
        Size = Vector3.new(0.1, 0.1, 0.1),
        Position = Vector3.new(0, 12, 0),
        Anchored = true,
        Transparency = 1,
        CanCollide = false,
        Locked = true,
    })
    local bg = Instance.new("BillboardGui")
    bg.Adornee = billboard
    bg.Size = UDim2.new(0, 280, 0, 80)
    bg.AlwaysOnTop = true
    bg.Parent = billboard

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.6, 0)
    title.BackgroundTransparency = 1
    title.Text = "STUDIO 88"
    title.TextColor3 = PINK
    title.Font = Enum.Font.GothamBold
    title.TextStrokeTransparency = 0
    title.TextStrokeColor3 = DARK
    title.TextScaled = true
    title.Parent = bg

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0.4, 0)
    subtitle.Position = UDim2.new(0, 0, 0.6, 0)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "TYCOON v1"
    subtitle.TextColor3 = CYAN
    subtitle.Font = Enum.Font.Code
    subtitle.TextScaled = true
    subtitle.Parent = bg
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

    -- Dropper -- emits coins
    local dropper = part("Dropper", plot, {
        Size = Vector3.new(6, 8, 6),
        Position = Vector3.new(-18, 5, 0),
        Anchored = true,
        Material = Enum.Material.Neon,
        Color = CYAN,
        Locked = true,
    })
    CollectionService:AddTag(dropper, "Studio88Dropper")

    -- Spawn point for emitted coins (small marker invisible)
    local emitter = part("Emitter", plot, {
        Size = Vector3.new(1, 1, 1),
        Position = Vector3.new(-18, 9, 0),
        Anchored = true,
        Transparency = 1,
        CanCollide = false,
    })
    emitter.Name = "Emitter"

    -- Collector -- coins touch this, grant balance, despawn
    local collector = part("Collector", plot, {
        Size = Vector3.new(8, 4, 8),
        Position = Vector3.new(18, 2, 0),
        Anchored = true,
        Material = Enum.Material.Neon,
        Color = PINK,
        Transparency = 0.3,
        Locked = true,
    })
    CollectionService:AddTag(collector, "Studio88Collector")

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

    -- Upgrade button (next-tier purchase)
    local btn = part("UpgradeButton", plot, {
        Size = Vector3.new(4, 4, 4),
        Position = Vector3.new(0, 2, -16),
        Anchored = true,
        Material = Enum.Material.Neon,
        Color = AMBER,
        Locked = true,
    })
    CollectionService:AddTag(btn, "Studio88UpgradeButton")

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "UpgradePrompt"
    prompt.ActionText = "Upgrade"
    prompt.ObjectText = "Studio 88 Tier"
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 8
    prompt.Parent = btn

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
        local marker = part("Plot" .. i, anchorsFolder, {
            Size = Vector3.new(2, 0.5, 2),
            Position = Vector3.new(x, 0.25, z),
            Anchored = true,
            Material = Enum.Material.Neon,
            Color = CYAN,
            Transparency = 0.4,
            CanCollide = false,
            Locked = true,
        })
        CollectionService:AddTag(marker, "Studio88PlotAnchor")
        marker:SetAttribute("PlotIndex", i)
    end
end

-- --- Leaderboard sign ------------------------------------------------------

local function buildLeaderboardSign()
    local existing = Workspace:FindFirstChild("Studio88LeaderboardSign")
    if existing then existing:Destroy() end

    local pole = part("Studio88LeaderboardSign", Workspace, {
        Size = Vector3.new(2, 30, 2),
        Position = Vector3.new(0, 15, -50),
        Anchored = true,
        Material = Enum.Material.Metal,
        Color = DARK,
        Locked = true,
    })

    local panel = part("Panel", pole, {
        Size = Vector3.new(20, 12, 1),
        Position = Vector3.new(0, 30, -50),
        Anchored = true,
        Material = Enum.Material.SmoothPlastic,
        Color = SURFACE,
        Locked = true,
    })
    CollectionService:AddTag(panel, "Studio88LeaderboardPanel")

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
    Lighting.Ambient = Color3.fromRGB(8, 5, 13)
    Lighting.OutdoorAmbient = Color3.fromRGB(28, 18, 40)
    Lighting.ClockTime = 19.5
    Lighting.FogColor = Color3.fromRGB(38, 13, 51)
    Lighting.FogStart = 100
    Lighting.FogEnd = 600
    Lighting.Brightness = 1.5
    Lighting.GlobalShadows = true
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
