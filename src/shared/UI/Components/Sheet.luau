--!strict
-- Velvet sheet. Bottom-anchored slide-up surface for mobile-friendly secondary
-- actions (egg picker, aura grid). Lighter weight than Modal -- no scrim.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type SheetProps = {
    title: string?,
    children: any?,
    onClose: () -> (),
    height: number?,
    layoutOrder: number?,
}

local function Sheet(props: SheetProps)
    local h = props.height or 360

    return e("Frame", {
        BackgroundColor3 = Tokens.color.plum,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -Tokens.layout.hudSafePaddingBottom),
        Size = UDim2.new(1, -Tokens.space[4], 0, h),
        ZIndex = Tokens.layer.modal,
        LayoutOrder = props.layoutOrder,
    }, {
        MaxWidth = e("UISizeConstraint", {
            MaxSize = Vector2.new(Tokens.layout.modalMaxWidth, math.huge),
        }),
        Corner = e("UICorner", { CornerRadius = Tokens.radius.lg }),
        Stroke = e("UIStroke", {
            Color = Tokens.color.velvet,
            Thickness = Tokens.stroke.regular,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.space[4]),
            PaddingBottom = UDim.new(0, Tokens.space[4]),
            PaddingLeft = UDim.new(0, Tokens.space[5]),
            PaddingRight = UDim.new(0, Tokens.space[5]),
        }),
        Layout = e("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, Tokens.space[3]),
        }),
        Handle = e("Frame", {
            BackgroundColor3 = Tokens.color.velvet,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 48, 0, 4),
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            LayoutOrder = 1,
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
        }),
        Title = if props.title then e("TextLabel", {
            BackgroundTransparency = 1,
            Text = string.upper(props.title),
            TextColor3 = Tokens.color.gold,
            FontFace = Tokens.font.display,
            TextSize = Tokens.text.h2,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, Tokens.text.h2 + 4),
            LayoutOrder = 2,
        }) else nil,
        Body = e("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            LayoutOrder = 3,
        }, {
            Content = props.children,
        }),
    })
end

return Sheet
