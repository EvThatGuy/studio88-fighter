--!strict
-- Training dummy NPCs. Builds a primitive humanoid rig (HRP + Head +
-- Torso + Humanoid) at fixed positions in the arena so a single client
-- can validate combat without needing a second player.
--
-- Dummies have:
--   - 200 HP (more than a player so you can punch a lot before respawn)
--   - No AI; they don't fight back
--   - Auto-respawn after 5s when killed
--   - Damage replicates through HitLanded → HitFx renders numbers
--   - HealthBars.client picks them up automatically (any character with
--     a Humanoid + Head shows a bar)

local Workspace = game:GetService("Workspace")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local DummyService = {}

local DUMMY_HEALTH = 200
local DUMMY_RESPAWN_SEC = 5
local DUMMY_FOLDER_NAME = "Studio88_Dummies"
local DUMMY_HRP_OFFSET_Y = 3      -- HRP center floats this high above ground

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local SURFACE = Color3.fromRGB(20, 17, 31)

-- Spawn positions chosen so dummies are visible from the SpawnA / SpawnB
-- spawn pads in the placeholder arena.
local DUMMY_SPAWNS = {
    {name = "DummyA", position = Vector3.new(0, DUMMY_HRP_OFFSET_Y, -30)},
    {name = "DummyB", position = Vector3.new(0, DUMMY_HRP_OFFSET_Y,  30)},
    {name = "DummyC", position = Vector3.new(30, DUMMY_HRP_OFFSET_Y, 0)},
}

local function ensureFolder(): Folder
    local existing = Workspace:FindFirstChild(DUMMY_FOLDER_NAME)
    if existing and existing:IsA("Folder") then return existing end
    local folder = Instance.new("Folder")
    folder.Name = DUMMY_FOLDER_NAME
    folder.Parent = Workspace
    return folder
end

local function buildRig(name: string, position: Vector3): Model
    local model = Instance.new("Model")
    model.Name = name

    -- HumanoidRootPart: invisible anchor, the OverlapParams query treats
    -- it like any other BasePart.
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Massless = true
    hrp.TopSurface = Enum.SurfaceType.Smooth
    hrp.BottomSurface = Enum.SurfaceType.Smooth
    hrp.Position = position
    hrp.Parent = model
    model.PrimaryPart = hrp

    -- Torso: visible body, inherits damage hits.
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = PINK
    torso.Material = Enum.Material.SmoothPlastic
    torso.TopSurface = Enum.SurfaceType.Smooth
    torso.BottomSurface = Enum.SurfaceType.Smooth
    torso.Position = position
    torso.Parent = model

    local torsoWeld = Instance.new("WeldConstraint")
    torsoWeld.Part0 = hrp
    torsoWeld.Part1 = torso
    torsoWeld.Parent = hrp

    -- Head: required by HealthBars.client + HitFx damage-number anchor.
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.2)
    head.Color = CYAN
    head.Material = Enum.Material.Neon
    head.TopSurface = Enum.SurfaceType.Smooth
    head.BottomSurface = Enum.SurfaceType.Smooth
    head.Position = position + Vector3.new(0, 1.6, 0)
    head.Parent = model

    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = torso

    -- Base / pedestal so the dummy appears to stand on the floor.
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(3, 0.5, 3)
    base.Color = SURFACE
    base.Material = Enum.Material.Slate
    base.Anchored = true
    base.TopSurface = Enum.SurfaceType.Smooth
    base.BottomSurface = Enum.SurfaceType.Smooth
    base.Position = position - Vector3.new(0, 1.5, 0)
    base.Parent = model

    -- Humanoid: drives Health + HealthChanged. We keep the rig anchored
    -- so it doesn't fall over when hit; this isn't a fight-back AI.
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = DUMMY_HEALTH
    humanoid.Health = DUMMY_HEALTH
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0
    humanoid.AutoRotate = false
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    humanoid.Parent = model

    -- Anchor the visible parts so the dummy holds position even when
    -- nudged by a punch's stun displacement.
    hrp.Anchored = true
    torso.Anchored = true
    head.Anchored = true

    -- Floating label so the user knows it's a dummy.
    local labelGui = Instance.new("BillboardGui")
    labelGui.Adornee = head
    labelGui.Size = UDim2.fromOffset(120, 24)
    labelGui.StudsOffset = Vector3.new(0, 4, 0)
    labelGui.AlwaysOnTop = true
    labelGui.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = CYAN
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.4
    label.TextSize = 14
    label.Text = "DUMMY"
    label.Parent = labelGui

    return model
end

local function spawnAt(folder: Folder, spec: {name: string, position: Vector3})
    local model = buildRig(spec.name, spec.position)
    model.Parent = folder
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.Died:Connect(function()
        task.wait(DUMMY_RESPAWN_SEC)
        if model.Parent then
            model:Destroy()
        end
        spawnAt(folder, spec)
    end)
end

-- Wait one frame so WorldBuilder.server.luau finishes constructing the
-- arena before we drop dummies into it; the arena rebuild also clears
-- spawning baseplates.
task.defer(function()
    -- Clean up any prior dummy folder (idempotent re-run after HotReload).
    local prior = Workspace:FindFirstChild(DUMMY_FOLDER_NAME)
    if prior then prior:Destroy() end
    local folder = ensureFolder()
    for _, spec in ipairs(DUMMY_SPAWNS) do
        spawnAt(folder, spec)
    end
    print(string.format("[DummyService] spawned %d training dummies", #DUMMY_SPAWNS))
end)

return DummyService
