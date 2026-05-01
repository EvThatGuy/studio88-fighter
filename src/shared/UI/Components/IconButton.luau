--!strict
-- Square icon-only button. Used in HUD button stacks where a label would be
-- too noisy. Falls back to TextLabel "?" if no icon is supplied.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type IconButtonProps = {
    icon: string?,
    fallbackText: string?,
    onClick: (() -> ())?,
    badge: (string | number)?,    -- top-right red dot with count
    accent: Color3?,              -- override stroke for tier-emphasis
    layoutOrder: number?,
    size: number?,                -- defaults to tap minimum
}

local function IconButton(props: IconButtonProps)
    local size = props.size or Tokens.layout.tapMin
    local accent = props.accent or Tokens.color.cream

    return e("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Tokens.color.plumRaised,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(size, size),
        Text = "",
        LayoutOrder = props.layoutOrder,
        [React.Event.Activated] = props.onClick,
    }, {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.md }),
        Stroke = e("UIStroke", {
            Color = accent,
            Thickness = Tokens.stroke.regular,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Icon = if props.icon then e("ImageLabel", {
            Image = props.icon,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.6, 0, 0.6, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ImageColor3 = accent,
        }) else nil,
        Fallback = if not props.icon then e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.fallbackText or "?",
            TextColor3 = accent,
            FontFace = Tokens.font.label,
            TextSize = Tokens.text.h3,
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }) else nil,
        Badge = if props.badge ~= nil then e("Frame", {
            BackgroundColor3 = Tokens.color.danger,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(1, -4, 0, -4),
            AnchorPoint = Vector2.new(1, 0),
            ZIndex = 2,
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
            Label = e("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = tostring(props.badge),
                TextColor3 = Tokens.color.cream,
                FontFace = Tokens.font.label,
                TextSize = Tokens.text.micro,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
            }),
        }) else nil,
    })
end

return IconButton
