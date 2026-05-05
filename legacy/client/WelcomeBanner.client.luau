--!strict
-- Receives WelcomeBanner from PlotAssigner on join + fades in a brief
-- 3s banner showing the player's tier + lifetime coins. Returning players
-- see "Welcome back" + their progress; first-time players see "Welcome to
-- Studio 88 Tycoon" with their fresh tier 1.
--
-- Lives entirely client-side: pure ScreenGui under PlayerGui, no remotes
-- back to server. Fades via TweenService so it doesn't fight HUD_v2's
-- existing layout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local PINK    = Color3.fromRGB(255, 46, 136)
local CYAN    = Color3.fromRGB(0, 240, 255)
local AMBER   = Color3.fromRGB(255, 176, 0)
local DARK    = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    if n < 1000000000 then return string.format("%.2fM", n / 1000000) end
    return string.format("%.2fB", n / 1000000000)
end

local function showBanner(payload)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    -- Tear down any prior banner so re-firing doesn't stack
    local existing = pg:FindFirstChild("Studio88WelcomeBanner")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88WelcomeBanner"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 100
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, -120)  -- start hidden above
    card.Size = UDim2.new(0, 480, 0, 110)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = card

    -- Pink top accent strip
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 4)
    accent.BackgroundColor3 = PINK
    accent.BorderSizePixel = 0
    accent.Parent = card
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 14)
    accentCorner.Parent = accent

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 40)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextStrokeTransparency = 0.4
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Text = (payload.isReturning and "WELCOME BACK, " or "WELCOME, ") .. string.upper(payload.playerName or "?")
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0, 28)
    sub.Position = UDim2.new(0, 16, 0, 56)
    sub.BackgroundTransparency = 1
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextColor3 = CYAN
    sub.TextStrokeTransparency = 0.4
    sub.TextStrokeColor3 = DARK
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.Text = string.format("TIER %d  ·  $%s LIFETIME%s",
        payload.tier or 1,
        fmtCoins(payload.lifetimeCoins or 0),
        (payload.rebirths or 0) > 0 and string.format("  ·  R%d", payload.rebirths) or ""
    )
    sub.Parent = card

    -- Slide in
    local slideIn = TweenService:Create(card,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0, 32)})
    slideIn:Play()

    -- Hold + slide out
    task.delay(3.2, function()
        if not card.Parent then return end
        local slideOut = TweenService:Create(card,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 0, -120)})
        slideOut:Play()
        slideOut.Completed:Once(function()
            if sg.Parent then sg:Destroy() end
        end)
    end)
end

remotes.WelcomeBanner.OnClientEvent:Connect(showBanner)

print("[WelcomeBanner] client ready")
