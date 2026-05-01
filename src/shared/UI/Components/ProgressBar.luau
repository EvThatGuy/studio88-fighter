--!strict
-- Velvet progress bar. Used for quest completion, achievement progress,
-- pity counter, daily streak. Includes optional inline label.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type ProgressBarProps = {
    progress: number,            -- 0..1
    label: string?,              -- e.g. "47 / 50"
    accent: Color3?,
    height: number?,
    layoutOrder: number?,
}

local function ProgressBar(props: ProgressBarProps)
    local p = math.clamp(props.progress, 0, 1)
    local accent = props.accent or Tokens.color.gold
    local height = props.height or 12

    return e("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height + (if props.label then Tokens.text.caption + Tokens.space[1] else 0)),
        AutomaticSize = Enum.AutomaticSize.None,
        LayoutOrder = props.layoutOrder,
    }, {
        Layout = e("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, Tokens.space[1]),
        }),
        Track = e("Frame", {
            BackgroundColor3 = Tokens.color.velvet,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, height),
            LayoutOrder = 1,
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
            Fill = e("Frame", {
                BackgroundColor3 = accent,
                BorderSizePixel = 0,
                Size = UDim2.new(p, 0, 1, 0),
            }, {
                Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
            }),
        }),
        Label = if props.label then e("TextLabel", {
            BackgroundTransparency = 1,
            Text = props.label,
            TextColor3 = Tokens.color.creamDim,
            FontFace = Tokens.font.body,
            TextSize = Tokens.text.caption,
            TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(1, 0, 0, Tokens.text.caption + 4),
            LayoutOrder = 2,
        }) else nil,
    })
end

return ProgressBar
