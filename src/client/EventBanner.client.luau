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
    sg = Instance.new("ScreenGui")
    (sg :: ScreenGui).Name = "Studio88EventBanner"
    (sg :: ScreenGui).ResetOnSpawn = false
    (sg :: ScreenGui).IgnoreGuiInset = true
    (sg :: ScreenGui).DisplayOrder = 60
    (sg :: ScreenGui).Parent = pg

    local accent = colorForName(activeName)

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, 8)
    card.Size = UDim2.new(0, 360, 0, 50)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = sg :: ScreenGui
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    strokeRef = Instance.new("UIStroke")
    (strokeRef :: UIStroke).Color = accent
    (strokeRef :: UIStroke).Thickness = 2
    (strokeRef :: UIStroke).Parent = card

    labelRef = Instance.new("TextLabel")
    (labelRef :: TextLabel).Size = UDim2.new(1, -16, 0, 22)
    (labelRef :: TextLabel).Position = UDim2.new(0, 8, 0, 4)
    (labelRef :: TextLabel).BackgroundTransparency = 1
    (labelRef :: TextLabel).Text = string.format("★ %s · %.1fx", activeName, activeMult or 1.0)
    (labelRef :: TextLabel).TextColor3 = accent
    (labelRef :: TextLabel).TextStrokeTransparency = 0.3
    (labelRef :: TextLabel).TextStrokeColor3 = DARK
    (labelRef :: TextLabel).Font = Enum.Font.GothamBold
    (labelRef :: TextLabel).TextScaled = true
    (labelRef :: TextLabel).Parent = card

    subRef = Instance.new("TextLabel")
    (subRef :: TextLabel).Size = UDim2.new(1, -16, 0, 20)
    (subRef :: TextLabel).Position = UDim2.new(0, 8, 0, 28)
    (subRef :: TextLabel).BackgroundTransparency = 1
    (subRef :: TextLabel).Text = "ends in ..."
    (subRef :: TextLabel).TextColor3 = Color3.fromRGB(220, 220, 220)
    (subRef :: TextLabel).TextStrokeTransparency = 0.5
    (subRef :: TextLabel).Font = Enum.Font.Code
    (subRef :: TextLabel).TextScaled = true
    (subRef :: TextLabel).Parent = card
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
        if activeEnd and subRef and subRef.Parent then
            local remaining = activeEnd - os.time()
            if remaining <= 0 then
                teardown()
            else
                (subRef :: TextLabel).Text = "ends in " .. fmtRemaining(remaining)
            end
        end
    end
end)

print("[EventBanner] client ready")
