--!strict
-- 3D coin model. Replaces the 1.2-stud neon sphere in Dropper.server.luau.
-- A flat cylindrical disc with bevelled glow, color-keyed to tier, slowly
-- self-rotating. Visually reads as "money" instead of "ball" within ~1
-- second of camera contact. CFrame-rotation is server-side (Anchored=false
-- so physics still pushes via conveyor belt).

local CollectionService = game:GetService("CollectionService")

local CYAN  = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK  = Color3.fromRGB(255, 46, 136)
local GOLD  = Color3.fromRGB(255, 215, 0)

local CoinModel = {}

local function colorForTier(tier: number): Color3
    if tier >= 5 then return GOLD
    elseif tier >= 4 then return PINK
    elseif tier >= 3 then return AMBER
    else return CYAN end
end

-- Build a coin disc: cylinder body, neon rim, inner face decal (a glowing
-- "$" symbol via TextLabel on a SurfaceGui rather than a Decal asset, so we
-- ship zero external dependencies). Returns the body Part with all visuals
-- parented to it. Caller sets Position, OwnerUserId attribute, Value attribute.
function CoinModel.build(tier: number): BasePart
    local color = colorForTier(tier)

    local coin = Instance.new("Part")
    coin.Name = "Studio88Coin"
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = Vector3.new(0.4, 2.0, 2.0)  -- thin disc, 2 studs across
    coin.Material = Enum.Material.Neon
    coin.Color = color
    coin.TopSurface = Enum.SurfaceType.Smooth
    coin.BottomSurface = Enum.SurfaceType.Smooth
    coin.CanCollide = true
    coin.CFrame = CFrame.Angles(0, 0, math.rad(90))  -- lay flat on conveyor

    -- Inner face: rim ring (slightly smaller cylinder, darker tone) so the
    -- eye reads "minted disc" not "single colour blob".
    local rim = Instance.new("Part")
    rim.Name = "Rim"
    rim.Shape = Enum.PartType.Cylinder
    rim.Size = Vector3.new(0.42, 1.5, 1.5)
    rim.Material = Enum.Material.SmoothPlastic
    rim.Color = Color3.fromRGB(
        math.clamp(math.floor(color.R * 255 * 0.4), 0, 255),
        math.clamp(math.floor(color.G * 255 * 0.4), 0, 255),
        math.clamp(math.floor(color.B * 255 * 0.4), 0, 255)
    )
    rim.CanCollide = false
    rim.CanQuery = false
    rim.CanTouch = false
    rim.Massless = true
    rim.CFrame = coin.CFrame
    rim.Anchored = false

    -- Weld rim to coin so they move together
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = coin
    weld.Part1 = rim
    weld.Parent = coin
    rim.Parent = coin

    -- Glowing "$" face. Two SurfaceGuis (one per cylinder face) so the icon
    -- shows from both sides as the coin tumbles.
    for _, face in ipairs({Enum.NormalId.Right, Enum.NormalId.Left}) do
        local sg = Instance.new("SurfaceGui")
        sg.Adornee = coin
        sg.Face = face
        sg.CanvasSize = Vector2.new(120, 120)
        sg.LightInfluence = 0
        sg.AlwaysOnTop = false
        sg.Parent = coin

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "$"
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0.2
        lbl.TextStrokeColor3 = Color3.fromRGB(20, 17, 31)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.Parent = sg
    end

    -- Subtle glow trail so the coin reads as moving even on low-end clients
    -- where conveyor velocity is barely visible.
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "Sparkle"
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(color)
    pe.Lifetime = NumberRange.new(0.3, 0.6)
    pe.Rate = 4
    pe.Speed = NumberRange.new(0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = coin

    CollectionService:AddTag(coin, "Studio88Coin")
    return coin
end

return CoinModel
