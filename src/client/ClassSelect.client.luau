--!strict
-- Press C to open class selection. Cards visualize each fighter's
-- relative speed / power / stamina as bars (auto-scaled across the
-- full class roster), tinted to a per-class accent color. Tap SELECT
-- on a card to fire SelectClass; server applies walkspeed via
-- ClassRegistry on next CharacterAdded (or immediately if a character
-- exists).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

-- ── palette ──────────────────────────────────────────────────────────
local DARK    = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local SUNKEN  = Color3.fromRGB(14, 12, 22)
local CYAN    = Color3.fromRGB(0, 240, 255)
local PINK    = Color3.fromRGB(255, 46, 136)
local AMBER   = Color3.fromRGB(255, 176, 0)
local TEXT    = Color3.fromRGB(232, 230, 245)
local TEXT_DIM = Color3.fromRGB(165, 160, 190)

-- Accent colors per class id. Falls back to CYAN if a class isn't listed.
local CLASS_ACCENT: {[string]: Color3} = {
    striker = CYAN,
    bruiser = AMBER,
    swift   = PINK,
}

local function accentFor(class: any): Color3
    local key = (class.id or class.key or ""):lower()
    return CLASS_ACCENT[key] or CYAN
end

-- ── ScreenGui scaffolding ────────────────────────────────────────────
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
backdrop.BackgroundTransparency = 0.35
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

-- Subtle radial gradient on the backdrop so the modal pops
local backdropGradient = Instance.new("UIGradient")
backdropGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(35, 8, 50)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(8, 5, 18)),
    ColorSequenceKeypoint.new(1,   Color3.new(0, 0, 0)),
})
backdropGradient.Transparency = NumberSequence.new(0.3)
backdropGradient.Rotation = 90
backdropGradient.Parent = backdrop

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(820, 480)
modal.BackgroundColor3 = DARK
modal.BorderSizePixel = 0
modal.Parent = backdrop

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 14)
modalCorner.Parent = modal

local modalStroke = Instance.new("UIStroke")
modalStroke.Color = PINK
modalStroke.Thickness = 1.5
modalStroke.Transparency = 0.6
modalStroke.Parent = modal

-- Header strip with vertical accent bar
local header = Instance.new("Frame")
header.Size = UDim2.new(1, -32, 0, 80)
header.Position = UDim2.fromOffset(16, 12)
header.BackgroundTransparency = 1
header.Parent = modal

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.fromOffset(4, 60)
headerAccent.Position = UDim2.fromOffset(0, 8)
headerAccent.BackgroundColor3 = PINK
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 36)
title.Position = UDim2.fromOffset(16, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextColor3 = TEXT
title.TextSize = 30
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "SELECT YOUR FIGHTER"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -16, 0, 18)
subtitle.Position = UDim2.fromOffset(16, 42)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextColor3 = TEXT_DIM
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "PRESS  C  TO CLOSE   •   SELECTION PERSISTS ACROSS SESSIONS"
subtitle.Parent = header

local closeHint = Instance.new("TextLabel")
closeHint.AnchorPoint = Vector2.new(1, 0)
closeHint.Position = UDim2.new(1, -12, 0, 16)
closeHint.Size = UDim2.fromOffset(120, 22)
closeHint.BackgroundTransparency = 1
closeHint.Font = Enum.Font.GothamBold
closeHint.TextColor3 = AMBER
closeHint.TextSize = 12
closeHint.TextXAlignment = Enum.TextXAlignment.Right
closeHint.Text = "[ ESC / C ]"
closeHint.Parent = header

-- Card row container
local list = Instance.new("Frame")
list.Position = UDim2.fromOffset(16, 104)
list.Size = UDim2.new(1, -32, 1, -120)
list.BackgroundTransparency = 1
list.Parent = modal

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 14)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

-- ── stat-bar component ───────────────────────────────────────────────
local function makeStatBar(parent: Instance, order: number, label: string, fraction: number, accent: Color3)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 64, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = TEXT_DIM
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = string.upper(label)
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.new(1, -68, 0, 8)
    track.BackgroundColor3 = SUNKEN
    track.BorderSizePixel = 0
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
    fill.BackgroundColor3 = accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    -- Thin internal hilight gradient on the fill so it doesn't read flat
    local fillGradient = Instance.new("UIGradient")
    fillGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, accent),
    })
    fillGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.65),
        NumberSequenceKeypoint.new(1, 0),
    })
    fillGradient.Rotation = 90
    fillGradient.Parent = fill
end

-- ── card builder ─────────────────────────────────────────────────────
type Stat = { label: string, value: number }
type Bounds = { min: number, max: number }

