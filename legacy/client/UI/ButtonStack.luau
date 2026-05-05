--!strict
-- Right-edge vertical button stack. Each entry opens a modal via `onOpen`.
-- Uses IconButton fallbackText (no icon assets needed yet) so we can ship
-- without commissioning art.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type ModalId = "pets" | "auras" | "achievements" | "quests" | "tribute" | "spin" | "titles" | "passes" | "codes" | "stats"

export type ButtonStackProps = {
    onOpen: (ModalId?) -> (),
    activeId: ModalId?,
}

type Entry = {
    id: ModalId,
    label: string,
    accent: Color3,
}

local ENTRIES: { Entry } = {
    { id = "pets",         label = "PETS",   accent = Tokens.color.gold },
    { id = "auras",        label = "AURAS",  accent = Tokens.color.rarityEpic },
    { id = "achievements", label = "TROPH",  accent = Tokens.color.gold },
    { id = "quests",       label = "QSTS",   accent = Tokens.color.success },
    { id = "passes",       label = "PASS",   accent = Tokens.color.warning },
    { id = "codes",        label = "CODE",   accent = Tokens.color.info },
    { id = "tribute",      label = "TRIB",   accent = Tokens.color.gold },
    { id = "spin",         label = "SPIN",   accent = Tokens.color.gold },
    { id = "titles",       label = "TITL",   accent = Tokens.color.info },
    { id = "stats",        label = "STAT",   accent = Tokens.color.cream },
}

local function ButtonStack(props: ButtonStackProps)
    local children: { [string]: any } = {
        Layout = e("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, Tokens.space[2]),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }

    for i, entry in ipairs(ENTRIES) do
        children[entry.id] = e(Components.IconButton, {
            fallbackText = entry.label,
            accent = if props.activeId == entry.id then Tokens.color.gold else entry.accent,
            layoutOrder = i,
            size = 56,
            onClick = function()
                if props.activeId == entry.id then
                    props.onOpen(nil)
                else
                    props.onOpen(entry.id)
                end
            end,
        })
    end

    return e("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(56, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = Tokens.layer.sticky,
    }, children)
end

return ButtonStack
