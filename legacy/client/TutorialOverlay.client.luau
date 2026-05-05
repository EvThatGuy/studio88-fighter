--!strict
-- FTUE overlay. Renders a single contextual BillboardGui tooltip pointing
-- to the next action a new player should take. Driven by TutorialService
-- on the server: server pushes TutorialStepReached when the player
-- crosses a step, client renders the tooltip for the NEXT step (or hides
-- the overlay if the tutorial is complete).
--
-- We keep this as a separate client script (not embedded in HUD) so the
-- tutorial can be modular and skipped/reset without touching HUD logic.
-- Per the research-engineer brief: total tutorial time should be <90s
-- (DevForum consensus that long tutorials kill D1 worse than no tutorial),
-- so all 5 steps complete naturally inside the first minute of play.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = Remotes.waitFor(15)

local CYAN    = Color3.fromRGB(0, 240, 255)
local AMBER   = Color3.fromRGB(255, 176, 0)
local SURFACE = Color3.fromRGB(20, 17, 31)
local DARK    = Color3.fromRGB(8, 7, 13)
local TEXT    = Color3.fromRGB(248, 248, 242)

-- Step copy. Index = step number (1..#FTUE_STEPS). Each entry tells the
-- player WHAT TO DO NEXT (not what they just completed). Anchor is the
-- target part on the player's plot the tooltip floats above.
type StepInfo = { headline: string, body: string, anchor: string }
local STEP_COPY: {StepInfo} = {
    {  -- step 1 advances when player joins, so copy 1 prompts the action that triggers step 2
        headline = "WELCOME TO STUDIO 88",
        body = "this is your plot - watch the dropper",
        anchor = "Dropper",
    },
    {
        headline = "COINS DROP HERE",
        body = "they ride the conveyor to the collector",
        anchor = "Collector",
    },
    {
        headline = "WALK INTO THE COLLECTOR",
        body = "to bank the coins onto your balance",
        anchor = "Collector",
    },
    {
        headline = "BUY YOUR FIRST UPGRADE",
        body = "press E on the orange button - costs 250 coins",
        anchor = "UpgradeButton",
    },
    {
        headline = "REACH 100K LIFETIME",
        body = "stand on the cyan rebirth pad - perma-mult unlocks",
        anchor = "RebirthPad",
    },
}

-- ---- Overlay UI ----------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "Studio88Tutorial"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

-- A single floating BillboardGui adornment that follows whatever target
-- part is current. We re-parent it as the step changes (cheaper than
-- destroy/recreate per step).
local tooltipRoot: BillboardGui? = nil
local headlineLbl: TextLabel? = nil
local bodyLbl: TextLabel? = nil

local function buildTooltip()
    local root = Instance.new("BillboardGui")
    root.Name = "TutorialTooltip"
    root.Size = UDim2.new(0, 320, 0, 90)
    root.AlwaysOnTop = true
    root.StudsOffset = Vector3.new(0, 6, 0)
    root.Parent = screen

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = SURFACE
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = root

    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = panel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = panel

    -- Top accent strip (amber) for visual separation between head + body.
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 36, 0, 3)
    accent.Position = UDim2.new(0, 0, 0, 28)
    accent.BackgroundColor3 = AMBER
    accent.BorderSizePixel = 0
    accent.Parent = panel

    local h = Instance.new("TextLabel")
    h.Name = "Head"
    h.Size = UDim2.new(1, 0, 0, 24)
    h.Position = UDim2.new(0, 0, 0, 0)
    h.BackgroundTransparency = 1
    h.Text = ""
    h.TextColor3 = CYAN
    h.TextStrokeColor3 = DARK
    h.TextStrokeTransparency = 0.5
    h.Font = Enum.Font.GothamBold
    h.TextScaled = true
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = panel

    local hConstraint = Instance.new("UITextSizeConstraint")
    hConstraint.MinTextSize = 14
    hConstraint.MaxTextSize = 22
    hConstraint.Parent = h

    local b = Instance.new("TextLabel")
    b.Name = "Body"
    b.Size = UDim2.new(1, 0, 0, 38)
    b.Position = UDim2.new(0, 0, 0, 36)
    b.BackgroundTransparency = 1
    b.Text = ""
    b.TextColor3 = TEXT
    b.TextStrokeColor3 = DARK
    b.TextStrokeTransparency = 0.6
    b.Font = Enum.Font.Gotham
    b.TextScaled = true
    b.TextWrapped = true
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = panel

    local bConstraint = Instance.new("UITextSizeConstraint")
    bConstraint.MinTextSize = 12
    bConstraint.MaxTextSize = 18
    bConstraint.Parent = b

    return root, h, b
