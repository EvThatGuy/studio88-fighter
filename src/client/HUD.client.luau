--!strict
-- Player HUD: balance, current tier, leaderboard rank panel. Subscribes to
-- BalanceUpdated + LeaderboardUpdated remotes; never reads currency
-- client-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = Remotes.waitFor(15)

-- ----- UI build -----

local screen = Instance.new("ScreenGui")
screen.Name = "Studio88HUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local BG = Color3.fromRGB(8, 7, 13)
local PINK = Color3.fromRGB(255, 46, 136)
local CYAN = Color3.fromRGB(0, 240, 255)
local TEXT = Color3.fromRGB(248, 248, 242)

local function makeFrame(name: string, size: UDim2, pos: UDim2): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = BG
    f.BackgroundTransparency = 0.15
    f.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Color = PINK
    stroke.Thickness = 1
    stroke.Parent = f
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = f
    return f
end

local function makeLabel(name: string, parent: Instance, text: string, size: UDim2, pos: UDim2): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = TEXT
    l.Font = Enum.Font.GothamBold
    l.TextScaled = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- Balance panel (top-left)
local balancePanel = makeFrame("BalancePanel", UDim2.new(0, 240, 0, 70), UDim2.new(0, 16, 0, 16))
balancePanel.Parent = screen

local balanceTag = makeLabel("Tag", balancePanel, "COINS", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 6))
balanceTag.TextColor3 = CYAN
balanceTag.Font = Enum.Font.Code

local balanceValue = makeLabel("Value", balancePanel, "0", UDim2.new(1, -16, 0, 38), UDim2.new(0, 8, 0, 22))
balanceValue.TextColor3 = TEXT

local tierLabel = makeLabel("Tier", balancePanel, "Tier 1", UDim2.new(1, -16, 0, 12), UDim2.new(0, 8, 1, -16))
tierLabel.TextColor3 = PINK
tierLabel.Font = Enum.Font.Code

-- Leaderboard panel (top-right)
local lbPanel = makeFrame("LeaderboardPanel", UDim2.new(0, 280, 0, 380), UDim2.new(1, -296, 0, 16))
lbPanel.Parent = screen

local lbHeader = makeLabel("Header", lbPanel, "TOP 10 -- LIFETIME", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 6))
lbHeader.TextColor3 = CYAN
lbHeader.Font = Enum.Font.Code

local lbList = Instance.new("Frame")
lbList.Name = "List"
lbList.Size = UDim2.new(1, -16, 1, -28)
lbList.Position = UDim2.new(0, 8, 0, 24)
lbList.BackgroundTransparency = 1
lbList.Parent = lbPanel

local lbLayout = Instance.new("UIListLayout")
lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
lbLayout.Padding = UDim.new(0, 4)
lbLayout.Parent = lbList

-- ----- updates -----

local function fmt(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local function setBalance(coins: number, lifetime: number, tier: number?)
    balanceValue.Text = fmt(coins)
    if tier then tierLabel.Text = "Tier " .. tier end
end

-- First-time hint: on first BalanceUpdated of the session we know the
-- player has reached their plot and a coin was credited. Until then, show
-- a soft hint at the bottom of the screen telling them what to do.
local hintFrame: Frame? = nil
local function dismissHint()
    if not hintFrame then return end
    local f = hintFrame
    hintFrame = nil
    pcall(function()
        TweenService:Create(f, TweenInfo.new(0.4), {
            Position = UDim2.new(0.5, -180, 1, 80),
            BackgroundTransparency = 1,
        }):Play()
    end)
    task.delay(0.5, function() if f then f:Destroy() end end)
end

local function showHint()
    if hintFrame then return end
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 360, 0, 56)
    f.Position = UDim2.new(0.5, -180, 1, 80)
    f.BackgroundColor3 = BG
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1
    stroke.Parent = f
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = f
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, -8)
    lbl.Position = UDim2.new(0, 8, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = "walk to your plot -- it earns automatically"
    lbl.TextColor3 = CYAN
    lbl.Font = Enum.Font.Code
    lbl.TextScaled = true
    lbl.Parent = f
    f.Parent = screen
    hintFrame = f

    -- Slide up from below the screen
    pcall(function()
        TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -180, 1, -88),
        }):Play()
    end)

    -- Auto-dismiss after 30s if they never reach the plot, so it doesn't
    -- linger forever.
    task.delay(30, dismissHint)
end

-- Show the hint after a short grace period so it doesn't compete with
-- character spawn animations.
task.delay(2, showHint)

remotes.BalanceUpdated.OnClientEvent:Connect(function(coins, lifetime)
    setBalance(coins, lifetime)
    dismissHint()
end)

remotes.LeaderboardUpdated.OnClientEvent:Connect(function(rows)
    -- Clear existing
    for _, child in ipairs(lbList:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    for i, row in ipairs(rows) do
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, 0, 0, 28)
        entry.BackgroundTransparency = 1
        entry.Font = Enum.Font.Code
        entry.TextSize = 14
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextColor3 = (row.userId == player.UserId) and PINK or TEXT
        entry.Text = string.format("%2d. %-12s %s", i, row.name:sub(1, 12), fmt(row.lifetimeCoins))
        entry.LayoutOrder = i
        entry.Parent = lbList
    end
end)

