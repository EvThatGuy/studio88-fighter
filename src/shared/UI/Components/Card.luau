--!strict
-- Velvet card. Default surface for any feature panel content. Supports an
-- optional accent stripe along the left edge to convey rarity or category.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type CardProps = {
    accent: Color3?,
    padding: number?,
    layoutOrder: number?,
    size: UDim2?,
    automaticSize: Enum.AutomaticSize?,
    children: any?,
    onClick: (() -> ())?,
    selected: boolean?,
}

local function Card(props: CardProps)
    local pad = props.padding or Tokens.space[4]
    local accent = props.accent
    local selected = props.selected == true
    local clickable = props.onClick ~= nil

    local children: { [string]: any } = {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.lg }),
        Stroke = e("UIStroke", {
            Color = if selected then Tokens.color.gold else Tokens.color.velvet,
            Thickness = if selected then Tokens.stroke.bold else Tokens.stroke.hairline,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, pad),
            PaddingBottom = UDim.new(0, pad),
            PaddingLeft = UDim.new(0, if accent then pad + 4 else pad),
            PaddingRight = UDim.new(0, pad),
        }),
        AccentStripe = if accent then e("Frame", {
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 4, 1, -16),
            Position = UDim2.new(0, 0, 0, 8),
            ZIndex = 2,
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.sm }),
        }) else nil,
        Content = props.children,
    }

    if clickable then
        return e("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = Tokens.color.plumRaised,
            BorderSizePixel = 0,
            Size = props.size or UDim2.new(1, 0, 0, 0),
            AutomaticSize = props.automaticSize or Enum.AutomaticSize.Y,
            LayoutOrder = props.layoutOrder,
            [React.Event.Activated] = props.onClick,
        }, children)
    end

    return e("Frame", {
        BackgroundColor3 = Tokens.color.plumRaised,
        BorderSizePixel = 0,
        Size = props.size or UDim2.new(1, 0, 0, 0),
        AutomaticSize = props.automaticSize or Enum.AutomaticSize.Y,
        LayoutOrder = props.layoutOrder,
    }, children)
end

return Card
