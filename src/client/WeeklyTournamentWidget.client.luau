--!strict
-- Top-left HUD widget showing the player's current week tournament status:
-- "MY WEEK $X (rank Y)". Refreshes every 30s by invoking
-- GetWeeklyTournament. Click opens... nothing yet (placeholder; could
-- open a modal in a future iteration with the top-10 leaderboard).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function makeWidget()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88WeeklyTournament")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88WeeklyTournament"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 70
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0, 0)
    card.Position = UDim2.new(0, 16, 0, 78)  -- below leaderstats
    card.Size = UDim2.new(0, 200, 0, 56)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = sg

    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 10)
    cor.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -16, 0, 22)
    title.Position = UDim2.new(0, 8, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "★ THIS WEEK"
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.4
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -16, 0, 26)
    body.Position = UDim2.new(0, 8, 0, 26)
    body.BackgroundTransparency = 1
    body.Text = "$0 (—)"
    body.TextColor3 = CYAN
    body.TextStrokeTransparency = 0.5
    body.Font = Enum.Font.Code
    body.TextScaled = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Parent = card

    return sg, body
end

local sg, bodyLbl = makeWidget()

-- ---- Modal --------------------------------------------------------------
-- Click the widget to open a top-50 tournament leaderboard modal.

local function fmtRow(rank: number, row): string
    return string.format("%2d. %-14s  $%s", rank, row.name:sub(1,14), fmtCoins(row.weeklyEarned or 0))
end

local function openModal()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local existing = pg:FindFirstChild("Studio88WeeklyTournamentModal")
    if existing then existing:Destroy() end

    local modalSg = Instance.new("ScreenGui")
    modalSg.Name = "Studio88WeeklyTournamentModal"
    modalSg.ResetOnSpawn = false
    modalSg.IgnoreGuiInset = true
    modalSg.DisplayOrder = 95
    modalSg.Parent = pg

    -- Backdrop
    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.45
    backdrop.BorderSizePixel = 0
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = modalSg
    backdrop.MouseButton1Click:Connect(function() modalSg:Destroy() end)

    -- Card
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 460, 0, 540)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = modalSg
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
    title.Text = "★ THIS WEEK — TOP 50"
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    -- Reward tooltip — players need to know what they're racing for.
    -- Sits below the title, before the scrolling list.
    local rewardHint = Instance.new("TextLabel")
    rewardHint.Size = UDim2.new(1, -32, 0, 26)
    rewardHint.Position = UDim2.new(0, 16, 0, 50)
    rewardHint.BackgroundTransparency = 1
    rewardHint.Text = "REWARDS:  1st = 10 tokens   2-3 = 5   4-10 = 2"
    rewardHint.TextColor3 = Color3.fromRGB(180, 180, 180)
    rewardHint.TextStrokeTransparency = 0.5
    rewardHint.Font = Enum.Font.Code
    rewardHint.TextScaled = true
    rewardHint.TextXAlignment = Enum.TextXAlignment.Left
    rewardHint.Parent = card

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -50, 0, 16)
    closeBtn.BackgroundColor3 = DARK
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 46, 136)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
    closeBtn.MouseButton1Click:Connect(function() modalSg:Destroy() end)

    -- Scrolling list (pushed down to make room for reward hint)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -32, 1, -114)
    scroll.Position = UDim2.new(0, 16, 0, 98)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = card
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 4)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = scroll

    local loading = Instance.new("TextLabel")
    loading.Size = UDim2.new(1, 0, 0, 32)
    loading.BackgroundTransparency = 1
    loading.Text = "loading..."
    loading.TextColor3 = Color3.fromRGB(150, 150, 150)
    loading.Font = Enum.Font.Code
    loading.TextScaled = true
    loading.LayoutOrder = 1
    loading.Parent = scroll

    task.spawn(function()
        local ok, payload = pcall(function()
            return remotes.GetWeeklyTournamentTopN:InvokeServer(50)
        end)
        if not modalSg.Parent then return end
        loading:Destroy()
        if not ok or not payload or not payload.entries or #payload.entries == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 40)
            empty.BackgroundTransparency = 1
            empty.Text = "(no entries yet — be the first this week)"
            empty.TextColor3 = Color3.fromRGB(150, 150, 150)
            empty.Font = Enum.Font.Code
            empty.TextScaled = true
            empty.LayoutOrder = 1
            empty.Parent = scroll
            return
        end
        for i, row in ipairs(payload.entries) do
            local rowLbl = Instance.new("TextLabel")
            rowLbl.Size = UDim2.new(1, 0, 0, 26)
            rowLbl.BackgroundTransparency = 1
            rowLbl.Text = fmtRow(i, row)
            rowLbl.TextColor3 = (i == 1) and AMBER or (i <= 3 and Color3.fromRGB(255, 46, 136) or CYAN)
            rowLbl.Font = Enum.Font.Code
            rowLbl.TextScaled = true
            rowLbl.TextXAlignment = Enum.TextXAlignment.Left
            rowLbl.LayoutOrder = i
            rowLbl.Parent = scroll
        end
    end)
end

-- Make the existing widget click open the modal
local widgetCard = sg:FindFirstChildWhichIsA("Frame")
if widgetCard then
    local clickTrap = Instance.new("TextButton")
    clickTrap.Size = UDim2.new(1, 0, 1, 0)
    clickTrap.BackgroundTransparency = 1
    clickTrap.Text = ""
    clickTrap.AutoButtonColor = false
    clickTrap.Parent = widgetCard
    clickTrap.MouseButton1Click:Connect(openModal)
end

local function refresh()
    pcall(function()
        local snap = remotes.GetWeeklyTournament:InvokeServer()
        if not snap or not bodyLbl.Parent then return end
        local rankPart = snap.rank and string.format(" (rank %d)", snap.rank) or " (—)"
        bodyLbl.Text = "$" .. fmtCoins(snap.weeklyEarned or 0) .. rankPart
    end)
end

-- First fetch + 30s loop
task.spawn(function()
    task.wait(2)  -- let server-side bootstrap settle
    refresh()
    while sg.Parent do
        task.wait(30)
        refresh()
    end
end)

print("[WeeklyTournamentWidget] client ready")
