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

-- Rebirth shop button (bottom-left, above rebirth button). Always visible;
-- modal lists permanent unlock items priced in Rebirth Tokens.
local rebirthShopBtn = Instance.new("TextButton")
rebirthShopBtn.Name = "RebirthShopButton"
rebirthShopBtn.Size = UDim2.new(0, 240, 0, 36)
rebirthShopBtn.Position = UDim2.new(0, 16, 1, -116)
rebirthShopBtn.BackgroundColor3 = BG
rebirthShopBtn.BackgroundTransparency = 0.15
rebirthShopBtn.BorderSizePixel = 0
rebirthShopBtn.AutoButtonColor = false
rebirthShopBtn.Text = ""
rebirthShopBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(180, 100, 240); s.Thickness = 1; s.Parent = rebirthShopBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = rebirthShopBtn
end
local rebirthShopLbl = makeLabel("Label", rebirthShopBtn, "REBIRTH SHOP", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
rebirthShopLbl.TextColor3 = Color3.fromRGB(180, 100, 240)
rebirthShopLbl.Font = Enum.Font.Code
rebirthShopLbl.TextXAlignment = Enum.TextXAlignment.Center

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

-- Pets button (bottom-right, top of stack above Quests). Opens egg-hatch +
-- inventory modal.
local petsBtn = Instance.new("TextButton")
petsBtn.Name = "PetsButton"
petsBtn.Size = UDim2.new(0, 140, 0, 44)
petsBtn.Position = UDim2.new(1, -156, 1, -228)
petsBtn.BackgroundColor3 = BG
petsBtn.BackgroundTransparency = 0.15
petsBtn.BorderSizePixel = 0
petsBtn.AutoButtonColor = false
petsBtn.Text = ""
petsBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(110, 220, 110); s.Thickness = 1; s.Parent = petsBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = petsBtn
end
local petsLabel = makeLabel("Label", petsBtn, "* PETS", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
petsLabel.TextColor3 = Color3.fromRGB(110, 220, 110)
petsLabel.Font = Enum.Font.Code
petsLabel.TextXAlignment = Enum.TextXAlignment.Center

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
codesModal.Size = UDim2.new(0, 380, 0, 320)
codesModal.Position = UDim2.new(0.5, -190, 0.5, -160)
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
submitBtn.Position = UDim2.new(1, -116, 0, 116)
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

-- Friend code section (bottom of codes modal)
local friendDiv = Instance.new("Frame")
friendDiv.Size = UDim2.new(1, -32, 0, 1)
friendDiv.Position = UDim2.new(0, 16, 0, 168)
friendDiv.BackgroundColor3 = Color3.fromRGB(60, 56, 80)
friendDiv.BorderSizePixel = 0
friendDiv.ZIndex = 51
friendDiv.Parent = codesModal

local friendHead = makeLabel("FriendHead", codesModal, "YOUR FRIEND CODE", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 178))
friendHead.TextColor3 = CYAN
friendHead.Font = Enum.Font.GothamBold
friendHead.TextSize = 12
friendHead.ZIndex = 51

local friendCodeBox = Instance.new("TextBox")
friendCodeBox.Name = "FriendCode"
friendCodeBox.Size = UDim2.new(1, -32, 0, 36)
friendCodeBox.Position = UDim2.new(0, 16, 0, 198)
friendCodeBox.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
friendCodeBox.BorderSizePixel = 0
friendCodeBox.Text = "loading..."
friendCodeBox.TextEditable = false
friendCodeBox.ClearTextOnFocus = false
friendCodeBox.TextColor3 = CYAN
friendCodeBox.Font = Enum.Font.GothamBold
friendCodeBox.TextScaled = true
friendCodeBox.ZIndex = 51
friendCodeBox.Parent = codesModal
do
    local s = Instance.new("UIStroke"); s.Color = CYAN; s.Thickness = 1; s.Parent = friendCodeBox
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = friendCodeBox
end

local friendStat = makeLabel("FriendStat", codesModal, "share with friends -- both get a coin bonus when they redeem",
    UDim2.new(1, -32, 0, 14), UDim2.new(0, 16, 0, 240))
friendStat.TextColor3 = TEXT
friendStat.Font = Enum.Font.Code
friendStat.TextSize = 11
friendStat.TextTransparency = 0.4
friendStat.ZIndex = 51

local friendCount = makeLabel("FriendCount", codesModal, "0 friends used your code -> +0 coins lifetime",
    UDim2.new(1, -32, 0, 14), UDim2.new(0, 16, 0, 258))
friendCount.TextColor3 = AMBER
friendCount.Font = Enum.Font.GothamBold
friendCount.TextSize = 11
friendCount.ZIndex = 51

local function refreshFriendCode()
    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetFriendCode:InvokeServer() end)
        if not ok or not snap then return end
        if snap.friendCode and snap.friendCode ~= "" then
            friendCodeBox.Text = snap.friendCode
        else
            friendCodeBox.Text = "(generating...)"
        end
        local count = snap.referralCount or 0
        friendCount.Text = string.format("%d friend%s used your code -> +%s coins earned",
            count, count == 1 and "" or "s", fmt(count * snap.referrerBonus))
        if snap.referredBy then
            friendStat.Text = "you were referred by " .. snap.referredBy
            friendStat.TextColor3 = CYAN
            friendStat.TextTransparency = 0.1
        else
            friendStat.Text = string.format("share with friends -- new player gets +%s, you get +%s each",
                fmt(snap.referredBonus), fmt(snap.referrerBonus))
        end
    end)
end

remotes.ReferralBonusGranted.OnClientEvent:Connect(function(sourceCount: number, totalBonus: number)
    showToast(string.format("+%d FRIEND%s", sourceCount, sourceCount == 1 and "" or "S"),
        string.format("+%s coins from referrals", fmt(totalBonus)),
        CYAN, 4)
    flashScreen(CYAN, 0.5)
    refreshFriendCode()
end)

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
    refreshFriendCode()
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

-- ----- Live event countdown banner -----
-- Top-center, only visible when EventStateChanged says active=true. Shows
-- event name + multiplier + countdown like "WEEKEND 2X - ends in 1d 4h 22m".

local eventBanner: Frame? = nil
local eventState: {active: boolean, event: any?, endsInSec: number?} = { active = false }

local function fmtCountdown(sec: number): string
    if sec <= 0 then return "ending..." end
    local d = math.floor(sec / 86400)
    sec %= 86400
    local h = math.floor(sec / 3600)
    sec %= 3600
    local m = math.floor(sec / 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, sec % 60) end
    return string.format("%ds", sec)
end

local function colorFor(name: string?): Color3
    if name == "amber" then return AMBER end
    if name == "cyan" then return CYAN end
    if name == "purple" then return Color3.fromRGB(180, 100, 240) end
    return PINK
end

