--!strict
-- Top-center match phase indicator. Shows lobby ("waiting for players"),
-- countdown ("MATCH IN 12s"), active ("MATCH 2:34 remaining"), or
-- results ("MATCH OVER").
--
-- Subscribes to MatchStateChanged. Pulls initial snapshot via
-- GetMatchState on script start since the match loop may have started
-- before this client joined.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_MatchHud"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 16)
panel.Size = UDim2.fromOffset(280, 48)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.Size = UDim2.fromScale(1, 0.45)
phaseLabel.Position = UDim2.fromScale(0, 0)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Font = Enum.Font.GothamBlack
phaseLabel.TextColor3 = CYAN
phaseLabel.TextSize = 14
phaseLabel.Text = "LOBBY"
phaseLabel.Parent = panel

local detailLabel = Instance.new("TextLabel")
detailLabel.Name = "Detail"
detailLabel.Size = UDim2.fromScale(1, 0.55)
detailLabel.Position = UDim2.fromScale(0, 0.45)
detailLabel.BackgroundTransparency = 1
detailLabel.Font = Enum.Font.Gotham
detailLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
detailLabel.TextSize = 12
detailLabel.Text = "waiting for players..."
detailLabel.Parent = panel

local currentState: any = {phase = "lobby", participants = {}, scores = {}}
local countdownDeadline = 0   -- os.clock() target for countdown phase

local function fmtMSS(secs: number): string
    secs = math.max(0, math.floor(secs + 0.5))
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function applyState(state: any)
    if typeof(state) ~= "table" then return end
    currentState = state
    if state.phase == "lobby" then
        phaseLabel.TextColor3 = CYAN
        phaseLabel.Text = "LOBBY"
        detailLabel.Text = string.format("waiting for %d players...", Constants.LOBBY_MIN_PLAYERS)
    elseif state.phase == "countdown" then
        phaseLabel.TextColor3 = AMBER
        phaseLabel.Text = "STARTING SOON"
        countdownDeadline = os.clock() + Constants.LOBBY_COUNTDOWN_SEC
        detailLabel.Text = string.format("match in %ds", Constants.LOBBY_COUNTDOWN_SEC)
    elseif state.phase == "active" then
        phaseLabel.TextColor3 = PINK
        phaseLabel.Text = "MATCH ACTIVE"
        detailLabel.Text = "match in progress"
    elseif state.phase == "results" then
        phaseLabel.TextColor3 = AMBER
        phaseLabel.Text = "MATCH OVER"
        detailLabel.Text = "results..."
    end
end

remotes.MatchStateChanged.OnClientEvent:Connect(applyState)

-- Pull initial snapshot in case the loop is mid-cycle.
task.spawn(function()
    local ok, snapshot = pcall(function()
        return remotes.GetMatchState:InvokeServer()
    end)
    if ok then applyState(snapshot) end
end)

-- Per-frame timer refresh for countdown / active phases.
RunService.RenderStepped:Connect(function()
    if currentState.phase == "countdown" then
        local remaining = math.max(0, countdownDeadline - os.clock())
        detailLabel.Text = string.format("match in %ds", math.ceil(remaining))
    elseif currentState.phase == "active" and currentState.endUnix then
        local remaining = currentState.endUnix - os.time()
        detailLabel.Text = "remaining " .. fmtMSS(remaining)
    end
end)