end

tooltipRoot, headlineLbl, bodyLbl = buildTooltip()
tooltipRoot.Enabled = false

-- Find the part on the local player's plot matching name `anchor`. The
-- plot is named "Plot_{userId}" by PlotAssigner.
local function findAnchorPart(anchorName: string): BasePart?
    local plot = workspace:FindFirstChild("Plot_" .. player.UserId)
    if not plot then return nil end
    local part = plot:FindFirstChild(anchorName)
    if part and part:IsA("BasePart") then return part end
    return nil
end

local function showStep(stepIndex: number)
    if stepIndex < 1 or stepIndex > #STEP_COPY then
        if tooltipRoot then tooltipRoot.Enabled = false end
        return
    end
    local copy = STEP_COPY[stepIndex]
    local anchor: BasePart? = nil
    -- Plot may not be ready instantly on join; poll briefly
    for _ = 1, 20 do
        anchor = findAnchorPart(copy.anchor)
        if anchor then break end
        task.wait(0.5)
    end
    if not anchor or not tooltipRoot then return end

    local wasEnabled = tooltipRoot.Enabled
    tooltipRoot.Adornee = anchor
    if headlineLbl then
        headlineLbl.Text = string.format("(%d/%d)  %s",
            stepIndex, #STEP_COPY, copy.headline)
    end
    if bodyLbl then bodyLbl.Text = copy.body end
    tooltipRoot.Enabled = true

    -- Subtle entry animation: tween the StudsOffset Y from 9 down to 6 +
    -- a tiny bounce-back, so the panel feels like it lands. Skipped on
    -- step swaps where it was already visible.
    if not wasEnabled then
        tooltipRoot.StudsOffset = Vector3.new(0, 9, 0)
        TweenService:Create(tooltipRoot,
            TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { StudsOffset = Vector3.new(0, 6, 0) }):Play()
    end
end

-- ---- State machine -------------------------------------------------------

-- Server tracks the highest STEP COMPLETED. Client always shows the
-- "what to do next" tooltip = step (completed + 1). When completed >=
-- #FTUE_STEPS, the tooltip hides for good.
local highestCompleted = 0

local function refreshFromCompleted(completed: number)
    highestCompleted = math.max(highestCompleted, completed)
    local nextStep = highestCompleted + 1
    if nextStep > #STEP_COPY then
        if tooltipRoot then tooltipRoot.Enabled = false end
        return
    end
    showStep(nextStep)
end

-- Initial fetch: server tells us how far the player got historically.
task.spawn(function()
    local ok, completed = pcall(function()
        return remotes.GetTutorialStep:InvokeServer()
    end)
    if ok and typeof(completed) == "number" then
        refreshFromCompleted(completed)
    else
        refreshFromCompleted(0)
    end
end)

remotes.TutorialStepReached.OnClientEvent:Connect(function(stepIdx: number, _stepId: string)
    refreshFromCompleted(stepIdx)
end)

-- Hide tooltip on death (avatar respawn replaces character; the adornee
-- part is unchanged but the tooltip can clip into respawn animations).
player.CharacterAdded:Connect(function()
    if highestCompleted < #STEP_COPY then
        task.wait(2)
        refreshFromCompleted(highestCompleted)
    end
end)

print("[TutorialOverlay] mounted")