local function buildEventBanner()
    local b = Instance.new("Frame")
    b.Name = "EventBanner"
    b.Size = UDim2.new(0, 380, 0, 56)
    b.Position = UDim2.new(0.5, -190, 0, 16)
    b.BackgroundColor3 = BG
    b.BackgroundTransparency = 0.05
    b.BorderSizePixel = 0
    b.ZIndex = 30
    b.Visible = false
    b.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = AMBER; s.Thickness = 2; s.Parent = b
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
    end
    local head = Instance.new("TextLabel")
    head.Name = "Head"
    head.Size = UDim2.new(1, -16, 0, 22)
    head.Position = UDim2.new(0, 8, 0, 6)
    head.BackgroundTransparency = 1
    head.TextColor3 = AMBER
    head.Font = Enum.Font.GothamBold
    head.TextScaled = true
    head.TextXAlignment = Enum.TextXAlignment.Left
    head.Text = ""
    head.ZIndex = 31
    head.Parent = b

    local count = Instance.new("TextLabel")
    count.Name = "Count"
    count.Size = UDim2.new(1, -16, 0, 20)
    count.Position = UDim2.new(0, 8, 0, 30)
    count.BackgroundTransparency = 1
    count.TextColor3 = TEXT
    count.Font = Enum.Font.Code
    count.TextScaled = true
    count.TextXAlignment = Enum.TextXAlignment.Left
    count.Text = ""
    count.ZIndex = 31
    count.Parent = b
    return b
end

local function applyEventBanner()
    if not eventBanner then eventBanner = buildEventBanner() end
    if not eventState.active or not eventState.event then
        eventBanner.Visible = false
        return
    end
    local e = eventState.event
    eventBanner.Visible = true
    local accent = colorFor(e.color)
    local stroke = eventBanner:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Color = accent end
    local head = eventBanner:FindFirstChild("Head") :: TextLabel?
    local count = eventBanner:FindFirstChild("Count") :: TextLabel?
    if head then
        head.Text = string.format("%s  x%.1f", e.name, e.multiplier)
        head.TextColor3 = accent
    end
    if count then
        count.Text = string.format("ends in %s -- %s",
            fmtCountdown(eventState.endsInSec or 0),
            e.sub or "")
    end
end

remotes.EventStateChanged.OnClientEvent:Connect(function(payload: any)
    eventState = payload or { active = false }
    applyEventBanner()
end)

-- Local countdown ticker so the "ends in X" text feels live without
-- depending on server scan cadence (server pushes every 30s; local tick
-- decrements every second).
task.spawn(function()
    while true do
        task.wait(1)
        if eventState.active and eventState.endsInSec then
            eventState.endsInSec = math.max(0, (eventState.endsInSec or 0) - 1)
            applyEventBanner()
            if eventState.endsInSec <= 0 then
                -- Server will fire the next state change; until then hide.
                eventState.active = false
                applyEventBanner()
            end
        end
    end
end)

-- ----- Rebirth Shop modal -----

local PURPLE = Color3.fromRGB(180, 100, 240)
local rebirthShopModal: Frame? = nil
local rebirthShopState: {tokens: number, items: {any}}? = nil

local function buildRebirthShopModal()
    local m = Instance.new("Frame")
    m.Name = "RebirthShopModal"
    m.Size = UDim2.new(0, 480, 0, 540)
    m.Position = UDim2.new(0.5, -240, 0.5, -270)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = PURPLE; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "REBIRTH SHOP", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = PURPLE
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51

    local sub = makeLabel("Sub", m, "spend rebirth tokens on permanent unlocks", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
    sub.TextColor3 = TEXT
    sub.Font = Enum.Font.Code
    sub.TextTransparency = 0.3
    sub.ZIndex = 51

    local tokenLbl = Instance.new("TextLabel")
    tokenLbl.Name = "Tokens"
    tokenLbl.Size = UDim2.new(0, 120, 0, 22)
    tokenLbl.Position = UDim2.new(1, -136, 0, 12)
    tokenLbl.BackgroundTransparency = 1
    tokenLbl.Text = "0 TOKENS"
    tokenLbl.TextColor3 = AMBER
    tokenLbl.Font = Enum.Font.GothamBold
    tokenLbl.TextXAlignment = Enum.TextXAlignment.Right
    tokenLbl.TextScaled = true
    tokenLbl.ZIndex = 51
    tokenLbl.Parent = m

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 24, 0, 24)
    x.Position = UDim2.new(1, -32, 0, 38)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = TEXT
    x.Font = Enum.Font.GothamBold
    x.TextSize = 18
    x.ZIndex = 51
    x.Parent = m
    x.MouseButton1Click:Connect(function() m.Visible = false end)

    local list = Instance.new("ScrollingFrame")
    list.Name = "Cards"
    list.Size = UDim2.new(1, -32, 1, -88)
    list.Position = UDim2.new(0, 16, 0, 72)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 51
    list.Parent = m
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = list

    return m
end

local rebirthShopCardsById: {[string]: Frame} = {}

local function applyShopCardState(card: Frame, item: any, tokens: number)
    local btn = card:FindFirstChild("Buy") :: TextButton?
    if not btn then return end
    if item.owned then
        btn.Text = "OWNED"
        btn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        btn.TextColor3 = TEXT
        btn.AutoButtonColor = false
        btn.Active = false
    elseif tokens < item.cost then
        btn.Text = string.format("%d T", item.cost)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.TextColor3 = TEXT
        btn.AutoButtonColor = false
        btn.Active = false
    else
        btn.Text = string.format("%d T", item.cost)
        btn.BackgroundColor3 = PURPLE
        btn.TextColor3 = BG
        btn.AutoButtonColor = true
        btn.Active = true
    end
end

local function buildShopCard(parent: Instance, item: any, tokens: number, order: number): Frame
    local card = Instance.new("Frame")
    card.Name = "Item_" .. item.id
    card.Size = UDim2.new(1, -8, 0, 90)
    card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
    card.BorderSizePixel = 0
    card.ZIndex = 52
    card.LayoutOrder = order
    card.Parent = parent
    do
        local s = Instance.new("UIStroke"); s.Color = PURPLE; s.Thickness = 1; s.Parent = card
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
    end

    local title = makeLabel("Title", card, item.title, UDim2.new(1, -120, 0, 22), UDim2.new(0, 12, 0, 10))
    title.TextColor3 = PURPLE
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 53

    local sub = makeLabel("Sub", card, item.sub, UDim2.new(1, -120, 0, 18), UDim2.new(0, 12, 0, 36))
    sub.TextColor3 = TEXT
    sub.Font = Enum.Font.Code
    sub.ZIndex = 53

    local btn = Instance.new("TextButton")
    btn.Name = "Buy"
    btn.Size = UDim2.new(0, 100, 0, 50)
    btn.Position = UDim2.new(1, -112, 0.5, -25)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.ZIndex = 53
    btn.Parent = card
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    end
    applyShopCardState(card, item, tokens)
    btn.MouseButton1Click:Connect(function()
        if not btn.Active then return end
        pcall(function()
            remotes.BuyRebirthShopItem:FireServer(item.id)
        end)
    end)
    card:SetAttribute("ItemId", item.id)
    return card
end

