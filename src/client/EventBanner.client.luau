--!strict
-- Server-wide event countdown banner. Top-of-screen card showing the
-- active event name + remaining time. Listens to EventStateChanged and
-- runs a local 1s countdown between server pushes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function colorForName(name: string): Color3
    -- Crude color mapping by event name keyword
    if name:find("GTA6") then return AMBER end
    if name:find("LAUNCH") then return PINK end
    return CYAN
end

local function fmtRemaining(sec: number): string
    if sec < 60 then return sec .. "s" end
    if sec < 3600 then
        return string.format("%dm %ds", math.floor(sec / 60), sec % 60)
    end
    return string.format("%dh %dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60))
end

local activeEnd: number? = nil
local activeName: string? = nil
local activeMult: number? = nil
local sg: ScreenGui? = nil
local labelRef: TextLabel? = nil
local subRef: TextLabel? = nil
local strokeRef: UIStroke? = nil

local function teardown()
    if sg then sg:Destroy(); sg = nil end
    activeEnd = nil
    activeName = nil
    activeMult = nil
end

local function rebuildBanner()
    teardown()
    if not activeName or not activeEnd then return end
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local newSg = Instance.new("ScreenGui")
    newSg.Name = "Studio88EventBanner"
    newSg.ResetOnSpawn = false
    newSg.IgnoreGuiInset = true
    newSg.DisplayOrder = 60
    newSg.Parent = pg
    sg = newSg

    local accent = colorForName(activeName)

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, 8)
    card.Size = UDim2.new(0, 360, 0, 50)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = newSg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local newStroke = Instance.new("UIStroke")
    newStroke.Color = accent
    newStroke.Thickness = 2
    newStroke.Parent = card
    strokeRef = newStroke

    local newLabel = Instance.new("TextLabel")
    newLabel.Size = UDim2.new(1, -16, 0, 22)
    newLabel.Position = UDim2.new(0, 8, 0, 4)
    newLabel.BackgroundTransparency = 1
    newLabel.Text = string.format("★ %s · %.1fx", activeName, activeMult or 1.0)
    newLabel.TextColor3 = accent
    newLabel.TextStrokeTransparency = 0.3
    newLabel.TextStrokeColor3 = DARK
    newLabel.Font = Enum.Font.GothamBold
    newLabel.TextScaled = true
    newLabel.Parent = card
    labelRef = newLabel

    local newSub = Instance.new("TextLabel")
    newSub.Size = UDim2.new(1, -16, 0, 20)
    newSub.Position = UDim2.new(0, 8, 0, 28)
    newSub.BackgroundTransparency = 1
    newSub.Text = "ends in ..."
    newSub.TextColor3 = Color3.fromRGB(220, 220, 220)
    newSub.TextStrokeTransparency = 0.5
    newSub.Font = Enum.Font.Code
    newSub.TextScaled = true
    newSub.Parent = card
    subRef = newSub
end

remotes.EventStateChanged.OnClientEvent:Connect(function(payload)
    if not payload or not payload.active then teardown(); return end
    local ev = payload.event
    if not ev then teardown(); return end
    activeName = ev.name
    activeMult = ev.multiplier
    activeEnd = os.time() + (payload.endsInSec or 0)
    rebuildBanner()
end)

-- Local 1s countdown between server pushes
task.spawn(function()
    while true do
        task.wait(1)
        local s = subRef
        if activeEnd and s and s.Parent then
            local remaining = activeEnd - os.time()
            if remaining <= 0 then
                teardown()
            else
                s.Text = "ends in " .. fmtRemaining(remaining)
            end
        end
    end
end)

print("[EventBanner] client ready")
