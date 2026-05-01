--!strict
-- Velvet modal. Centered on landscape, full-bleed sheet on mobile portrait.
-- Includes scrim backdrop, close affordance, and optional sticky footer CTA.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type ModalProps = {
    title: string,
    subtitle: string?,
    onClose: () -> (),
    children: any?,
    footer: any?,         -- optional component rendered in sticky footer slot
    width: number?,       -- pixel width on landscape; defaults to layout.modalMaxWidth
    accent: Color3?,      -- override title color (e.g. gold for premium modals)
}

local function Modal(props: ModalProps)
    local width = props.width or Tokens.layout.modalMaxWidth
    local accent = props.accent or Tokens.color.gold

    return e("Frame", {
        BackgroundColor3 = Tokens.color.plumDeep,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = Tokens.layer.modal,
    }, {
        ScrimTap = e("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = Tokens.layer.modal,
            [React.Event.Activated] = props.onClose,
        }),

        Panel = e("Frame", {
            BackgroundColor3 = Tokens.color.plum,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -32, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = Tokens.layer.modal + 1,
        }, {
            MaxWidth = e("UISizeConstraint", {
                MaxSize = Vector2.new(width, math.huge),
            }),
            Corner = e("UICorner", { CornerRadius = Tokens.radius.lg }),
            Stroke = e("UIStroke", {
                Color = Tokens.color.velvet,
                Thickness = Tokens.stroke.regular,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }),

            Padding = e("UIPadding", {
                PaddingTop = UDim.new(0, Tokens.space[5]),
                PaddingBottom = UDim.new(0, Tokens.space[5]),
                PaddingLeft = UDim.new(0, Tokens.space[5]),
                PaddingRight = UDim.new(0, Tokens.space[5]),
            }),

            Layout = e("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, Tokens.space[4]),
                FillDirection = Enum.FillDirection.Vertical,
            }),

            Header = e("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1,
            }, {
                Layout = e("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, Tokens.space[1]),
                }),
                Title = e("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = string.upper(props.title),
                    TextColor3 = accent,
                    FontFace = Tokens.font.display,
                    TextSize = Tokens.text.h2,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -56, 0, Tokens.text.h2 + 4),
                    LayoutOrder = 1,
                }),
                Subtitle = if props.subtitle then e("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = props.subtitle,
                    TextColor3 = Tokens.color.creamDim,
                    FontFace = Tokens.font.body,
                    TextSize = Tokens.text.body,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Size = UDim2.new(1, -56, 0, 0),
                    LayoutOrder = 2,
                }) else nil,
                CloseBtn = e("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = Tokens.color.plumRaised,
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(40, 40),
                    Position = UDim2.new(1, 0, 0, 0),
                    AnchorPoint = Vector2.new(1, 0),
                    Text = "X",
                    TextColor3 = Tokens.color.creamDim,
                    FontFace = Tokens.font.label,
                    TextSize = Tokens.text.body,
                    [React.Event.Activated] = props.onClose,
                }, {
                    Corner = e("UICorner", { CornerRadius = Tokens.radius.md }),
                }),
            }),

            Body = e("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, {
                Layout = e("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, Tokens.space[3]),
                }),
                Content = props.children,
            }),

            Footer = if props.footer then e("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 3,
            }, {
                Content = props.footer,
            }) else nil,
        }),
    })
end

return Modal
