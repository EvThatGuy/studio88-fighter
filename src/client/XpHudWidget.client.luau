--!strict
-- Bottom-left XP HUD widget. Shows "LEVEL N · X/Y XP" with a thin amber
-- progress bar. Refreshes on XpLeveledUp + every 30s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local CYAN = Color3.fromRGB(0, 240, 255)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtXp(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.1fM", n / 1000000)
end

local widget: ScreenGui? = nil
local labelRef: TextLabel? = nil
local barFillRef: Frame? = nil

local function makeWidget()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88XpWidget")
    if existing then existing:Destroy() end

    widget = Instance.new("ScreenGui")
    widget.Name = "Studio88XpWidget"
    widget.ResetOnSpawn = false
    widget.IgnoreGuiInset = false
    widget.DisplayOrder = 70
    widget.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0, 1)
    card.Position = UDim2.new(0, 16, 1, -16)
    card.Size = UDim2.new(0, 220, 0, 50)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = widget
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 0, 22)
    label.Position = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = "LEVEL — · — XP"
    label.TextColor3 = AMBER
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card
    labelRef = label

    -- Progress bar
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -16, 0, 8)
    barBg.Position = UDim2.new(0, 8, 0, 32)
    barBg.BackgroundColor3 = DARK
    barBg.BackgroundTransparency = 0.3
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0.5, 0)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = AMBER
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0.5, 0)
    barFillRef = barFill
end

local function refresh()
    local lbl = labelRef
    local bar = barFillRef
    if not lbl or not bar or not lbl.Parent then return end
    pcall(function()
        local snap = remotes.GetXpSnapshot:InvokeServer()
        if not snap then return end
        local lvl = snap.level or 1
        local xp = snap.xp or 0
        local prev = snap.prevThreshold or 0
        local nxt = snap.nextThreshold
        if nxt then
            local progress = (xp - prev) / math.max(1, (nxt - prev))
            progress = math.clamp(progress, 0, 1)
            lbl.Text = string.format("LEVEL %d · %s/%s XP",
                lvl, fmtXp(xp - prev), fmtXp(nxt - prev))
            bar.Size = UDim2.new(progress, 0, 1, 0)
        else
            lbl.Text = string.format("LEVEL %d · MAX", lvl)
            bar.Size = UDim2.new(1, 0, 1, 0)
        end
    end)
end

makeWidget()
player.CharacterAdded:Connect(function()
    -- Re-mount on respawn (PlayerGui rebuilds); refresh after
    task.wait(0.5)
    makeWidget()
    refresh()
end)

-- Initial fetch + 30s loop + on-level-up event
task.spawn(function()
    task.wait(2)
    refresh()
    while widget and widget.Parent do
        task.wait(30)
        refresh()
    end
end)

remotes.XpLeveledUp.OnClientEvent:Connect(function() refresh() end)

print("[XpHudWidget] client ready")