local function renderRebirthShop(state: any)
    rebirthShopState = state
    if not rebirthShopModal then return end
    local tokenLbl = rebirthShopModal:FindFirstChild("Tokens") :: TextLabel?
    if tokenLbl then tokenLbl.Text = string.format("%d TOKENS", state.tokens) end
    local list = rebirthShopModal:FindFirstChild("Cards")
    if not list then return end
    for order, item in ipairs(state.items) do
        local card = rebirthShopCardsById[item.id]
        if card and card.Parent ~= list then card = nil end
        if not card then
            card = buildShopCard(list, item, state.tokens, order)
            rebirthShopCardsById[item.id] = card
        else
            applyShopCardState(card, item, state.tokens)
        end
    end
end

local function refreshRebirthShop()
    task.spawn(function()
        local ok, result = pcall(function()
            return remotes.GetRebirthShop:InvokeServer()
        end)
        if ok and result then renderRebirthShop(result) end
    end)
end

rebirthShopBtn.MouseButton1Click:Connect(function()
    if not rebirthShopModal then rebirthShopModal = buildRebirthShopModal() end
    rebirthShopModal.Visible = true
    refreshRebirthShop()
end)

remotes.RebirthShopPurchased.OnClientEvent:Connect(function(itemId: string, tokensRemaining: number)
    if rebirthShopState then
        rebirthShopState.tokens = tokensRemaining
        for _, it in ipairs(rebirthShopState.items) do
            if it.id == itemId then it.owned = true; break end
        end
        renderRebirthShop(rebirthShopState)
    end
    showToast(
        "PERMA-UNLOCK ACTIVE",
        string.format("'%s' multiplier now stacks forever", itemId),
        PURPLE,
        5
    )
    flashScreen(PURPLE, 0.6)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

local SHOP_REJECTION_COPY: {[string]: string} = {
    no_data = "Save data still loading.",
    bad_request = "Invalid item.",
    unknown_item = "Unknown item.",
    already_owned = "Already owned.",
    insufficient_tokens = "Need %d more tokens (rebirth more).",
}

remotes.RebirthShopRejected.OnClientEvent:Connect(function(itemId: string, reason: string, needed: number?)
    local template = SHOP_REJECTION_COPY[reason] or reason
    if reason == "insufficient_tokens" and needed then
        template = string.format(template, needed)
    end
    showToast("CAN'T BUY", template, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
end)

-- ----- Pets modal -----
-- Tabbed: EGGS (hatch flow) and INVENTORY (equip flow). Lazy-built on
-- first open. PetHatched / PetEquipChanged drive incremental refresh.

local GREEN = Color3.fromRGB(110, 220, 110)
local petsModal: Frame? = nil
local petState: any = nil

local function rarityColor(rarity: string): Color3
    local rgb = Constants.PET_RARITY_COLORS[rarity] or {200,200,200}
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function rebuildEggList(eggsList: ScrollingFrame, state: any)
    for _, c in ipairs(eggsList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for order, e in ipairs(state.eggs) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 90)
        card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.ZIndex = 52
        card.Parent = eggsList
        do
            local s = Instance.new("UIStroke"); s.Color = GREEN; s.Thickness = 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end
        local title = makeLabel("Title", card, e.name, UDim2.new(1, -140, 0, 22), UDim2.new(0, 12, 0, 10))
        title.TextColor3 = GREEN
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 53
        local sub = makeLabel("Sub", card, e.sub, UDim2.new(1, -140, 0, 18), UDim2.new(0, 12, 0, 36))
        sub.TextColor3 = TEXT
        sub.Font = Enum.Font.Code
        sub.ZIndex = 53
        local cost = makeLabel("Cost", card, fmt(e.cost) .. " coins", UDim2.new(1, -140, 0, 18), UDim2.new(0, 12, 0, 60))
        cost.TextColor3 = AMBER
        cost.Font = Enum.Font.Code
        cost.ZIndex = 53

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 110, 0, 50)
        btn.Position = UDim2.new(1, -122, 0.5, -25)
        btn.BorderSizePixel = 0
        btn.Text = "HATCH"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.ZIndex = 53
        btn.Parent = card
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        end
        if state.coinsAvailable >= e.cost then
            btn.BackgroundColor3 = GREEN
            btn.TextColor3 = BG
            btn.AutoButtonColor = true
            btn.Active = true
        else
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            btn.TextColor3 = TEXT
            btn.AutoButtonColor = false
            btn.Active = false
        end
        local eggId = e.id
        btn.MouseButton1Click:Connect(function()
            if btn.Active then
                pcall(function() remotes.HatchEgg:FireServer(eggId) end)
            end
        end)
    end
end

local function rebuildInventory(invList: ScrollingFrame, state: any)
    for _, c in ipairs(invList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    -- Group identical petIds with a stack count, but show one card per uid
    -- so equip choice is unambiguous. Sort by rarity (legendary first) +
    -- name as tiebreaker.
    local sorted = {}
    for _, p in ipairs(state.pets) do table.insert(sorted, p) end
    local rarityRank: {[string]: number} = {legendary=1, epic=2, rare=3, uncommon=4, common=5}
    table.sort(sorted, function(a, b)
        local ra, rb = rarityRank[a.rarity] or 9, rarityRank[b.rarity] or 9
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    local equippedSet: {[string]: boolean} = {}
    for _, uid in ipairs(state.equippedPetIds) do equippedSet[uid] = true end

    -- Auto-equip card: pinned above the fusion cards. One tap, server picks
    -- the best PET_MAX_EQUIPPED unequipped pets by rarity multiplier.
    do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 44)
        card.BackgroundColor3 = Color3.fromRGB(28, 24, 44)
        card.BorderSizePixel = 0
        card.LayoutOrder = -2000 -- pin above fuse cards
        card.ZIndex = 52
        card.Parent = invList
        do
            local s = Instance.new("UIStroke"); s.Color = GREEN; s.Thickness = 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end
        local label = makeLabel("Auto", card, "AUTO-EQUIP best 3 by multiplier",
            UDim2.new(1, -160, 1, -8), UDim2.new(0, 10, 0, 4))
        label.TextColor3 = GREEN
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.ZIndex = 53
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 0, 30)
        btn.Position = UDim2.new(1, -140, 0.5, -15)
        btn.BackgroundColor3 = GREEN
        btn.TextColor3 = BG
        btn.Text = "AUTO"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.ZIndex = 53
        btn.Parent = card
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn end
        btn.MouseButton1Click:Connect(function()
            pcall(function() remotes.AutoEquipPets:FireServer() end)
        end)
    end

    -- Fusion: count non-equipped per rarity and offer a "fuse 3 -> 1 next"
    -- button per rarity that has enough + has a promotion target. Pinned
    -- at the top of the list (LayoutOrder negative).
    local fuseCount: {[string]: number} = {}
    for _, p in ipairs(sorted) do
        if not equippedSet[p.uid] then
            fuseCount[p.rarity] = (fuseCount[p.rarity] or 0) + 1
        end
    end
    local fuseRarityOrder = {"common", "uncommon", "rare", "epic"}
    local PROMO = Constants.PET_RARITY_PROMOTION or {}
    local fuseSlot = 0
    for _, rarity in ipairs(fuseRarityOrder) do
        local nextRarity = PROMO[rarity]
        local count = fuseCount[rarity] or 0
        if nextRarity and count >= Constants.PET_FUSE_COST then
            fuseSlot += 1
            local rcolor = Constants.PET_RARITY_COLORS[rarity] or {200,200,200}
            local nrcolor = Constants.PET_RARITY_COLORS[nextRarity] or {200,200,200}
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -8, 0, 50)
            card.BackgroundColor3 = Color3.fromRGB(28, 24, 44)
            card.BorderSizePixel = 0
            card.LayoutOrder = -1000 + fuseSlot -- pin to top
            card.ZIndex = 52
            card.Parent = invList
            do
                local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
                local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(nrcolor[1], nrcolor[2], nrcolor[3]); s.Thickness = 1; s.Parent = card
            end
            local label = makeLabel("Fuse", card,
                string.format("FUSE %d %s -> 1 %s", Constants.PET_FUSE_COST, string.upper(rarity), string.upper(nextRarity)),
                UDim2.new(1, -160, 1, -8), UDim2.new(0, 10, 0, 4))
            label.TextColor3 = Color3.fromRGB(rcolor[1], rcolor[2], rcolor[3])
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.ZIndex = 53
            local sub = makeLabel("Sub", card,
                string.format("you have %d %s available", count, rarity),
                UDim2.new(1, -160, 0, 14), UDim2.new(0, 10, 0, 30))
            sub.TextColor3 = TEXT
            sub.Font = Enum.Font.Code
            sub.TextSize = 11
            sub.TextTransparency = 0.4
            sub.ZIndex = 53
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 130, 0, 30)
            btn.Position = UDim2.new(1, -140, 0.5, -15)
            btn.BackgroundColor3 = Color3.fromRGB(nrcolor[1], nrcolor[2], nrcolor[3])
            btn.TextColor3 = BG
            btn.Text = "FUSE"
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 14
            btn.BorderSizePixel = 0
            btn.ZIndex = 53
            btn.Parent = card
            do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn end
            local rarityCapture = rarity
            btn.MouseButton1Click:Connect(function()
                pcall(function() remotes.FusePets:FireServer(rarityCapture) end)
            end)
        end
    end

    for order, p in ipairs(sorted) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 60)
        card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        card.ZIndex = 52
        card.Parent = invList
        do
            local color = Color3.fromRGB(p.color[1] or 200, p.color[2] or 200, p.color[3] or 200)
            local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end
        local title = makeLabel("Title", card, p.name, UDim2.new(1, -160, 0, 18), UDim2.new(0, 10, 0, 6))
        title.TextColor3 = Color3.fromRGB(p.color[1] or 200, p.color[2] or 200, p.color[3] or 200)
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 53
        local sub = makeLabel("Sub", card, string.format("%s  +%d%% income", string.upper(p.rarity), math.floor(p.mult*100)),
            UDim2.new(1, -160, 0, 16), UDim2.new(0, 10, 0, 28))
        sub.TextColor3 = TEXT
        sub.Font = Enum.Font.Code
        sub.TextTransparency = 0.2
        sub.ZIndex = 53

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 0, 36)
        btn.Position = UDim2.new(1, -140, 0.5, -18)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.ZIndex = 53
        btn.Parent = card
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        end
        local uid = p.uid
        if equippedSet[uid] then
            btn.Text = "UNEQUIP"
            btn.BackgroundColor3 = AMBER
            btn.TextColor3 = BG
            btn.MouseButton1Click:Connect(function()
                pcall(function() remotes.UnequipPet:FireServer(uid) end)
            end)
        elseif #state.equippedPetIds >= state.maxEquipped then
            btn.Text = "EQUIP FULL"
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            btn.TextColor3 = TEXT
            btn.AutoButtonColor = false
            btn.Active = false
        else
            btn.Text = "EQUIP"
            btn.BackgroundColor3 = GREEN
            btn.TextColor3 = BG
            btn.MouseButton1Click:Connect(function()
                pcall(function() remotes.EquipPet:FireServer(uid) end)
            end)
        end
    end
