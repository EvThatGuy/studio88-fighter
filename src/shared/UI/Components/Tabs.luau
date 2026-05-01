--!strict
-- Velvet tab bar. Horizontal pills along the top of a modal or sheet.
-- Supports badges (count indicator) and per-tab disabled states.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type Tab = {
    id: string,
    label: string,
    badge: (string | number)?,
    disabled: boolean?,
}

export type TabsProps = {
    tabs: { Tab },
    activeId: string,
    onChange: (string) -> (),
    layoutOrder: number?,
}

local function Tabs(props: TabsProps)
    local tabs = props.tabs

    local children: { [string]: any } = {
        Layout = e("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, Tokens.space[2]),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }

    for i, tab in ipairs(tabs) do
        local isActive = tab.id == props.activeId
        local isDisabled = tab.disabled == true
        local fill = if isActive then Tokens.color.gold else Tokens.color.plumRaised
        local textColor = if isActive then Tokens.color.plum
            elseif isDisabled then Tokens.color.creamMuted
            else Tokens.color.cream

        children[tab.id] = e("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = fill,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 36),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = i,
            Active = not isDisabled,
            [React.Event.Activated] = if not isDisabled then function()
                if not isActive then props.onChange(tab.id) end
            end else nil,
        }, {
            Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
            Padding = e("UIPadding", {
                PaddingLeft = UDim.new(0, Tokens.space[3]),
                PaddingRight = UDim.new(0, Tokens.space[3]),
            }),
            InnerLayout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, Tokens.space[1]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            Label = e("TextLabel", {
                BackgroundTransparency = 1,
                Text = tab.label,
                TextColor3 = textColor,
                FontFace = Tokens.font.label,
                TextSize = Tokens.text.body,
                AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.new(0, 0, 1, 0),
                LayoutOrder = 1,
            }),
            Badge = if tab.badge ~= nil then e("TextLabel", {
                BackgroundColor3 = if isActive then Tokens.color.plum else Tokens.color.gold,
                BorderSizePixel = 0,
                Text = tostring(tab.badge),
                TextColor3 = if isActive then Tokens.color.gold else Tokens.color.plum,
                FontFace = Tokens.font.label,
                TextSize = Tokens.text.micro,
                Size = UDim2.fromOffset(20, 20),
                LayoutOrder = 2,
            }, {
                Corner = e("UICorner", { CornerRadius = Tokens.radius.full }),
            }) else nil,
        })
    end

    return e("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        LayoutOrder = props.layoutOrder,
    }, children)
end

return Tabs
