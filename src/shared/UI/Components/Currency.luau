--!strict
-- Velvet currency chip. Shows a coin/token with formatted amount.
-- Default surface for the HUD balance, modal price tags, reward callouts.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Tokens = require(script.Parent.Parent.Tokens)

local e = React.createElement

export type CurrencyKind = "coins" | "tokens" | "tickets"

export type CurrencyProps = {
    amount: number,
    kind: CurrencyKind?,
    size: ("sm" | "md" | "lg")?,
    layoutOrder: number?,
    align: Enum.TextXAlignment?,
}

local KIND_LABEL = {
    coins = "COINS",
    tokens = "RBTH TOKENS",
    tickets = "TICKETS",
}

local KIND_COLOR = {
    coins = Tokens.color.gold,
    tokens = Tokens.color.rarityEpic,
    tickets = Tokens.color.info,
}

local function formatAmount(n: number): string
    -- 1234567 -> "1.23M", 10500 -> "10.5K", 943 -> "943"
    local abs = math.abs(n)
    if abs >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if abs >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if abs >= 1e4 then return string.format("%.1fK", n / 1e3) end
    -- Integer with thousand separators below 10k
    local s = tostring(math.floor(n))
    local _, _, sign, digits = string.find(s, "^([%-]?)(%d+)$")
    if not digits then return s end
    local out = ""
    for i = #digits, 1, -1 do
        local idx = #digits - i
        out = string.sub(digits, i, i) .. (if idx > 0 and idx % 3 == 0 then "," else "") .. out
    end
    return (sign or "") .. out
end

local function Currency(props: CurrencyProps)
    local kind = props.kind or "coins"
    local size = props.size or "md"
    local accent = KIND_COLOR[kind]
    local label = KIND_LABEL[kind]

    local valueSize = if size == "sm" then Tokens.text.body
        elseif size == "lg" then Tokens.text.hero
        else Tokens.text.h2
    local labelSize = if size == "sm" then Tokens.text.micro
        elseif size == "lg" then Tokens.text.body
        else Tokens.text.caption

    return e("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, valueSize + labelSize + Tokens.space[1]),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = props.layoutOrder,
    }, {
        Layout = e("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 0),
            HorizontalAlignment = if props.align == Enum.TextXAlignment.Right then Enum.HorizontalAlignment.Right
                elseif props.align == Enum.TextXAlignment.Center then Enum.HorizontalAlignment.Center
                else Enum.HorizontalAlignment.Left,
        }),
        Tag = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = accent,
            FontFace = Tokens.font.label,
            TextSize = labelSize,
            TextXAlignment = props.align or Enum.TextXAlignment.Left,
            Size = UDim2.new(0, 0, 0, labelSize + 2),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 1,
        }),
        Value = e("TextLabel", {
            BackgroundTransparency = 1,
            Text = formatAmount(props.amount),
            TextColor3 = Tokens.color.cream,
            FontFace = Tokens.font.display,
            TextSize = valueSize,
            TextXAlignment = props.align or Enum.TextXAlignment.Left,
            Size = UDim2.new(0, 0, 0, valueSize + 2),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
        }),
    })
end

return Currency