end

local function buildPetsModal()
    local m = Instance.new("Frame")
    m.Name = "PetsModal"
    m.Size = UDim2.new(0, 520, 0, 560)
    m.Position = UDim2.new(0.5, -260, 0.5, -280)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = GREEN; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "PETS", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = GREEN
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51
    local sub = makeLabel("Sub", m, "hatch eggs - equip up to 3 - collect them all for +50% perma", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
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

    -- Tabs
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -32, 0, 36)
    tabBar.Position = UDim2.new(0, 16, 0, 64)
    tabBar.BackgroundTransparency = 1
    tabBar.ZIndex = 51
    tabBar.Parent = m

    local function makeTab(text: string, x: number)
        local t = Instance.new("TextButton")
        t.Size = UDim2.new(0, 120, 1, 0)
        t.Position = UDim2.new(0, x, 0, 0)
        t.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        t.BorderSizePixel = 0
        t.Text = text
        t.TextColor3 = TEXT
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        t.ZIndex = 52
        t.Parent = tabBar
        do
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = t
            local s = Instance.new("UIStroke"); s.Color = GREEN; s.Thickness = 1; s.Parent = t
        end
        return t
    end

    local eggsTab = makeTab("EGGS", 0)
    local invTab = makeTab("INVENTORY", 128)

    local eggsList = Instance.new("ScrollingFrame")
    eggsList.Name = "EggsList"
    eggsList.Size = UDim2.new(1, -32, 1, -120)
    eggsList.Position = UDim2.new(0, 16, 0, 108)
    eggsList.BackgroundTransparency = 1
    eggsList.ScrollBarThickness = 4
    eggsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    eggsList.CanvasSize = UDim2.new(0,0,0,0)
    eggsList.ZIndex = 51
    eggsList.Parent = m
    local eL = Instance.new("UIListLayout"); eL.SortOrder = Enum.SortOrder.LayoutOrder; eL.Padding = UDim.new(0, 8); eL.Parent = eggsList

    local invList = Instance.new("ScrollingFrame")
    invList.Name = "InvList"
    invList.Size = UDim2.new(1, -32, 1, -120)
    invList.Position = UDim2.new(0, 16, 0, 108)
    invList.BackgroundTransparency = 1
    invList.ScrollBarThickness = 4
    invList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    invList.CanvasSize = UDim2.new(0,0,0,0)
    invList.ZIndex = 51
    invList.Visible = false
    invList.Parent = m
    local iL = Instance.new("UIListLayout"); iL.SortOrder = Enum.SortOrder.LayoutOrder; iL.Padding = UDim.new(0, 8); iL.Parent = invList

    eggsTab.MouseButton1Click:Connect(function()
        eggsList.Visible = true; invList.Visible = false
        eggsTab.BackgroundColor3 = GREEN; eggsTab.TextColor3 = BG
        invTab.BackgroundColor3 = Color3.fromRGB(20, 18, 32); invTab.TextColor3 = TEXT
    end)
    invTab.MouseButton1Click:Connect(function()
        eggsList.Visible = false; invList.Visible = true
        invTab.BackgroundColor3 = GREEN; invTab.TextColor3 = BG
        eggsTab.BackgroundColor3 = Color3.fromRGB(20, 18, 32); eggsTab.TextColor3 = TEXT
    end)
    -- Initial style
    eggsTab.BackgroundColor3 = GREEN
    eggsTab.TextColor3 = BG

    return m, eggsList, invList
