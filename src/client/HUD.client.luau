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
local AMBER = Color3.fromRGB(255, 176, 0)
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
local balancePanel = makeFrame("BalancePanel", UDim2.new(0, 240, 0, 84), UDim2.new(0, 16, 0, 16))
balancePanel.Parent = screen

local balanceTag = makeLabel("Tag", balancePanel, "COINS", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 6))
balanceTag.TextColor3 = CYAN
balanceTag.Font = Enum.Font.Code

local balanceValue = makeLabel("Value", balancePanel, "0", UDim2.new(1, -16, 0, 38), UDim2.new(0, 8, 0, 22))
balanceValue.TextColor3 = TEXT

local tierLabel = makeLabel("Tier", balancePanel, "Tier 1", UDim2.new(0, 120, 0, 12), UDim2.new(0, 8, 1, -16))
tierLabel.TextColor3 = PINK
tierLabel.Font = Enum.Font.Code

local rebirthLabel = makeLabel("Rebirths", balancePanel, "R: 0", UDim2.new(0, 96, 0, 12), UDim2.new(1, -104, 1, -16))
rebirthLabel.TextColor3 = CYAN
rebirthLabel.Font = Enum.Font.Code
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Rebirth button (bottom-left). Visible always; disabled-look until eligible.
-- Uses a TextButton (not Frame) so client can press it; server validates.
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthButton"
rebirthBtn.Size = UDim2.new(0, 240, 0, 56)
rebirthBtn.Position = UDim2.new(0, 16, 1, -72)
rebirthBtn.BackgroundColor3 = BG
rebirthBtn.BackgroundTransparency = 0.15
rebirthBtn.BorderSizePixel = 0
rebirthBtn.AutoButtonColor = false
rebirthBtn.Text = ""
rebirthBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 1; s.Parent = rebirthBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = rebirthBtn
end
local rebirthHead = makeLabel("Head", rebirthBtn, "REBIRTH", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 6))
rebirthHead.TextColor3 = CYAN
rebirthHead.Font = Enum.Font.Code
local rebirthSub = makeLabel("Sub", rebirthBtn, "reach max tier first", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 24))
rebirthSub.TextColor3 = TEXT
rebirthSub.Font = Enum.Font.Gotham
rebirthSub.TextTransparency = 0.4

