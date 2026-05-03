--!strict
-- Per-player plot assignment. On join: find a free anchor (tagged
-- Studio88PlotAnchor, no Owner attribute), clone the template into the
-- workspace at that anchor's CFrame, stamp Owner=userId on every tagged
-- part inside the plot so Dropper / Collector / UpgradeButton can resolve
-- which player they belong to.
--
-- Exports a small lookup so UpgradeStation can find the player's plot
-- model without re-walking the workspace each purchase.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local PlotAssigner = {}

local plotTemplate: Model? = nil
-- userId -> plot Model (cleared on PlayerRemoving)
local plotsByUserId: {[number]: Model} = {}

local function getTemplate(): Model
    -- WorldBuilder runs synchronously at script start, but it lives in a
    -- different server script which may not have loaded yet on first frame
    -- under Rojo. Yield until template exists.
    local templates = ServerStorage:WaitForChild("Studio88Templates", 30)
    assert(templates, "Studio88Templates folder never appeared")
    plotTemplate = templates:WaitForChild("Plot", 30) :: Model
    assert(plotTemplate, "Plot template never appeared")
    return plotTemplate :: Model
end

local function findFreeAnchor(): BasePart?
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:IsA("BasePart") and not anchor:GetAttribute("OwnerUserId") then
            return anchor
        end
    end
    return nil
end

local function stampOwner(plot: Model, userId: number)
    -- Tag every owned part so the gameplay scripts can resolve player
    plot:SetAttribute("OwnerUserId", userId)
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant:SetAttribute("OwnerUserId", userId)
        end
    end
end

local OBELISK_NAME = "ProsperityObelisk"

function PlotAssigner.applyTierArt(plot: Model, tier: number)
    -- Paint the foundation Material + Color to match the tier.
    -- Idempotent: caller can spam this, last write wins.
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local spec = Constants.TIER_PLOT_ART[tier] or Constants.TIER_PLOT_ART[1]
    foundation.Material = spec.material
    foundation.Color = spec.color
    plot:SetAttribute("CurrentTier", tier)
    -- Build / replace the prosperity obelisk: a vertical glowing pillar
    -- positioned on the foundation that grows + brightens per tier. Visible
    -- from far across the map; the visual carrot for tier-up.
    local obSpec = Constants.TIER_OBELISK[tier] or Constants.TIER_OBELISK[1]
    if obSpec then
        local existing = plot:FindFirstChild(OBELISK_NAME)
        if existing then existing:Destroy() end
        local obelisk = Instance.new("Part")
        obelisk.Name = OBELISK_NAME
        obelisk.Size = Vector3.new(obSpec.width, obSpec.height, obSpec.width)
        -- Sit on top of foundation: foundation top + half obelisk height
        local basePos = foundation.Position
            + Vector3.new(0, foundation.Size.Y / 2 + obSpec.height / 2, 0)
        obelisk.Position = basePos
        obelisk.Anchored = true
        obelisk.CanCollide = false
        obelisk.CanQuery = false
        obelisk.CanTouch = false
        obelisk.Material = Enum.Material.Neon
        obelisk.Color = obSpec.color
        obelisk.Transparency = 0.05
        obelisk.Parent = plot

        -- Gentle pulse: subtle Y-bob + transparency oscillation. No new
        -- particles or lights, pure server CFrame + property writes — zero
        -- perf cost beyond the existing 1/0.05s WorldBuilder budget. The
        -- bob amplitude scales with tier so capstone obelisks feel more
        -- alive than tier-1 ones.
        local bobAmp = 0.4 + (tier * 0.15)
        task.spawn(function()
            local t = 0
            while obelisk.Parent do
                t += 0.05
                local phase = math.sin(t * 1.6)  -- ~3.9s period
                obelisk.Position = basePos + Vector3.new(0, phase * bobAmp, 0)
                obelisk.Transparency = 0.05 + (phase + 1) * 0.06  -- 0.05 .. 0.17
                task.wait(0.05)
            end
        end)
    end
    -- Tier-keyed visual decor (border ring, corner posts, floor panels,
    -- spire, capstone particle ring). Additive — tier 6 includes 2-5.
    local TierPlotDecor = require(script.Parent:WaitForChild("Visuals"):WaitForChild("TierPlotDecor"))
    TierPlotDecor.build(plot, tier)
end

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

