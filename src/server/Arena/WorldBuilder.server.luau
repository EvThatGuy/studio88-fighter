--!strict
-- Constructs a placeholder arena at server start. Idempotent — re-running
-- (e.g. via HotReload) is a no-op once the marker is present. Phase 2
-- replaces this with authored maps cloned from ServerStorage by
-- MapRotation.

local Workspace = game:GetService("Workspace")

local MARKER_NAME = "Studio88_PlaceholderArena"

if Workspace:FindFirstChild(MARKER_NAME) then
    return
end

local arena = Instance.new("Folder")
arena.Name = MARKER_NAME
arena.Parent = Workspace

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): BasePart
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.Position = position
    part.Color = color
    part.Material = material
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = arena
    return part
end

-- Floor: 200×200, dark concrete with neon-pink seam
local FLOOR_COLOR = Color3.fromRGB(28, 22, 40)
local SEAM_COLOR = Color3.fromRGB(255, 46, 136)

makePart(
    "Floor",
    Vector3.new(200, 2, 200),
    Vector3.new(0, 0, 0),
    FLOOR_COLOR,
    Enum.Material.Concrete
)

-- Center accent: thin neon pink cross
makePart(
    "SeamX",
    Vector3.new(200, 0.3, 1),
    Vector3.new(0, 1.05, 0),
    SEAM_COLOR,
    Enum.Material.Neon
)
makePart(
    "SeamZ",
    Vector3.new(1, 0.3, 200),
    Vector3.new(0, 1.05, 0),
    SEAM_COLOR,
    Enum.Material.Neon
)

-- Walls: 4 sides, 16 studs tall, dark slate
local WALL_COLOR = Color3.fromRGB(20, 17, 31)
local WALL_HEIGHT = 16
local WALL_THICKNESS = 2
local HALF = 100

makePart("WallN", Vector3.new(200 + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, -HALF - WALL_THICKNESS / 2),
    WALL_COLOR, Enum.Material.Slate)
makePart("WallS", Vector3.new(200 + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS),
    Vector3.new(0, WALL_HEIGHT / 2 + 1, HALF + WALL_THICKNESS / 2),
    WALL_COLOR, Enum.Material.Slate)
makePart("WallE", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 200),
    Vector3.new(HALF + WALL_THICKNESS / 2, WALL_HEIGHT / 2 + 1, 0),
    WALL_COLOR, Enum.Material.Slate)
makePart("WallW", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, 200),
    Vector3.new(-HALF - WALL_THICKNESS / 2, WALL_HEIGHT / 2 + 1, 0),
    WALL_COLOR, Enum.Material.Slate)

-- Two opposing SpawnLocations so two players land apart by default
local function makeSpawn(name: string, position: Vector3)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = name
    spawn.Anchored = true
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = position
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Material = Enum.Material.Neon
    spawn.Color = Color3.fromRGB(0, 240, 255)
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Parent = arena
end

makeSpawn("SpawnA", Vector3.new(-60, 1.5, 0))
makeSpawn("SpawnB", Vector3.new(60, 1.5, 0))

-- Remove the default Baseplate / SpawnLocation Roblox creates with new
-- Baseplate templates so they don't fight with our spawns.
for _, child in ipairs(Workspace:GetChildren()) do
    if child.Name == "Baseplate" and child:IsA("BasePart") then
        child:Destroy()
    elseif child.Name == "SpawnLocation" and child:IsA("BasePart") then
        child:Destroy()
    end
end

print("[WorldBuilder] placeholder arena built (200×200 with two spawns)")
