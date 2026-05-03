--!strict
-- VaultRaid client toasts. Renders SPAWN + END notifications based on
-- server VaultRaidSpawned + VaultRaidEnded broadcasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local CYAN = Color3.fromRGB(0, 240, 255)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local function showToast(name: string, title: string, body: string, accent: Color3, hold: number)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild(name)
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = name
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 130
    sg.Parent = pg

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

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -32, 0, 38)
    titleLbl.Position = UDim2.new(0, 16, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = accent
    titleLbl.TextStrokeTransparency = 0.3
    titleLbl.TextStrokeColor3 = DARK
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextScaled = true
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local bodyLbl = Instance.new("TextLabel")
    bodyLbl.Size = UDim2.new(1, -32, 0, 32)
    bodyLbl.Position = UDim2.new(0, 16, 0, 56)
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text = body
    bodyLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    bodyLbl.TextStrokeTransparency = 0.4
    bodyLbl.TextStrokeColor3 = DARK
    bodyLbl.Font = Enum.Font.Code
    bodyLbl.TextScaled = true
    bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
    bodyLbl.Parent = card

    TweenService:Create(card,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0, 32)}):Play()

    task.delay(hold, function()
        if not card.Parent then return end
        TweenService:Create(card,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 0, -130)}):Play()
        task.delay(0.5, function() if sg.Parent then sg:Destroy() end end)
    end)
end

remotes.VaultRaidSpawned.OnClientEvent:Connect(function(payload)
    showToast("Studio88VaultRaidSpawn",
        "★ VAULT RAIDER ★",
        string.format("Tag at lobby for a $%s share! (%ds)",
            fmtCoins(payload.pool or 0), payload.timeoutSec or 60),
        AMBER, 6.0)
end)

remotes.VaultRaidEnded.OnClientEvent:Connect(function(payload)
    -- Find my share if I tagged
    local myShare = 0
    local myTags = 0
    for _, r in ipairs(payload.results or {}) do
        if r.userId == player.UserId then
            myShare = r.share or 0
            myTags = r.tags or 0
        end
    end
    local title, body, accent
    if myShare > 0 then
        title = "★ RAID REWARD ★"
        body = string.format("+$%s (%d tags, %d total players)",
            fmtCoins(myShare), myTags, #(payload.results or {}))
        accent = AMBER
    else
        title = "RAID ENDED"
        body = string.format("%d players tagged $%s pool",
            #(payload.results or {}), fmtCoins(payload.pool or 0))
        accent = CYAN
    end
    showToast("Studio88VaultRaidEnd", title, body, accent, 4.0)
end)

print("[VaultRaidToast] client ready")
