--!strict
-- Client combat input. Translates mouse / keyboard / gamepad into the
-- combat RemoteEvents. The server is authoritative; this script only
-- emits intent.
--
-- Bindings:
--   M1 (LMB)        → PunchRequest
--   F (hold)        → BlockRequest(true) / BlockRequest(false) on release
--   Q               → DodgeRequest
--   1..N            → AbilityRequest("ability_<n>")  (Phase 3 wires ids)
--
-- Suppressed while a TextBox has focus or while the character is dead.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local PUNCH_ACTION = "Studio88_Punch"
local BLOCK_ACTION = "Studio88_Block"
local DODGE_ACTION = "Studio88_Dodge"

local function aliveAndUnfocused(): boolean
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if UserInputService:GetFocusedTextBox() then return false end
    return true
end

local function onPunch(_, state: Enum.UserInputState)
    if state ~= Enum.UserInputState.Begin then return end
    if not aliveAndUnfocused() then return end
    remotes.PunchRequest:FireServer()
end

local function onBlock(_, state: Enum.UserInputState)
    if not aliveAndUnfocused() then
        if state == Enum.UserInputState.End then
            remotes.BlockRequest:FireServer(false)
        end
        return
    end
    if state == Enum.UserInputState.Begin then
        remotes.BlockRequest:FireServer(true)
    elseif state == Enum.UserInputState.End then
        remotes.BlockRequest:FireServer(false)
    end
end

local function onDodge(_, state: Enum.UserInputState)
    if state ~= Enum.UserInputState.Begin then return end
    if not aliveAndUnfocused() then return end
    remotes.DodgeRequest:FireServer()
end

ContextActionService:BindAction(
    PUNCH_ACTION, onPunch, false,
    Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2
)
ContextActionService:BindAction(
    BLOCK_ACTION, onBlock, false,
    Enum.KeyCode.F, Enum.KeyCode.ButtonL2
)
ContextActionService:BindAction(
    DODGE_ACTION, onDodge, false,
    Enum.KeyCode.Q, Enum.KeyCode.ButtonB
)

-- Ability hotkeys 1..4 (Phase 3 maps these to real abilities).
local ABILITY_KEYS = {
    [Enum.KeyCode.One] = "ability_1",
    [Enum.KeyCode.Two] = "ability_2",
    [Enum.KeyCode.Three] = "ability_3",
    [Enum.KeyCode.Four] = "ability_4",
}
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not aliveAndUnfocused() then return end
    local abilityId = ABILITY_KEYS[input.KeyCode]
    if abilityId then
        remotes.AbilityRequest:FireServer(abilityId)
    end
end)
