--!strict
-- Bottom-center stamina bar + class indicator. Subscribes to
-- StaminaUpdated for reactive updates. Phase 4 polishes; this is the
-- minimum so the player can see whether an action will succeed.

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
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_CombatHud"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -32)
panel.Size = UDim2.fromOffset(360, 56)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local classLabel = Instance.new("TextLabel")
classLabel.Name = "Class"
classLabel.AnchorPoint = Vector2.new(0, 0)
classLabel.Position = UDim2.fromOffset(12, 6)
classLabel.Size = UDim2.new(1, -24, 0, 16)
classLabel.BackgroundTransparency = 1
classLabel.Font = Enum.Font.GothamBold
classLabel.TextColor3 = CYAN
classLabel.TextSize = 13
classLabel.TextXAlignment = Enum.TextXAlignment.Left
classLabel.Text = string.upper(Constants.DEFAULT_CLASS)
classLabel.Parent = panel

local barTrack = Instance.new("Frame")
barTrack.Name = "Track"
barTrack.AnchorPoint = Vector2.new(0, 1)
barTrack.Position = UDim2.new(0, 12, 1, -10)
barTrack.Size = UDim2.new(1, -24, 0, 16)
barTrack.BackgroundColor3 = SURFACE
barTrack.BorderSizePixel = 0
barTrack.Parent = panel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 6)
trackCorner.Parent = barTrack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = PINK
barFill.BorderSizePixel = 0
barFill.Parent = barTrack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = barFill

local valueLabel = Instance.new("TextLabel")
valueLabel.Name = "Value"
valueLabel.Size = UDim2.fromScale(1, 1)
valueLabel.BackgroundTransparency = 1
valueLabel.Font = Enum.Font.GothamBold
valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
valueLabel.TextSize = 11
valueLabel.Text = "100 / 100"
valueLabel.Parent = barTrack

local lastFrac = 1
local function setStamina(current: number, max: number)
    if max <= 0 then return end
    local frac = math.clamp(current / max, 0, 1)
    lastFrac = frac
    TweenService:Create(barFill, TweenInfo.new(0.15), {
        Size = UDim2.fromScale(frac, 1),
    }):Play()
    valueLabel.Text = string.format("%d / %d", math.floor(current + 0.5), math.floor(max + 0.5))
    if frac < 0.25 then
        barFill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
    elseif frac < 0.5 then
        barFill.BackgroundColor3 = Color3.fromRGB(255, 176, 0)
    else
        barFill.BackgroundColor3 = PINK
    end
end

remotes.StaminaUpdated.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    setStamina(payload.current or 0, payload.max or Constants.STAMINA_MAX)
end)

remotes.ClassSelected.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.classId) == "string" then
        classLabel.Text = string.upper(payload.classId)
    end
end)
