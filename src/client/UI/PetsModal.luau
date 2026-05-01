--!strict
-- Pets feature surface in Velvet Studio aesthetic.
--
-- Three tabs: EGGS (price + hatch CTA), INVENTORY (owned pets, equip/unequip),
-- FUSION (3-of-a-rarity stub for now).
--
-- Hydrates from GetPetState on mount + subscribes to PetEquipChanged +
-- PetHatched + PetHatchRejected for live updates without re-polling.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

export type PetsModalProps = {
    onClose: () -> (),
}

type Snapshot = {
    pets: { any },
    equippedPetIds: { string },
    maxEquipped: number,
    eggs: { any },
    collectionComplete: boolean,
    coinsAvailable: number,
    pity: number,
    pityThreshold: number,
}

local RARITY_COLOR: { [string]: Color3 } = {
    common = Tokens.color.rarityCommon,
    uncommon = Tokens.color.rarityUncommon,
    rare = Tokens.color.rarityRare,
    epic = Tokens.color.rarityEpic,
    legendary = Tokens.color.rarityLegendary,
}

local function isEquipped(snap: Snapshot?, uid: string): boolean
    if not snap then return false end
    for _, equippedUid in snap.equippedPetIds do
        if equippedUid == uid then return true end
    end
    return false
end