end

local petsEggsList: ScrollingFrame? = nil
local petsInvList: ScrollingFrame? = nil

local function refreshPets()
    task.spawn(function()
        local ok, result = pcall(function() return remotes.GetPetState:InvokeServer() end)
        if ok and result then
            petState = result
            if petsEggsList then rebuildEggList(petsEggsList, result) end
            if petsInvList then rebuildInventory(petsInvList, result) end
        end
    end)
end

petsBtn.MouseButton1Click:Connect(function()
    if not petsModal then
        petsModal, petsEggsList, petsInvList = buildPetsModal()
    end
    petsModal.Visible = true
    refreshPets()
end)

remotes.PetHatched.OnClientEvent:Connect(function(pet: any, petName: string)
    refreshPets()
    local color = Color3.fromRGB(pet.color and pet.color[1] or 200, pet.color and pet.color[2] or 200, pet.color and pet.color[3] or 200)
    local rarityColor = Constants.PET_RARITY_COLORS[pet.rarity] or {200,200,200}
    color = Color3.fromRGB(rarityColor[1], rarityColor[2], rarityColor[3])
    showToast(
        string.format("%s HATCHED!", string.upper(petName)),
        string.format("%s rarity", string.upper(pet.rarity)),
        color,
        5
    )
    flashScreen(color, 0.7)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
end)

local PET_REJECTION_COPY: {[string]: string} = {
    no_data = "Save data still loading.",
    bad_request = "Invalid egg.",
    unknown_egg = "That egg doesn't exist.",
    inventory_full = "Pet inventory full -- equip or sell some first.",
    insufficient_coins = "Need %s more coins to hatch.",
}

remotes.PetHatchRejected.OnClientEvent:Connect(function(eggId: string, reason: string, needed: number?)
    local template = PET_REJECTION_COPY[reason] or reason
    if reason == "insufficient_coins" and needed then
        template = string.format(template, fmt(needed))
    end
    showToast("HATCH FAILED", template, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
end)

remotes.PetEquipChanged.OnClientEvent:Connect(function(_equippedPetIds: {string})
    refreshPets()
end)

remotes.StreakEggGranted.OnClientEvent:Connect(function(streakDay: number, _eggId: string, pet: any, petName: string)
    local rarityColor = Constants.PET_RARITY_COLORS[pet.rarity] or {200,200,200}
    local color = Color3.fromRGB(rarityColor[1], rarityColor[2], rarityColor[3])
    showToast(
        string.format("%d-DAY STREAK GIFT", streakDay),
        string.format("free %s -- %s rarity", string.upper(petName), string.upper(pet.rarity)),
        color,
        6
    )
    flashScreen(color, 0.8)
    playSound(Constants.SOUND_IDS.daily_bonus, 0.7)
    refreshPets()
end)

local PET_FUSE_REJECT_COPY: {[string]: string} = {
    no_data = "Save data still loading.",
    bad_request = "Invalid fusion request.",
    cannot_promote = "Legendary pets can't be fused further.",
    not_enough = "Need %d more pets of this rarity (3 minimum, none equipped).",
    promotion_pool_empty = "No promoted pets defined yet.",
}

remotes.PetFuseRejected.OnClientEvent:Connect(function(rarity: string, reason: string, needed: number?)
    local template = PET_FUSE_REJECT_COPY[reason] or reason
    if reason == "not_enough" and needed then
        template = string.format(template, needed)
    end
    showToast("FUSE FAILED", template, AMBER, 3)
    playSound(Constants.SOUND_IDS.purchase_fail, 0.5)
end)

-- =============================================================================
-- Achievements
-- =============================================================================

local GOLD = Color3.fromRGB(255, 207, 64)
local achModal: Frame? = nil
local achList: ScrollingFrame? = nil

local achBtn = Instance.new("TextButton")
achBtn.Name = "AchievementsButton"
achBtn.Size = UDim2.new(0, 140, 0, 44)
achBtn.Position = UDim2.new(1, -156, 1, -284)
achBtn.BackgroundColor3 = BG
achBtn.BackgroundTransparency = 0.15
achBtn.BorderSizePixel = 0
achBtn.AutoButtonColor = false
achBtn.Text = ""
achBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = GOLD; s.Thickness = 1; s.Parent = achBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = achBtn
end
local achLabel = makeLabel("Label", achBtn, "* TROPHIES", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
achLabel.TextColor3 = GOLD
achLabel.Font = Enum.Font.Code
achLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Small "n / total" badge anchored to the button so players see progress
-- without opening the modal.
local achBadge = Instance.new("TextLabel")
achBadge.Name = "Badge"
achBadge.Size = UDim2.new(0, 56, 0, 18)
achBadge.Position = UDim2.new(1, -28, 0, -8)
achBadge.AnchorPoint = Vector2.new(0.5, 0)
achBadge.BackgroundColor3 = GOLD
achBadge.BackgroundTransparency = 0.05
achBadge.BorderSizePixel = 0
achBadge.Text = "0 / 0"
achBadge.TextColor3 = BG
achBadge.Font = Enum.Font.GothamBold
achBadge.TextSize = 12
achBadge.Visible = false
achBadge.Parent = achBtn
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = achBadge
end

local function buildAchievementsModal(): (Frame, ScrollingFrame)
    local m = Instance.new("Frame")
    m.Name = "AchievementsModal"
    m.Size = UDim2.new(0, 540, 0, 580)
    m.Position = UDim2.new(0.5, -270, 0.5, -290)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = GOLD; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "TROPHIES", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = GOLD
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51
    local sub = makeLabel("Sub", m, "milestones earn coins, tokens, and Roblox push notifications", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
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

    local list = Instance.new("ScrollingFrame")
    list.Name = "AchList"
    list.Size = UDim2.new(1, -32, 1, -76)
    list.Position = UDim2.new(0, 16, 0, 64)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0,0,0,0)
    list.ZIndex = 51
    list.Parent = m
    local L = Instance.new("UIListLayout"); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Padding = UDim.new(0, 8); L.Parent = list

    return m, list
end

local function rebuildAchievementsList(list: ScrollingFrame, snap: any)
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if not snap or not snap.entries then return end
    -- Render unlocked first (gold border + checkmark), then locked sorted
    -- by progress percentage descending so closest-to-unlock floats up.
    local entries = snap.entries
    local sorted = {}
    for i, e in ipairs(entries) do sorted[i] = e end
    table.sort(sorted, function(a, b)
        if a.unlocked ~= b.unlocked then return a.unlocked end
        local aPct = (a.target > 0) and (a.progress / a.target) or 0
        local bPct = (b.target > 0) and (b.progress / b.target) or 0
        return aPct > bPct
    end)
    for i, e in ipairs(sorted) do
        local card = Instance.new("Frame")
        card.Name = e.id
        card.Size = UDim2.new(1, -8, 0, 64)
        card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        card.BorderSizePixel = 0
        card.ZIndex = 52
        card.LayoutOrder = i
        card.Parent = list
        do
            local s = Instance.new("UIStroke"); s.Color = e.unlocked and GOLD or Color3.fromRGB(60, 56, 80); s.Thickness = 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end
        local title = makeLabel("Title", card, (e.unlocked and "[X] " or "[ ] ") .. e.name, UDim2.new(1, -200, 0, 18), UDim2.new(0, 12, 0, 8))
        title.TextColor3 = e.unlocked and GOLD or TEXT
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 53
        local desc = makeLabel("Desc", card, e.desc, UDim2.new(1, -200, 0, 14), UDim2.new(0, 12, 0, 28))
        desc.TextColor3 = TEXT
        desc.Font = Enum.Font.Code
        desc.TextTransparency = 0.4
        desc.ZIndex = 53
        -- Reward chip
        local rewardText = ""
        if e.rewardCoins > 0 then rewardText = "+" .. fmt(e.rewardCoins) .. "c" end
        if e.rewardTokens > 0 then
            if rewardText ~= "" then rewardText = rewardText .. " " end
            rewardText = rewardText .. "+" .. e.rewardTokens .. "T"
        end
        local reward = makeLabel("Reward", card, rewardText, UDim2.new(0, 120, 0, 18), UDim2.new(1, -132, 0, 8))
        reward.TextColor3 = GOLD
        reward.Font = Enum.Font.GothamBold
        reward.TextXAlignment = Enum.TextXAlignment.Right
        reward.ZIndex = 53
        -- Progress bar (only for non-boolean triggers; skip for collection-complete)
        if not e.unlocked and e.target and e.target > 1 then
            local barBg = Instance.new("Frame")
            barBg.Size = UDim2.new(1, -24, 0, 6)
            barBg.Position = UDim2.new(0, 12, 0, 50)
            barBg.BackgroundColor3 = Color3.fromRGB(40, 36, 56)
            barBg.BorderSizePixel = 0
            barBg.ZIndex = 53
            barBg.Parent = card
            do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = barBg end
            local pct = math.clamp(e.progress / e.target, 0, 1)
            local barFill = Instance.new("Frame")
            barFill.Size = UDim2.new(pct, 0, 1, 0)
            barFill.BackgroundColor3 = GOLD
            barFill.BorderSizePixel = 0
            barFill.ZIndex = 54
            barFill.Parent = barBg
            do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = barFill end
            local pctLbl = makeLabel("Pct", card, fmt(e.progress) .. " / " .. fmt(e.target), UDim2.new(1, -24, 0, 12), UDim2.new(0, 12, 0, 36))
            pctLbl.TextColor3 = TEXT
            pctLbl.Font = Enum.Font.Code
            pctLbl.TextTransparency = 0.3
            pctLbl.TextSize = 11
            pctLbl.TextXAlignment = Enum.TextXAlignment.Right
            pctLbl.ZIndex = 53
        elseif e.unlocked then
            local stamp = makeLabel("Stamp", card, "UNLOCKED", UDim2.new(0, 100, 0, 12), UDim2.new(0, 12, 0, 46))
            stamp.TextColor3 = GOLD
            stamp.Font = Enum.Font.GothamBold
            stamp.TextSize = 11
            stamp.ZIndex = 53
        end
    end
end

local function refreshAchievements()
    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetAchievements:InvokeServer() end)
        if ok and snap then
            achBadge.Text = string.format("%d / %d", snap.unlockedCount, snap.totalCount)
            achBadge.Visible = snap.totalCount > 0
            if achList then rebuildAchievementsList(achList, snap) end
        end
    end)
