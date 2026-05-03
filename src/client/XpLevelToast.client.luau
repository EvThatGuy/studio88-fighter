--!strict
-- XP level-up celebration toast. Server fires XpLeveledUp with
-- {newLevel, xp, nextThreshold}. Client renders a centered "★ LEVEL N
-- UNLOCKED ★" card with scale-in + fade-out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local CYAN = Color3.fromRGB(0, 240, 255)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

remotes.XpLeveledUp.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88XpLevelToast")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88XpLevelToast"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 140
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.45, 0)
    card.Size = UDim2.new(0, 0, 0, 0)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 3
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0.55, 0)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = string.format("★ LEVEL %d UNLOCKED ★", payload.newLevel or 1)
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.2
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0.4, 0)
    sub.Position = UDim2.new(0, 16, 0.55, 0)
    sub.BackgroundTransparency = 1
    sub.Text = payload.nextThreshold
        and string.format("Next level: %d XP", payload.nextThreshold)
        or "MAX LEVEL — capstone reached!"
    sub.TextColor3 = CYAN
    sub.TextStrokeTransparency = 0.4
    sub.TextStrokeColor3 = DARK
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.Parent = card

    TweenService:Create(card,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 380, 0, 130)}):Play()

    task.delay(2.5, function()
        if not card.Parent then return end
        TweenService:Create(card,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Size = UDim2.new(0, 380, 0, 0), BackgroundTransparency = 1}):Play()
        for _, c in ipairs({title, sub}) do
            TweenService:Create(c,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
        task.delay(0.5, function() if sg.Parent then sg:Destroy() end end)
    end)
end)

print("[XpLevelToast] client ready")
