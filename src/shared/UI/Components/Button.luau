--!strict
-- Velvet Studio button. Three variants -- primary (gold), secondary (cream
-- outline), ghost (transparent). Mobile-first 56px tap minimum.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type ButtonProps = {
    label: string,
    onClick: (() -> ())?,
    variant: ("primary" | "secondary" | "ghost")?,
    icon: string?,         -- optional Roblox asset id, shown left of label
    disabled: boolean?,
    fullWidth: boolean?,
    layoutOrder: number?,
    size: ("sm" | "md" | "lg")?,
}

local function Button(props: ButtonProps)
    local variant = props.variant or "primary"
    local size = props.size or "md"
    local disabled = props.disabled == true

    local height = if size == "sm" then 40 elseif size == "lg" then 64 else Tokens.layout.tapMin
    local padX = if size == "sm" then Tokens.space[3] else Tokens.space[5]
    local textSize = if size == "sm" then Tokens.text.body elseif size == "lg" then Tokens.text.h3 else Tokens.text.body

    local fillColor: Color3
    local textColor: Color3
    local strokeColor: Color3
    local strokeThickness: number

    if variant == "primary" then
        fillColor = Tokens.color.gold
        textColor = Tokens.color.plum
        strokeColor = Tokens.color.goldDeep
        strokeThickness = Tokens.stroke.regular
    elseif variant == "secondary" then
        fillColor = Tokens.color.plumRaised
        textColor = Tokens.color.cream
        strokeColor = Tokens.color.cream
        strokeThickness = Tokens.stroke.regular
    else -- ghost
        fillColor = Tokens.color.plum
        textColor = Tokens.color.creamDim
        strokeColor = Tokens.color.creamMuted
        strokeThickness = Tokens.stroke.hairline
    end

    if disabled then
        textColor = Tokens.color.creamMuted
        strokeColor = Tokens.color.creamMuted
    end

    return e("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = fillColor,
        BackgroundTransparency = if disabled then 0.5 else 0,
        BorderSizePixel = 0,
        Size = if props.fullWidth then UDim2.new(1, 0, 0, height) else UDim2.fromOffset(0, height),
        AutomaticSize = if props.fullWidth then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
        LayoutOrder = props.layoutOrder,
        Text = "",
        Active = not disabled,
        Selectable = not disabled,
        [React.Event.Activated] = if not disabled and props.onClick then props.onClick else nil,
    }, {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.md }),
        Stroke = e("UIStroke", {
            Color = strokeColor,
            Thickness = strokeThickness,
            Transparency = if disabled then 0.5 else 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Padding = e("UIPadding", {
            PaddingLeft = UDim.new(0, padX),
            PaddingRight = UDim.new(0, padX),
        }),
        Layout = e("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, Tokens.space[2]),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Icon = if props.icon then e("ImageLabel", {
            Image = props.icon,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(20, 20),
            ImageColor3 = textColor,
            LayoutOrder = 1,
        }) else nil,
        Label = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.label,
            TextColor3 = textColor,
            FontFace = Tokens.font.label,
            TextSize = textSize,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            LayoutOrder = 2,
        }),
    })
end

return Button
