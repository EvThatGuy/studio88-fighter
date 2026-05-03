--!strict
-- Codes redeem overlay. "🎁" button → modal with text input + Redeem button.
-- Server fires CodeRedeemed/CodeRejected; client toasts the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local function showResult(text: string, accent: Color3, parent: ScreenGui)
    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Position = UDim2.new(0.5, 0, 1, 12)
    toast.Size = UDim2.new(0, 320, 0, 36)
    toast.BackgroundColor3 = SURFACE
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    toast.Parent = parent
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Parent = toast
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, -8)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = accent
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = toast
    task.delay(2.4, function() if toast.Parent then toast:Destroy() end end)
end

local function openModal()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88CodesModal")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88CodesModal"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 93
    sg.Parent = pg

    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.45
    backdrop.BorderSizePixel = 0
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = sg
    backdrop.MouseButton1Click:Connect(function() sg:Destroy() end)

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 420, 0, 240)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 2
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "🎁 REDEEM CODE"
    title.TextColor3 = CYAN
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -50, 0, 16)
    closeBtn.BackgroundColor3 = DARK
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "X"
    closeBtn.TextColor3 = PINK
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -32, 0, 50)
    input.Position = UDim2.new(0, 16, 0, 64)
    input.BackgroundColor3 = DARK
    input.BackgroundTransparency = 0.2
    input.BorderSizePixel = 0
    input.PlaceholderText = "Enter code (e.g. LAUNCH)..."
    input.Text = ""
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    input.Font = Enum.Font.Code
    input.TextScaled = true
    input.ClearTextOnFocus = false
    input.Parent = card
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)

    local submit = Instance.new("TextButton")
    submit.Size = UDim2.new(1, -32, 0, 50)
    submit.Position = UDim2.new(0, 16, 0, 124)
    submit.BackgroundColor3 = AMBER
    submit.BorderSizePixel = 0
    submit.Text = "REDEEM"
    submit.TextColor3 = DARK
    submit.Font = Enum.Font.GothamBold
    submit.TextScaled = true
    submit.Parent = card
    Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 8)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -32, 0, 26)
    hint.Position = UDim2.new(0, 16, 0, 184)
    hint.BackgroundTransparency = 1
    hint.Text = "Try LAUNCH or GTA6HYPE"
    hint.TextColor3 = Color3.fromRGB(150, 150, 150)
    hint.Font = Enum.Font.Code
    hint.TextScaled = true
    hint.Parent = card

    submit.MouseButton1Click:Connect(function()
        local code = string.upper(input.Text)
        if code == "" then return end
        remotes.RequestRedeemCode:FireServer(code)
        input.Text = ""
    end)
end

local function makeButton()
    local pg = player:WaitForChild("PlayerGui")
    local prior = pg:FindFirstChild("Studio88CodesButton")
    if prior then prior:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88CodesButton"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 78
    sg.Parent = pg

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, -128, 0, 16)  -- left of "🛒" Daily Shop button
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = SURFACE
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel = 0
    btn.Text = "🎁"
    btn.TextColor3 = CYAN
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 2
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(openModal)
end

remotes.CodeRedeemed.OnClientEvent:Connect(function(code: string, reward: number)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    local modal = pg and pg:FindFirstChild("Studio88CodesModal")
    if modal then
        showResult(string.format("✓ %s → +$%s", code, fmtCoins(reward or 0)), AMBER, modal)
    end
end)

remotes.CodeRejected.OnClientEvent:Connect(function(code: string, reason: string)
    local pg = player:FindFirstChildOfClass("PlayerGui")
    local modal = pg and pg:FindFirstChild("Studio88CodesModal")
    if modal then
        showResult(string.format("✗ %s — %s", code, reason or "rejected"), PINK, modal)
    end
end)

makeButton()
player.CharacterAdded:Connect(makeButton)

print("[CodesOverlay] client ready")