local function fractionFor(value: number, b: Bounds): number
    if b.max <= b.min then return 0.5 end
    local range = b.max - b.min
    -- Clamp at 15% min so even the lowest stat shows a sliver of fill
    return math.clamp(0.15 + 0.85 * ((value - b.min) / range), 0.15, 1)
end

local function makeCard(class: any, order: number, bounds: {speed: Bounds, power: Bounds, stamina: Bounds})
    local accent = accentFor(class)

    local card = Instance.new("TextButton")
    card.Name = class.id or "unknown"
    card.Size = UDim2.new(0, 240, 1, 0)
    card.BackgroundColor3 = SURFACE
    card.BorderSizePixel = 0
    card.AutoButtonColor = false
    card.Text = ""
    card.LayoutOrder = order
    card.Parent = list

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = accent
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.6
    cardStroke.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingTop = UDim.new(0, 14)
    cardPad.PaddingBottom = UDim.new(0, 14)
    cardPad.PaddingLeft = UDim.new(0, 14)
    cardPad.PaddingRight = UDim.new(0, 14)
    cardPad.Parent = card

    -- Top class-color band (subtle vertical gradient fading into card)
    local band = Instance.new("Frame")
    band.AnchorPoint = Vector2.new(0, 0)
    band.Position = UDim2.fromScale(0, 0)
    band.Size = UDim2.new(1, 0, 0, 80)
    band.BackgroundColor3 = accent
    band.BorderSizePixel = 0
    band.Parent = card
    band.ZIndex = 0

    local bandCorner = Instance.new("UICorner")
    bandCorner.CornerRadius = UDim.new(0, 12)
    bandCorner.Parent = band

    local bandGradient = Instance.new("UIGradient")
    bandGradient.Color = ColorSequence.new(accent)
    bandGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0.55),
        NumberSequenceKeypoint.new(0.55, 0.85),
        NumberSequenceKeypoint.new(1,    1),
    })
    bandGradient.Rotation = 90
    bandGradient.Parent = band

    -- Slot-number badge (top-left of card)
    local slot = Instance.new("TextLabel")
    slot.Size = UDim2.fromOffset(28, 28)
    slot.Position = UDim2.fromOffset(0, 0)
    slot.BackgroundColor3 = DARK
    slot.BackgroundTransparency = 0.2
    slot.BorderSizePixel = 0
    slot.Font = Enum.Font.GothamBlack
    slot.TextColor3 = accent
    slot.TextSize = 14
    slot.Text = string.format("%02d", order)
    slot.Parent = card
    slot.ZIndex = 2

    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 6)
    slotCorner.Parent = slot

    -- Class name + display name (large, bold)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 28)
    nameLabel.Position = UDim2.fromOffset(0, 38)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextColor3 = TEXT
    nameLabel.TextSize = 26
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = string.upper(tostring(class.displayName or class.key or class.id))
    nameLabel.Parent = card
    nameLabel.ZIndex = 2

    -- Tagline
    local tagline = Instance.new("TextLabel")
    tagline.Size = UDim2.new(1, 0, 0, 32)
    tagline.Position = UDim2.fromOffset(0, 70)
    tagline.BackgroundTransparency = 1
    tagline.Font = Enum.Font.GothamMedium
    tagline.TextColor3 = TEXT_DIM
    tagline.TextSize = 12
    tagline.TextXAlignment = Enum.TextXAlignment.Left
    tagline.TextYAlignment = Enum.TextYAlignment.Top
    tagline.TextWrapped = true
    tagline.Text = tostring(class.blurb or "")
    tagline.Parent = card
    tagline.ZIndex = 2

    -- Stat bars container
    local statsContainer = Instance.new("Frame")
    statsContainer.Size = UDim2.new(1, 0, 0, 86)
    statsContainer.Position = UDim2.fromOffset(0, 116)
    statsContainer.BackgroundTransparency = 1
    statsContainer.Parent = card
    statsContainer.ZIndex = 2

    local statsLayout = Instance.new("UIListLayout")
    statsLayout.Padding = UDim.new(0, 6)
    statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statsLayout.Parent = statsContainer

    makeStatBar(statsContainer, 1, "Speed",   fractionFor(class.walkspeed   or 0, bounds.speed),   accent)
    makeStatBar(statsContainer, 2, "Power",   fractionFor(class.punchDamage or 0, bounds.power),   accent)
    makeStatBar(statsContainer, 3, "Stamina", fractionFor(class.staminaMax  or 0, bounds.stamina), accent)

    -- Numerical stat readout below the bars
    local readout = Instance.new("TextLabel")
    readout.Size = UDim2.new(1, 0, 0, 34)
    readout.AnchorPoint = Vector2.new(0, 1)
    readout.Position = UDim2.new(0, 0, 1, -56)
    readout.BackgroundTransparency = 1
    readout.Font = Enum.Font.RobotoMono
    readout.TextColor3 = TEXT_DIM
    readout.TextSize = 11
    readout.TextXAlignment = Enum.TextXAlignment.Left
    readout.TextYAlignment = Enum.TextYAlignment.Top
    readout.Text = string.format(
        "spd %d  ·  pwr %d  ·  stm %d",
        class.walkspeed or 0, class.punchDamage or 0, class.staminaMax or 0
    )
    readout.Parent = card
    readout.ZIndex = 2

    -- SELECT button (full width, accent-tinted)
    local pickBtn = Instance.new("TextButton")
    pickBtn.AnchorPoint = Vector2.new(0, 1)
    pickBtn.Position = UDim2.new(0, 0, 1, 0)
    pickBtn.Size = UDim2.new(1, 0, 0, 40)
    pickBtn.BackgroundColor3 = accent
    pickBtn.BorderSizePixel = 0
    pickBtn.Font = Enum.Font.GothamBlack
    pickBtn.TextColor3 = DARK
    pickBtn.TextSize = 14
    pickBtn.Text = "SELECT"
    pickBtn.AutoButtonColor = true
    pickBtn.Parent = card
    pickBtn.ZIndex = 2

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = pickBtn

    -- Hover effect: brighten stroke + raise card slightly via card padding
    local hoverIn = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
    card.MouseEnter:Connect(function()
        TweenService:Create(cardStroke, hoverIn, {Thickness = 2, Transparency = 0.1}):Play()
        TweenService:Create(card, hoverIn, {BackgroundColor3 = Color3.new(
            math.min(1, SURFACE.R + 0.04),
            math.min(1, SURFACE.G + 0.04),
            math.min(1, SURFACE.B + 0.06)
        )}):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(cardStroke, hoverIn, {Thickness = 1, Transparency = 0.6}):Play()
        TweenService:Create(card, hoverIn, {BackgroundColor3 = SURFACE}):Play()
    end)

    -- Card click is also valid (whole card behaves like SELECT)
    local function fireSelect()
        local key = class.key or class.id
        if typeof(key) == "string" then
            remotes.SelectClass:FireServer(key)
            screenGui.Enabled = false
        end
    end
    pickBtn.MouseButton1Click:Connect(fireSelect)
    card.MouseButton1Click:Connect(fireSelect)