end

achBtn.MouseButton1Click:Connect(function()
    if not achModal then
        achModal, achList = buildAchievementsModal()
    end
    achModal.Visible = true
    refreshAchievements()
end)

-- Initial badge sync once remotes are warm
task.delay(2, refreshAchievements)

-- =============================================================================
-- Hourly Tribute (sessions/user/day driver)
-- =============================================================================

local CYAN_TRIBUTE = Color3.fromRGB(110, 220, 220)

local tributeBtn = Instance.new("TextButton")
tributeBtn.Name = "TributeButton"
tributeBtn.Size = UDim2.new(0, 140, 0, 44)
tributeBtn.Position = UDim2.new(1, -156, 1, -340)
tributeBtn.BackgroundColor3 = BG
tributeBtn.BackgroundTransparency = 0.15
tributeBtn.BorderSizePixel = 0
tributeBtn.AutoButtonColor = false
tributeBtn.Text = ""
tributeBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = CYAN_TRIBUTE; s.Thickness = 1; s.Parent = tributeBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = tributeBtn
end
local tributeLabel = makeLabel("Label", tributeBtn, "* TRIBUTE", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 4))
tributeLabel.TextColor3 = CYAN_TRIBUTE
tributeLabel.Font = Enum.Font.Code
tributeLabel.TextXAlignment = Enum.TextXAlignment.Center
local tributeSub = makeLabel("Sub", tributeBtn, "next in --:--", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 24))
tributeSub.TextColor3 = TEXT
tributeSub.Font = Enum.Font.Code
tributeSub.TextSize = 11
tributeSub.TextTransparency = 0.3
tributeSub.TextXAlignment = Enum.TextXAlignment.Center

local tributeBadge = Instance.new("TextLabel")
tributeBadge.Name = "Badge"
tributeBadge.Size = UDim2.new(0, 24, 0, 24)
tributeBadge.Position = UDim2.new(1, -12, 0, -8)
tributeBadge.AnchorPoint = Vector2.new(1, 0)
tributeBadge.BackgroundColor3 = CYAN_TRIBUTE
tributeBadge.BackgroundTransparency = 0.05
tributeBadge.BorderSizePixel = 0
tributeBadge.Text = "0"
tributeBadge.TextColor3 = BG
tributeBadge.Font = Enum.Font.GothamBold
tributeBadge.TextSize = 14
tributeBadge.Visible = false
tributeBadge.Parent = tributeBtn
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = tributeBadge end

local tributeState: any = nil

local function fmtCountdown(sec: number): string
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    if m >= 60 then
        local h = math.floor(m / 60)
        local mm = m - h * 60
        return string.format("%dh %02dm", h, mm)
    end
    return string.format("%d:%02d", m, s)
end

local function applyTributeUI(snap: any)
    if not snap then return end
    tributeState = snap
    if snap.available > 0 then
        tributeBadge.Visible = true
        tributeBadge.Text = tostring(snap.available)
        if snap.capped then
            tributeSub.Text = "FULL -- claim now"
            tributeSub.TextColor3 = AMBER
        else
            tributeSub.Text = string.format("+%s next in %s", fmt(snap.perStackReward), fmtCountdown(snap.nextStackInSec))
            tributeSub.TextColor3 = TEXT
        end
    else
        tributeBadge.Visible = false
        tributeSub.TextColor3 = TEXT
        tributeSub.Text = "next in " .. fmtCountdown(snap.nextStackInSec)
    end
end

local function refreshTribute()
    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetHourlyTribute:InvokeServer() end)
        if ok and snap then applyTributeUI(snap) end
    end)
end

tributeBtn.MouseButton1Click:Connect(function()
    if tributeState and tributeState.available > 0 then
        pcall(function() remotes.ClaimHourlyTribute:FireServer() end)
    else
        showToast("NOT YET",
            "Tribute will be ready in " .. fmtCountdown((tributeState and tributeState.nextStackInSec) or 0),
            CYAN_TRIBUTE, 2.5)
    end
end)

