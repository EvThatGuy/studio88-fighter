--!strict
-- Desktop + gamepad keyboard shortcuts for opening Studio 88 modals.
-- Decoupled from HUD via the UICommands registry: each modal opener
-- (HUD-hosted Pets/Spin/Quests/etc + freestanding Help/DailyShop/Codes/
-- FriendCode overlays) registers itself as "openX" → openX is invoked
-- here when its key fires.
--
-- Bindings avoid Roblox built-ins (Esc, /, Tab, F9-F12, ` console).
-- Shortcuts are suppressed while a TextBox has focus so typing in
-- chat / codes input doesn't trigger modals.
--
-- Gamepad bindings use ContextActionService so console controllers can
-- reach the same actions via DPad/face buttons.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local UICommands = require(Modules:WaitForChild("UICommands"))

local player = Players.LocalPlayer

-- key -> (label, command name).  Q is reserved by Roblox default
-- (camera-pan in the legacy control scheme) so we use J for Quests.
-- T is also reserved (chat in some control schemes), but only when
-- TRADING is enabled do we bind it; otherwise it is left untouched.
type Binding = { key: Enum.KeyCode, label: string, command: string, gated: (() -> boolean)? }

local BINDINGS: {Binding} = {
    { key = Enum.KeyCode.P, label = "Pets",         command = "openPets" },
    { key = Enum.KeyCode.J, label = "Quests",       command = "openQuests" },
    { key = Enum.KeyCode.B, label = "Spin Wheel",   command = "openSpin" },
    { key = Enum.KeyCode.M, label = "Daily Shop",   command = "openDailyShop" },
    { key = Enum.KeyCode.H, label = "Help",         command = "openHelp" },
    { key = Enum.KeyCode.U, label = "Auras",        command = "openAuras" },
    { key = Enum.KeyCode.Y, label = "Titles",       command = "openTitles" },
    { key = Enum.KeyCode.K, label = "Achievements", command = "openAchievements" },
    { key = Enum.KeyCode.R, label = "Rebirth Shop", command = "openRebirthShop" },
    { key = Enum.KeyCode.C, label = "Codes",        command = "openCodes" },
    { key = Enum.KeyCode.F, label = "Friend Code",  command = "openFriendCode" },
    { key = Enum.KeyCode.T, label = "Trade",        command = "openTrade",
      gated = function()
          return Constants.TRADING and Constants.TRADING.ENABLED == true
      end },
}

-- Suppress shortcuts while a TextBox has focus (chat, codes input, etc.)
local function isTypingInTextBox(): boolean
    local focused = UserInputService:GetFocusedTextBox()
    return focused ~= nil
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
    if processed then return end                    -- Roblox or another script claimed it
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if isTypingInTextBox() then return end
    for _, b in ipairs(BINDINGS) do
        if input.KeyCode == b.key then
            if b.gated and not b.gated() then return end
            local fired = UICommands.invoke(b.command)
            if not fired then
                -- Registry not ready yet (e.g. HUD module hasn't hit
                -- registration line for this opener). One-shot retry
                -- after a tick so first-key-after-join still works.
                task.delay(0.5, function() UICommands.invoke(b.command) end)
            end
            return
        end
    end
end)

-- Gamepad: DPadUp = Pets, DPadRight = Quests, DPadDown = Spin,
-- DPadLeft = Daily Shop. Face buttons left for camera/jump per Roblox
-- defaults so we don't break the locomotion feel.
local function makeGamepadHandler(command: string)
    return function(_actionName: string, state: Enum.UserInputState, _input: InputObject)
        if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
        UICommands.invoke(command)
        return Enum.ContextActionResult.Sink
    end
end

ContextActionService:BindAction("Studio88_OpenPets",   makeGamepadHandler("openPets"),   false, Enum.KeyCode.DPadUp)
ContextActionService:BindAction("Studio88_OpenQuests", makeGamepadHandler("openQuests"), false, Enum.KeyCode.DPadRight)
ContextActionService:BindAction("Studio88_OpenSpin",   makeGamepadHandler("openSpin"),   false, Enum.KeyCode.DPadDown)
ContextActionService:BindAction("Studio88_OpenShop",   makeGamepadHandler("openDailyShop"), false, Enum.KeyCode.DPadLeft)

-- Help line printed once so devs / power users see what's wired.
print(string.format("[KeyboardShortcuts] %d desktop + 4 gamepad bindings live", #BINDINGS))