-- Initial balance fetch via RemoteFunction so HUD shows real state on join.
task.spawn(function()
    local ok, result = pcall(function()
        return remotes.GetBalance:InvokeServer()
    end)
    if ok and result then
        setBalance(result.coins or 0, result.lifetimeCoins or 0, result.upgradeTier)
    end
end)

-- ----- Toast layer (daily-bonus banner + tier-up flash) -----

local AMBER = Color3.fromRGB(255, 176, 0)

-- Sound layer. SoundIds live in Constants.SOUND_IDS as either a stable
-- "rbxassetid://N" string or "" (empty). Empty short-circuits, so the
-- world is silent until David picks library assets and updates the table.
local function playSound(assetId: string?, volume: number?)
    if not assetId or assetId == "" or assetId == "0" then return end
    local s = Instance.new("Sound")
    s.SoundId = assetId
    s.Volume = volume or 0.6
    s.PlayOnRemove = false
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
    -- Defensive cleanup if Ended never fires (network failure on stream)
    task.delay(8, function() if s.Parent then s:Destroy() end end)
end

local function showToast(headline: string, sub: string, accent: Color3, holdSec: number?)
    -- Center-screen banner that fades in, holds, fades out. Stacks if called
    -- in quick succession (each toast is independent and self-cleans).
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 420, 0, 100)
    toast.Position = UDim2.new(0.5, -210, 0, -120)
    toast.BackgroundColor3 = BG
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    toast.Parent = screen

    local stroke = Instance.new("UIStroke")
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Parent = toast
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toast

    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, -16, 0.55, 0)
    head.Position = UDim2.new(0, 8, 0, 8)
    head.BackgroundTransparency = 1
    head.Text = headline
    head.TextColor3 = accent
    head.Font = Enum.Font.GothamBold
    head.TextScaled = true
    head.TextXAlignment = Enum.TextXAlignment.Left
    head.Parent = toast

    local sublbl = Instance.new("TextLabel")
    sublbl.Size = UDim2.new(1, -16, 0.45, -8)
    sublbl.Position = UDim2.new(0, 8, 0.55, 0)
    sublbl.BackgroundTransparency = 1
    sublbl.Text = sub
    sublbl.TextColor3 = TEXT
    sublbl.Font = Enum.Font.Code
    sublbl.TextScaled = true
    sublbl.TextXAlignment = Enum.TextXAlignment.Left
    sublbl.Parent = toast

    local enter = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0, 32),
    })
    enter:Play()

    task.delay(holdSec or 4, function()
        local exit = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -210, 0, -120),
            BackgroundTransparency = 1,
        })
        exit:Play()
        exit.Completed:Wait()
        toast:Destroy()
    end)
end

local function flashScreen(color: Color3, duration: number)
    -- Full-screen color flash for tier-up, fades from 0.5 transparency to
    -- fully transparent. Doesn't block input (CanvasGroup with no callbacks).
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.Position = UDim2.new(0, 0, 0, 0)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = 0.5
    flash.BorderSizePixel = 0
    flash.ZIndex = 0
    flash.Parent = screen

    local fade = TweenService:Create(flash, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    })
    fade:Play()
    fade.Completed:Wait()
    flash:Destroy()
end

remotes.DailyBonusGranted.OnClientEvent:Connect(function(streak: number, reward: number)
    showToast(
        string.format("DAY %d STREAK", streak),
        string.format("+%s coins -- come back tomorrow", fmt(reward)),
        AMBER,
        5
    )
    playSound(Constants.SOUND_IDS.daily_bonus, 0.6)
end)

remotes.TierUpgraded.OnClientEvent:Connect(function(newTier: number, mult: number)
    tierLabel.Text = "Tier " .. newTier
    showToast(
        string.format("TIER %d UNLOCKED", newTier),
        string.format("Income x%s", tostring(mult)),
        PINK,
        4
    )
    flashScreen(PINK, 0.6)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

local REJECTION_COPY: {[string]: {head: string, sub: string}} = {
    no_data = {head = "NOT READY", sub = "Save data still loading. Try again in a sec."},
    max_tier = {head = "MAX TIER", sub = "You've maxed every upgrade. Flex on the leaderboard."},
    insufficient_coins = {head = "NOT ENOUGH COINS", sub = "Need %s more"},
}

remotes.PurchaseRejected.OnClientEvent:Connect(function(reason: string, needed: number?)
    local copy = REJECTION_COPY[reason] or {head = "DENIED", sub = reason}
    local sub = copy.sub
    if reason == "insufficient_coins" and needed then
        sub = string.format(copy.sub, fmt(needed))
    end
    showToast(copy.head, sub, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
end)

print("[HUD] mounted")
