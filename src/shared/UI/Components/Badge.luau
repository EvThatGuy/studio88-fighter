--!strict
-- Velvet badge. Pill-shaped label for tags (rarity, status, count). Uses
-- AutomaticSize.X so the pill hugs its text without manual width math.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type BadgeVariant = "neutral" | "gold" | "success" | "warning" | "danger" | "rarity"

export type BadgeProps = {
    label: string,
    variant: BadgeVariant?,
    accent: Color3?,         -- only honored when variant == "rarity"
    layoutOrder: number?,
}

local function colorsForVariant(variant: BadgeVariant, accent: Color3?): (Color3, Color3)
    if variant == "gold" then return Tokens.color.gold, Tokens.color.plum end
    if variant == "success" then return Tokens.color.success, Tokens.color.plum end
    if variant == "warning" then return Tokens.color.warning, Tokens.color.plum end
    if variant == "danger" then return Tokens.color.danger, Tokens.color.cream end
    if variant == "rarity" and accent then return accent, Tokens.color.plum end
    return Tokens.color.velvet, Tokens.color.cream
end

local function Badge(props: BadgeProps)
    local variant = props.variant or "neutral"
    local fill, fg = colorsForVariant(variant, props.accent)

    return e("Frame", {
        BackgroundColor3 = fill,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = props.layoutOrder,
    }, {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
        Padding = e("UIPadding", {
            PaddingLeft = UDim.new(0, Tokens.space[2]),
            PaddingRight = UDim.new(0, Tokens.space[2]),
        }),
        Label = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = string.upper(props.label),
            TextColor3 = fg,
            FontFace = Tokens.font.label,
            TextSize = Tokens.text.micro,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            TextYAlignment = Enum.TextYAlignment.Center,
        }),
    })
end

return Badge
