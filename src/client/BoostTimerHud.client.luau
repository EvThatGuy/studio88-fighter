--!strict
-- Top-right HUD badge that shows pet-boost remaining time + multiplier
-- ONLY when a boost is active. Listens to PetBoostStateChanged + polls
-- GetPetBoost on join. Ticks every second. Pulses below 60s for urgency.
-- Hidden whenever no boost is active so the corner stays clean.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local URGENT = Color3.fromRGB(255, 96, 96)
local SURFACE = Color3.fromRGB(20, 17, 31)

local cardRef: Frame? = nil
local labelRef: TextLabel? = nil
local subRef: TextLabel? = nil
local strokeRef: UIStroke? = nil
local state: { active: boolean, remainingSec: number, multiplier: number } = {
    active = false, remainingSec = 0, multiplier = 2,
}

local function fmtTime(s: number): string
    if s < 0 then s = 0 end
    local m = math.floor(s / 60)
    local rem = s - m * 60
    return string.format("%d:%02d", m, rem)
end

local function makeWidget()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88BoostTimer")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88BoostTimer"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 73
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(1, 0)
    card.Position = UDim2.new(1, -16, 0, 16)
    card.Size = UDim2.new(0, 168, 0, 48)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Visible = false
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = AMBER
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = card
    strokeRef = stroke

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 18)
    title.Position = UDim2.new(0, 8, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "PET BOOST x2"
    title.TextColor3 = AMBER
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    labelRef = title

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -16, 0, 22)
    sub.Position = UDim2.new(0, 8, 0, 22)
    sub.BackgroundTransparency = 1
    sub.Text = "0:00 left"
    sub.TextColor3 = Color3.fromRGB(220, 220, 230)
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = card
    subRef = sub

    cardRef = card
end

local function applyState()
    if not cardRef or not cardRef.Parent or not labelRef or not subRef or not strokeRef then return end
    if not state.active or state.remainingSec <= 0 then
        cardRef.Visible = false
        return
    end
    cardRef.Visible = true
    labelRef.Text = string.format("PET BOOST x%.1f", state.multiplier or 2)
    subRef.Text = string.format("%s left", fmtTime(state.remainingSec))
    if state.remainingSec <= 60 then
        labelRef.TextColor3 = URGENT
        strokeRef.Color = URGENT
        -- Subtle pulse when under 1m
        local goal = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(strokeRef, goal, { Transparency = 0.05 }):Play()
    else
        labelRef.TextColor3 = AMBER
        strokeRef.Color = AMBER
        strokeRef.Transparency = 0.3
    end
end

makeWidget()

-- Initial poll
task.spawn(function()
    local ok, snap = pcall(function() return remotes.GetPetBoost:InvokeServer() end)
    if ok and typeof(snap) == "table" then
        state.active = snap.active == true
        state.remainingSec = tonumber(snap.remainingSec) or 0
        state.multiplier = tonumber(snap.multiplier) or 2
        applyState()
    end
end)

-- Push updates from server
remotes.PetBoostStateChanged.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    state.active = payload.active == true
    state.remainingSec = tonumber(payload.remainingSec) or 0
    state.multiplier = tonumber(payload.multiplier) or state.multiplier or 2
    applyState()
end)

-- Local 1Hz tick to count down between server pushes
task.spawn(function()
    while true do
        task.wait(1)
        if state.active and state.remainingSec > 0 then
            state.remainingSec -= 1
            if state.remainingSec <= 0 then
                state.active = false
            end
            applyState()
        end
    end
end)

-- Re-mount on respawn (PlayerGui might be reset)
player.CharacterAdded:Connect(function()
    task.wait(0.3)
    makeWidget()
    applyState()
end)

print("[BoostTimerHud] client ready")
