--!strict
-- Generic notification toast renderer. Server fires NotificationToast
-- with {kind, title, body}; client renders a slide-in card. Kind drives
-- accent color: "streak_risk"=amber, "info"=cyan, "warn"=pink.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function accentForKind(kind: string): Color3
    if kind == "streak_risk" then return AMBER end
    if kind == "warn" then return PINK end
    return CYAN
end

remotes.NotificationToast.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88GenericToast")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88GenericToast"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 125
    sg.Parent = pg

    local accent = accentForKind(payload.kind or "info")

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, -130)
    card.Size = UDim2.new(0, 460, 0, 100)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 38)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = payload.title or ""
    title.TextColor3 = accent
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -32, 0, 32)
    body.Position = UDim2.new(0, 16, 0, 56)
    body.BackgroundTransparency = 1
    body.Text = payload.body or ""
    body.TextColor3 = Color3.fromRGB(255, 255, 255)
    body.TextStrokeTransparency = 0.4
    body.TextStrokeColor3 = DARK
    body.Font = Enum.Font.Code
    body.TextScaled = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Parent = card

    TweenService:Create(card,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0, 32)}):Play()

    task.delay(5.0, function()
        if not card.Parent then return end
        TweenService:Create(card,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 0, -130)}):Play()
        task.delay(0.5, function() if sg.Parent then sg:Destroy() end end)
    end)
end)

print("[NotificationToast] client ready")
