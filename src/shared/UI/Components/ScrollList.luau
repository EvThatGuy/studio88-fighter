--!strict
-- Velvet scroll container. Vertical layout, gold-on-plum scrollbar styled to
-- match the aesthetic. Auto-sizes its CanvasSize from its UIListLayout.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type ScrollListProps = {
    children: any?,
    padding: number?,           -- gap between rows; defaults to space[3]
    maxHeight: number?,         -- pixel cap; defaults to 480
    layoutOrder: number?,
    horizontal: boolean?,
}

local function ScrollList(props: ScrollListProps)
    local pad = props.padding or Tokens.space[3]
    local maxHeight = props.maxHeight or 480
    local horizontal = props.horizontal == true

    -- Build children inline: spread the caller's children dict instead of
    -- nesting it under a "Content" key. React-Lua treats the "Content" key
    -- as a text node when its value is a children dict (vs a React element)
    -- and emits "UNIMPLEMENTED ERROR: createTextInstance" -- caused a single
    -- noisy stack on every PetsModal mount before this fix.
    local children: { [any]: any } = {
        Layout = e("UIListLayout", {
            FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
            Padding = UDim.new(0, pad),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.space[1]),
            PaddingBottom = UDim.new(0, Tokens.space[1]),
            PaddingLeft = UDim.new(0, Tokens.space[1]),
            PaddingRight = UDim.new(0, Tokens.space[2]),
        }),
    }
    if typeof(props.children) == "table" then
        for k, v in props.children do children[k] = v end
    end

    return e("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, maxHeight),
        AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = Tokens.color.gold,
        ScrollBarImageTransparency = 0.4,
        ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        LayoutOrder = props.layoutOrder,
    }, children)
end

return ScrollList
