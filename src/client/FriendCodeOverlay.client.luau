--!strict
-- Friend code share overlay. "👥" button → modal with the player's
-- friend code displayed prominently + share copy hint. Players cannot
-- programmatically copy to clipboard from Roblox, but seeing the code
-- in big text is enough for them to type it elsewhere.

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

local function openModal()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88FriendCodeModal")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88FriendCodeModal"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 94
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
    card.Size = UDim2.new(0, 460, 0, 320)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color = PINK
    stroke.Thickness = 2
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 36)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "👥 YOUR FRIEND CODE"
    title.TextColor3 = PINK
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

    -- Big code display
    local codeBox = Instance.new("Frame")
    codeBox.Size = UDim2.new(1, -32, 0, 90)
    codeBox.Position = UDim2.new(0, 16, 0, 64)
    codeBox.BackgroundColor3 = DARK
    codeBox.BackgroundTransparency = 0.2
    codeBox.BorderSizePixel = 0
    codeBox.Parent = card
    Instance.new("UICorner", codeBox).CornerRadius = UDim.new(0, 10)
    local codeStroke = Instance.new("UIStroke")
    codeStroke.Color = AMBER
    codeStroke.Thickness = 2
    codeStroke.Parent = codeBox

    local code = Instance.new("TextBox")
    code.Size = UDim2.new(1, -16, 1, -16)
    code.Position = UDim2.new(0, 8, 0, 8)
    code.BackgroundTransparency = 1
    code.Text = "..."
    code.TextColor3 = AMBER
    code.TextStrokeTransparency = 0.2
    code.TextStrokeColor3 = DARK
    code.Font = Enum.Font.Code
    code.TextScaled = true
    code.TextEditable = false  -- read-only display
    code.ClearTextOnFocus = false
    code.Parent = codeBox

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0, 30)
    sub.Position = UDim2.new(0, 16, 0, 168)
    sub.BackgroundTransparency = 1
    sub.Text = "Share with friends — they redeem this code, you BOTH get coins!"
    sub.TextColor3 = CYAN
    sub.TextStrokeTransparency = 0.4
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.TextWrapped = true
    sub.Parent = card

    local stats = Instance.new("TextLabel")
    stats.Name = "ReferralStats"
    stats.Size = UDim2.new(1, -32, 0, 30)
    stats.Position = UDim2.new(0, 16, 0, 204)
    stats.BackgroundTransparency = 1
    stats.Text = "Referrals so far: 0"
    stats.TextColor3 = Color3.fromRGB(180, 180, 180)
    stats.Font = Enum.Font.Code
    stats.TextScaled = true
    stats.Parent = card

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -32, 0, 30)
    hint.Position = UDim2.new(0, 16, 0, 252)
    hint.BackgroundTransparency = 1
    hint.Text = "(tap the code to select + copy)"
    hint.TextColor3 = Color3.fromRGB(120, 120, 120)
    hint.Font = Enum.Font.Code
    hint.TextScaled = true
    hint.Parent = card

    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetFriendCode:InvokeServer() end)
        if not ok or not snap then return end
        if not codeBox.Parent then return end
        code.Text = snap.friendCode and snap.friendCode ~= "" and snap.friendCode or "(generating...)"
        stats.Text = string.format("Referrals so far: %d", snap.referralCount or 0)
    end)
end

local function makeButton()
    local pg = player:WaitForChild("PlayerGui")
    local prior = pg:FindFirstChild("Studio88FriendCodeButton")
    if prior then prior:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88FriendCodeButton"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 77
    sg.Parent = pg

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, -184, 0, 16)  -- left of "🎁" Codes button
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = SURFACE
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel = 0
    btn.Text = "👥"
    btn.TextColor3 = PINK
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color = PINK
    stroke.Thickness = 2
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(openModal)
end

makeButton()
player.CharacterAdded:Connect(makeButton)

print("[FriendCodeOverlay] client ready")
