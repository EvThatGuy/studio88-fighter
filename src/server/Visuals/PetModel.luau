--!strict
-- Procedural per-rarity pet model. Replaces the 2.5-stud neon cube
-- "badge" in PetStandService. Each rarity gets a distinct silhouette so
-- the eye instantly reads "this is a legendary" vs "this is a common"
-- from across the plot. Common = floating orb. Uncommon = body+head.
-- Rare = body+head+wings. Epic = + tail + glow aura. Legendary = +
-- horns + dual aura + pulsing light.
--
-- All parts are CanCollide=false / CanQuery=false / Massless=true so they
-- never interfere with player movement. Anchored=true and welded only
-- conceptually (CFrame-positioned per assembly).

local PetModel = {}

local function part(model: Model, name: string, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Massless = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = model
    return p
end

local function attachSparkle(parent: BasePart, color: Color3, rate: number, speed: number)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(color)
    pe.Speed = NumberRange.new(speed * 0.5, speed)
    pe.Lifetime = NumberRange.new(0.6, 1.2)
    pe.Rate = rate
    pe.SpreadAngle = Vector2.new(30, 30)
    pe.Acceleration = Vector3.new(0, 1, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = parent
end

-- Build a pet at world position `pos`, parented to `parent`, color-keyed
-- to the rarity. Returns the model. The PrimaryPart is set to the body so
-- callers can PivotTo the model around for animation.
function PetModel.build(rarity: string, color: Color3, pos: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "PetModel_" .. rarity

    -- Body: every rarity has a body. Size scales with rarity.
    local bodySizeByRarity = {
        common = 1.6, uncommon = 1.8, rare = 2.0, epic = 2.4, legendary = 2.8,
    }
    local bodyDiameter = bodySizeByRarity[rarity] or 1.6
    local body = part(model, "Body", {
        Size = Vector3.new(bodyDiameter, bodyDiameter, bodyDiameter),
        Position = pos,
        Material = Enum.Material.Neon,
        Color = color,
        Shape = Enum.PartType.Ball,
        Transparency = 0.1,
    })
    model.PrimaryPart = body

    -- Head: uncommon and above
    if rarity ~= "common" then
        part(model, "Head", {
            Size = Vector3.new(bodyDiameter * 0.7, bodyDiameter * 0.7, bodyDiameter * 0.7),
            Position = pos + Vector3.new(0, bodyDiameter * 0.85, 0),
            Material = Enum.Material.Neon,
            Color = color,
            Shape = Enum.PartType.Ball,
            Transparency = 0.05,
        })
        -- Two small "eyes" = darker dots
        local eyeColor = Color3.fromRGB(20, 17, 31)
        for _, sign in ipairs({-1, 1}) do
            part(model, "Eye", {
                Size = Vector3.new(0.25, 0.25, 0.25),
                Position = pos + Vector3.new(sign * bodyDiameter * 0.18, bodyDiameter * 0.95, bodyDiameter * 0.3),
                Material = Enum.Material.SmoothPlastic,
                Color = eyeColor,
                Shape = Enum.PartType.Ball,
            })
        end
    end

    -- Wings: rare and above
    if rarity == "rare" or rarity == "epic" or rarity == "legendary" then
        for _, sign in ipairs({-1, 1}) do
            part(model, "Wing", {
                Size = Vector3.new(0.2, bodyDiameter * 0.8, bodyDiameter * 1.1),
                Position = pos + Vector3.new(sign * bodyDiameter * 0.6, bodyDiameter * 0.2, 0),
                Material = Enum.Material.Neon,
                Color = color,
                Transparency = 0.3,
                CFrame = CFrame.new(pos + Vector3.new(sign * bodyDiameter * 0.6, bodyDiameter * 0.2, 0))
                    * CFrame.Angles(0, 0, math.rad(sign * 25)),
            })
        end
    end

    -- Tail: epic and above
    if rarity == "epic" or rarity == "legendary" then
        local prevPos = pos + Vector3.new(0, 0, -bodyDiameter * 0.8)
        for i = 1, 3 do
            local segSize = bodyDiameter * (0.5 - i * 0.08)
            part(model, "TailSeg" .. i, {
                Size = Vector3.new(segSize, segSize, segSize),
                Position = prevPos,
                Material = Enum.Material.Neon,
                Color = color,
                Shape = Enum.PartType.Ball,
                Transparency = 0.1 + i * 0.1,
            })
            prevPos = prevPos + Vector3.new(0, -bodyDiameter * 0.15, -bodyDiameter * 0.4)
        end
    end

    -- Horns: legendary only
    if rarity == "legendary" then
        for _, sign in ipairs({-1, 1}) do
            part(model, "Horn", {
                Size = Vector3.new(0.3, bodyDiameter * 0.8, 0.3),
                Position = pos + Vector3.new(sign * bodyDiameter * 0.25, bodyDiameter * 1.4, 0),
                Material = Enum.Material.Neon,
                Color = color,
                CFrame = CFrame.new(pos + Vector3.new(sign * bodyDiameter * 0.25, bodyDiameter * 1.4, 0))
                    * CFrame.Angles(0, 0, math.rad(sign * 15)),
            })
        end
    end

    -- Aura sphere (rare+) and pulsing light (epic+)
    if rarity == "rare" or rarity == "epic" or rarity == "legendary" then
        local aura = part(model, "Aura", {
            Size = Vector3.new(bodyDiameter * 1.8, bodyDiameter * 1.8, bodyDiameter * 1.8),
            Position = pos,
            Material = Enum.Material.ForceField,
            Color = color,
            Shape = Enum.PartType.Ball,
            Transparency = 0.7,
        })
        local _ = aura
    end

    -- Sparkle particles: scale rate by rarity
    local sparkleRateByRarity = {
        common = 2, uncommon = 3, rare = 5, epic = 8, legendary = 14,
    }
    local sparkleSpeedByRarity = {
        common = 0.5, uncommon = 0.8, rare = 1.2, epic = 1.6, legendary = 2.4,
    }
    attachSparkle(body, color,
        sparkleRateByRarity[rarity] or 2,
        sparkleSpeedByRarity[rarity] or 0.5)

    -- PointLight: epic and legendary
    if rarity == "epic" or rarity == "legendary" then
        local pl = Instance.new("PointLight")
        pl.Brightness = (rarity == "legendary") and 3 or 2
        pl.Range = (rarity == "legendary") and 12 or 8
        pl.Color = color
        pl.Parent = body
    end

    model.Parent = parent
    return model
end

return PetModel
