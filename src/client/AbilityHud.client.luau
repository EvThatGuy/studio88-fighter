--!strict
-- Bottom-right ability slots showing the abilities for the player's
-- current class. Pressing 1..N fires the corresponding ability. Slots
-- are populated from GetClasses (which AbilityRuntime augments with
-- per-class ability lists).
--
-- Cooldown rendering is purely client-side: we predict cooldowns from
-- AbilityRequest fires + the spec's cooldownSec. The server is still
-- authoritative on whether a cast actually succeeded; predicted UI
-- can be wrong if the request was rejected (insufficient stamina, etc.)
-- but the visual artifact is brief — the next StaminaUpdated will
-- correct any guidance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Studio88_AbilityHud"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -16, 1, -32)
panel.Size = UDim2.fromOffset(280, 64)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screenGui

local pCorner = Instance.new("UICorner")
pCorner.CornerRadius = UDim.new(0, 10)
pCorner.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = panel

type SlotState = {
    abilityId: string,
    displayName: string,
    cooldownSec: number,
    readyAt: number,           -- os.clock() when next castable
    frame: Frame,
    fillFrame: Frame,
    keyLabel: TextLabel,
    nameLabel: TextLabel,
}

local slots: {SlotState} = {}

local function makeSlot(index: number, ability: any): SlotState
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(48, 48)
    frame.BackgroundColor3 = SURFACE
    frame.BorderSizePixel = 0
    frame.LayoutOrder = index
    frame.Parent = panel

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = frame

    -- Cooldown overlay: dark rectangle that scales from full → empty
    local fill = Instance.new("Frame")
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.fromScale(0, 1)
    fill.Size = UDim2.fromScale(1, 0)
    fill.BackgroundColor3 = Color3.new(0, 0, 0)
    fill.BackgroundTransparency = 0.4
    fill.BorderSizePixel = 0
    fill.ZIndex = 2
    fill.Parent = frame

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 8)
    fillCorner.Parent = fill

    local key = Instance.new("TextLabel")
    key.Size = UDim2.new(1, 0, 0, 14)
    key.Position = UDim2.fromOffset(0, 4)
    key.BackgroundTransparency = 1
    key.Font = Enum.Font.GothamBold
    key.TextColor3 = AMBER
    key.TextSize = 12
    key.ZIndex = 3
    key.Text = tostring(index)
    key.Parent = frame

    local name = Instance.new("TextLabel")
    name.AnchorPoint = Vector2.new(0, 1)
    name.Position = UDim2.new(0, 0, 1, -4)
    name.Size = UDim2.new(1, 0, 0, 12)
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.Gotham
    name.TextColor3 = Color3.fromRGB(220, 220, 230)
    name.TextSize = 10
    name.TextScaled = false
    name.TextWrapped = false
    name.ZIndex = 3
    name.Text = string.upper(tostring(ability.displayName or ability.id))
    name.Parent = frame

    return {
        abilityId = ability.id,
        displayName = ability.displayName,
        cooldownSec = ability.cooldownSec,
        readyAt = 0,
        frame = frame,
        fillFrame = fill,
        keyLabel = key,
        nameLabel = name,
    }
end

local function clearSlots()
    for _, slot in ipairs(slots) do
        slot.frame:Destroy()
    end
    slots = {}
end

local function rebuild(myClassKey: string)
    clearSlots()
    local ok, classList = pcall(function()
        return remotes.GetClasses:InvokeServer()
    end)
    if not ok or typeof(classList) ~= "table" then return end
    local mine: any = nil
    for _, entry in ipairs(classList) do
        if entry.key == myClassKey or entry.id == myClassKey then
            mine = entry; break
        end
    end
    if not mine or typeof(mine.abilities) ~= "table" then
        panel.Visible = false
        return
    end
    panel.Visible = #mine.abilities > 0
    for i, ability in ipairs(mine.abilities) do
        if i > 4 then break end  -- 4 hotkey slots max
        table.insert(slots, makeSlot(i, ability))
    end
end

-- Default class on script load; refreshed on ClassSelected
rebuild(Constants.DEFAULT_CLASS)

remotes.ClassSelected.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.classId) == "string" then
        rebuild(payload.classId)
    end
end)

-- Cooldown tick: animates the dark overlay shrinking from full → empty
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    for _, slot in ipairs(slots) do
        if slot.cooldownSec > 0 and slot.readyAt > now then
            local remaining = slot.readyAt - now
            local frac = math.clamp(remaining / slot.cooldownSec, 0, 1)
            slot.fillFrame.Size = UDim2.fromScale(1, frac)
        else
            slot.fillFrame.Size = UDim2.fromScale(1, 0)
        end
    end
end)

-- Keybinds: 1..4 → fire ability + start client-predicted cooldown
local ABILITY_KEYS = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
}

local function aliveAndUnfocused(): boolean
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if UserInputService:GetFocusedTextBox() then return false end
    return true
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not aliveAndUnfocused() then return end
    local slotIndex = ABILITY_KEYS[input.KeyCode]
    if not slotIndex then return end
    local slot = slots[slotIndex]
    if not slot then return end
    if os.clock() < slot.readyAt then return end
    -- The CombatInput script already binds 1..4 → AbilityRequest("ability_N")
    -- directly. We don't fire here; we just predict the cooldown for HUD.
    slot.readyAt = os.clock() + slot.cooldownSec
end)
