--!strict
-- "?" SOS button + onboarding modal. Pure client — no remotes.
-- Top-right corner button below the HUD. Tap to open a centered card
-- with the 5 essential onboarding hints. Tap anywhere outside or X
-- to close.
--
-- Targets the D1 cohort that lands on a plot but doesn't know what to
-- do next. Per checklist: D1 hook is 30 seconds; if a player can't
-- locate the dropper / upgrade button / spin / quests in that window,
-- they bounce. The SOS is the safety net.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UICommands = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UICommands"))

local player = Players.LocalPlayer

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local HINTS = {
    {icon = "1", title = "Walk to your DROPPER", body = "It produces coins. They ride the conveyor to your COLLECTOR (vault door)."},
    {icon = "2", title = "Touch the UPGRADE button", body = "Costs coins, doubles your income. Tier up 6 times to reach the capstone."},
    {icon = "3", title = "Stand on the REBIRTH portal", body = "After tier 2 + 1500 lifetime coins, prestige for permanent +10% income."},
    {icon = "4", title = "Hatch PETS for income boost", body = "Open the menu → Pets. Equip up to 3 for stacking multipliers."},
    {icon = "5", title = "Daily QUESTS + SPIN", body = "Open the menu daily. Quests + spin reset every 24h UTC."},
}

local function destroyExisting(pg: PlayerGui)
    local x = pg:FindFirstChild("Studio88HelpModal")
    if x then x:Destroy() end
end

local function openModal()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    destroyExisting(pg)

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88HelpModal"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 90
    sg.Parent = pg

    -- Backdrop
    local backdrop = Instance.new("TextButton")  -- TextButton swallows clicks
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.4
    backdrop.BorderSizePixel = 0
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = sg
    backdrop.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    -- Card
    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 520, 0, 460)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = sg

    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 16)
    cor.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 2
    stroke.Parent = card

    -- Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -32, 0, 50)
    header.Position = UDim2.new(0, 16, 0, 12)
    header.BackgroundTransparency = 1
    header.Text = "QUICK START"
    header.TextColor3 = CYAN
    header.Font = Enum.Font.GothamBold
    header.TextScaled = true
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = card

    -- Close X
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -50, 0, 16)
    closeBtn.AnchorPoint = Vector2.new(0, 0)
    closeBtn.BackgroundColor3 = DARK
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = PINK
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.AutoButtonColor = true
    closeBtn.Parent = card
    local closeCor = Instance.new("UICorner")
    closeCor.CornerRadius = UDim.new(0.5, 0)
    closeCor.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- Hints list
    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -32, 1, -88)
    list.Position = UDim2.new(0, 16, 0, 72)
    list.BackgroundTransparency = 1
    list.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list

    for i, hint in ipairs(HINTS) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 65)
        row.BackgroundColor3 = DARK
        row.BackgroundTransparency = 0.55
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = list
        local rowCor = Instance.new("UICorner")
        rowCor.CornerRadius = UDim.new(0, 10)
        rowCor.Parent = row

        -- Number bubble
        local bubble = Instance.new("TextLabel")
        bubble.Size = UDim2.new(0, 44, 0, 44)
        bubble.Position = UDim2.new(0, 10, 0.5, -22)
        bubble.BackgroundColor3 = AMBER
        bubble.BackgroundTransparency = 0.05
        bubble.BorderSizePixel = 0
        bubble.Text = hint.icon
        bubble.TextColor3 = DARK
        bubble.Font = Enum.Font.GothamBold
        bubble.TextScaled = true
        bubble.Parent = row
        local bubbleCor = Instance.new("UICorner")
        bubbleCor.CornerRadius = UDim.new(0.5, 0)
        bubbleCor.Parent = bubble

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -68, 0, 22)
        title.Position = UDim2.new(0, 64, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = hint.title
        title.TextColor3 = CYAN
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = row

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -68, 0, 30)
        body.Position = UDim2.new(0, 64, 0, 32)
        body.BackgroundTransparency = 1
        body.Text = hint.body
        body.TextColor3 = Color3.fromRGB(220, 220, 220)
        body.TextStrokeTransparency = 0.6
        body.Font = Enum.Font.Gotham
        body.TextScaled = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextWrapped = true
        body.Parent = row
    end

    -- Open animation
    card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(card,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 520, 0, 460)}):Play()
end

local function makeButton()
    local pg = player:WaitForChild("PlayerGui")
    -- Tear down any prior to keep this idempotent on character respawn
    local prior = pg:FindFirstChild("Studio88HelpButton")
    if prior then prior:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88HelpButton"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 80
    sg.Parent = pg

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, -16, 0, 16)
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = SURFACE
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel = 0
    btn.Text = "?"
    btn.TextColor3 = CYAN
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.AutoButtonColor = true
    btn.Parent = sg
    local btnCor = Instance.new("UICorner")
    btnCor.CornerRadius = UDim.new(0.5, 0)
    btnCor.Parent = btn
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = CYAN
    btnStroke.Thickness = 2
    btnStroke.Parent = btn

    btn.MouseButton1Click:Connect(openModal)
end

makeButton()
player.CharacterAdded:Connect(makeButton)

UICommands.register("openHelp", openModal)

print("[HelpOverlay] client ready")
