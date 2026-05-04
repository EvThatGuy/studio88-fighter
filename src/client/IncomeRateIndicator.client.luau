--!strict
-- "+N/sec" income rate indicator. Listens to BalanceUpdated and
-- maintains a 5-sample rolling window to compute average gain per sec.
-- Renders a small bottom-center badge.

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
    if n < 1000 then return tostring(math.floor(n)) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.1fM", n / 1000000)
end

-- Rolling window of {time, coins} samples; rate = (latest - oldest) / dt
local samples = {}
local WINDOW_SAMPLES = 5

local labelRef: TextLabel? = nil

local function makeBadge()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88IncomeRate")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88IncomeRate"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 72
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.Position = UDim2.new(0.5, 0, 1, -16)
    card.Size = UDim2.new(0, 140, 0, 32)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, -8)
    label.Position = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = "+0/sec"
    label.TextColor3 = AMBER
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = card
    labelRef = label
end

local function record(coins: number)
    local now = os.clock()
    table.insert(samples, {t = now, c = coins})
    if #samples > WINDOW_SAMPLES then table.remove(samples, 1) end
    if not labelRef or not labelRef.Parent then return end
    if #samples < 2 then
        labelRef.Text = "+0/sec"
        return
    end
    local first = samples[1]
    local last = samples[#samples]
    local dt = last.t - first.t
    if dt <= 0 then return end
    local rate = (last.c - first.c) / dt
    if rate < 0 then rate = 0 end  -- spending > earning shows as 0
    labelRef.Text = string.format("+%s/sec", fmtCoins(rate))
end

makeBadge()
player.CharacterAdded:Connect(function() task.wait(0.3); makeBadge(); samples = {} end)
remotes.BalanceUpdated.OnClientEvent:Connect(function(coins: number)
    record(coins)
end)

print("[IncomeRateIndicator] client ready")
