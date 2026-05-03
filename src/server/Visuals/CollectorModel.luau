--!strict
-- Vault-door collector. Replaces the 8x4x8 pink neon cube tagged
-- Studio88Collector in WorldBuilder. A pedestal + circular vault door
-- with rotating handle + slot mouth that the conveyor coins fall into.
-- Preserves Studio88Collector tag on the catch part so Collector.server
-- Touched bindings stay live, AND keeps a CollectFX ParticleEmitter
-- inside named "CollectFX" so the existing FX-burst code finds it.

local CollectionService = game:GetService("CollectionService")

local PINK    = Color3.fromRGB(255, 46, 136)
local AMBER   = Color3.fromRGB(255, 176, 0)
local DARK    = Color3.fromRGB(8, 7, 13)
local STEEL   = Color3.fromRGB(60, 65, 78)
local SURFACE = Color3.fromRGB(20, 17, 31)

local CollectorModel = {}

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

function CollectorModel.build(pos: Vector3, parent: Instance): Model
    local model = Instance.new("Model")
    model.Name = "Collector"

    -- Pedestal base (the part that sits on the foundation)
    local pedestal = part("Pedestal", model, {
        Size = Vector3.new(8, 1.5, 8),
        Position = pos + Vector3.new(0, -1.25, 0),
        Material = Enum.Material.Metal,
        Color = STEEL,
    })
    local _ = pedestal

    -- Catch slot: thin invisible part under the conveyor end with the
    -- Studio88Collector tag — coins touch here and credit the owner.
    -- Slightly transparent pink to read as the active collection zone.
    local catch = part("Catch", model, {
        Size = Vector3.new(8, 4, 8),
        Position = pos,
        Material = Enum.Material.Neon,
        Color = PINK,
        Transparency = 0.5,
        CanCollide = true,
    })
    model.PrimaryPart = catch
    CollectionService:AddTag(catch, "Studio88Collector")

    -- Vault door: tall circular disc behind the catch, with a rotating
    -- handle and "VAULT" sign. Camera read: "money goes here, gets locked
    -- away in the vault."
    local doorBackplate = part("DoorBackplate", model, {
        Size = Vector3.new(0.6, 11, 11),
        Position = pos + Vector3.new(4.0, 4.5, 0),
        Material = Enum.Material.Metal,
        Color = DARK,
    })
    local _ = doorBackplate

    local door = part("Door", model, {
        Size = Vector3.new(0.8, 8, 8),
        Position = pos + Vector3.new(4.4, 4.5, 0),
        Material = Enum.Material.Metal,
        Color = STEEL,
    })
    do
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = door
    end

    -- Rotating handle (an X-shape made of two crossed bars) on the door
    local handle = part("Handle", model, {
        Size = Vector3.new(0.9, 0.6, 4),
        Position = pos + Vector3.new(4.85, 4.5, 0),
        Material = Enum.Material.Metal,
        Color = Color3.fromRGB(120, 100, 60),  -- brass
    })
    local handleCross = part("HandleCross", model, {
        Size = Vector3.new(0.9, 4, 0.6),
        Position = pos + Vector3.new(4.85, 4.5, 0),
        Material = Enum.Material.Metal,
        Color = Color3.fromRGB(120, 100, 60),
    })
    -- Slow handle rotation
    task.spawn(function()
        local angle = 0
        while handle.Parent do
            angle += 0.03
            handle.CFrame = CFrame.new(handle.Position) * CFrame.Angles(angle, 0, 0)
            handleCross.CFrame = CFrame.new(handleCross.Position) * CFrame.Angles(angle + math.pi/2, 0, 0)
            task.wait(0.05)
        end
    end)

    -- Glowing "VAULT" label above the door
    local labelHost = part("LabelHost", model, {
        Size = Vector3.new(0.1, 0.1, 0.1),
        Position = pos + Vector3.new(4.4, 11, 0),
        Transparency = 1,
        CanCollide = false,
    })
    local bb = Instance.new("BillboardGui")
    bb.Adornee = labelHost
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.AlwaysOnTop = true
    bb.Parent = labelHost
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "COLLECT"
    lbl.TextColor3 = AMBER
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = DARK
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = bb

    -- Backlight glow behind the door + amber light from above the slot
    local backLight = Instance.new("PointLight")
    backLight.Brightness = 2
    backLight.Range = 14
    backLight.Color = PINK
    backLight.Parent = catch

    local doorLight = Instance.new("SpotLight")
    doorLight.Brightness = 1.5
    doorLight.Range = 10
    doorLight.Angle = 70
    doorLight.Color = AMBER
    doorLight.Face = Enum.NormalId.Top
    doorLight.Parent = labelHost

    -- Pre-existing "CollectFX" ParticleEmitter that Collector.server.luau
    -- bursts on each collect. Kept inside the catch part so existing
    -- FindFirstChild("CollectFX") still resolves.
    local fx = Instance.new("ParticleEmitter")
    fx.Name = "CollectFX"
    fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    fx.LightEmission = 1
    fx.Color = ColorSequence.new(PINK)
    fx.Speed = NumberRange.new(0, 1)
    fx.Lifetime = NumberRange.new(0.6, 1.2)
    fx.Rate = 2
    fx.SpreadAngle = Vector2.new(30, 30)
    fx.Acceleration = Vector3.new(0, 4, 0)
    fx.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1.0),
    })
    fx.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    fx.Parent = catch

    -- Two side wall plates that frame the slot mouth, dark metal
    for _, side in ipairs({-3.5, 3.5}) do
        part("SideWall", model, {
            Size = Vector3.new(7, 5, 0.4),
            Position = pos + Vector3.new(0.5, 2.5, side),
            Material = Enum.Material.Metal,
            Color = SURFACE,
        })
    end

    model.Parent = parent
    return model
end

return CollectorModel