remotes.HourlyTributeClaimed.OnClientEvent:Connect(function(stacks: number, totalReward: number)
    showToast(string.format("TRIBUTE CLAIMED x%d", stacks),
        string.format("+%s coins", fmt(totalReward)),
        CYAN_TRIBUTE, 4)
    flashScreen(CYAN_TRIBUTE, 0.5)
    playSound(Constants.SOUND_IDS.daily_bonus, 0.6)
    refreshTribute()
end)

remotes.HourlyTributeRejected.OnClientEvent:Connect(function(reason: string)
    if reason == "no_stacks" then
        -- silent, button click already showed countdown
        return
    end
    showToast("TRIBUTE FAILED", reason, AMBER, 2)
end)

-- Local countdown tick: smooth the visible "next in X:XX" between server polls.
task.spawn(function()
    while true do
        task.wait(1)
        if tributeState and tributeState.nextStackInSec and tributeState.nextStackInSec > 0 then
            tributeState.nextStackInSec = tributeState.nextStackInSec - 1
            if tributeState.nextStackInSec <= 0 then
                -- Force a server resync; a new stack should be available now
                refreshTribute()
            else
                applyTributeUI(tributeState)
            end
        end
    end
end)

-- Server poll every 30s as a safety net (clock drift, missed claims while
-- the modal was closed, capped state changes from another mechanic, etc).
task.spawn(function()
    task.wait(2) -- let remotes warm
    refreshTribute()
    while true do
        task.wait(30)
        refreshTribute()
    end
end)

remotes.AchievementUnlocked.OnClientEvent:Connect(function(payload: any)
    local rewardLine = ""
    if payload.rewardCoins and payload.rewardCoins > 0 then
        rewardLine = "+" .. fmt(payload.rewardCoins) .. " coins"
    end
    if payload.rewardTokens and payload.rewardTokens > 0 then
        if rewardLine ~= "" then rewardLine = rewardLine .. ", " end
        rewardLine = rewardLine .. "+" .. payload.rewardTokens .. " token" .. (payload.rewardTokens > 1 and "s" or "")
    end
    if rewardLine == "" then rewardLine = payload.desc or "milestone reached" end
    showToast(
        "TROPHY: " .. string.upper(payload.name or "UNLOCKED"),
        rewardLine,
        GOLD,
        5
    )
    flashScreen(GOLD, 0.6)
    playSound(Constants.SOUND_IDS.tier_up, 0.7)
    refreshAchievements()
end)

-- =============================================================================
-- Auras (cosmetic flex; sister to Pets but visible to other players)
-- =============================================================================

local AURA_PINK = Color3.fromRGB(255, 130, 200)
local auraModal: Frame? = nil
local auraList: ScrollingFrame? = nil

local auraBtn = Instance.new("TextButton")
auraBtn.Name = "AurasButton"
auraBtn.Size = UDim2.new(0, 140, 0, 44)
auraBtn.Position = UDim2.new(1, -156, 1, -396)
auraBtn.BackgroundColor3 = BG
auraBtn.BackgroundTransparency = 0.15
auraBtn.BorderSizePixel = 0
auraBtn.AutoButtonColor = false
auraBtn.Text = ""
auraBtn.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = AURA_PINK; s.Thickness = 1; s.Parent = auraBtn
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = auraBtn
end
local auraLabel = makeLabel("Label", auraBtn, "* AURAS", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4))
auraLabel.TextColor3 = AURA_PINK
auraLabel.Font = Enum.Font.Code
auraLabel.TextXAlignment = Enum.TextXAlignment.Center

local function buildAurasModal(): (Frame, ScrollingFrame)
    local m = Instance.new("Frame")
    m.Name = "AurasModal"
    m.Size = UDim2.new(0, 540, 0, 580)
    m.Position = UDim2.new(0.5, -270, 0.5, -290)
    m.BackgroundColor3 = BG
    m.BackgroundTransparency = 0.05
    m.BorderSizePixel = 0
    m.ZIndex = 50
    m.Visible = false
    m.Parent = screen
    do
        local s = Instance.new("UIStroke"); s.Color = AURA_PINK; s.Thickness = 2; s.Parent = m
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = m
    end
    local head = makeLabel("Head", m, "AURAS", UDim2.new(1, -32, 0, 24), UDim2.new(0, 16, 0, 12))
    head.TextColor3 = AURA_PINK
    head.Font = Enum.Font.GothamBold
    head.ZIndex = 51
    local sub = makeLabel("Sub", m, "cosmetic only -- visible to every player in the server", UDim2.new(1, -32, 0, 16), UDim2.new(0, 16, 0, 38))
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

    local list = Instance.new("ScrollingFrame")
    list.Name = "AuraList"
    list.Size = UDim2.new(1, -32, 1, -76)
    list.Position = UDim2.new(0, 16, 0, 64)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0,0,0,0)
    list.ZIndex = 51
    list.Parent = m
    local L = Instance.new("UIListLayout"); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Padding = UDim.new(0, 8); L.Parent = list

    return m, list
end

local function rebuildAurasList(list: ScrollingFrame, snap: any)
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if not snap or not snap.entries then return end
    -- Sort: equipped first, then unlocked, then locked-but-progressed
    local entries = {}
    for i, e in ipairs(snap.entries) do entries[i] = e end
    table.sort(entries, function(a, b)
        if a.equipped ~= b.equipped then return a.equipped end
        if a.unlocked ~= b.unlocked then return a.unlocked end
        local aPct = (a.target > 0) and (a.progress / a.target) or 0
        local bPct = (b.target > 0) and (b.progress / b.target) or 0
        return aPct > bPct
    end)
    for i, e in ipairs(entries) do
        local color = Color3.fromRGB(e.color[1], e.color[2], e.color[3])
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 70)
        card.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
        card.BorderSizePixel = 0
        card.LayoutOrder = i
        card.ZIndex = 52
        card.Parent = list
        do
            local s = Instance.new("UIStroke"); s.Color = e.unlocked and color or Color3.fromRGB(60, 56, 80); s.Thickness = e.equipped and 2 or 1; s.Parent = card
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = card
        end
        -- Color swatch
        local swatch = Instance.new("Frame")
        swatch.Size = UDim2.new(0, 14, 0, 50)
        swatch.Position = UDim2.new(0, 10, 0, 10)
        swatch.BackgroundColor3 = color
        swatch.BorderSizePixel = 0
        swatch.ZIndex = 53
        swatch.Parent = card
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = swatch end

        local title = makeLabel("Title", card, e.name .. "  [" .. string.upper(e.rarity) .. "]", UDim2.new(1, -200, 0, 18), UDim2.new(0, 32, 0, 8))
        title.TextColor3 = e.unlocked and color or TEXT
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 53
        local desc = makeLabel("Desc", card, e.desc, UDim2.new(1, -200, 0, 14), UDim2.new(0, 32, 0, 28))
        desc.TextColor3 = TEXT
        desc.Font = Enum.Font.Code
        desc.TextTransparency = 0.4
        desc.ZIndex = 53

        -- Status line
        local statusText
        if e.unlocked then
            statusText = "UNLOCKED"
        elseif e.trigger == "lifetime_coins" then
            statusText = string.format("%s / %s lifetime coins", fmt(e.progress), fmt(e.target))
        elseif e.trigger == "rebirths" then
            statusText = string.format("rebirth %d / %d", e.progress, e.target)
        elseif e.trigger == "achievements_unlocked" then
            statusText = string.format("trophies %d / %d", e.progress, e.target)
        elseif e.trigger == "pets_collection_complete" then
            statusText = "complete the pet collection"
        else
            statusText = string.format("%d / %d", e.progress, e.target)
        end
        local status = makeLabel("Status", card, statusText, UDim2.new(1, -200, 0, 12), UDim2.new(0, 32, 0, 48))
        status.TextColor3 = e.unlocked and color or TEXT
        status.Font = Enum.Font.Code
        status.TextSize = 11
        status.TextTransparency = e.unlocked and 0.1 or 0.4
        status.ZIndex = 53

        -- Action button
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 0, 36)
        btn.Position = UDim2.new(1, -140, 0.5, -18)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.ZIndex = 53
        btn.Parent = card
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn end
        if e.equipped then
            btn.Text = "UNEQUIP"
            btn.BackgroundColor3 = AMBER
            btn.TextColor3 = BG
            btn.MouseButton1Click:Connect(function()
                pcall(function() remotes.EquipAura:FireServer("") end)
            end)
        elseif e.unlocked then
            btn.Text = "EQUIP"
            btn.BackgroundColor3 = color
            btn.TextColor3 = BG
            local idCapture = e.id
            btn.MouseButton1Click:Connect(function()
                pcall(function() remotes.EquipAura:FireServer(idCapture) end)
            end)
        else
            btn.Text = "LOCKED"
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            btn.TextColor3 = TEXT
            btn.AutoButtonColor = false
            btn.Active = false
        end
    end
