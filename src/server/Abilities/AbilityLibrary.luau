--!strict
-- Built-in ability definitions, one per class. Each entry is a complete
-- AbilitySpec; AbilityRuntime indexes into here when an AbilityRequest
-- arrives. Keep effects tight — gameplay-specific damage tunables come
-- from Constants where possible so balance changes don't require code.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local AbilitySpec = require(Modules:WaitForChild("AbilitySpec"))

local AbilityLibrary = {}

-- Striker / Dash: short-range forward burst. No damage; pure repositioning.
local function strikerDash(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    -- Velocity push along facing. Anchored chars can't be Velocity'd, so
    -- we use BodyVelocity briefly. (Anchored test irrelevant — players
    -- aren't anchored.)
    local push = hrp.CFrame.LookVector * 80
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Velocity = push
    bodyVel.MaxForce = Vector3.new(1e5, 0, 1e5)  -- horizontal only
    bodyVel.P = 1e4
    bodyVel.Parent = hrp
    task.delay(0.18, function()
        if bodyVel.Parent then bodyVel:Destroy() end
    end)
    return true
end

-- Bruiser / Ground Slam: AOE damage in a 12-stud radius around the caster.
local function bruiserGroundSlam(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    -- Build a one-shot OverlapParams sphere around the caster to hit
    -- everyone in range (using GetPartBoundsInBox with a wide cube as
    -- a cheap proxy for a sphere).
    local SLAM_RADIUS = 12
    local SLAM_DAMAGE = 22
    local origin = hrp.CFrame
    local size = Vector3.new(SLAM_RADIUS * 2, 8, SLAM_RADIUS * 2)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}
    params.MaxParts = 64

    local seen: {[Model]: true} = {}
    local parts = workspace:GetPartBoundsInBox(origin, size, params)
    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and not seen[model] then
            seen[model] = true
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid:TakeDamage(SLAM_DAMAGE)
            end
        end
    end

    -- Visible shockwave (purely cosmetic, replicates via Workspace).
    local shock = Instance.new("Part")
    shock.Anchored = true
    shock.CanCollide = false
    shock.Size = Vector3.new(2, 0.4, 2)
    shock.Color = Color3.fromRGB(255, 130, 60)
    shock.Material = Enum.Material.Neon
    shock.Transparency = 0.2
    shock.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2, 0))
    shock.Parent = workspace
    task.spawn(function()
        local TweenService = game:GetService("TweenService")
        TweenService:Create(shock, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {
            Size = Vector3.new(SLAM_RADIUS * 2, 0.4, SLAM_RADIUS * 2),
            Transparency = 1,
        }):Play()
        task.wait(0.5)
        shock:Destroy()
    end)
    return true
end

-- Swift / Double Jump: applies a single upward velocity boost while airborne.
local function swiftDoubleJump(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    -- Only allow while in air; on the ground a regular jump is the
    -- correct affordance.
    local state = humanoid:GetState()
    if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
        return false
    end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    -- Reset Y velocity then push up so the boost feels consistent
    -- regardless of when in the fall it's used.
    local current = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(current.X, 0, current.Z)
    hrp:ApplyImpulse(Vector3.new(0, hrp.AssemblyMass * 60, 0))
    return true
end

AbilityLibrary.SPECS = {
    {
        id = "striker_dash",
        displayName = "Dash",
        classId = "Striker",
        staminaCost = 30,
        cooldownSec = 4,
        blurb = "burst forward 80 studs/s for 0.18s",
        effect = strikerDash,
    },
    {
        id = "bruiser_ground_slam",
        displayName = "Ground Slam",
        classId = "Bruiser",
        staminaCost = 45,
        cooldownSec = 8,
        blurb = "AOE 22 dmg in 12-stud radius",
        effect = bruiserGroundSlam,
    },
    {
        id = "swift_double_jump",
        displayName = "Double Jump",
        classId = "Swift",
        staminaCost = 20,
        cooldownSec = 2,
        blurb = "mid-air upward boost",
        effect = swiftDoubleJump,
    },
} :: {AbilitySpec.AbilitySpec}

-- Index by id for O(1) lookup in AbilityRuntime.
AbilityLibrary.BY_ID = {} :: {[string]: AbilitySpec.AbilitySpec}
for _, spec in ipairs(AbilityLibrary.SPECS) do
    AbilityLibrary.BY_ID[spec.id] = spec
end

-- Index by classId so the client can show "what abilities does my class have?"
AbilityLibrary.BY_CLASS = {} :: {[string]: {AbilitySpec.AbilitySpec}}
for _, spec in ipairs(AbilityLibrary.SPECS) do
    local list = AbilityLibrary.BY_CLASS[spec.classId]
    if not list then
        list = {}
        AbilityLibrary.BY_CLASS[spec.classId] = list
    end
    table.insert(list, spec)
end

return AbilityLibrary
