--!strict
-- Achievements modal. Renders the 17 milestones as a scrollable list with
-- progress bars + reward callouts. BadgeService push notifications still
-- fire server-side on unlock; this modal is the player's at-a-glance view.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type AchievementsModalProps = {
    onClose: () -> (),
}

type Entry = {
    id: string,
    name: string,
    desc: string,
    unlocked: boolean,
    progress: number,
    target: number,
    rewardCoins: number,
    rewardTokens: number,
}

type Snapshot = {
    entries: { Entry },
    unlockedCount: number,
    totalCount: number,
}

local function AchievementsModal(props: AchievementsModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetAchievements:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        refresh()
        local remotes = Remotes.waitFor(15)
        local conn = remotes.AchievementUnlocked.OnClientEvent:Connect(function() refresh() end)
        return function() conn:Disconnect() end
    end, { refresh } :: { any })

    local body: any
    if not snap then
        body = e(Components.EmptyState, { headline = "LOADING" })
    else
        local rows: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[2]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        for i, entry in ipairs(snap.entries) do
            local target = math.max(entry.target or 1, 1)
            local progress = math.min(entry.progress or 0, target)
            local pct = if entry.unlocked then 1 else progress / target
            local accent = if entry.unlocked then Tokens.color.gold else Tokens.color.creamMuted

            local rewardText = ""
            if entry.rewardCoins > 0 then
                rewardText = string.format("+%d coins", entry.rewardCoins)
            end
            if entry.rewardTokens > 0 then
                rewardText = (if rewardText == "" then "" else rewardText .. "  ") .. string.format("+%d tokens", entry.rewardTokens)
            end

            rows[entry.id] = e(Components.Card, {
                accent = accent,
                selected = entry.unlocked,
                layoutOrder = i,
                padding = Tokens.space[3],
                children = e("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                }, {
                    Layout = e("UIListLayout", {
                        Padding = UDim.new(0, Tokens.space[1]),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    Header = e("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 24),
                        LayoutOrder = 1,
                    }, {
                        Layout = e("UIListLayout", {
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            SortOrder = Enum.SortOrder.LayoutOrder,
                        }),
                        Name = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = string.upper(entry.name),
                            TextColor3 = if entry.unlocked then accent else Tokens.color.cream,
                            FontFace = Tokens.font.display,
                            TextSize = Tokens.text.body,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, -100, 1, 0),
                            LayoutOrder = 1,
                        }),
                        Status = e(Components.Badge, {
                            label = if entry.unlocked then "UNLOCKED" else "LOCKED",
                            variant = if entry.unlocked then "gold" else "neutral",
                            layoutOrder = 2,
                        }),
                    }),
                    Desc = e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = entry.desc,
                        TextColor3 = Tokens.color.creamDim,
                        FontFace = Tokens.font.body,
                        TextSize = Tokens.text.caption,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Size = UDim2.new(1, 0, 0, 0),
                        LayoutOrder = 2,
                    }),
                    Bar = e(Components.ProgressBar, {
                        progress = pct,
                        label = if entry.unlocked
                            then rewardText
                            else string.format("%d / %d", progress, target),
                        accent = accent,
                        layoutOrder = 3,
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, { maxHeight = 400, children = rows })
    end

    local subtitle = if snap
        then string.format("%d / %d UNLOCKED", snap.unlockedCount, snap.totalCount)
        else "loading..."

    return e(Components.Modal, {
        title = "TROPHIES",
        subtitle = subtitle,
        accent = Tokens.color.gold,
        onClose = props.onClose,
        children = body,
    })
end

return AchievementsModal
