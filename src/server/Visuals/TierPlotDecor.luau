--!strict
-- Per-tier plot decor. PlotAssigner.applyTierArt repaints the foundation
-- but a tier-6 plot then looks identical to a tier-1 plot except for
-- color. Players can't tell from camera distance whether they've made
-- progress, which kills the visible-prestige loop.
--
-- This module adds tier-keyed overlays on top of the foundation:
--   Tier 1 = no extra (raw concrete)
--   Tier 2 = cyan border ring around the foundation perimeter
--   Tier 3 = + 4 corner accent posts
--   Tier 4 = + glowing floor panels (rectangular grid pattern)
--   Tier 5 = + holographic central spire
--   Tier 6 = + swirling particle ring (capstone "i made it" flex)
--
-- Each tier's decor is ADDITIVE — applying tier 5 includes everything
-- from tiers 2-4. Caller (PlotAssigner.applyTierArt) calls clear()
-- first then build(plot, tier).

local TierPlotDecor = {}

local DECOR_NAME = "Studio88TierDecor"

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local AMBER = Color3.fromRGB(255, 176, 0)
local WHITE = Color3.fromRGB(255, 255, 255)

local function makePart(folder: Instance, name: string, props: {[string]: any}): BasePart
    local p = Instance.new("Part")
    p.Name = name
    for k, v in pairs(props) do (p :: any)[k] = v end
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Locked = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = folder
    return p
end

function TierPlotDecor.clear(plot: Model)
    local existing = plot:FindFirstChild(DECOR_NAME)
    if existing then existing:Destroy() end
end

function TierPlotDecor.build(plot: Model, tier: number)
    TierPlotDecor.clear(plot)
    if tier <= 1 then return end

    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end

    local folder = Instance.new("Folder")
    folder.Name = DECOR_NAME
    folder.Parent = plot

    local fpos = foundation.Position
    local fsize = foundation.Size  -- 50x1x50

    -- Tier 2+: cyan border ring around the foundation perimeter
    if tier >= 2 then
        local stripWidth = 0.4
        local stripHeight = 0.3
        for _, side in ipairs({
            {pos = fpos + Vector3.new(0, fsize.Y/2 + stripHeight/2,  fsize.Z/2 - stripWidth/2),
             size = Vector3.new(fsize.X, stripHeight, stripWidth)},
            {pos = fpos + Vector3.new(0, fsize.Y/2 + stripHeight/2, -fsize.Z/2 + stripWidth/2),
             size = Vector3.new(fsize.X, stripHeight, stripWidth)},
            {pos = fpos + Vector3.new( fsize.X/2 - stripWidth/2, fsize.Y/2 + stripHeight/2, 0),
             size = Vector3.new(stripWidth, stripHeight, fsize.Z)},
            {pos = fpos + Vector3.new(-fsize.X/2 + stripWidth/2, fsize.Y/2 + stripHeight/2, 0),
             size = Vector3.new(stripWidth, stripHeight, fsize.Z)},
        }) do
            makePart(folder, "BorderStrip", {
                Size = side.size,
                Position = side.pos,
                Material = Enum.Material.Neon,
                Color = CYAN,
                Transparency = 0.2,
            })
        end
    end

    -- Tier 3+: 4 corner accent posts
    if tier >= 3 then
        local postH = 4
        local postW = 0.6
        for _, corner in ipairs({
            Vector3.new( fsize.X/2 - 1, fsize.Y/2 + postH/2,  fsize.Z/2 - 1),
            Vector3.new(-fsize.X/2 + 1, fsize.Y/2 + postH/2,  fsize.Z/2 - 1),
            Vector3.new( fsize.X/2 - 1, fsize.Y/2 + postH/2, -fsize.Z/2 + 1),
            Vector3.new(-fsize.X/2 + 1, fsize.Y/2 + postH/2, -fsize.Z/2 + 1),
        }) do
            local post = makePart(folder, "CornerPost", {
                Size = Vector3.new(postW, postH, postW),
                Position = fpos + corner,
                Material = Enum.Material.Neon,
                Color = (tier >= 5) and AMBER or CYAN,
                Transparency = 0.15,
            })
            local pl = Instance.new("PointLight")
            pl.Brightness = 1.5
            pl.Range = 8
            pl.Color = post.Color
            pl.Parent = post
        end
    end

    -- Tier 4+: glowing floor grid panels (4 rectangular strips on top)
    if tier >= 4 then
        local panelInsetX = 8
        local panelInsetZ = 8
        local panelSizeX = (fsize.X - 2 * panelInsetX) / 2 - 0.5
        local panelSizeZ = (fsize.Z - 2 * panelInsetZ) / 2 - 0.5
        for _, signs in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do
            local sx, sz = signs[1], signs[2]
            local px = (panelInsetX + panelSizeX/2) * sx
            local pz = (panelInsetZ + panelSizeZ/2) * sz
            makePart(folder, "FloorPanel", {
                Size = Vector3.new(panelSizeX, 0.1, panelSizeZ),
                Position = fpos + Vector3.new(px, fsize.Y/2 + 0.05, pz),
                Material = Enum.Material.Neon,
                Color = (tier >= 5) and PINK or CYAN,
                Transparency = 0.4,
            })
        end
    end

    -- Tier 5+: holographic central spire (vertical bands + light)
    if tier >= 5 then
        local spire = makePart(folder, "Spire", {
            Size = Vector3.new(2.5, 12, 2.5),
            Position = fpos + Vector3.new(0, fsize.Y/2 + 6, 0),
            Material = Enum.Material.ForceField,
            Color = (tier >= 6) and WHITE or AMBER,
            Transparency = 0.4,
        })
        local mesh = Instance.new("CylinderMesh")
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = spire
        local pl = Instance.new("PointLight")
        pl.Brightness = 2.5
        pl.Range = 18
        pl.Color = (tier >= 6) and PINK or AMBER
        pl.Parent = spire
    end

    -- Tier 6: capstone swirling particle ring around the foundation
    if tier >= 6 then
        local ringHost = makePart(folder, "CapstoneRingHost", {
            Size = Vector3.new(0.1, 0.1, 0.1),
            Position = fpos + Vector3.new(0, fsize.Y/2 + 0.5, 0),
            Transparency = 1,
        })
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.LightEmission = 1
        pe.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, PINK),
            ColorSequenceKeypoint.new(0.5, AMBER),
            ColorSequenceKeypoint.new(1, WHITE),
        })
        pe.Speed = NumberRange.new(8, 14)
        pe.Lifetime = NumberRange.new(2.0, 3.5)
        pe.Rate = 50
        pe.SpreadAngle = Vector2.new(180, 0)  -- 360 horizontal swirl
        pe.Acceleration = Vector3.new(0, 1, 0)
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.5, 1.2),
            NumberSequenceKeypoint.new(1, 0.4),
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        })
        pe.Parent = ringHost
    end
end

return TierPlotDecor
