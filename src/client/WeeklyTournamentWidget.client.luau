--!strict
-- Top-left HUD widget showing the player's current week tournament status:
-- "MY WEEK $X (rank Y)". Refreshes every 30s by invoking
-- GetWeeklyTournament. Click opens... nothing yet (placeholder; could
-- open a modal in a future iteration with the top-10 leaderboard).

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
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    if n < 1000000000 then return string.format("%.2fM", n / 1000000) end
    return string.format("%.2fB", n / 1000000000)
end

local function makeWidget()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88WeeklyTournament")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88WeeklyTournament"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 70
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0, 0)
    card.Position = UDim2.new(0, 16, 0, 78)  -- below leaderstats
    card.Size = UDim2.new(0, 200, 0, 56)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = sg

    local cor = Instance.new("UICorner")
    cor.CornerRadius = UDim.new(0, 10)
    cor.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -16, 0, 22)
    title.Position = UDim2.new(0, 8, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "★ THIS WEEK"
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.4
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local body = Instance.new("TextLabel")
    body.Name = "Body"
    body.Size = UDim2.new(1, -16, 0, 26)
    body.Position = UDim2.new(0, 8, 0, 26)
    body.BackgroundTransparency = 1
    body.Text = "$0 (—)"
    body.TextColor3 = CYAN
    body.TextStrokeTransparency = 0.5
    body.Font = Enum.Font.Code
    body.TextScaled = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Parent = card

    return sg, body
end

local sg, bodyLbl = makeWidget()

local function refresh()
    pcall(function()
        local snap = remotes.GetWeeklyTournament:InvokeServer()
        if not snap or not bodyLbl.Parent then return end
        local rankPart = snap.rank and string.format(" (rank %d)", snap.rank) or " (—)"
        bodyLbl.Text = "$" .. fmtCoins(snap.weeklyEarned or 0) .. rankPart
    end)
end

-- First fetch + 30s loop
task.spawn(function()
    task.wait(2)  -- let server-side bootstrap settle
    refresh()
    while sg.Parent do
        task.wait(30)
        refresh()
    end
end)

print("[WeeklyTournamentWidget] client ready")
