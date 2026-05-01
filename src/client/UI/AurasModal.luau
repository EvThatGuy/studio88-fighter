--!strict
-- Auras modal. Cosmetic flex; only one aura equipped at a time. Locked entries
-- show progress toward unlock. Tapping an unlocked aura toggles equip.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type AurasModalProps = {
    onClose: () -> (),
}

type Entry = {
    id: string,
    name: string,
    desc: string,
    color: { number },     -- {r,g,b}
    rarity: string,
    unlocked: boolean,
    equipped: boolean,
    progress: number?,
    target: number?,
    trigger: string,
}

type Snapshot = {
    entries: { Entry },
    equippedAura: string?,
    unlockedCount: number,
    totalCount: number,
}

local function arrToColor(arr: { number }?): Color3
    if not arr or #arr < 3 then return Tokens.color.cream end
    return Color3.fromRGB(arr[1], arr[2], arr[3])
end

local function AurasModal(props: AurasModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetAuras:InvokeServer() end)
        if ok and fresh then setSnap(fresh) end
    end, {})

    React.useEffect(function()
        refresh()
        local remotes = Remotes.waitFor(15)
        local conns = {
            remotes.AuraReplicate.OnClientEvent:Connect(function() refresh() end),
            remotes.AuraRejected.OnClientEvent:Connect(function() refresh() end),
        }
        return function()
            for _, c in conns do c:Disconnect() end
        end
    end, { refresh } :: { any })

    local toggle = React.useCallback(function(auraId: string?, currentlyEquipped: boolean)
        local remotes = Remotes.waitFor(15)
        -- Server interprets nil/empty as "unequip current"; an id as "equip that".
        if currentlyEquipped then
            remotes.EquipAura:FireServer(nil)
        else
            remotes.EquipAura:FireServer(auraId)
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
            local target = entry.target and math.max(entry.target, 1) or 1
            local progress = entry.progress and math.min(entry.progress, target) or 0
            local pct = if entry.unlocked then 1 else progress / target

            local statusLabel = if entry.equipped then "EQUIPPED"
                elseif entry.unlocked then "TAP TO EQUIP"
                else string.format("PROGRESS  %d / %d", progress, target)

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
                            Size = UDim2.new(1, -100, 1, 0),
                            LayoutOrder = 1,
                        }),
                        Rarity = e(Components.Badge, {
                            label = entry.rarity,
                            variant = "rarity",
                            accent = accent,
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
                    Status = if entry.unlocked then e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = statusLabel,
                        TextColor3 = accent,
                        FontFace = Tokens.font.label,
                        TextSize = Tokens.text.caption,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.new(1, 0, 0, 14),
                        LayoutOrder = 3,
                    }) else e(Components.ProgressBar, {
                        progress = pct,
                        label = statusLabel,
                        accent = accent,
                        layoutOrder = 3,
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, { maxHeight = 440, children = cards })
    end

    local subtitle = if snap
        then string.format("%d / %d UNLOCKED", snap.unlockedCount, snap.totalCount)
        else "loading..."

    return e(Components.Modal, {
        title = "AURAS",
        subtitle = subtitle,
        accent = Tokens.color.rarityEpic,
        onClose = props.onClose,
        children = body,
    })
end

return AurasModal