end

-- ── populate ─────────────────────────────────────────────────────────
local function clearCards()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function computeBounds(classes: {any}): {speed: Bounds, power: Bounds, stamina: Bounds}
    local function field(name: string)
        local minV = math.huge
        local maxV = -math.huge
        for _, c in ipairs(classes) do
            local v = tonumber(c[name]) or 0
            if v < minV then minV = v end
            if v > maxV then maxV = v end
        end
        if minV == math.huge then minV, maxV = 0, 0 end
        return {min = minV, max = maxV}
    end
    return {
        speed = field("walkspeed"),
        power = field("punchDamage"),
        stamina = field("staminaMax"),
    }
end

local function populate()
    clearCards()
    local ok, classes = pcall(function() return remotes.GetClasses:InvokeServer() end)
    if not ok or typeof(classes) ~= "table" then return end
    local bounds = computeBounds(classes)
    for i, class in ipairs(classes) do
        makeCard(class, i, bounds)
    end
end

-- ── open / close ─────────────────────────────────────────────────────
local function setOpen(open: boolean)
    if open then
        populate()
        screenGui.Enabled = true
    else
        screenGui.Enabled = false
    end
end

local OPEN_ACTION = "Studio88_OpenClassSelect"
ContextActionService:BindAction(OPEN_ACTION, function(_, state)
    if state ~= Enum.UserInputState.Begin then return end
    if UserInputService:GetFocusedTextBox() then return end
    setOpen(not screenGui.Enabled)
end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonY)

-- Close on Esc as well
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not screenGui.Enabled then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        setOpen(false)
    end
end)

-- Click-outside-modal closes
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local pos = input.Position
    local frame = modal.AbsolutePosition
    local size = modal.AbsoluteSize
    if pos.X < frame.X or pos.X > frame.X + size.X
    or pos.Y < frame.Y or pos.Y > frame.Y + size.Y then
        setOpen(false)
    end
end)
