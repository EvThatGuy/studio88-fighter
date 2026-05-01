--!strict
-- Daily Spin Wheel modal. One free spin per UTC day. Renders the 10 weighted
-- segments as a vertical preview (we don't actually animate a wheel here --
-- the legacy 3D wheel was visual chrome; the mechanic is "tap CLAIM").

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type SpinModalProps = {
    onClose: () -> (),
}

type Segment = {
    id: string,
    label: string,
    color: { number },   -- {r,g,b}
    weight: number,
}

type Snapshot = {
    available: boolean,
    segments: { Segment },
    nextResetSec: number,
}

local function arrToColor(arr: { number }?): Color3
    if not arr or #arr < 3 then return Tokens.color.cream end
    return Color3.fromRGB(arr[1], arr[2], arr[3])
end

local function fmtCountdown(sec: number): string
    if sec <= 0 then return "AVAILABLE NOW" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    return string.format("%02dh %02dm", h, m)
end

local function SpinModal(props: SpinModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)
    local now, setNow = React.useState(os.time())

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetSpinState:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        refresh()
        local remotes = Remotes.waitFor(15)
        local conns = {
            remotes.SpinResult.OnClientEvent:Connect(function() refresh() end),
            remotes.SpinRejected.OnClientEvent:Connect(function() refresh() end),
        }
        local tickThread = task.spawn(function()
            while true do
                task.wait(1)
                setNow(os.time())
            end
        end)
        return function()
            for _, c in conns do c:Disconnect() end
            task.cancel(tickThread)
        end
    end, { refresh } :: { any })

    local claim = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        remotes.ClaimSpin:FireServer()
    end, {})

    local body: any
    if not snap then
        body = e(Components.EmptyState, { headline = "LOADING" })
    else
        local segCards: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[2]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        local totalWeight = 0
        for _, s in snap.segments do totalWeight += s.weight end
        for i, seg in ipairs(snap.segments) do
            local pct = if totalWeight > 0 then (seg.weight / totalWeight) * 100 else 0
            segCards[seg.id] = e(Components.Card, {
                accent = arrToColor(seg.color),
                padding = Tokens.space[3],
                layoutOrder = i,
                children = e("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 28),
                }, {
                    Layout = e("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, Tokens.space[2]),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    Label = e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = string.upper(seg.label),
                        TextColor3 = Tokens.color.cream,
                        FontFace = Tokens.font.label,
                        TextSize = Tokens.text.body,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, -80, 1, 0),
                        LayoutOrder = 1,
                    }),
                    Odds = e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = string.format("%.1f%%", pct),
                        TextColor3 = Tokens.color.creamDim,
                        FontFace = Tokens.font.body,
                        TextSize = Tokens.text.caption,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        Size = UDim2.new(0, 80, 1, 0),
                        LayoutOrder = 2,
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, { maxHeight = 360, children = segCards })
    end

    local cooldownSec = if snap then math.max(0, snap.nextResetSec - (now - os.time())) else 0
    local available = snap and snap.available == true

    local subtitle = if available
        then "ONE FREE SPIN AVAILABLE"
        else "NEXT SPIN IN " .. fmtCountdown(cooldownSec)

    return e(Components.Modal, {
        title = "DAILY SPIN",
        subtitle = subtitle,
        accent = Tokens.color.gold,
        onClose = props.onClose,
        children = body,
        footer = e(Components.Button, {
            label = if available then "SPIN NOW" else "COME BACK TOMORROW",
            variant = if available then "primary" else "secondary",
            disabled = not available,
            fullWidth = true,
            onClick = if available then claim else nil,
        }),
    })
end

return SpinModal
