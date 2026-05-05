--!strict
-- Press C to open class selection. Tap a class card to fire SelectClass.
-- Server applies walkspeed via ClassRegistry on next CharacterAdded
-- (or immediately if a character exists).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local AMBER = Color3.fromRGB(255, 176, 0)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_ClassSelect"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(640, 360)
modal.BackgroundColor3 = DARK
modal.BorderSizePixel = 0
modal.Parent = backdrop

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 12)
modalCorner.Parent = modal

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -32, 0, 36)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextColor3 = PINK
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "PICK YOUR FIGHTER"
title.Parent = modal

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -32, 0, 18)
hint.Position = UDim2.fromOffset(16, 44)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.fromRGB(180, 180, 200)
hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "press C to close • selection persists across sessions"
hint.Parent = modal

local list = Instance.new("Frame")
list.Position = UDim2.fromOffset(16, 80)
list.Size = UDim2.new(1, -32, 1, -96)
list.BackgroundTransparency = 1
list.Parent = modal

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 12)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function makeCard(class: any, order: number)
    local card = Instance.new("TextButton")
    card.Name = class.id or "unknown"
    card.Size = UDim2.new(0, 196, 1, 0)
    card.BackgroundColor3 = SURFACE
    card.BorderSizePixel = 0
    card.AutoButtonColor = false
    card.Text = ""
    card.LayoutOrder = order
    card.Parent = list

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1
    stroke.Transparency = 0.7
    stroke.Parent = card

    local cardTitle = Instance.new("TextLabel")
    cardTitle.Position = UDim2.fromOffset(12, 12)
    cardTitle.Size = UDim2.new(1, -24, 0, 24)
    cardTitle.BackgroundTransparency = 1
    cardTitle.Font = Enum.Font.GothamBlack
    cardTitle.TextColor3 = AMBER
    cardTitle.TextSize = 18
    cardTitle.TextXAlignment = Enum.TextXAlignment.Left
    cardTitle.Text = string.upper(tostring(class.displayName or class.key or class.id))
    cardTitle.Parent = card

    local stats = Instance.new("TextLabel")
    stats.Position = UDim2.fromOffset(12, 44)
    stats.Size = UDim2.new(1, -24, 0, 60)
    stats.BackgroundTransparency = 1
    stats.Font = Enum.Font.Gotham
    stats.TextColor3 = Color3.fromRGB(220, 220, 230)
    stats.TextSize = 12
    stats.TextXAlignment = Enum.TextXAlignment.Left
    stats.TextYAlignment = Enum.TextYAlignment.Top
    stats.TextWrapped = true
    stats.Text = string.format(
        "speed %d\nstamina %d\npunch %d",
        class.walkspeed or 0,
        class.staminaMax or 0,
        class.punchDamage or 0
    )
    stats.Parent = card

    local blurb = Instance.new("TextLabel")
    blurb.AnchorPoint = Vector2.new(0, 1)
    blurb.Position = UDim2.new(0, 12, 1, -42)
    blurb.Size = UDim2.new(1, -24, 0, 28)
    blurb.BackgroundTransparency = 1
    blurb.Font = Enum.Font.Gotham
    blurb.TextColor3 = Color3.fromRGB(150, 150, 180)
    blurb.TextSize = 11
    blurb.TextWrapped = true
    blurb.TextXAlignment = Enum.TextXAlignment.Left
    blurb.TextYAlignment = Enum.TextYAlignment.Top
    blurb.Text = tostring(class.blurb or "")
    blurb.Parent = card

    local pickBtn = Instance.new("TextButton")
    pickBtn.AnchorPoint = Vector2.new(0, 1)
    pickBtn.Position = UDim2.new(0, 12, 1, -8)
    pickBtn.Size = UDim2.new(1, -24, 0, 28)
    pickBtn.BackgroundColor3 = PINK
    pickBtn.BorderSizePixel = 0
    pickBtn.Font = Enum.Font.GothamBold
    pickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pickBtn.TextSize = 13
    pickBtn.Text = "SELECT"
    pickBtn.AutoButtonColor = true
    pickBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = pickBtn

    pickBtn.MouseButton1Click:Connect(function()
        local key = class.key or class.id
        if typeof(key) == "string" then
            remotes.SelectClass:FireServer(key)
            screenGui.Enabled = false
        end
    end)
end

local function populate()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local ok, classes = pcall(function()
        return remotes.GetClasses:InvokeServer()
    end)
    if not ok or typeof(classes) ~= "table" then return end
    for i, class in ipairs(classes) do
        makeCard(class, i)
    end
end

local OPEN_ACTION = "Studio88_OpenClassSelect"
ContextActionService:BindAction(OPEN_ACTION, function(_, state)
    if state ~= Enum.UserInputState.Begin then return end
    if UserInputService:GetFocusedTextBox() then return end
    if screenGui.Enabled then
        screenGui.Enabled = false
    else
        populate()
        screenGui.Enabled = true
    end
end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonY)

backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = input.Position
        local frame = modal.AbsolutePosition
        local size = modal.AbsoluteSize
        if pos.X < frame.X or pos.X > frame.X + size.X
        or pos.Y < frame.Y or pos.Y > frame.Y + size.Y then
            screenGui.Enabled = false
        end
    end
end)
