--!strict
-- Velvet toast. Slides in from top-center, holds, slides out. Color-coded by
-- severity. Self-managed timer; consumer just supplies key + content via the
-- ToastHost component.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type ToastVariant = "info" | "success" | "warning" | "danger" | "celebrate"

export type ToastProps = {
    headline: string,
    body: string?,
    variant: ToastVariant?,
    layoutOrder: number?,
}

local function colorForVariant(v: ToastVariant): Color3
    if v == "success" then return Tokens.color.success end
    if v == "warning" then return Tokens.color.warning end
    if v == "danger" then return Tokens.color.danger end
    if v == "celebrate" then return Tokens.color.gold end
    return Tokens.color.info
end

local function Toast(props: ToastProps)
    local variant = props.variant or "info"
    local accent = colorForVariant(variant)

    return e("Frame", {
        BackgroundColor3 = Tokens.color.plum,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = props.layoutOrder,
    }, {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.md }),
        Stroke = e("UIStroke", {
            Color = accent,
            Thickness = Tokens.stroke.regular,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.space[3]),
            PaddingBottom = UDim.new(0, Tokens.space[3]),
            PaddingLeft = UDim.new(0, Tokens.space[4]),
            PaddingRight = UDim.new(0, Tokens.space[4]),
        }),
        AccentBar = e("Frame", {
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, -16),
            Position = UDim2.new(0, 0, 0, 8),
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.sm }),
        }),
        Layout = e("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, Tokens.space[1]),
        }),
        Headline = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = string.upper(props.headline),
            TextColor3 = accent,
            FontFace = Tokens.font.display,
            TextSize = Tokens.text.body,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, Tokens.text.body + 4),
            LayoutOrder = 1,
        }),
        Body = if props.body then e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.body,
            TextColor3 = Tokens.color.creamDim,
            FontFace = Tokens.font.body,
            TextSize = Tokens.text.caption,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            LayoutOrder = 2,
        }) else nil,
    })
end

return Toast
