--!strict
-- Toast that fires once when the player crosses the rebirth eligibility
-- threshold (false→true). Server fires RebirthReadyNudge with
-- {rebirths, isFirst, nextMult}. Client renders a center-of-screen
-- card with a 1.6s scale-in + 4.5s hold + 0.5s fade-out.
--
-- Different copy for first rebirth (THE D1→D7 conversion moment per
-- retention checklist) vs subsequent rebirths (less ceremony).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function showToast(payload)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88RebirthNudge")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88RebirthNudge"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 150
    sg.Parent = pg

    local isFirst = payload.isFirst == true
    local accent = isFirst and AMBER or CYAN

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.35, 0)
    card.Size = UDim2.new(0, 0, 0, 0)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg

    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 16)
    cor.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 3
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0.45, 0)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = isFirst and "★ REBIRTH UNLOCKED ★" or "REBIRTH READY"
    title.TextColor3 = accent
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Parent = card

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0.4, 0)
    sub.Position = UDim2.new(0, 16, 0.5, 0)
    sub.BackgroundTransparency = 1
    sub.Text = isFirst
        and string.format("Step on the cyan portal on your plot for x%.2f permanent income!", payload.nextMult or 1.10)
        or string.format("R%d ready — perma x%.2f waiting", payload.rebirths or 0, payload.nextMult or 1)
    sub.TextColor3 = Color3.fromRGB(255, 255, 255)
    sub.TextStrokeTransparency = 0.5
    sub.TextStrokeColor3 = DARK
    sub.Font = Enum.Font.Gotham
    sub.TextScaled = true
    sub.Parent = card

    -- Scale in
    TweenService:Create(card,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 480, 0, 130)}):Play()

    local holdSec = isFirst and 4.5 or 2.5
    task.delay(holdSec, function()
        if not card.Parent then return end
        TweenService:Create(card,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1, Size = UDim2.new(0, 480, 0, 0)}):Play()
        for _, c in ipairs({title, sub}) do
            TweenService:Create(c,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
        task.delay(0.6, function() if sg.Parent then sg:Destroy() end end)
    end)
end

remotes.RebirthReadyNudge.OnClientEvent:Connect(showToast)

print("[RebirthReadyNudge] client ready")
