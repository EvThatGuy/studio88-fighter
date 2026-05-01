--!strict
-- HUD_v2 root component. Manages "which modal is open" + renders the always-on
-- HUD chrome (Balance + ButtonStack + leaderboard slot). Each feature modal
-- lives in its own module under src/client/UI/ and gets opened/closed via the
-- `openModal` setter on this component.

local React = require(game:GetService("ReplicatedStorage").Packages.React)

local Tokens = require(game:GetService("ReplicatedStorage").Modules.UI.Tokens)
local Balance = require(script.Parent.Balance)
local ButtonStack = require(script.Parent.ButtonStack)
local PetsModal = require(script.Parent.PetsModal)

local e = React.createElement

export type ModalId = "pets" | "auras" | "achievements" | "quests" | "tribute" | "spin" | "titles" | "passes" | "codes" | "stats" | nil

local function App()
    local openModalId, setOpenModal = React.useState(nil :: ModalId)

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
            onOpen = setOpenModal,
            activeId = openModalId,
        }),

        PetsModal = if openModalId == "pets" then e(PetsModal, { onClose = close }) else nil,
    })
end

return App
