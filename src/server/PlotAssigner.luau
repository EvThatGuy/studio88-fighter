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
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local remotes = Remotes.get()

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
    -- Detect a real tier change (vs initial paint on assignment) — only
    -- flash when CurrentTier is set and changed.
    local prevTier = plot:GetAttribute("CurrentTier")
    foundation.Material = spec.material
    foundation.Color = spec.color
    plot:SetAttribute("CurrentTier", tier)
    -- Tier-up flash: briefly switch foundation to Neon before settling
    -- back to the tier material. 0.6s pulse, color stays the tier color
    -- so eye reads "your plot just leveled up".
    if prevTier and prevTier ~= tier then
        local origMaterial = spec.material
        foundation.Material = Enum.Material.Neon
        task.delay(0.6, function()
            if foundation.Parent then
                foundation.Material = origMaterial
            end
        end)
    end
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

    -- Update tier badge on the welcome arch (if present)
    local arch = plot:FindFirstChild("WelcomeArch")
    if arch then
        local beam = arch:FindFirstChild("ArchBeam") :: BasePart?
        if beam then
            local sg = beam:FindFirstChildWhichIsA("SurfaceGui")
            if sg then
                local tierLbl = sg:FindFirstChild("TierLabel") :: TextLabel?
                if tierLbl then
                    tierLbl.Text = "TIER " .. tier
                end
            end
        end
    end
end

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

-- Per-board state for income count-up animation. Keyed by board part so
-- multiple plots can animate independently without state collision.
local incomeAnimState: {[BasePart]: number} = {}

-- Per-userId rolling income samples (last 30 seconds, 1 sample/sec).
-- Collector pushes a sample on every collect; chart loop draws.
local incomeSamples: {[number]: {number}} = {}
local CHART_WINDOW = 30  -- seconds

-- Called by Collector on every coin collect to feed the chart
function PlotAssigner.recordIncomeSample(userId: number, value: number)
    local list = incomeSamples[userId]
    if not list then
        list = {}
        incomeSamples[userId] = list
    end
    table.insert(list, value)
    if #list > CHART_WINDOW then
        table.remove(list, 1)
    end
end

local function buildChart(frame: Frame)
    local chart = frame:FindFirstChild("IncomeChart") :: Frame?
    if chart then return chart end
    chart = Instance.new("Frame")
    chart.Name = "IncomeChart"
    chart.Size = UDim2.new(1, -32, 0, 56)
    chart.Position = UDim2.new(0, 16, 1, -72)
    chart.AnchorPoint = Vector2.new(0, 0)
    chart.BackgroundColor3 = Color3.fromRGB(8, 7, 13)
    chart.BackgroundTransparency = 0.4
    chart.BorderSizePixel = 0
    chart.Parent = frame
    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 6)
    cor.Parent = chart
    -- 30 dots laid out in a horizontal strip
    for i = 1, CHART_WINDOW do
        local dot = Instance.new("Frame")
        dot.Name = "ChartDot" .. i
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.AnchorPoint = Vector2.new(0.5, 1)
        dot.Position = UDim2.new((i - 1) / (CHART_WINDOW - 1), 0, 1, -4)
        dot.BackgroundColor3 = Color3.fromRGB(0, 240, 255)
        dot.BackgroundTransparency = 0.15
        dot.BorderSizePixel = 0
        dot.Parent = chart
        local dotCor = Instance.new("UICorner")
        dotCor.CornerRadius = UDim.new(0.5, 0)
        dotCor.Parent = dot
    end
    return chart
end

