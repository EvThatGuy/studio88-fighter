--!strict
-- Titles modal. Sister to Auras -- one equipped tag at a time, displayed via
-- BillboardGui above the player. Locked entries show a hint of what triggers
-- the unlock.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type TitlesModalProps = {
    onClose: () -> (),
}

type Entry = {
    id: string,
    name: string,
    color: { number },
    trigger: string,
    target: number,
    progress: number?,
    unlocked: boolean,
    equipped: boolean,
}

type Snapshot = {
    entries: { Entry },
    equippedTitle: string?,
}

local TRIGGER_LABEL: { [string]: string } = {
    lifetime_coins = "Lifetime coins",
    rebirths = "Rebirths",
    pets_owned = "Pets owned",
    achievements = "Achievements unlocked",
    daily_login_streak = "Login streak",
    aura_equipped = "Equip aura",
}

local function arrToColor(arr: { number }?): Color3
    if not arr or #arr < 3 then return Tokens.color.cream end
    return Color3.fromRGB(arr[1], arr[2], arr[3])
end

local function TitlesModal(props: TitlesModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetTitles:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        refresh()
        local remotes = Remotes.waitFor(15)
        local conns = {
            remotes.TitleReplicate.OnClientEvent:Connect(function() refresh() end),
            remotes.TitleRejected.OnClientEvent:Connect(function() refresh() end),
        }
        return function()
            for _, c in conns do c:Disconnect() end
        end
    end, { refresh } :: { any })

    local toggle = React.useCallback(function(titleId: string?, currentlyEquipped: boolean)
        local remotes = Remotes.waitFor(15)
        if currentlyEquipped then
            remotes.EquipTitle:FireServer(nil)
        else
            remotes.EquipTitle:FireServer(titleId)
        end
    end, {})

    local body: any
    if not snap then
        body = e(Components.EmptyState, { headline = "LOADING" })
    else
        local cards: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[2]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        }
        for i, entry in ipairs(snap.entries) do
            local accent = arrToColor(entry.color)
            local progress = entry.progress and math.min(entry.progress, math.max(entry.target, 1)) or 0
            local pct = if entry.unlocked then 1 else progress / math.max(entry.target, 1)
            local triggerLabel = TRIGGER_LABEL[entry.trigger] or entry.trigger

            cards[entry.id] = e(Components.Card, {
                accent = accent,
                selected = entry.equipped,
                layoutOrder = i,
                padding = Tokens.space[3],
                onClick = if entry.unlocked then function()
                    toggle(entry.id, entry.equipped)
                end else nil,
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
                            TextColor3 = if entry.unlocked then accent else Tokens.color.creamDim,
                            FontFace = Tokens.font.display,
                            TextSize = Tokens.text.body,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, -120, 1, 0),
                            LayoutOrder = 1,
                        }),
                        Status = e(Components.Badge, {
                            label = if entry.equipped then "EQUIPPED"
                                elseif entry.unlocked then "READY"
                                else "LOCKED",
                            variant = if entry.equipped then "gold"
                                elseif entry.unlocked then "neutral"
                                else "neutral",
                            layoutOrder = 2,
                        }),
                    }),
                    Detail = if entry.unlocked then e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = if entry.equipped then "Tap card to remove" else "Tap card to equip",
                        TextColor3 = Tokens.color.creamDim,
                        FontFace = Tokens.font.body,
                        TextSize = Tokens.text.caption,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        LayoutOrder = 2,
                    }) else e(Components.ProgressBar, {
                        progress = pct,
                        label = string.format("%s  %d / %d", triggerLabel, progress, entry.target),
                        accent = accent,
                        layoutOrder = 2,
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, { maxHeight = 440, children = cards })
    end

    local unlockedCount = 0
    if snap then
        for _, t in snap.entries do
            if t.unlocked then unlockedCount += 1 end
        end
    end
    local subtitle = if snap
        then string.format("%d / %d EARNED", unlockedCount, #snap.entries)
        else "loading..."

    return e(Components.Modal, {
        title = "TITLES",
        subtitle = subtitle,
        accent = Tokens.color.info,
        onClose = props.onClose,
        children = body,
    })
end

return TitlesModal