function PlotAssigner.updateStatsBoard(plot: Model, tier: number, lifetime: number)
    local board = plot:FindFirstChild("StatsBoard") :: BasePart?
    if not board then return end
    local sg = board:FindFirstChildWhichIsA("SurfaceGui")
    if not sg then return end
    local frame = sg:FindFirstChildWhichIsA("Frame")
    if not frame then return end
    local tierLbl = frame:FindFirstChild("Tier") :: TextLabel?
    local incomeLbl = frame:FindFirstChild("Income") :: TextLabel?
    local lifetimeLbl = frame:FindFirstChild("Lifetime") :: TextLabel?
    local tierSpec = Constants.UPGRADE_TIERS[tier] or Constants.UPGRADE_TIERS[1]
    local perSec = (Constants.BASE_INCOME_PER_TICK * tierSpec.incomeMult) / Constants.TICK_SECONDS
    if tierLbl then tierLbl.Text = "TIER " .. tier end
    if incomeLbl then incomeLbl.Text = string.format("+%s / sec", fmtCoins(math.floor(perSec))) end
    if lifetimeLbl then lifetimeLbl.Text = "lifetime: " .. fmtCoins(lifetime) end
end

function PlotAssigner.getPlotFor(userId: number): Model?
    return plotsByUserId[userId]
end

local function paintPlotName(plot: Model, player: Player)
    -- Find the Foundation and put the player's name floating over it
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local marker = Instance.new("Part")
    marker.Size = Vector3.new(0.1, 0.1, 0.1)
    marker.Position = foundation.Position + Vector3.new(0, 28, 0)
    marker.Anchored = true
    marker.Transparency = 1
    marker.CanCollide = false
    marker.Parent = plot

    local bg = Instance.new("BillboardGui")
    bg.Adornee = marker
    bg.Size = UDim2.new(0, 220, 0, 40)
    bg.AlwaysOnTop = true
    bg.Parent = marker

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = player.Name .. "'s plot"
    lbl.TextColor3 = Color3.fromRGB(248, 248, 242)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.TextScaled = true
    lbl.Parent = bg
end

-- Build the player-name welcome arch over the south walk-in gap. The
-- foundation is 50x50 centered at plot origin, walls have a 12-stud
-- middle gap, and the arch sits ~7 studs above the foundation with the
-- player's name on a SurfaceGui — reads like a real shop entrance.
local function buildWelcomeArch(plot: Model, player: Player)
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local fpos = foundation.Position
    local fsize = foundation.Size
    local existing = plot:FindFirstChild("WelcomeArch")
    if existing then existing:Destroy() end
    local arch = Instance.new("Folder")
    arch.Name = "WelcomeArch"
    arch.Parent = plot

    local function part(name: string, props: {[string]: any}): BasePart
        local p = Instance.new("Part")
        p.Name = name
        for k, v in pairs(props) do (p :: any)[k] = v end
        p.Anchored = true
        p.Locked = true
        p.CanCollide = false
        p.CanQuery = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = arch
        return p
    end

    -- South-facing arch over the walk-in gap (-Z edge of foundation)
    local edgeZ = -fsize.Z / 2
    local archHeight = 8
    local archWidth = 14   -- straddles the 12-stud gap with 1 stud overhang each side
    local pillarH = archHeight - 1.2
    local CYAN = Color3.fromRGB(0, 240, 255)
    local STEEL = Color3.fromRGB(60, 65, 78)
    local DARK = Color3.fromRGB(8, 7, 13)

    -- Two side pillars
    for _, signX in ipairs({-1, 1}) do
        part("ArchPillar", {
            Size = Vector3.new(0.8, pillarH, 0.8),
            Position = fpos + Vector3.new(signX * archWidth/2, fsize.Y/2 + pillarH/2, edgeZ),
            Material = Enum.Material.Metal,
            Color = STEEL,
        })
    end
    -- Cross beam on top
    local beam = part("ArchBeam", {
        Size = Vector3.new(archWidth + 1, 1.2, 1),
        Position = fpos + Vector3.new(0, fsize.Y/2 + pillarH + 0.6, edgeZ),
        Material = Enum.Material.Metal,
        Color = STEEL,
    })
    local _ = beam
    -- Cyan neon underglow on the beam
    part("ArchUnderglow", {
        Size = Vector3.new(archWidth, 0.2, 0.4),
        Position = fpos + Vector3.new(0, fsize.Y/2 + pillarH + 0.05, edgeZ - 0.1),
        Material = Enum.Material.Neon,
        Color = CYAN,
        Transparency = 0.2,
    })

    -- Sign with player name on the front face of the beam (looking south)
    local sg = Instance.new("SurfaceGui")
    sg.Adornee = beam
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(560, 60)
    sg.LightInfluence = 0
    sg.Parent = beam
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.upper(player.Name)
    lbl.TextColor3 = CYAN
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = DARK
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = sg
end