-- Chart loop: redraws every 2s for every player's plot
task.spawn(function()
    while true do
        task.wait(2)
        for userId, samples in pairs(incomeSamples) do
            local plot = plotsByUserId[userId]
            if not plot then continue end
            local board = plot:FindFirstChild("StatsBoard") :: BasePart?
            if not board then continue end
            local sg = board:FindFirstChildWhichIsA("SurfaceGui")
            if not sg then continue end
            local frame = sg:FindFirstChildWhichIsA("Frame")
            if not frame then continue end
            local chart = buildChart(frame)
            -- Compute peak in window for normalization
            local peak = 1
            for _, v in ipairs(samples) do
                if v > peak then peak = v end
            end
            -- Update each dot height by sample value (most recent on the right)
            local n = #samples
            for i = 1, CHART_WINDOW do
                local dot = chart:FindFirstChild("ChartDot" .. i) :: Frame?
                if not dot then continue end
                -- Map dot index to sample index (most recent right-aligned)
                local sampleIdx = n - (CHART_WINDOW - i)
                if sampleIdx >= 1 and sampleIdx <= n then
                    local v = samples[sampleIdx]
                    local frac = v / peak
                    local height = 6 + frac * 38  -- 6..44 px tall column
                    dot.Size = UDim2.new(0, 6, 0, height)
                    dot.BackgroundTransparency = 0.15
                else
                    dot.Size = UDim2.new(0, 4, 0, 4)
                    dot.BackgroundTransparency = 0.65
                end
            end
        end
    end
end)

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
    -- Animate income count-up from previous to new perSec value over 1s.
    -- First call snaps to value (no anim).
    if incomeLbl then
        local prev = incomeAnimState[board]
        if prev == nil or prev == perSec then
            incomeLbl.Text = string.format("+%s / sec", fmtCoins(math.floor(perSec)))
            incomeAnimState[board] = perSec
        else
            local from = prev
            local to = perSec
            incomeAnimState[board] = perSec
            task.spawn(function()
                local startT = os.clock()
                while os.clock() - startT < 1.0 do
                    if not incomeLbl.Parent or incomeAnimState[board] ~= to then return end
                    local t = (os.clock() - startT) / 1.0
                    local eased = 1 - (1 - t) * (1 - t)  -- ease-out quad
                    local v = from + (to - from) * eased
                    incomeLbl.Text = string.format("+%s / sec", fmtCoins(math.floor(v)))
                    task.wait(0.05)
                end
                if incomeLbl.Parent then
                    incomeLbl.Text = string.format("+%s / sec", fmtCoins(math.floor(to)))
                end
            end)
        end
    end
    if lifetimeLbl then lifetimeLbl.Text = "lifetime: " .. fmtCoins(lifetime) end

    -- Tier rank pips: ●●○○○○ visual badge so the eye reads tier without
    -- having to parse the text. 6 dots, filled to current tier. Built once
    -- on first call (lazy) and updated on each call.
    local pipsRoot = frame:FindFirstChild("TierPips") :: Frame?
    if not pipsRoot then
        pipsRoot = Instance.new("Frame")
        pipsRoot.Name = "TierPips"
        pipsRoot.Size = UDim2.new(0, 200, 0, 18)
        pipsRoot.Position = UDim2.new(0, 16, 0, 130)
        pipsRoot.BackgroundTransparency = 1
        pipsRoot.Parent = frame
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = pipsRoot
        for i = 1, #Constants.UPGRADE_TIERS do
            local pip = Instance.new("Frame")
            pip.Name = "Pip" .. i
            pip.Size = UDim2.new(0, 16, 0, 16)
            pip.LayoutOrder = i
            pip.BorderSizePixel = 0
            pip.Parent = pipsRoot
            local cor = Instance.new("UICorner")
            cor.CornerRadius = UDim.new(0.5, 0)
            cor.Parent = pip
        end
        -- Push existing labels down to make room for the pip row
        if incomeLbl then incomeLbl.Position = UDim2.new(0, 16, 0, 156) end
        if lifetimeLbl then lifetimeLbl.Position = UDim2.new(0, 16, 0, 226) end
    end
    -- Color pips: filled = tier color (use TIER_OBELISK color), empty = grey
    local pipFilledColor = (Constants.TIER_OBELISK[tier] and Constants.TIER_OBELISK[tier].color) or Color3.fromRGB(255, 46, 136)
    local pipEmptyColor = Color3.fromRGB(60, 65, 78)
    for i = 1, #Constants.UPGRADE_TIERS do
        local pip = pipsRoot:FindFirstChild("Pip" .. i) :: Frame?
        if pip then
            pip.BackgroundColor3 = (i <= tier) and pipFilledColor or pipEmptyColor
            pip.BackgroundTransparency = (i <= tier) and 0 or 0.4
        end
    end
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

