--!strict
-- Top-right scoreboard during active matches. Lists each participant +
-- their KO count, sorted highest first. On results phase, replaces with
-- a center "VICTORY" / "DEFEAT" / "DRAW" banner for MATCH_RESULTS_SEC.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local PINK = Color3.fromRGB(255, 46, 136)
local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_MatchScoreboard"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Scoreboard panel (right side, hidden until active phase)
local scoreboard = Instance.new("Frame")
scoreboard.Name = "Scoreboard"
scoreboard.AnchorPoint = Vector2.new(1, 0)
scoreboard.Position = UDim2.new(1, -16, 0, 80)
scoreboard.Size = UDim2.fromOffset(220, 8)  -- height grows per row
scoreboard.AutomaticSize = Enum.AutomaticSize.Y
scoreboard.BackgroundColor3 = DARK
scoreboard.BackgroundTransparency = 0.15
scoreboard.BorderSizePixel = 0
scoreboard.Visible = false
scoreboard.Parent = screenGui

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 10)
sbCorner.Parent = scoreboard

local sbPad = Instance.new("UIPadding")
sbPad.PaddingTop = UDim.new(0, 8)
sbPad.PaddingBottom = UDim.new(0, 8)
sbPad.PaddingLeft = UDim.new(0, 12)
sbPad.PaddingRight = UDim.new(0, 12)
sbPad.Parent = scoreboard

local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0, 4)
sbLayout.SortOrder = Enum.SortOrder.LayoutOrder
sbLayout.Parent = scoreboard

local sbHeader = Instance.new("TextLabel")
sbHeader.Size = UDim2.new(1, 0, 0, 16)
sbHeader.BackgroundTransparency = 1
sbHeader.Font = Enum.Font.GothamBold
sbHeader.TextColor3 = AMBER
sbHeader.TextSize = 11
sbHeader.TextXAlignment = Enum.TextXAlignment.Left
sbHeader.Text = "SCOREBOARD"
sbHeader.LayoutOrder = 0
sbHeader.Parent = scoreboard

-- Results banner (center, fades in/out)
local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.4)
banner.Size = UDim2.fromOffset(420, 110)
banner.BackgroundColor3 = DARK
banner.BackgroundTransparency = 1  -- start hidden
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = screenGui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 14)
bannerCorner.Parent = banner

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = PINK
bannerStroke.Thickness = 2
bannerStroke.Transparency = 1
bannerStroke.Parent = banner

local bannerTitle = Instance.new("TextLabel")
bannerTitle.Size = UDim2.new(1, 0, 0.5, 0)
bannerTitle.Position = UDim2.fromScale(0, 0.05)
bannerTitle.BackgroundTransparency = 1
bannerTitle.Font = Enum.Font.GothamBlack
bannerTitle.TextSize = 36
bannerTitle.TextColor3 = AMBER
bannerTitle.TextTransparency = 1
bannerTitle.Text = ""
bannerTitle.Parent = banner

local bannerSub = Instance.new("TextLabel")
bannerSub.Size = UDim2.new(1, 0, 0.4, 0)
bannerSub.Position = UDim2.fromScale(0, 0.55)
bannerSub.BackgroundTransparency = 1
bannerSub.Font = Enum.Font.Gotham
bannerSub.TextSize = 13
bannerSub.TextColor3 = Color3.fromRGB(220, 220, 230)
bannerSub.TextTransparency = 1
bannerSub.Text = ""
bannerSub.Parent = banner

local function showBanner(title: string, sub: string, accent: Color3)
    banner.Visible = true
    bannerTitle.Text = title
    bannerTitle.TextColor3 = accent
    bannerSub.Text = sub
    bannerStroke.Color = accent
    TweenService:Create(banner, TweenInfo.new(0.35), {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(bannerStroke, TweenInfo.new(0.35), {Transparency = 0}):Play()
    TweenService:Create(bannerTitle, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
    TweenService:Create(bannerSub, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
end

local function hideBanner()
    if not banner.Visible then return end
    TweenService:Create(banner, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(bannerStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
    TweenService:Create(bannerTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    TweenService:Create(bannerSub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    task.delay(0.35, function() banner.Visible = false end)
end

local function nameFor(userId: number): string
    local p = Players:GetPlayerByUserId(userId)
    return p and p.DisplayName or ("user_" .. tostring(userId))
end

local function clearRows()
    for _, child in ipairs(scoreboard:GetChildren()) do
        if child:IsA("TextLabel") and child ~= sbHeader then
            child:Destroy()
        end
    end
end

local function renderScoreboard(state: any)
    if not state.participants or #state.participants == 0 then
        scoreboard.Visible = false
        return
    end
    clearRows()
    -- Sort participants by score desc
    local entries = {}
    for _, userId in ipairs(state.participants) do
        table.insert(entries, {userId = userId, score = state.scores[userId] or 0})
    end
    table.sort(entries, function(a, b) return a.score > b.score end)
    for i, entry in ipairs(entries) do
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, 0, 0, 16)
        row.BackgroundTransparency = 1
        row.Font = entry.userId == player.UserId and Enum.Font.GothamBold or Enum.Font.Gotham
        row.TextColor3 = entry.userId == player.UserId and CYAN or Color3.fromRGB(220, 220, 230)
        row.TextSize = 12
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = string.format("%s   %d KO", nameFor(entry.userId), entry.score)
        row.LayoutOrder = i
        row.Parent = scoreboard
    end
    scoreboard.Visible = true
end

remotes.MatchStateChanged.OnClientEvent:Connect(function(state: any)
    if typeof(state) ~= "table" then return end
    if state.phase == "active" then
        hideBanner()
        renderScoreboard(state)
    elseif state.phase == "results" then
        scoreboard.Visible = false
        local winnerId = state.winnerUserId
        if winnerId == player.UserId then
            showBanner("VICTORY", "match won — well fought", PINK)
        elseif winnerId == nil then
            showBanner("DRAW", "no clear winner this round", AMBER)
        else
            showBanner("DEFEAT", "next match starts soon", CYAN)
        end
    else
        scoreboard.Visible = false
        hideBanner()
    end
end)

-- Pull initial snapshot (in case we joined mid-match)
task.spawn(function()
    local ok, state = pcall(function() return remotes.GetMatchState:InvokeServer() end)
    if ok and typeof(state) == "table" and state.phase == "active" then
        renderScoreboard(state)
    end
end)
