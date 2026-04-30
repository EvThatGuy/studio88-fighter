--!strict
-- Player HUD: balance, current tier, leaderboard rank panel. Subscribes to
-- BalanceUpdated + LeaderboardUpdated remotes; never reads currency
-- client-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

remotes.BalanceUpdated.OnClientEvent:Connect(function(coins, lifetime)
    setBalance(coins, lifetime)
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

print("[HUD] mounted")