-- Welcome mat: cyan plate just inside the south walk-in gap with player
-- name + tier on the top face. Players step onto it as they enter their
-- plot — personalizes the entry.
local function buildWelcomeMat(plot: Model, player: Player)
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local fpos = foundation.Position
    local fsize = foundation.Size
    local existing = plot:FindFirstChild("WelcomeMat")
    if existing then existing:Destroy() end

    local CYAN = Color3.fromRGB(0, 240, 255)
    local DARK = Color3.fromRGB(8, 7, 13)

    local mat = Instance.new("Part")
    mat.Name = "WelcomeMat"
    mat.Size = Vector3.new(8, 0.2, 4)
    mat.Position = fpos + Vector3.new(0, fsize.Y / 2 + 0.1, -fsize.Z / 2 + 4)
    mat.Anchored = true
    mat.Locked = true
    mat.CanCollide = false
    mat.CanQuery = false
    mat.Material = Enum.Material.Neon
    mat.Color = CYAN
    mat.Transparency = 0.4
    mat.TopSurface = Enum.SurfaceType.Smooth
    mat.BottomSurface = Enum.SurfaceType.Smooth
    mat.Parent = plot

    local sg = Instance.new("SurfaceGui")
    sg.Adornee = mat
    sg.Face = Enum.NormalId.Top
    sg.CanvasSize = Vector2.new(400, 200)
    sg.LightInfluence = 0
    sg.Parent = mat

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
    nameLbl.Position = UDim2.new(0, 0, 0.1, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = string.upper(player.Name)
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0.2
    nameLbl.TextStrokeColor3 = DARK
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextScaled = true
    nameLbl.Parent = sg

    local subLbl = Instance.new("TextLabel")
    subLbl.Name = "MatTagline"
    subLbl.Size = UDim2.new(1, 0, 0.3, 0)
    subLbl.Position = UDim2.new(0, 0, 0.65, 0)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "WELCOME"
    subLbl.TextColor3 = DARK
    subLbl.TextStrokeTransparency = 0.6
    subLbl.Font = Enum.Font.Code
    subLbl.TextScaled = true
    subLbl.Parent = sg
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

    -- Sign with player name + tier on the front face of the beam.
    -- Layout: TIER X (small, top) over PLAYERNAME (large, bottom).
    -- The tier label is named "TierLabel" so applyTierArt can find +
    -- update it on tier-up without rebuilding the whole arch.
    local sg = Instance.new("SurfaceGui")
    sg.Adornee = beam
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(560, 80)
    sg.LightInfluence = 0
    sg.Parent = beam
    local tierLbl = Instance.new("TextLabel")
    tierLbl.Name = "TierLabel"
    tierLbl.Size = UDim2.new(1, 0, 0.35, 0)
    tierLbl.Position = UDim2.new(0, 0, 0, 0)
    tierLbl.BackgroundTransparency = 1
    tierLbl.Text = "TIER 1"
    tierLbl.TextColor3 = Color3.fromRGB(255, 176, 0)  -- amber to read as "rank"
    tierLbl.TextStrokeTransparency = 0.3
    tierLbl.TextStrokeColor3 = DARK
    tierLbl.Font = Enum.Font.Code
    tierLbl.TextScaled = true
    tierLbl.Parent = sg
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0.65, 0)
    lbl.Position = UDim2.new(0, 0, 0.35, 0)
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
    buildWelcomeMat(clone, player)
    plotsByUserId[player.UserId] = clone

    -- Apply tier art at assignment so returning players land on the right
    -- foundation. Cached data is usually available; fall back to tier 1 if
    -- it isn't (the next upgrade will repaint).
    local data = DataStore.getCached(player.UserId)
    local tier = (data and data.upgradeTier) or 1
    local lifetime = (data and data.lifetimeCoins) or 0
    PlotAssigner.applyTierArt(clone, tier)
    PlotAssigner.updateStatsBoard(clone, tier, lifetime)

    -- Welcome banner: brief 3s flash showing the player's tier + lifetime
    -- coins so returning players see "your progress is intact" right after
    -- spawn. Sent via dedicated remote; client-side renderer fades in/out.
    pcall(function()
        local rebirths = (data and data.rebirths) or 0
        remotes.WelcomeBanner:FireClient(player, {
            playerName = player.Name,
            tier = tier,
            lifetimeCoins = lifetime,
            rebirths = rebirths,
            isReturning = (data and data.streakDay or 0) > 1 or rebirths > 0 or lifetime > 0,
        })
    end)

    -- Spatial join chime at the spawn position so the join has audio +
    -- visual feedback. Played from the foundation so other players hear
    -- it from the relevant spot rather than across the map.
    pcall(function()
        local AmbientAudio = require(script.Parent:WaitForChild("AmbientAudio"))
        local foundation = clone:FindFirstChild("Foundation") :: BasePart?
        if foundation then
            AmbientAudio.playSpatial("purchase", foundation, 0.25, 1.3)
        end
    end)

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
