--!strict
-- Hourly Tribute modal. Stack-up-to-cap mechanic; players who log in once a
-- day can sweep up to 4 stacks at once. Tier multiplier applies to the
-- per-stack reward. RFY signal #2 driver (sessions per user per day).

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type TributeModalProps = {
    onClose: () -> (),
}

type Snapshot = {
    available: number,
    capped: boolean,
    nextStackInSec: number,
    perStackReward: number,
    cap: number,
}

local function fmtClock(sec: number): string
    if sec <= 0 then return "00m 00s" end
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02dm %02ds", m, s)
end

local function TributeModal(props: TributeModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)
    local _now, setNow = React.useState(os.time())

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetHourlyTribute:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        local conns: { RBXScriptConnection } = {}
        local cancelled = false
        local tickThread = task.spawn(function()
            while true do
                task.wait(1)
                setNow(os.time())
            end
        end)
        local refetchThread = task.spawn(function()
            while true do
                task.wait(60)
                refresh()
            end
        end)
        task.spawn(function()
            refresh()
            if cancelled then return end
            local remotes = Remotes.waitFor(15)
            if cancelled then return end
            table.insert(conns, remotes.HourlyTributeClaimed.OnClientEvent:Connect(function() refresh() end))
            table.insert(conns, remotes.HourlyTributeRejected.OnClientEvent:Connect(function() refresh() end))
        end)
        return function()
            cancelled = true
            for _, c in conns do c:Disconnect() end
            task.cancel(tickThread)
            task.cancel(refetchThread)
        end
    end, { refresh } :: { any })

    local claim = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        remotes.ClaimHourlyTribute:FireServer()
    end, {})

    local body: any
    local canClaim = false
    if not snap then
        body = e(Components.EmptyState, { headline = "LOADING" })
    else
        canClaim = snap.available > 0
        local stackCards: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[3]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            Stacks = e("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 88),
                LayoutOrder = 1,
            }, {
                Layout = e("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, Tokens.space[2]),
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                }),
                S1 = nil,
            }),
            Reward = e(Components.Card, {
                accent = Tokens.color.gold,
                layoutOrder = 2,
                children = e("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 56),
                }, {
                    Layout = e("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, Tokens.space[3]),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    LblBlock = e("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -180, 1, 0),
                        LayoutOrder = 1,
                    }, {
                        Layout = e("UIListLayout", { Padding = UDim.new(0, 2) }),
                        H = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = "PER-STACK PAYOUT",
                            TextColor3 = Tokens.color.creamDim,
                            FontFace = Tokens.font.label,
                            TextSize = Tokens.text.caption,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, 14),
                            LayoutOrder = 1,
                        }),
                        S = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = string.format("Tier-scaled. Stacks every %d minutes up to %dx.",
                                math.floor((snap.nextStackInSec > 0 and snap.nextStackInSec or 3600) / 60),
                                snap.cap),
                            TextColor3 = Tokens.color.cream,
                            FontFace = Tokens.font.body,
                            TextSize = Tokens.text.caption,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextWrapped = true,
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Size = UDim2.new(1, 0, 0, 0),
                            LayoutOrder = 2,
                        }),
                    }),
                    Coin = e(Components.Currency, {
                        amount = snap.perStackReward,
                        kind = "coins",
                        size = "md",
                        layoutOrder = 2,
                        align = Enum.TextXAlignment.Right,
                    }),
                }),
            }),
        }
        -- Render `cap` cells, fill in stacks worth.
        local cells: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, Tokens.space[2]),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        for i = 1, snap.cap do
            local filled = i <= snap.available
            cells["c" .. i] = e("Frame", {
                BackgroundColor3 = if filled then Tokens.color.gold else Tokens.color.velvet,
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(64, 64),
                LayoutOrder = i,
            }, {
                Corner = e("UICorner", { CornerRadius = Tokens.radius.md }),
                Stroke = e("UIStroke", {
                    Color = if filled then Tokens.color.goldDeep else Tokens.color.creamMuted,
                    Thickness = Tokens.stroke.regular,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }),
                N = e("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = "x" .. tostring(i),
                    TextColor3 = if filled then Tokens.color.plum else Tokens.color.creamDim,
                    FontFace = Tokens.font.display,
                    TextSize = Tokens.text.h3,
                    Size = UDim2.fromScale(1, 1),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                }),
            })
        end
        stackCards.Stacks = e("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 64),
            LayoutOrder = 1,
        }, cells)
        body = e("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, stackCards)
    end

    local subtitle = if snap == nil
        then "loading..."
        elseif canClaim
            then string.format("READY  %dx", snap.available)
        else "NEXT STACK IN " .. fmtClock(snap.nextStackInSec)

    local ctaLabel = if canClaim
        then string.format("CLAIM %dx (%s coins)", snap.available, tostring(snap.available * snap.perStackReward))
        else "WAITING"

    return e(Components.Modal, {
        title = "HOURLY TRIBUTE",
        subtitle = subtitle,
        accent = Tokens.color.gold,
        onClose = props.onClose,
        children = body,
        footer = e(Components.Button, {
            label = ctaLabel,
            variant = if canClaim then "primary" else "secondary",
            disabled = not canClaim,
            fullWidth = true,
            onClick = if canClaim then claim else nil,
        }),
    })
end

return TributeModal
