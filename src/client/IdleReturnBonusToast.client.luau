--!strict
-- "Welcome back! Earned X coins offline" toast on rejoin.
-- Receives IdleReturnBonusGranted from server with {offlineSec, bonus, tier}.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    if n < 1000000000 then return string.format("%.2fM", n / 1000000) end
    return string.format("%.2fB", n / 1000000000)
end

local function fmtDuration(sec: number): string
    if sec < 60 then return sec .. "s" end
    if sec < 3600 then return math.floor(sec / 60) .. "m" end
    return string.format("%.1fh", sec / 3600)
end

local function show(payload)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88IdleReturn")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88IdleReturn"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 110
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, -140)
    card.Size = UDim2.new(0, 460, 0, 110)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 14)
    cor.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 2
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 40)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "WELCOME BACK"
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0, 32)
    sub.Position = UDim2.new(0, 16, 0, 56)
    sub.BackgroundTransparency = 1
    sub.Text = string.format("Earned $%s offline (%s away)",
        fmtCoins(payload.bonus or 0), fmtDuration(payload.offlineSec or 0))
    sub.TextColor3 = CYAN
    sub.TextStrokeTransparency = 0.4
    sub.TextStrokeColor3 = DARK
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = card

    TweenService:Create(card,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0, 32)}):Play()

    task.delay(4.0, function()
        if not card.Parent then return end
        TweenService:Create(card,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 0, -140)}):Play()
        task.delay(0.5, function() if sg.Parent then sg:Destroy() end end)
    end)
end

remotes.IdleReturnBonusGranted.OnClientEvent:Connect(show)
print("[IdleReturnBonusToast] client ready")
