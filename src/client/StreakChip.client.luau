--!strict
-- Bottom-right "🔥 Day N" streak chip. Sits ABOVE the Tribute Quick
-- Claim button. Always visible so the streak day + tomorrow's reward
-- sticks in the player's peripheral vision (loss-aversion driver per
-- daily-bonus retention playbook).
--
-- Polls GetDailyStreakSchedule on join + every 60s + reflects
-- DailyBonusGranted instantly. If currentStreak == 0 (brand new), shows
-- a softer "🔥 Start your streak" prompt to teach the mechanic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local GOLD = Color3.fromRGB(255, 215, 100)
local SURFACE = Color3.fromRGB(20, 17, 31)
local DIM = Color3.fromRGB(180, 180, 195)

local cardRef: Frame? = nil
local titleRef: TextLabel? = nil
local subRef: TextLabel? = nil
local strokeRef: UIStroke? = nil

local currentStreak = 0
local nextDayInfo: { coins: number, tag: string, jackpot: boolean }? = nil

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(math.floor(n)) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.1fM", n / 1000000)
end

local function makeChip()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88StreakChip")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88StreakChip"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 71
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(1, 1)
    -- Tribute claim button is at (1, -16, 1, -16) Size 200x50.
    -- Stack chip 8px above it: y offset -16 - 50 - 8 = -74.
    card.Position = UDim2.new(1, -16, 1, -74)
    card.Size = UDim2.new(0, 200, 0, 44)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card
    strokeRef = stroke

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 18)
    title.Position = UDim2.new(0, 8, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "🔥 Day 0"
    title.TextColor3 = AMBER
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    titleRef = title

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -16, 0, 18)
    sub.Position = UDim2.new(0, 8, 0, 22)
    sub.BackgroundTransparency = 1
    sub.Text = "tomorrow: +500"
    sub.TextColor3 = DIM
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.Parent = card
    subRef = sub

    cardRef = card
end

local function applyState()
    if not titleRef or not subRef or not strokeRef then return end
    if currentStreak <= 0 then
        titleRef.Text = "🔥 Start your streak"
        subRef.Text = "log in tomorrow for +500"
        titleRef.TextColor3 = AMBER
        strokeRef.Color = AMBER
        return
    end
    titleRef.Text = string.format("🔥 Day %d", currentStreak)
    if nextDayInfo then
        local tag = (nextDayInfo.tag and nextDayInfo.tag ~= "") and nextDayInfo.tag or ""
        if nextDayInfo.jackpot then
            subRef.Text = string.format("tomorrow: +%s · %s", fmtCoins(nextDayInfo.coins), tag)
            titleRef.TextColor3 = GOLD
            strokeRef.Color = GOLD
            strokeRef.Transparency = 0.2
        else
            subRef.Text = string.format("tomorrow: +%s", fmtCoins(nextDayInfo.coins))
            titleRef.TextColor3 = AMBER
            strokeRef.Color = AMBER
            strokeRef.Transparency = 0.4
        end
    else
        subRef.Text = "claim again tomorrow"
        titleRef.TextColor3 = AMBER
        strokeRef.Color = AMBER
    end
end

local function poll()
    local ok, snap = pcall(function() return remotes.GetDailyStreakSchedule:InvokeServer() end)
    if not ok or typeof(snap) ~= "table" then return end
    currentStreak = tonumber(snap.currentStreak) or 0
    nextDayInfo = nil
    if typeof(snap.schedule) == "table" then
        for _, s in ipairs(snap.schedule) do
            if s.current == true then
                nextDayInfo = {
                    coins = tonumber(s.coins) or 0,
                    tag = tostring(s.tag or ""),
                    jackpot = s.jackpot == true,
                }
                break
            end
        end
    end
    applyState()
end

makeChip()

task.spawn(function()
    task.wait(2)
    poll()
    while true do
        task.wait(60)
        poll()
    end
end)

remotes.DailyBonusGranted.OnClientEvent:Connect(function(streak: any, _reward: any)
    local s = tonumber(streak)
    if s and s > currentStreak then
        currentStreak = s
        -- Re-poll to get new "next day" info quickly.
        task.spawn(poll)
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    makeChip()
    applyState()
end)

print("[StreakChip] client ready")