-- Quests button (bottom-right, top of stack). Opens the daily quests modal.
-- Shows a small "n / 3" badge of how many of today's quests are claimable
-- so players see opportunity even before opening.
local questsBtn = Instance.new("TextButton")
questsBtn.Name = "QuestsButton"
questsBtn.Size = UDim2.new(0, 140, 0, 44)
questsBtn.Position = UDim2.new(1, -156, 1, -172)
questsBtn.BackgroundColor3 = BG
questsBtn.BackgroundTransparency = 0.15
questsBtn.BorderSizePixel = 0
questsBtn.AutoButtonColor = false
questsBtn.Text = ""
questsBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 1; s.Parent = questsBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = questsBtn
end
local questsLabel = makeLabel("Label", questsBtn, "* QUESTS", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
questsLabel.TextColor3 = CYAN
questsLabel.Font = Enum.Font.Code
questsLabel.TextXAlignment = Enum.TextXAlignment.Center

local questsBadge = Instance.new("TextLabel")
questsBadge.Name = "Badge"
questsBadge.Size = UDim2.new(0, 24, 0, 24)
questsBadge.Position = UDim2.new(1, -28, 0, -8)
questsBadge.BackgroundColor3 = AMBER
questsBadge.BorderSizePixel = 0
questsBadge.Text = ""
questsBadge.TextColor3 = BG
questsBadge.Font = Enum.Font.GothamBold
questsBadge.TextSize = 14
questsBadge.Visible = false
questsBadge.Parent = questsBtn
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = questsBadge
end

-- Passes button (bottom-right, above codes button). Opens the in-game
-- shop modal listing Starter Pack / VIP / Premium with their copy +
-- price + an OWNED badge once purchased.
local passesBtn = Instance.new("TextButton")
passesBtn.Name = "PassesButton"
passesBtn.Size = UDim2.new(0, 140, 0, 44)
passesBtn.Position = UDim2.new(1, -156, 1, -116)
passesBtn.BackgroundColor3 = BG
passesBtn.BackgroundTransparency = 0.15
passesBtn.BorderSizePixel = 0
passesBtn.AutoButtonColor = false
passesBtn.Text = ""
passesBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = AMBER; s.Thickness = 1; s.Parent = passesBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = passesBtn
end
local passesLabel = makeLabel("Label", passesBtn, "$ PASSES", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
passesLabel.TextColor3 = AMBER
passesLabel.Font = Enum.Font.Code
passesLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Codes button (bottom-right). Always visible; clicking opens the input
-- modal. Codes are advertised via @ModernGrindTech tweets / Discord pins.
local codesBtn = Instance.new("TextButton")
codesBtn.Name = "CodesButton"
codesBtn.Size = UDim2.new(0, 140, 0, 44)
codesBtn.Position = UDim2.new(1, -156, 1, -60)
codesBtn.BackgroundColor3 = BG
codesBtn.BackgroundTransparency = 0.15
codesBtn.BorderSizePixel = 0
codesBtn.AutoButtonColor = false
codesBtn.Text = ""
codesBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = PINK; s.Thickness = 1; s.Parent = codesBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = codesBtn
end
local codesLabel = makeLabel("Label", codesBtn, "+ CODES", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
codesLabel.TextColor3 = PINK
codesLabel.Font = Enum.Font.Code
codesLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Codes input modal (hidden by default). Center-screen, click-blocks via
-- the parent ScreenGui order. ESC or the X button dismisses.
local codesModal = Instance.new("Frame")
codesModal.Name = "CodesModal"
codesModal.Size = UDim2.new(0, 380, 0, 180)
codesModal.Position = UDim2.new(0.5, -190, 0.5, -90)
codesModal.BackgroundColor3 = BG
codesModal.BackgroundTransparency = 0.05
codesModal.BorderSizePixel = 0
codesModal.Visible = false
codesModal.ZIndex = 50
codesModal.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = PINK; s.Thickness = 2; s.Parent = codesModal
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = codesModal
end
local modalHead = makeLabel("Head", codesModal, "REDEEM CODE", UDim2.new(1, -32, 0, 22), UDim2.new(0, 16, 0, 12))
modalHead.TextColor3 = PINK
modalHead.Font = Enum.Font.GothamBold
modalHead.ZIndex = 51

local modalSub = makeLabel("Sub", codesModal, "type the code from @ModernGrindTech", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 36))
modalSub.TextColor3 = TEXT
modalSub.Font = Enum.Font.Code
modalSub.TextTransparency = 0.3
modalSub.ZIndex = 51

local codeBox = Instance.new("TextBox")
codeBox.Name = "CodeInput"
codeBox.Size = UDim2.new(1, -32, 0, 44)
codeBox.Position = UDim2.new(0, 16, 0, 64)
codeBox.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
codeBox.BackgroundTransparency = 0
codeBox.BorderSizePixel = 0
codeBox.Text = ""
codeBox.PlaceholderText = "e.g. LAUNCH"
codeBox.PlaceholderColor3 = Color3.fromRGB(96, 96, 110)
codeBox.TextColor3 = TEXT
codeBox.Font = Enum.Font.Code
codeBox.TextScaled = true
codeBox.ClearTextOnFocus = false
codeBox.MultiLine = false
codeBox.ZIndex = 51
codeBox.Parent = codesModal
do
    local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 1; s.Parent = codeBox
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = codeBox
end

local submitBtn = Instance.new("TextButton")
submitBtn.Name = "Submit"
submitBtn.Size = UDim2.new(0, 100, 0, 36)
submitBtn.Position = UDim2.new(1, -116, 1, -52)
submitBtn.BackgroundColor3 = PINK
submitBtn.BorderSizePixel = 0
submitBtn.Text = "REDEEM"
submitBtn.TextColor3 = BG
submitBtn.Font = Enum.Font.GothamBold
submitBtn.TextSize = 16
submitBtn.ZIndex = 51
submitBtn.Parent = codesModal
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = submitBtn
end

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = TEXT
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.ZIndex = 51
closeBtn.Parent = codesModal

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

-- Mirror of last-known server state so the rebirth button can decide whether
-- it's eligible without re-pinging the server on every tick. Updated by
-- BalanceUpdated, TierUpgraded, RebirthGranted, and the initial GetBalance.
local localState = {
    coins = 0,
    lifetimeCoins = 0,
    upgradeTier = 1,
    rebirths = 0,
}

local MAX_TIER = #Constants.UPGRADE_TIERS

local function refreshRebirthButton()
    local rb = localState.rebirths
    local atMaxTier = localState.upgradeTier >= MAX_TIER
    local hasLifetime = localState.lifetimeCoins >= Constants.REBIRTH_MIN_LIFETIME_COINS
    local atMaxRebirths = rb >= Constants.REBIRTH_MAX
    local eligible = atMaxTier and hasLifetime and not atMaxRebirths
    if atMaxRebirths then
        rebirthHead.Text = "MAX REBIRTHS"
        rebirthSub.Text = string.format("R%d perma x%.2f", rb, 1 + rb * Constants.REBIRTH_BONUS_PER)
        rebirthSub.TextTransparency = 0.4
    elseif eligible then
        local nextMult = 1 + (rb + 1) * Constants.REBIRTH_BONUS_PER
        rebirthHead.Text = "REBIRTH READY"
        rebirthSub.Text = string.format("press to prestige - new perma x%.2f", nextMult)
        rebirthSub.TextTransparency = 0
    elseif not atMaxTier then
        rebirthHead.Text = "REBIRTH"
        rebirthSub.Text = string.format("reach tier %d first", MAX_TIER)
        rebirthSub.TextTransparency = 0.4
    else
        local need = Constants.REBIRTH_MIN_LIFETIME_COINS - localState.lifetimeCoins
        rebirthHead.Text = "REBIRTH"
        rebirthSub.Text = string.format("earn %s more lifetime coins", fmt(math.max(0, need)))
        rebirthSub.TextTransparency = 0.4
    end
end

local function setBalance(coins: number, lifetime: number, tier: number?, rebirths: number?)
    localState.coins = coins
    localState.lifetimeCoins = lifetime
    if tier then localState.upgradeTier = tier end
    if rebirths then localState.rebirths = rebirths end
    balanceValue.Text = fmt(coins)
    if tier then tierLabel.Text = "Tier " .. tier end
    rebirthLabel.Text = "R: " .. localState.rebirths
    refreshRebirthButton()
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

-- Click handler: ask the server to rebirth. Server validates eligibility
-- (we don't trust the client's button-enabled state). Either RebirthGranted
-- or RebirthRejected fires back.
rebirthBtn.MouseButton1Click:Connect(function()
    pcall(function()
        remotes.RequestRebirth:FireServer()
    end)
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
        setBalance(result.coins or 0, result.lifetimeCoins or 0, result.upgradeTier, result.rebirths)
    end
end)

-- ----- Toast layer (daily-bonus banner + tier-up flash) -----

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
    localState.upgradeTier = newTier
    refreshRebirthButton()
    showToast(
        string.format("TIER %d UNLOCKED", newTier),
        string.format("Income x%s", tostring(mult)),
        PINK,
        4
    )
    flashScreen(PINK, 0.6)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

remotes.RebirthGranted.OnClientEvent:Connect(function(rebirths: number, newMult: number)
    -- Server has reset coins/tier server-side; the next BalanceUpdated will
    -- carry the zero. Update local mirror for the button copy + label.
    localState.rebirths = rebirths
    localState.upgradeTier = 1
    localState.coins = 0
    rebirthLabel.Text = "R: " .. rebirths
    tierLabel.Text = "Tier 1"
    balanceValue.Text = "0"
    refreshRebirthButton()
    showToast(
        string.format("REBIRTH #%d", rebirths),
        string.format("perma income x%.2f -- climb again, faster", newMult),
        CYAN,
        6
    )
    flashScreen(CYAN, 0.8)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

local REBIRTH_REJECTION_COPY: {[string]: string} = {
    no_data = "Save data still loading. Try again in a sec.",
    min_tier = "You need to reach the max upgrade tier first.",
    insufficient_lifetime = "Earn %s more lifetime coins first.",
    max_rebirths = "You're already at max rebirths. Flex on the leaderboard.",
}

remotes.RebirthRejected.OnClientEvent:Connect(function(reason: string, needed: number?)
    local sub = REBIRTH_REJECTION_COPY[reason] or reason
    if reason == "insufficient_lifetime" and needed then
        sub = string.format(REBIRTH_REJECTION_COPY[reason], fmt(needed))
    end
    showToast("CAN'T REBIRTH YET", sub, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
end)

-- ----- Passes modal -----
-- Built lazily on first open so we can fetch ownership server-side first.

local MarketplaceService = game:GetService("MarketplaceService")

local passesModal: Frame? = nil
local passOwnership: {[string]: boolean} = {}

local ACCENT_BY_NAME: {[string]: Color3} = {
    amber = AMBER,
    pink = PINK,
    cyan = CYAN,
}

local function buildPassesModal()
    local m = Instance.new("Frame")
    m.Name = "PassesModal"
    m.Size = UDim2.new(0, 460, 0, 480)
    m.Position = UDim2.new(0.5, -230, 0.5, -240)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = AMBER; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "PASSES", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = AMBER
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51

    local sub = makeLabel("Sub", m, "permanent multipliers + perks", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
    sub.TextColor3 = TEXT
    sub.Font = Enum.Font.Code
    sub.TextTransparency = 0.3
    sub.ZIndex = 51

    -- X close
    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 24, 0, 24)
    x.Position = UDim2.new(1, -32, 0, 8)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = TEXT
    x.Font = Enum.Font.GothamBold
    x.TextSize = 18
    x.ZIndex = 51
    x.Parent = m
    x.MouseButton1Click:Connect(function() m.Visible = false end)

    -- 3 cards stacked. List layout for clean spacing.
    local list = Instance.new("Frame")
    list.Name = "Cards"
    list.Size = UDim2.new(1, -32, 1, -88)
    list.Position = UDim2.new(0, 16, 0, 72)
    list.BackgroundTransparency = 1
    list.ZIndex = 51
    list.Parent = m
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = list

    for order, key in ipairs(Constants.GAME_PASS_ORDER) do
        local meta = Constants.GAME_PASS_DISPLAY[key]
        local passId = Constants.GAME_PASSES[key]
        if not meta then continue end
        local accent = ACCENT_BY_NAME[meta.accent] or PINK

        local card = Instance.new("Frame")
        card.Name = "Card_" .. key
        card.Size = UDim2.new(1, 0, 0, 116)
        card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        card.BorderSizePixel = 0
        card.ZIndex = 52
        card.LayoutOrder = order
        card.Parent = list
        do
            local s = Instance.new("UIStroke"); s.Color = accent; s.Thickness = 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end

        local title = makeLabel("Title", card, meta.title, UDim2.new(1, -160, 0, 22), UDim2.new(0, 12, 0, 10))
        title.TextColor3 = accent
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 53

        local copy = makeLabel("Copy", card, meta.copy, UDim2.new(1, -160, 0, 18), UDim2.new(0, 12, 0, 36))
        copy.TextColor3 = TEXT
        copy.Font = Enum.Font.Code
        copy.ZIndex = 53

        local subc = makeLabel("Sub", card, meta.sub, UDim2.new(1, -160, 0, 36), UDim2.new(0, 12, 0, 60))
        subc.TextColor3 = TEXT
        subc.TextTransparency = 0.4
        subc.Font = Enum.Font.Gotham
        subc.TextWrapped = true
        subc.TextScaled = false
        subc.TextSize = 12
        subc.ZIndex = 53

        local btn = Instance.new("TextButton")
        btn.Name = "Buy"
        btn.Size = UDim2.new(0, 130, 0, 50)
        btn.Position = UDim2.new(1, -142, 0.5, -25)
        btn.BackgroundColor3 = accent
        btn.BorderSizePixel = 0
        btn.Text = string.format("R$ %d", meta.priceRobux)
        btn.TextColor3 = BG
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 18
        btn.ZIndex = 53
        btn.Parent = card
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        end

        local function refreshState()
            if passOwnership[key] then
                btn.Text = "OWNED"
                btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                btn.TextColor3 = TEXT
                btn.AutoButtonColor = false
                btn.Active = false
            elseif passId == 0 then
                btn.Text = "SOON"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                btn.TextColor3 = TEXT
                btn.AutoButtonColor = false
                btn.Active = false
            else
                btn.Text = string.format("R$ %d", meta.priceRobux)
                btn.BackgroundColor3 = accent
                btn.TextColor3 = BG
                btn.AutoButtonColor = true
                btn.Active = true
            end
        end
        refreshState()
        card:SetAttribute("Key", key)

        btn.MouseButton1Click:Connect(function()
            if passOwnership[key] or passId == 0 then return end
            pcall(function()
                MarketplaceService:PromptGamePassPurchase(player, passId)
            end)
        end)
    end

    return m
end

local function refreshOwnership()
    task.spawn(function()
        local ok, result = pcall(function()
            return remotes.GetPassOwnership:InvokeServer()
        end)
        if not ok or typeof(result) ~= "table" then return end
        passOwnership = result
        if not passesModal then return end
        for _, card in ipairs(passesModal:FindFirstChild("Cards"):GetChildren()) do
            if card:IsA("Frame") then
                local key = card:GetAttribute("Key") :: string?
                if not key then continue end
                local btn = card:FindFirstChild("Buy") :: TextButton?
                local meta = Constants.GAME_PASS_DISPLAY[key]
                local passId = Constants.GAME_PASSES[key]
                if not btn or not meta then continue end
                if passOwnership[key] then
                    btn.Text = "OWNED"
                    btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                    btn.TextColor3 = TEXT
                    btn.AutoButtonColor = false
                    btn.Active = false
                elseif passId == 0 then
                    btn.Text = "SOON"
                    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                    btn.TextColor3 = TEXT
                    btn.AutoButtonColor = false
                    btn.Active = false
                else
                    btn.Text = string.format("R$ %d", meta.priceRobux)
                    btn.BackgroundColor3 = ACCENT_BY_NAME[meta.accent] or PINK
                    btn.TextColor3 = BG
                    btn.AutoButtonColor = true
                    btn.Active = true
                end
            end
        end
    end)
end

local function openPassesModal()
    if not passesModal then passesModal = buildPassesModal() end
    passesModal.Visible = true
    refreshOwnership()
end

passesBtn.MouseButton1Click:Connect(openPassesModal)

remotes.PassPurchased.OnClientEvent:Connect(function(passKey: string, passId: number)
    passOwnership[passKey] = true
    if passesModal and passesModal.Visible then refreshOwnership() end
    local meta = Constants.GAME_PASS_DISPLAY[passKey]
    local title = (meta and meta.title) or passKey
    local copy = (meta and meta.copy) or "purchase complete"
    showToast(string.format("%s ACTIVATED", title), copy, ACCENT_BY_NAME[meta and meta.accent or "pink"] or PINK, 5)
    flashScreen(ACCENT_BY_NAME[meta and meta.accent or "pink"] or PINK, 0.6)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

-- Initial fetch so first open is instant.
refreshOwnership()

-- ----- Codes modal wiring -----

local function openCodesModal()
    codeBox.Text = ""
    codesModal.Visible = true
    -- Pop a half-second after modal becomes visible so focus lands cleanly
    task.delay(0.05, function()
        if codesModal.Visible then codeBox:CaptureFocus() end
    end)
end

local function closeCodesModal()
    codesModal.Visible = false
end

local function submitCode()
    local raw = codeBox.Text or ""
    if #raw == 0 then return end
    pcall(function()
        remotes.RequestRedeemCode:FireServer(raw)
    end)
    -- Keep modal open until server responds; CodeRedeemed closes it,
    -- CodeRejected leaves it open so the player can try another spelling.
end

codesBtn.MouseButton1Click:Connect(openCodesModal)
closeBtn.MouseButton1Click:Connect(closeCodesModal)
submitBtn.MouseButton1Click:Connect(submitCode)
codeBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then submitCode() end
end)

remotes.CodeRedeemed.OnClientEvent:Connect(function(code: string, reward: number)
    closeCodesModal()
    showToast(
        string.format("+%s COINS", fmt(reward)),
        string.format("code '%s' redeemed", code),
        PINK,
        4
    )
    flashScreen(PINK, 0.5)
    playSound(Constants.SOUND_IDS.daily_bonus, 0.6)
end)

local CODE_REJECTION_COPY: {[string]: string} = {
    rate_limited = "Slow down -- one redeem at a time.",
    empty = "Type the code first.",
    unknown = "Code '%s' isn't valid. Check spelling.",
    expired = "Code '%s' has expired.",
    no_data = "Save data still loading. Try again in a sec.",
    already_redeemed = "You already redeemed '%s'.",
    cap_reached = "Code '%s' hit its global cap. Sorry!",
}

remotes.CodeRejected.OnClientEvent:Connect(function(code: string, reason: string)
    local template = CODE_REJECTION_COPY[reason] or reason
    local sub = template
    if string.find(template, "%%s") then
        sub = string.format(template, code ~= "" and code or "(blank)")
    end
    showToast("CODE REJECTED", sub, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
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

-- ----- Quests modal -----
-- Built lazily on first open; refreshes from server when opened or when a
-- QuestProgressed / QuestClaimed event fires.

local questsModal: Frame? = nil
local questCardsByQuestId: {[string]: Frame} = {}
local questsState: {dateKey: string, quests: {any}}? = nil

local function fmtProgress(progress: number, target: number): string
    return string.format("%s / %s", fmt(progress), fmt(target))
end

local function buildQuestsModal()
    local m = Instance.new("Frame")
    m.Name = "QuestsModal"
    m.Size = UDim2.new(0, 460, 0, 460)
    m.Position = UDim2.new(0.5, -230, 0.5, -230)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "DAILY QUESTS", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = CYAN
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51

    local sub = makeLabel("Sub", m, "resets at midnight UTC -- come back tomorrow", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
    sub.TextColor3 = TEXT
    sub.Font = Enum.Font.Code
    sub.TextTransparency = 0.3
    sub.ZIndex = 51

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 24, 0, 24)
    x.Position = UDim2.new(1, -32, 0, 8)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = TEXT
    x.Font = Enum.Font.GothamBold
    x.TextSize = 18
    x.ZIndex = 51
    x.Parent = m
    x.MouseButton1Click:Connect(function() m.Visible = false end)

    local list = Instance.new("Frame")
    list.Name = "Cards"
    list.Size = UDim2.new(1, -32, 1, -88)
    list.Position = UDim2.new(0, 16, 0, 72)
    list.BackgroundTransparency = 1
    list.ZIndex = 51
    list.Parent = m
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = list

    return m
end

local function buildQuestCard(parent: Instance, q: any, order: number): Frame
    local card = Instance.new("Frame")
    card.Name = "Quest_" .. q.id
    card.Size = UDim2.new(1, 0, 0, 116)
    card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
    card.BorderSizePixel = 0
    card.ZIndex = 52
    card.LayoutOrder = order
    card.Parent = parent
    do
        local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 1; s.Parent = card
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
    end

    local title = makeLabel("Title", card, q.label, UDim2.new(1, -160, 0, 22), UDim2.new(0, 12, 0, 10))
    title.TextColor3 = TEXT
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 53

    local progressText = makeLabel("Progress", card, fmtProgress(q.progress, q.target), UDim2.new(1, -160, 0, 18), UDim2.new(0, 12, 0, 36))
    progressText.TextColor3 = CYAN
    progressText.Font = Enum.Font.Code
    progressText.ZIndex = 53

    -- Progress bar
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, -160, 0, 8)
    barBg.Position = UDim2.new(0, 12, 0, 60)
    barBg.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 53
    barBg.Parent = card
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = barBg
    end
    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.new(math.min(1, q.progress / q.target), 0, 1, 0)
    barFill.BackgroundColor3 = q.complete and AMBER or CYAN
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 54
    barFill.Parent = barBg
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = barFill
    end

    local reward = makeLabel("Reward", card, string.format("+%s coins", fmt(q.reward)), UDim2.new(1, -160, 0, 18), UDim2.new(0, 12, 0, 78))
    reward.TextColor3 = AMBER
    reward.Font = Enum.Font.Code
    reward.ZIndex = 53

    local btn = Instance.new("TextButton")
    btn.Name = "Claim"
    btn.Size = UDim2.new(0, 130, 0, 50)
    btn.Position = UDim2.new(1, -142, 0.5, -25)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.ZIndex = 53
    btn.Parent = card
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    end
    if q.claimed then
        btn.Text = "CLAIMED"
        btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        btn.TextColor3 = TEXT
        btn.AutoButtonColor = false
        btn.Active = false
    elseif q.complete then
        btn.Text = "CLAIM"
        btn.BackgroundColor3 = AMBER
        btn.TextColor3 = BG
        btn.AutoButtonColor = true
        btn.Active = true
    else
        btn.Text = "IN PROGRESS"
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.TextColor3 = TEXT
        btn.AutoButtonColor = false
        btn.Active = false
    end
    btn.MouseButton1Click:Connect(function()
        if not q.complete or q.claimed then return end
        pcall(function()
            remotes.ClaimQuest:FireServer(q.id)
        end)
    end)

    card:SetAttribute("QuestId", q.id)
    return card
end

local function applyQuestStateToCard(card: Frame, q: any)
    local progressText = card:FindFirstChild("Progress") :: TextLabel?
    if progressText then progressText.Text = fmtProgress(q.progress, q.target) end
    local barBg = card:FindFirstChild("BarBg")
    local barFill = barBg and barBg:FindFirstChild("BarFill") :: Frame?
    if barFill then
        barFill.Size = UDim2.new(math.min(1, q.progress / q.target), 0, 1, 0)
        barFill.BackgroundColor3 = (q.claimed or q.complete) and AMBER or CYAN
    end
    local btn = card:FindFirstChild("Claim") :: TextButton?
    if btn then
        if q.claimed then
            btn.Text = "CLAIMED"
            btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            btn.TextColor3 = TEXT
            btn.AutoButtonColor = false
            btn.Active = false
        elseif q.complete then
            btn.Text = "CLAIM"
            btn.BackgroundColor3 = AMBER
            btn.TextColor3 = BG
            btn.AutoButtonColor = true
            btn.Active = true
        else
            btn.Text = "IN PROGRESS"
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            btn.TextColor3 = TEXT
            btn.AutoButtonColor = false
            btn.Active = false
        end
    end
end

local function refreshBadge()
    if not questsState then
        questsBadge.Visible = false
        return
    end
    local count = 0
    for _, q in ipairs(questsState.quests) do
        if q.complete and not q.claimed then count += 1 end
    end
    if count > 0 then
        questsBadge.Visible = true
        questsBadge.Text = tostring(count)
    else
        questsBadge.Visible = false
    end
end

local function renderQuests(state: any)
    questsState = state
    if not questsModal then return end
    local list = questsModal:FindFirstChild("Cards")
    if not list then return end
    -- Rebuild card map idempotently. Reuse existing cards if their QuestId
    -- matches; otherwise destroy + recreate.
    local seenIds: {[string]: boolean} = {}
    for order, q in ipairs(state.quests) do
        seenIds[q.id] = true
        local card = questCardsByQuestId[q.id]
        if card and card.Parent ~= list then card = nil end
        if not card then
            card = buildQuestCard(list, q, order)
            questCardsByQuestId[q.id] = card
        else
            applyQuestStateToCard(card, q)
        end
    end
    -- Drop stale cards (from yesterday's quests)
    for id, card in pairs(questCardsByQuestId) do
        if not seenIds[id] then
            card:Destroy()
            questCardsByQuestId[id] = nil
        end
    end
    refreshBadge()
end

local function refreshQuests()
    task.spawn(function()
        local ok, result = pcall(function()
            return remotes.GetDailyQuests:InvokeServer()
        end)
        if ok and result and result.quests then
            renderQuests(result)
        end
    end)
end

local function openQuestsModal()
    if not questsModal then questsModal = buildQuestsModal() end
    questsModal.Visible = true
    refreshQuests()
end

questsBtn.MouseButton1Click:Connect(openQuestsModal)

remotes.QuestProgressed.OnClientEvent:Connect(function(questId: string, progress: number, target: number)
    if not questsState then return end
    for _, q in ipairs(questsState.quests) do
        if q.id == questId then
            q.progress = progress
            q.complete = progress >= target
            local card = questCardsByQuestId[questId]
            if card then applyQuestStateToCard(card, q) end
            break
        end
    end
    refreshBadge()
end)

remotes.QuestClaimed.OnClientEvent:Connect(function(questId: string, reward: number)
    if questsState then
        for _, q in ipairs(questsState.quests) do
            if q.id == questId then
                q.claimed = true
                local card = questCardsByQuestId[questId]
                if card then applyQuestStateToCard(card, q) end
                break
            end
        end
    end
    refreshBadge()
    showToast(
        string.format("+%s COINS", fmt(reward)),
        "daily quest claimed",
        AMBER,
        4
    )
    flashScreen(AMBER, 0.5)
    playSound(Constants.SOUND_IDS.daily_bonus, 0.6)
end)

local QUEST_REJECTION_COPY: {[string]: string} = {
    no_data = "Save data still loading.",
    bad_request = "Invalid quest.",
    not_today = "That quest isn't active today.",
    already_claimed = "Already claimed.",
    not_complete = "Finish the quest first.",
}

remotes.QuestRejected.OnClientEvent:Connect(function(questId: string, reason: string)
    showToast("CAN'T CLAIM", QUEST_REJECTION_COPY[reason] or reason, AMBER, 3)
end)

-- Initial fetch so the badge counter is accurate on join.
refreshQuests()

print("[HUD] mounted")
