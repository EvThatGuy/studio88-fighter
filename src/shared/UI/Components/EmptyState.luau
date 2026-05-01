--!strict
-- Velvet empty state. Shown in scroll lists when a player has no pets, no
-- achievements unlocked, no friends invited, no spin available, etc. Always
-- pairs a hint with a single primary CTA so the player knows what to do.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)
local Button = require(script.Parent.Button)

local e = React.createElement

export type EmptyStateProps = {
    headline: string,
    body: string?,
    ctaLabel: string?,
    onCta: (() -> ())?,
    layoutOrder: number?,
}

local function EmptyState(props: EmptyStateProps)
    return e("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = props.layoutOrder,
    }, {
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.space[7]),
            PaddingBottom = UDim.new(0, Tokens.space[7]),
            PaddingLeft = UDim.new(0, Tokens.space[5]),
            PaddingRight = UDim.new(0, Tokens.space[5]),
        }),
        Layout = e("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, Tokens.space[3]),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
        }),
        Headline = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.headline,
            TextColor3 = Tokens.color.cream,
            FontFace = Tokens.font.display,
            TextSize = Tokens.text.h3,
            TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, 0, 0, Tokens.text.h3 + 4),
            LayoutOrder = 1,
        }),
        Body = if props.body then e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.body,
            TextColor3 = Tokens.color.creamDim,
            FontFace = Tokens.font.body,
            TextSize = Tokens.text.body,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            LayoutOrder = 2,
        }) else nil,
        CTA = if props.ctaLabel and props.onCta then e(Button, {
            label = props.ctaLabel,
            onClick = props.onCta,
            variant = "primary",
            layoutOrder = 3,
        }) else nil,
    })
end

return EmptyState
