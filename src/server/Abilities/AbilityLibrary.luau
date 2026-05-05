--!strict
-- Built-in ability definitions, one per class. Each entry is a complete
-- AbilitySpec; AbilityRuntime indexes into here when an AbilityRequest
-- arrives. Keep effects tight — gameplay-specific damage tunables come
-- from Constants where possible so balance changes don't require code.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local AbilitySpec = require(Modules:WaitForChild("AbilitySpec"))
local Constants = require(Modules:WaitForChild("Constants"))

-- CombatService exposes the modifier setters (setParry / setIronSkin /
-- setIFrames) that the slot-2 abilities mutate. We require it here, not
-- in each effect function, so the dependency is explicit.
local CombatService = require(script.Parent.Parent:WaitForChild("Combat"):WaitForChild("CombatService"))

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

-- Striker / Counter Stance (Slot 2): opens a brief parry window. Any
-- incoming hit during the window does 0 damage AND counter-stuns the
-- attacker for PARRY_ATTACKER_STUN_SEC. Single-use — first hit consumes.
local function strikerCounterStance(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    CombatService.setParry(player.UserId, Constants.PARRY_WINDOW_SEC)

    -- Visual: brief cyan ring at the feet so the parry window is readable.
    local ring = Instance.new("Part")
    ring.Anchored = true
    ring.CanCollide = false
    ring.Size = Vector3.new(6, 0.2, 6)
    ring.Color = Color3.fromRGB(0, 240, 255)
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.3
    ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0))
    ring.Parent = workspace
    task.spawn(function()
        local TweenService = game:GetService("TweenService")
        TweenService:Create(ring, TweenInfo.new(Constants.PARRY_WINDOW_SEC, Enum.EasingStyle.Quad), {
            Size = Vector3.new(10, 0.2, 10),
            Transparency = 1,
        }):Play()
        task.wait(Constants.PARRY_WINDOW_SEC + 0.1)
        ring:Destroy()
    end)
    return true
end

-- Bruiser / Iron Skin (Slot 2): IRON_SKIN_DURATION_SEC of damage
-- reduction (multiplier IRON_SKIN_REDUCTION). Stacks with block.
local function bruiserIronSkin(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    CombatService.setIronSkin(player.UserId, Constants.IRON_SKIN_DURATION_SEC)

    -- Visual: amber pulse under the caster while the buff is up. We
    -- recreate the part at apply time and tween it to fade over the
    -- buff duration so the player can see when it's about to drop.
    local pulse = Instance.new("Part")
    pulse.Anchored = true
    pulse.CanCollide = false
    pulse.Size = Vector3.new(5, 0.2, 5)
    pulse.Color = Color3.fromRGB(255, 176, 0)
    pulse.Material = Enum.Material.Neon
    pulse.Transparency = 0.2
    pulse.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0))
    pulse.Parent = workspace
    -- Track the caster's HRP so the pulse follows. WeldConstraint to HRP.
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = pulse
    weld.Part1 = hrp
    weld.Parent = pulse
    pulse.Anchored = false
    task.spawn(function()
        local TweenService = game:GetService("TweenService")
        TweenService:Create(pulse, TweenInfo.new(Constants.IRON_SKIN_DURATION_SEC, Enum.EasingStyle.Linear), {
            Transparency = 1,
        }):Play()
        task.wait(Constants.IRON_SKIN_DURATION_SEC + 0.1)
        pulse:Destroy()
    end)
    return true
end

-- Swift / Wind Step (Slot 2): translate HRP forward WIND_STEP_DISTANCE
-- studs in the facing direction with a brief WIND_STEP_IFRAME_SEC of
-- iframes so the dash also dodges incoming hits.
local function swiftWindStep(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end
    local forward = hrp.CFrame.LookVector
    local destination = hrp.Position + forward * Constants.WIND_STEP_DISTANCE
    -- Preserve orientation; only translate.
    hrp.CFrame = CFrame.new(destination, destination + forward)
    CombatService.setIFrames(player.UserId, Constants.WIND_STEP_IFRAME_SEC)

    -- Visual: a translucent pink streak from origin to destination.
    local streak = Instance.new("Part")
    streak.Anchored = true
    streak.CanCollide = false
    streak.Material = Enum.Material.Neon
    streak.Color = Color3.fromRGB(255, 46, 136)
    streak.Transparency = 0.4
    local mid = (hrp.Position + destination) * 0.5
    streak.Size = Vector3.new(0.6, 0.6, Constants.WIND_STEP_DISTANCE)
    streak.CFrame = CFrame.new(mid, mid + forward)
    streak.Parent = workspace
    task.spawn(function()
        local TweenService = game:GetService("TweenService")
        TweenService:Create(streak, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Transparency = 1,
        }):Play()
        task.wait(0.35)
        streak:Destroy()
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
    -- Striker
    {
        id = "striker_dash",
        displayName = "Dash",
        classId = "striker",
        staminaCost = 30,
        cooldownSec = 4,
        blurb = "burst forward 80 studs/s for 0.18s",
        effect = strikerDash,
    },
    {
        id = "striker_counter_stance",
        displayName = "Counter Stance",
        classId = "striker",
        staminaCost = 35,
        cooldownSec = 6,
        blurb = "0.5s parry window — incoming hit stuns attacker 1.2s",
        effect = strikerCounterStance,
    },
    -- Bruiser
    {
        id = "bruiser_ground_slam",
        displayName = "Ground Slam",
        classId = "bruiser",
        staminaCost = 45,
        cooldownSec = 8,
        blurb = "AOE 22 dmg in 12-stud radius",
        effect = bruiserGroundSlam,
    },
    {
        id = "bruiser_iron_skin",
        displayName = "Iron Skin",
        classId = "bruiser",
        staminaCost = 40,
        cooldownSec = 12,
        blurb = "3s buff: incoming damage halved",
        effect = bruiserIronSkin,
    },
    -- Swift
    {
        id = "swift_double_jump",
        displayName = "Double Jump",
        classId = "swift",
        staminaCost = 20,
        cooldownSec = 2,
        blurb = "mid-air upward boost",
        effect = swiftDoubleJump,
    },
    {
        id = "swift_wind_step",
        displayName = "Wind Step",
        classId = "swift",
        staminaCost = 25,
        cooldownSec = 5,
        blurb = "teleport 14 studs forward + 0.25s i-frames",
        effect = swiftWindStep,
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