local function assign(player: Player)
    local template = plotTemplate or getTemplate()
    local anchor = findFreeAnchor()
    if not anchor then
        warn("[PlotAssigner] no free plot anchor for " .. player.Name .. "; server full?")
        return
    end
    anchor:SetAttribute("OwnerUserId", player.UserId)

    local clone = template:Clone()
    clone.Name = "Plot_" .. player.UserId
    -- Move whole model so foundation lands on the anchor's spot
    if clone.PrimaryPart then
        clone:PivotTo(CFrame.new(anchor.Position + Vector3.new(0, 0.5, 0))
            * CFrame.Angles(0, math.atan2(-anchor.Position.X, -anchor.Position.Z), 0))
    end
    clone.Parent = Workspace
    stampOwner(clone, player.UserId)
    paintPlotName(clone, player)
    buildWelcomeArch(clone, player)
    plotsByUserId[player.UserId] = clone

    -- Apply tier art at assignment so returning players land on the right
    -- foundation. Cached data is usually available; fall back to tier 1 if
    -- it isn't (the next upgrade will repaint).
    local data = DataStore.getCached(player.UserId)
    local tier = (data and data.upgradeTier) or 1
    local lifetime = (data and data.lifetimeCoins) or 0
    PlotAssigner.applyTierArt(clone, tier)
    PlotAssigner.updateStatsBoard(clone, tier, lifetime)

    -- FTUE step 1: plot assigned. Players who already past this step are
    -- no-op'd inside TutorialService.advance (highest-step-wins).
    TutorialService.advance(player.UserId, "01_arrived_at_plot")

    print(string.format("[PlotAssigner] %s -> plot index %s",
        player.Name, tostring(anchor:GetAttribute("PlotIndex"))))

    -- Teleport the player onto their plot so they land in front of the
    -- machines instead of stuck on the spawn platform. Both PivotTo +
    -- HumanoidRootPart.CFrame are written so whichever Roblox honours
    -- after its own spawn-positioning races ours wins. Re-applies on
    -- every CharacterAdded so respawns also land here.
    task.spawn(function()
        local foundation = clone:FindFirstChild("Foundation") :: BasePart?
        if not foundation then return end
        local landing = CFrame.new(foundation.Position + Vector3.new(0, 8, 0))

        local function teleport(char: Model)
            -- Wait until HRP exists and humanoid is alive, otherwise CFrame
            -- writes get clobbered by the spawn pipeline.
            local hrp: BasePart? = char:FindFirstChild("HumanoidRootPart") :: any
            local hum: Humanoid? = char:FindFirstChildOfClass("Humanoid")
            local deadline = os.clock() + 5
            while (not hrp or not hum) and os.clock() < deadline do
                task.wait(0.1)
                hrp = char:FindFirstChild("HumanoidRootPart") :: any
                hum = char:FindFirstChildOfClass("Humanoid")
            end
            if not hrp then return end
            local hrpPart: BasePart = hrp
            -- Settle so Roblox finishes its own spawn placement first.
            task.wait(1.0)
            char:PivotTo(landing)
            hrpPart.CFrame = landing
        end

        if player.Character then teleport(player.Character) end
        player.CharacterAdded:Connect(teleport)
    end)
end

local function release(player: Player)
    local userId = player.UserId
    -- Free the anchor
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:GetAttribute("OwnerUserId") == userId then
            anchor:SetAttribute("OwnerUserId", nil)
        end
    end
    -- Remove the plot model
    local plot = Workspace:FindFirstChild("Plot_" .. userId)
    if plot then plot:Destroy() end
    plotsByUserId[userId] = nil
end

-- Bootstrap: run after WorldBuilder has had a chance to populate
task.spawn(function()
    getTemplate()
    Players.PlayerAdded:Connect(assign)
    Players.PlayerRemoving:Connect(release)
    -- Catch any players who joined before this script connected
    for _, p in ipairs(Players:GetPlayers()) do assign(p) end
    print("[PlotAssigner] online")
end)

return PlotAssigner
