--!strict
-- Vending-machine style dropper. Replaces the 6x8x6 cyan neon cube in
-- WorldBuilder.server.luau:buildPlotTemplate(). A welded model: tall
-- narrow chassis with cyan outline, glowing inner core, output spout at
-- bottom, marquee label across the top. Tagged Studio88Dropper so existing
-- Dropper.server.luau loop finds it without changes.

local CollectionService = game:GetService("CollectionService")

local CYAN    = Color3.fromRGB(0, 240, 255)
local PINK    = Color3.fromRGB(255, 46, 136)
local DARK    = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local STEEL   = Color3.fromRGB(60, 65, 78)

local DropperModel = {}

local function part(name: string, parent: Instance, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.Locked = true
    p.Parent = parent
    return p
end

-- Build a dropper at world position `pos`. Parents the assembled Model to
-- `parent`. Returns the model so caller can attach attributes. The collision
-- root (`Body`) is tagged Studio88Dropper so existing tag-driven systems
-- pick it up. Foundation/back-compat: previous code used a single Part
-- tagged Studio88Dropper; the model exposes a child also tagged so anything
-- searching by the tag still finds it whether iterating models or parts.
function DropperModel.build(pos: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "Dropper"

    -- Main chassis: tall dark box, the silhouette
    local chassis = part("Body", model, {
        Size = Vector3.new(6, 10, 6),
        Position = pos,
        Material = Enum.Material.SmoothPlastic,
        Color = SURFACE,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
    })
    model.PrimaryPart = chassis
    CollectionService:AddTag(chassis, "Studio88Dropper")

    -- Inner glowing core: visible through glass front, "the thing producing"
    local core = part("Core", model, {
        Size = Vector3.new(2.5, 6, 2.5),
        Position = pos + Vector3.new(0, -0.5, 0),
        Material = Enum.Material.Neon,
        Color = CYAN,
        Transparency = 0.15,
    })

    -- Glass front panel so the core glows through
    local glass = part("Glass", model, {
        Size = Vector3.new(0.2, 7, 5),
        Position = pos + Vector3.new(3.0, 0, 0),
        Material = Enum.Material.Glass,
        Color = Color3.fromRGB(180, 220, 255),
        Transparency = 0.6,
        Reflectance = 0.3,
    })

    -- Steel rim around glass face
    for _, side in ipairs({
        {name="RimT", size=Vector3.new(0.3, 0.4, 6),  off=Vector3.new(3.0, 3.7, 0)},
        {name="RimB", size=Vector3.new(0.3, 0.4, 6),  off=Vector3.new(3.0, -3.7, 0)},
        {name="RimL", size=Vector3.new(0.3, 7,   0.4), off=Vector3.new(3.0, 0, 2.8)},
        {name="RimR", size=Vector3.new(0.3, 7,   0.4), off=Vector3.new(3.0, 0, -2.8)},
    }) do
        part(side.name, model, {
            Size = side.size,
            Position = pos + side.off,
            Material = Enum.Material.Metal,
            Color = STEEL,
        })
    end

    -- Marquee header: pink neon strip across the top with brand text
    local marquee = part("Marquee", model, {
        Size = Vector3.new(6.2, 1.4, 6.2),
        Position = pos + Vector3.new(0, 5.7, 0),
        Material = Enum.Material.Neon,
        Color = PINK,
    })
    local marqueeSg = Instance.new("SurfaceGui")
    marqueeSg.Adornee = marquee
    marqueeSg.Face = Enum.NormalId.Front
    marqueeSg.CanvasSize = Vector2.new(400, 80)
    marqueeSg.LightInfluence = 0
    marqueeSg.Parent = marquee
    local marqueeLbl = Instance.new("TextLabel")
    marqueeLbl.Size = UDim2.new(1, 0, 1, 0)
    marqueeLbl.BackgroundTransparency = 1
    marqueeLbl.Text = "STUDIO 88"
    marqueeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    marqueeLbl.TextStrokeTransparency = 0.2
    marqueeLbl.TextStrokeColor3 = DARK
    marqueeLbl.Font = Enum.Font.GothamBold
    marqueeLbl.TextScaled = true
    marqueeLbl.Parent = marqueeSg

    -- Output spout at bottom-front, where coins emerge
    local spout = part("Spout", model, {
        Size = Vector3.new(1.5, 1.2, 3),
        Position = pos + Vector3.new(2.5, -3.5, 0),
        Material = Enum.Material.Metal,
        Color = STEEL,
    })

    -- Slow particle drift at the spout, telling the eye "this thing produces"
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(CYAN, PINK)
    pe.Speed = NumberRange.new(0.5, 1.5)
    pe.Lifetime = NumberRange.new(0.6, 1.2)
    pe.Rate = 8
    pe.SpreadAngle = Vector2.new(15, 15)
    pe.Acceleration = Vector3.new(0, -2, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = spout

    -- Inner light so the core glow casts on the surrounding plot floor
    local pl = Instance.new("PointLight")
    pl.Brightness = 2
    pl.Range = 14
    pl.Color = CYAN
    pl.Parent = core

    model.Parent = parent
    return model
end

return DropperModel
