--!strict
-- Renders a brief screen flash when the LOCAL player gets hit, and a
-- floating damage number above the victim when ANYONE gets hit. Sound
-- hooks read Constants.SOUND_IDS.{hit,block} but no-op silently when
-- the IDs are unset.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_HitFx"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 1
flash.Parent = screenGui

local function flashScreen()
    flash.BackgroundTransparency = 0.6
    TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1,
    }):Play()
end

local function playSound(id: string)
    if id == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function() s:Destroy() end)
    task.delay(2, function() if s.Parent then s:Destroy() end end)
end

local function spawnDamageNumber(victimUserId: number, finalDamage: number, blocked: boolean)
    local victim = Players:GetPlayerByUserId(victimUserId)
    if not victim or not victim.Character then return end
    local head = victim.Character:FindFirstChild("Head") :: BasePart?
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(80, 32)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    if blocked then
        label.Text = "BLOCK"
        label.TextColor3 = Color3.fromRGB(0, 240, 255)
    else
        label.Text = "-" .. tostring(math.floor(finalDamage + 0.5))
        label.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
    label.Parent = billboard

    TweenService:Create(billboard, TweenInfo.new(0.8), {
        StudsOffset = Vector3.new(0, 5, 0),
    }):Play()
    TweenService:Create(label, TweenInfo.new(0.8), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.85, function()
        if billboard.Parent then billboard:Destroy() end
    end)
end

remotes.HitLanded.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    local victimUserId = tonumber(payload.victimUserId)
    if not victimUserId then return end
    spawnDamageNumber(victimUserId, payload.finalDamage or 0, payload.blocked == true)
    if victimUserId == player.UserId then
        flashScreen()
        playSound(payload.blocked and Constants.SOUND_IDS.block or Constants.SOUND_IDS.hit)
    end
end)