end

local function refreshAuras()
    task.spawn(function()
        local ok, snap = pcall(function() return remotes.GetAuras:InvokeServer() end)
        if ok and snap and auraList then
            rebuildAurasList(auraList, snap)
        end
    end)
end

auraBtn.MouseButton1Click:Connect(function()
    if not auraModal then
        auraModal, auraList = buildAurasModal()
    end
    auraModal.Visible = true
    refreshAuras()
end)

local AURA_REJECT_COPY: {[string]: string} = {
    no_data = "Save data still loading.",
    bad_request = "Invalid aura.",
    unknown_aura = "That aura doesn't exist.",
    locked = "You haven't unlocked that aura yet.",
}

remotes.AuraRejected.OnClientEvent:Connect(function(_auraId: string, reason: string)
    local copy = AURA_REJECT_COPY[reason] or reason
    showToast("AURA FAILED", copy, AMBER, 3)
end)

-- =============================================================================
-- Live Activity Feed (FOMO ticker, top-left)
-- =============================================================================

local FEED_KIND_COLOR: {[string]: Color3} = {
    hatch_legendary = Color3.fromRGB(255, 207, 64),    -- gold
    rebirth_milestone = Color3.fromRGB(255, 130, 200), -- pink
    aura_unlock = Color3.fromRGB(200, 130, 255),       -- purple
    achievement_legendary = Color3.fromRGB(110, 220, 220), -- cyan
}

local feedFrame = Instance.new("Frame")
feedFrame.Name = "ActivityFeed"
feedFrame.Size = UDim2.new(0, 320, 0, 240)
feedFrame.Position = UDim2.new(0, 12, 0, 80)
feedFrame.BackgroundColor3 = BG
feedFrame.BackgroundTransparency = 0.25
feedFrame.BorderSizePixel = 0
feedFrame.Visible = true
feedFrame.Parent = screen
do
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60, 56, 80); s.Thickness = 1; s.Parent = feedFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = feedFrame
end
local feedHead = makeLabel("Head", feedFrame, "LIVE FEED", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 6))
feedHead.TextColor3 = TEXT
feedHead.Font = Enum.Font.GothamBold
feedHead.TextSize = 12
feedHead.TextTransparency = 0.3

local feedList = Instance.new("Frame")
feedList.Name = "List"
feedList.Size = UDim2.new(1, -16, 1, -28)
feedList.Position = UDim2.new(0, 8, 0, 24)
feedList.BackgroundTransparency = 1
feedList.Parent = feedFrame
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = feedList

local function fmtAgo(unix: number): string
    local sec = os.time() - unix
    if sec < 60 then return tostring(math.max(0, sec)) .. "s" end
    if sec < 3600 then return tostring(math.floor(sec / 60)) .. "m" end
    return tostring(math.floor(sec / 3600)) .. "h"
end

local function rebuildFeed(entries: {any})
    for _, c in ipairs(feedList:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    if not entries or #entries == 0 then
        local empty = makeLabel("Empty", feedList, "(quiet for now)", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 0))
        empty.TextColor3 = TEXT
        empty.Font = Enum.Font.Code
        empty.TextSize = 11
        empty.TextTransparency = 0.6
        empty.TextXAlignment = Enum.TextXAlignment.Left
        return
    end
    for i, e in ipairs(entries) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.LayoutOrder = i
        row.Parent = feedList
        local color = FEED_KIND_COLOR[e.kind] or TEXT
        -- name
        local who = makeLabel("Who", row, e.userName, UDim2.new(0, 88, 1, 0), UDim2.new(0, 0, 0, 0))
        who.TextColor3 = color
        who.Font = Enum.Font.GothamBold
        who.TextSize = 11
        who.TextXAlignment = Enum.TextXAlignment.Left
        who.TextTruncate = Enum.TextTruncate.AtEnd
        -- detail
        local what = makeLabel("What", row, e.detail, UDim2.new(1, -148, 1, 0), UDim2.new(0, 92, 0, 0))
        what.TextColor3 = TEXT
        what.Font = Enum.Font.Code
        what.TextSize = 11
        what.TextXAlignment = Enum.TextXAlignment.Left
        what.TextTruncate = Enum.TextTruncate.AtEnd
        -- ago
        local ago = makeLabel("Ago", row, fmtAgo(e.unix), UDim2.new(0, 40, 1, 0), UDim2.new(1, -44, 0, 0))
        ago.TextColor3 = TEXT
        ago.Font = Enum.Font.Code
        ago.TextSize = 10
        ago.TextTransparency = 0.5
        ago.TextXAlignment = Enum.TextXAlignment.Right
    end
end

local feedCache: {any} = {}

remotes.ActivityFeedUpdated.OnClientEvent:Connect(function(entries: {any})
    feedCache = entries or {}
    rebuildFeed(feedCache)
end)

task.spawn(function()
    task.wait(2)
    local ok, snap = pcall(function() return remotes.GetActivityFeed:InvokeServer() end)
    if ok and snap and snap.entries then
        feedCache = snap.entries
        rebuildFeed(feedCache)
    else
        rebuildFeed({})
    end
end)

-- Refresh ago-strings every 15s without refetching
task.spawn(function()
    while true do
        task.wait(15)
        if #feedCache > 0 then rebuildFeed(feedCache) end
    end
end)

print("[HUD] mounted")
