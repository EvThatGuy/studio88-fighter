--!strict
-- 1v1 duel HUD. Shows a top-center pill with the current duel state and
-- binds the K key to toggle queue membership. Server is authoritative
-- on state; this script is purely a renderer that reacts to
-- DuelStateChanged push events.
--
-- States rendered:
--   idle    → "Press K for 1v1"
--   queued  → "In queue (N waiting) — K to leave"
--   active  → "DUEL  vs <opp>   <self>-<opp>   <secs>s"
--   ended   → "DUEL WON +<xp> XP"  /  "DUEL LOST +<xp> XP"

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

-- ── palette (matches arena / class-select theming) ───────────────────
local DARK    = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)
local CYAN    = Color3.fromRGB(0, 240, 255)
local PINK    = Color3.fromRGB(255, 46, 136)
local AMBER   = Color3.fromRGB(255, 176, 0)
local GREEN   = Color3.fromRGB(80, 220, 130)
local TEXT    = Color3.fromRGB(232, 230, 245)
local TEXT_DIM = Color3.fromRGB(165, 160, 190)

-- ── ScreenGui scaffold ───────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_DuelHud"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 4
screenGui.Parent = player:WaitForChild("PlayerGui")

local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 84)  -- below match scoreboard
pill.Size = UDim2.fromOffset(420, 44)
pill.BackgroundColor3 = SURFACE
pill.BackgroundTransparency = 0.15
pill.BorderSizePixel = 0
pill.Visible = false
pill.Parent = screenGui

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(1, 0)
pillCorner.Parent = pill

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = CYAN
pillStroke.Thickness = 1.5
pillStroke.Transparency = 0.3
pillStroke.Parent = pill

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.TextColor3 = TEXT
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.Text = ""
label.Parent = pill

-- ── state ────────────────────────────────────────────────────────────
type DuelState = {
    phase: string,                  -- "idle" | "queued" | "active" | "ended"
    queueTotal: number?,
    opponentName: string?,
    selfScore: number?,
    opponentScore: number?,
    endsAtUnix: number?,
    won: boolean?,
    xpAwarded: number?,
}

local current: DuelState = { phase = "idle" }

local function setStrokeAndBg(strokeColor: Color3, bgAlpha: number?)
    pillStroke.Color = strokeColor
    pillStroke.Transparency = 0.2
    pill.BackgroundTransparency = bgAlpha or 0.15
end

local function render()
    if current.phase == "idle" then
        label.Text = "PRESS K FOR 1V1"
        label.TextColor3 = TEXT_DIM
        setStrokeAndBg(CYAN, 0.35)
        pill.Visible = true
    elseif current.phase == "queued" then
        local n = current.queueTotal or 1
        label.Text = string.format("IN QUEUE  (%d WAITING)   ·   K TO LEAVE", n)
        label.TextColor3 = AMBER
        setStrokeAndBg(AMBER, 0.15)
        pill.Visible = true
    elseif current.phase == "active" then
        local opp = current.opponentName or "?"
        local self = current.selfScore or 0
        local oppS = current.opponentScore or 0
        local now = os.time()
        local ends = current.endsAtUnix or now
        local left = math.max(0, ends - now)
        label.Text = string.format("DUEL  vs %s   %d—%d   %ds", opp, self, oppS, left)
        label.TextColor3 = TEXT
        setStrokeAndBg(self > oppS and CYAN or PINK, 0.10)
        pill.Visible = true
    elseif current.phase == "ended" then
        local xp = current.xpAwarded or 0
        if current.won then
            label.Text = string.format("DUEL WON  ·  +%d XP", xp)
            label.TextColor3 = GREEN
            setStrokeAndBg(GREEN, 0.10)
        else
            label.Text = string.format("DUEL LOST  ·  +%d XP", xp)
            label.TextColor3 = PINK
            setStrokeAndBg(PINK, 0.10)
        end
        pill.Visible = true
    else
        pill.Visible = false
    end
end

-- ── server push ──────────────────────────────────────────────────────
remotes.DuelStateChanged.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    current = {
        phase = tostring(payload.phase or "idle"),
        queueTotal = tonumber(payload.queueTotal),
        opponentName = payload.opponentName and tostring(payload.opponentName) or nil,
        selfScore = tonumber(payload.selfScore),
        opponentScore = tonumber(payload.opponentScore),
        endsAtUnix = tonumber(payload.endsAtUnix),
        won = payload.won == true,
        xpAwarded = tonumber(payload.xpAwarded),
    }
    render()
end)

-- ── per-frame timer refresh while active ─────────────────────────────
RunService.Heartbeat:Connect(function()
    if current.phase == "active" then
        render()
    end
end)

-- ── K key: toggle queue membership ───────────────────────────────────
local QUEUE_ACTION = "Studio88_DuelQueueToggle"
ContextActionService:BindAction(QUEUE_ACTION, function(_, state)
    if state ~= Enum.UserInputState.Begin then return end
    if UserInputService:GetFocusedTextBox() then return end
    if current.phase == "active" or current.phase == "ended" then
        return  -- can't toggle queue while in a duel
    end
    local joining = current.phase ~= "queued"
    remotes.DuelQueueRequest:FireServer({ join = joining })
end, false, Enum.KeyCode.K)

render()
