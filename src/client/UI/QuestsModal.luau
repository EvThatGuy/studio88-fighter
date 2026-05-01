--!strict
-- Daily Quests modal. Shows today's 3 quests; rotates deterministically at
-- UTC midnight. Each card shows progress bar + reward + per-quest claim CTA.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type QuestsModalProps = {
    onClose: () -> (),
}

type Quest = {
    id: string,
    kind: string,
    target: number,
    reward: number,
    label: string,
    progress: number,
    claimed: boolean,
    complete: boolean,
}

type Snapshot = {
    dateKey: string,
    quests: { Quest },
}

local function QuestsModal(props: QuestsModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetDailyQuests:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        refresh()
        local remotes = Remotes.waitFor(15)
        local conns = {
            remotes.QuestProgressed.OnClientEvent:Connect(function() refresh() end),
            remotes.QuestClaimed.OnClientEvent:Connect(function() refresh() end),
            remotes.QuestRejected.OnClientEvent:Connect(function() refresh() end),
        }
        return function()
            for _, c in conns do c:Disconnect() end
        end
    end, { refresh } :: { any })

    local claim = React.useCallback(function(questId: string)
        local remotes = Remotes.waitFor(15)
        remotes.ClaimQuest:FireServer(questId)
    end, {})

    local body: any
    if not snap then
        body = e(Components.EmptyState, { headline = "LOADING" })
    else
        local cards: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[3]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        for i, q in ipairs(snap.quests) do
            local target = math.max(q.target or 1, 1)
            local progress = math.min(q.progress or 0, target)
            local pct = progress / target
            local accent = if q.claimed then Tokens.color.creamMuted
                elseif q.complete then Tokens.color.success
                else Tokens.color.gold

            local ctaLabel = if q.claimed then "CLAIMED"
                elseif q.complete then "CLAIM REWARD"
                else string.format("%d / %d", progress, target)
            local ctaVariant = if q.claimed then "ghost"
                elseif q.complete then "primary"
                else "secondary"
            local ctaDisabled = q.claimed or not q.complete

            cards[q.id] = e(Components.Card, {
                accent = accent,
                layoutOrder = i,
                padding = Tokens.space[3],
                children = e("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                }, {
                    Layout = e("UIListLayout", {
                        Padding = UDim.new(0, Tokens.space[2]),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    Label = e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = q.label,
                        TextColor3 = Tokens.color.cream,
                        FontFace = Tokens.font.display,
                        TextSize = Tokens.text.body,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Size = UDim2.new(1, 0, 0, 0),
                        LayoutOrder = 1,
                    }),
                    Bar = e(Components.ProgressBar, {
                        progress = pct,
                        label = string.format("REWARD: +%d coins", q.reward),
                        accent = accent,
                        layoutOrder = 2,
                    }),
                    CTA = e(Components.Button, {
                        label = ctaLabel,
                        variant = ctaVariant :: any,
                        disabled = ctaDisabled,
                        fullWidth = true,
                        onClick = if ctaDisabled then nil else function() claim(q.id) end,
                        layoutOrder = 3,
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, { maxHeight = 480, children = cards })
    end

    local doneCount = 0
    if snap then
        for _, q in snap.quests do
            if q.claimed then doneCount += 1 end
        end
    end
    local subtitle = if snap
        then string.format("%d / %d CLAIMED  ::  RESETS AT UTC MIDNIGHT", doneCount, #snap.quests)
        else "loading..."

    return e(Components.Modal, {
        title = "DAILY QUESTS",
        subtitle = subtitle,
        accent = Tokens.color.success,
        onClose = props.onClose,
        children = body,
    })
end

return QuestsModal
