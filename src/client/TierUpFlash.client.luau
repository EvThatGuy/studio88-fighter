--!strict
-- Brief screen flash + corner toast on tier-up. Pairs with the spatial
-- "tier_up" sound fired from UpgradeStation server-side. Listens to the
-- existing TierUpgraded RemoteEvent so no new wires.
--
-- Flash: full-screen Frame fades 0.4 → 0 alpha over 0.5s in tier color.
-- Toast: top-center "TIER X" text scales in + holds 1.6s + fades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local function tierColor(tier: number): Color3
    if tier >= 6 then return Color3.fromRGB(255, 255, 255) end
    if tier >= 5 then return Color3.fromRGB(255, 176, 0) end
    if tier >= 4 then return Color3.fromRGB(220, 80, 200) end
    if tier >= 3 then return Color3.fromRGB(180, 100, 220) end
    if tier >= 2 then return Color3.fromRGB(120, 120, 200) end
    return Color3.fromRGB(0, 240, 255)
end

local function showFlash(newTier: number, mult: number)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88TierFlash")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88TierFlash"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 200
    sg.Parent = pg

    local color = tierColor(newTier)

    -- 1. Full-screen flash
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = 0.6
    flash.BorderSizePixel = 0
    flash.ZIndex = 1
    flash.Parent = sg
    TweenService:Create(flash,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    -- 2. Center "TIER X" toast
    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(0.5, 0.5)
    toast.Position = UDim2.new(0.5, 0, 0.4, 0)
    toast.Size = UDim2.new(0, 0, 0, 0)  -- start at 0 — scale in
    toast.BackgroundColor3 = Color3.fromRGB(20, 17, 31)
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    toast.ZIndex = 2
    toast.Parent = sg

    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 18)
    toastCorner.Parent = toast

    local toastStroke = Instance.new("UIStroke")
    toastStroke.Color = color
    toastStroke.Thickness = 3
    toastStroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -32, 0.6, 0)
    label.Position = UDim2.new(0, 16, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = "TIER " .. newTier
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(8, 7, 13)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = toast

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0.4, 0)
    sub.Position = UDim2.new(0, 16, 0.6, 0)
    sub.BackgroundTransparency = 1
    sub.Text = string.format("x%d INCOME", mult)
    sub.TextColor3 = Color3.fromRGB(248, 248, 242)
    sub.TextStrokeTransparency = 0.5
    sub.TextStrokeColor3 = Color3.fromRGB(8, 7, 13)
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.TextTransparency = 0.15
    sub.Parent = toast

    -- Scale in
    TweenService:Create(toast,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 360, 0, 130)}):Play()

    -- Hold + fade out
    task.delay(1.8, function()
        if not toast.Parent then return end
        TweenService:Create(toast,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1, Size = UDim2.new(0, 360, 0, 0)}):Play()
        for _, c in ipairs({label, sub}) do
            TweenService:Create(c,
                TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
        task.delay(0.55, function()
            if sg.Parent then sg:Destroy() end
        end)
    end)
end

remotes.TierUpgraded.OnClientEvent:Connect(showFlash)

print("[TierUpFlash] client ready")