local function PetsModal(props: PetsModalProps)
    local snap, setSnap = React.useState(nil :: Snapshot?)
    local activeTab, setActiveTab = React.useState("eggs")

    local refresh = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        local ok, fresh = pcall(function() return remotes.GetPetState:InvokeServer() end)
        if ok and fresh then
            setSnap(fresh)
        end
    end, {})

    React.useEffect(function()
        refresh()

        local remotes = Remotes.waitFor(15)
        local conns = {
            remotes.PetHatched.OnClientEvent:Connect(function() refresh() end),
            remotes.PetEquipChanged.OnClientEvent:Connect(function() refresh() end),
            remotes.BalanceUpdated.OnClientEvent:Connect(function(coinsArg: number, _lifetime: number?)
                if typeof(coinsArg) ~= "number" then return end
                setSnap(function(prev)
                    if prev == nil then return prev end
                    return {
                        pets = prev.pets,
                        equippedPetIds = prev.equippedPetIds,
                        maxEquipped = prev.maxEquipped,
                        eggs = prev.eggs,
                        collectionComplete = prev.collectionComplete,
                        coinsAvailable = coinsArg,
                        pity = prev.pity,
                        pityThreshold = prev.pityThreshold,
                    } :: Snapshot
                end)
            end),
        }

        return function()
            for _, c in conns do c:Disconnect() end
        end
    end, { refresh } :: { any })

    local hatchEgg = React.useCallback(function(eggId: string)
        local remotes = Remotes.waitFor(15)
        remotes.HatchEgg:FireServer(eggId)
    end, {})

    local toggleEquip = React.useCallback(function(uid: string, equipped: boolean)
        local remotes = Remotes.waitFor(15)
        if equipped then
            remotes.UnequipPet:FireServer(uid)
        else
            remotes.EquipPet:FireServer(uid)
        end
    end, {})

    local autoEquip = React.useCallback(function()
        local remotes = Remotes.waitFor(15)
        remotes.AutoEquipPets:FireServer()
    end, {})

    -- Body content swaps based on active tab.
    local body: any = nil

    if not snap then
        body = e(Components.EmptyState, {
            headline = "LOADING",
            body = "Pulling your pet inventory from the studio vault.",
        })
    elseif activeTab == "eggs" then
        local eggCards: { [string]: any } = {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[3]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            PityHint = e(Components.ProgressBar, {
                progress = snap.pity / snap.pityThreshold,
                label = string.format("PITY  %d / %d", snap.pity, snap.pityThreshold),
                accent = Tokens.color.rarityLegendary,
                layoutOrder = 0,
            }),
        }
        for i, egg in ipairs(snap.eggs) do
            local affordable = snap.coinsAvailable >= egg.cost
            eggCards[egg.id] = e(Components.Card, {
                accent = Tokens.color.gold,
                layoutOrder = i,
                children = e("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                }, {
                    Layout = e("UIListLayout", {
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, Tokens.space[2]),
                    }),
                    Header = e("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 28),
                        LayoutOrder = 1,
                    }, {
                        Layout = e("UIListLayout", {
                            FillDirection = Enum.FillDirection.Horizontal,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            HorizontalAlignment = Enum.HorizontalAlignment.Left,
                        }),
                        Name = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = string.upper(egg.name),
                            TextColor3 = Tokens.color.cream,
                            FontFace = Tokens.font.display,
                            TextSize = Tokens.text.h3,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 1, 0),
                        }),
                    }),
                    Sub = if egg.sub then e("TextLabel", {
                        BackgroundTransparency = 1,
                        Text = egg.sub,
                        TextColor3 = Tokens.color.creamDim,
                        FontFace = Tokens.font.body,
                        TextSize = Tokens.text.caption,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Size = UDim2.new(1, 0, 0, 0),
                        LayoutOrder = 2,
                    }) else nil,
                    Foot = e("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, Tokens.layout.tapMin),
                        LayoutOrder = 3,
                    }, {
                        Layout = e("UIListLayout", {
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Right,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            Padding = UDim.new(0, Tokens.space[3]),
                            SortOrder = Enum.SortOrder.LayoutOrder,
                        }),
                        Cost = e(Components.Currency, {
                            amount = egg.cost,
                            kind = "coins",
                            size = "sm",
                            layoutOrder = 1,
                            align = Enum.TextXAlignment.Right,
                        }),
                        CTA = e(Components.Button, {
                            label = if affordable then "HATCH" else "NEED MORE",
                            variant = if affordable then "primary" else "secondary",
                            disabled = not affordable,
                            onClick = if affordable then function() hatchEgg(egg.id) end else nil,
                            layoutOrder = 2,
                        }),
                    }),
                }),
            })
        end
        body = e(Components.ScrollList, {
            maxHeight = 360,
            children = eggCards,
        })
    elseif activeTab == "inventory" then
        if #snap.pets == 0 then
            body = e(Components.EmptyState, {
                headline = "NO PETS YET",
                body = "Hatch an egg to start your collection. Each rarity bumps your coin multiplier.",
                ctaLabel = "GO TO EGGS",
                onCta = function() setActiveTab("eggs") end,
            })
        else
            local petCards: { [string]: any } = {
                Layout = e("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, Tokens.space[2]),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                AutoEquip = e(Components.Button, {
                    label = string.format("AUTO-EQUIP BEST %d", snap.maxEquipped),
                    variant = "secondary",
                    fullWidth = true,
                    onClick = autoEquip,
                    layoutOrder = 0,
                }),
            }
            for i, pet in ipairs(snap.pets) do
                local equipped = isEquipped(snap, pet.uid)
                petCards[pet.uid] = e(Components.Card, {
                    accent = RARITY_COLOR[pet.rarity] or Tokens.color.rarityCommon,
                    selected = equipped,
                    layoutOrder = i,
                    onClick = function() toggleEquip(pet.uid, equipped) end,
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
                        Name = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = string.upper(pet.name),
                            TextColor3 = Tokens.color.cream,
                            FontFace = Tokens.font.display,
                            TextSize = Tokens.text.body,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, -160, 1, 0),
                            LayoutOrder = 1,
                        }),
                        Rarity = e(Components.Badge, {
                            label = pet.rarity,
                            variant = "rarity",
                            accent = RARITY_COLOR[pet.rarity] or Tokens.color.rarityCommon,
                            layoutOrder = 2,
                        }),
                        Mult = e("TextLabel", {
                            BackgroundTransparency = 1,
                            Text = string.format("+%d%%", math.floor((pet.mult or 0) * 100)),
                            TextColor3 = Tokens.color.gold,
                            FontFace = Tokens.font.label,
                            TextSize = Tokens.text.body,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Size = UDim2.new(0, 60, 1, 0),
                            LayoutOrder = 3,
                        }),
                    }),
                })
            end
            body = e(Components.ScrollList, {
                maxHeight = 360,
                children = petCards,
            })
        end
    else
        body = e(Components.EmptyState, {
            headline = "FUSION COMING SOON",
            body = "Combine 3 same-rarity pets to roll one of the next tier. Wired through PetService -- UI lands in the next pass.",
        })
    end

    local equippedCount = if snap then #snap.equippedPetIds else 0
    local inventoryCount = if snap then #snap.pets else 0
    local subtitle = if snap
        then string.format("%d / %d EQUIPPED  ::  %d OWNED", equippedCount, snap.maxEquipped, inventoryCount)
        else "loading..."

    return e(Components.Modal, {
        title = "PET STUDIO",
        subtitle = subtitle,
        onClose = props.onClose,
        children = e("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, Tokens.space[3]),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            Tabs = e(Components.Tabs, {
                tabs = {
                    { id = "eggs", label = "Eggs" },
                    { id = "inventory", label = "Inventory", badge = if snap then #snap.pets else nil },
                    { id = "fusion", label = "Fusion" },
                },
                activeId = activeTab,
                onChange = setActiveTab,
                layoutOrder = 1,
            }),
            Body = e("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
            }, { Content = body }),
        }),
    })
end

return PetsModal
