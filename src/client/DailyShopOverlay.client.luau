--!strict
-- Daily Shop client overlay. Top-right "🛒" button opens a card listing
-- today's 3 items. Click buy fires BuyDailyShopItem; refresh on response.

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

local function openModal()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88DailyShop")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88DailyShop"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 92
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
    card.Size = UDim2.new(0, 460, 0, 380)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 2
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 38)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "🛒 DAILY SHOP"
    title.TextColor3 = AMBER
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
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = PINK
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -32, 0, 20)
    sub.Position = UDim2.new(0, 16, 0, 50)
    sub.BackgroundTransparency = 1
    sub.Text = "Resets daily at 00:00 UTC"
    sub.TextColor3 = Color3.fromRGB(180, 180, 180)
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = card

    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -32, 1, -90)
    list.Position = UDim2.new(0, 16, 0, 76)
    list.BackgroundTransparency = 1
    list.Parent = card
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = list

    local function renderItems(snap)
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        if not snap or not snap.items or #snap.items == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 30)
            empty.BackgroundTransparency = 1
            empty.Text = "(no items today — try tomorrow)"
            empty.TextColor3 = Color3.fromRGB(150, 150, 150)
            empty.Font = Enum.Font.Code
            empty.TextScaled = true
            empty.Parent = list
            return
        end
        for _, item in ipairs(snap.items) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 64)
            row.BackgroundColor3 = DARK
            row.BackgroundTransparency = 0.55
            row.BorderSizePixel = 0
            row.Parent = list
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.65, -8, 1, -8)
            lbl.Position = UDim2.new(0, 8, 0, 4)
            lbl.BackgroundTransparency = 1
            lbl.Text = item.label or "?"
            lbl.TextColor3 = CYAN
            lbl.Font = Enum.Font.GothamBold
            lbl.TextScaled = true
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.32, -8, 1, -16)
            btn.Position = UDim2.new(0.68, 0, 0, 8)
            btn.BackgroundColor3 = item.bought and Color3.fromRGB(60, 65, 78) or AMBER
            btn.BackgroundTransparency = 0.05
            btn.BorderSizePixel = 0
            btn.Text = item.bought and "BOUGHT" or ("$" .. fmtCoins(item.price or 0))
            btn.TextColor3 = item.bought and Color3.fromRGB(180, 180, 180) or DARK
            btn.Font = Enum.Font.GothamBold
            btn.TextScaled = true
            btn.AutoButtonColor = not item.bought
            btn.Active = not item.bought
            btn.Parent = row
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

            if not item.bought then
                btn.MouseButton1Click:Connect(function()
                    btn.Text = "..."
                    btn.AutoButtonColor = false
                    remotes.BuyDailyShopItem:FireServer(item.id)
                    -- Refetch after server processes
                    task.wait(0.4)
                    local newSnap = remotes.GetDailyShop:InvokeServer()
                    renderItems(newSnap)
                end)
            end
        end
    end

    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetDailyShop:InvokeServer() end)
        if ok and sg.Parent then renderItems(snap) end
    end)
end

local function makeButton()
    local pg = player:WaitForChild("PlayerGui")
    local prior = pg:FindFirstChild("Studio88DailyShopButton")
    if prior then prior:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88DailyShopButton"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 79
    sg.Parent = pg

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, -72, 0, 16)  -- left of the "?" Help button
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = SURFACE
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel = 0
    btn.Text = "🛒"
    btn.TextColor3 = AMBER
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.AutoButtonColor = true
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 2
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(openModal)
end

makeButton()
player.CharacterAdded:Connect(makeButton)

print("[DailyShopOverlay] client ready")
