--!strict
-- HUD_v2 root component. Manages "which modal is open" + renders the always-on
-- HUD chrome (Balance + ButtonStack + leaderboard slot). Each feature modal
-- lives in its own module under src/client/UI/ and gets opened/closed via the
-- `openModal` setter on this component.

local React = require(game:GetService("ReplicatedStorage").Packages.React)

local Tokens = require(game:GetService("ReplicatedStorage").Modules.UI.Tokens)
local TestBridge = require(game:GetService("ReplicatedStorage").Modules.UI.TestBridge)
local Balance = require(script.Parent.Balance)
local ButtonStack = require(script.Parent.ButtonStack)
local PetsModal = require(script.Parent.PetsModal)
local SpinModal = require(script.Parent.SpinModal)
local TributeModal = require(script.Parent.TributeModal)
local AchievementsModal = require(script.Parent.AchievementsModal)
local QuestsModal = require(script.Parent.QuestsModal)
local AurasModal = require(script.Parent.AurasModal)
local TitlesModal = require(script.Parent.TitlesModal)

local e = React.createElement

export type ModalId = "pets" | "auras" | "achievements" | "quests" | "tribute" | "spin" | "titles" | "passes" | "codes" | "stats" | nil

local function App()
    local openModalId, setOpenModal = React.useState(nil :: ModalId)

    -- Bridge external setOpenModal callers (AutoTest, Roblox signals) through
    -- a BindableEvent so the connect callback runs in the standard Roblox
    -- event context where setState batches+flushes correctly. Direct calls
    -- to setOpenModal from outside React's event flow get silently dropped.
    React.useEffect(function()
        local conn = TestBridge.changed.Event:Connect(function(next: any)
            setOpenModal(next)
        end)
        return function() conn:Disconnect() end
    end, {})

    local function exposedSetter(next: ModalId)
        TestBridge.changed:Fire(next)
    end
    TestBridge.setModal = exposedSetter :: any

    local close = React.useCallback(function()
        setOpenModal(nil)
    end, {})

    return e("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, {
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.layout.hudSafePaddingTop),
            PaddingBottom = UDim.new(0, Tokens.layout.hudSafePaddingBottom),
            PaddingLeft = UDim.new(0, Tokens.space[4]),
            PaddingRight = UDim.new(0, Tokens.space[4]),
        }),

        Balance = e(Balance, {}),

        ButtonStack = e(ButtonStack, {
            onOpen = exposedSetter,
            activeId = openModalId,
        }),

        PetsModal = if openModalId == "pets" then e(PetsModal, { onClose = close }) else nil,
        SpinModal = if openModalId == "spin" then e(SpinModal, { onClose = close }) else nil,
        TributeModal = if openModalId == "tribute" then e(TributeModal, { onClose = close }) else nil,
        AchievementsModal = if openModalId == "achievements" then e(AchievementsModal, { onClose = close }) else nil,
        QuestsModal = if openModalId == "quests" then e(QuestsModal, { onClose = close }) else nil,
        AurasModal = if openModalId == "auras" then e(AurasModal, { onClose = close }) else nil,
        TitlesModal = if openModalId == "titles" then e(TitlesModal, { onClose = close }) else nil,
    })
end

return App
