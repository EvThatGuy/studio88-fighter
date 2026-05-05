--!strict
-- Top-left COINS chip + tier + rebirth badge. Subscribes to BalanceUpdated
-- + TierUpgraded + RebirthGranted remotes; never reads currency client-side.

local React = require(game:GetService("ReplicatedStorage").Packages.React)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Modules.UI.Tokens)
local Remotes = require(ReplicatedStorage.Modules.Remotes)
local Components = require(ReplicatedStorage.Modules.UI.Components)

local e = React.createElement

local function Balance()
    local coins, setCoins = React.useState(0)
    local tier, setTier = React.useState(1)
    local rebirths, setRebirths = React.useState(0)

    React.useEffect(function()
        -- All work that yields (Remotes.waitFor, InvokeServer) MUST run inside
        -- task.spawn so this effect callback returns synchronously. Yielding
        -- here breaks React's commit chain and silently kills sibling effects
        -- (cost us 4hrs of debugging via Studio 88 v51-v59).
        local conns: { RBXScriptConnection } = {}
        local cancelled = false

        task.spawn(function()
            local remotes = Remotes.waitFor(15)
            if cancelled then return end

            local ok, snap = pcall(function() return remotes.GetBalance:InvokeServer() end)
            if cancelled then return end
            if ok and snap then
                setCoins(snap.coins or 0)
                setTier(snap.upgradeTier or 1)
                setRebirths(snap.rebirths or 0)
            end

            -- Positional args, not a table payload.
            table.insert(conns, remotes.BalanceUpdated.OnClientEvent:Connect(function(coinsArg: number, _lifetime: number?)
                if typeof(coinsArg) == "number" then setCoins(coinsArg) end
            end))
            table.insert(conns, remotes.TierUpgraded.OnClientEvent:Connect(function(nextTier: number, _mult: number?)
                if typeof(nextTier) == "number" then setTier(nextTier) end
            end))
            table.insert(conns, remotes.RebirthGranted.OnClientEvent:Connect(function(nextRebirths: number, _mult: number?)
                if typeof(nextRebirths) == "number" then setRebirths(nextRebirths) end
            end))
        end)

        return function()
            cancelled = true
            for _, c in conns do c:Disconnect() end
        end
    end, {})

    return e("Frame", {
        BackgroundColor3 = Tokens.color.plum,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Position = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        ZIndex = Tokens.layer.hud,
    }, {
        Corner = e("UICorner", { CornerRadius = Tokens.radius.lg }),
        Stroke = e("UIStroke", {
            Color = Tokens.color.velvet,
            Thickness = Tokens.stroke.regular,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        Padding = e("UIPadding", {
            PaddingTop = UDim.new(0, Tokens.space[3]),
            PaddingBottom = UDim.new(0, Tokens.space[3]),
            PaddingLeft = UDim.new(0, Tokens.space[4]),
            PaddingRight = UDim.new(0, Tokens.space[4]),
        }),
        Layout = e("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, Tokens.space[2]),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Coins = e(Components.Currency, {
            amount = coins,
            kind = "coins",
            size = "lg",
            layoutOrder = 1,
        }),
        Tags = e("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 24),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = 2,
        }, {
            Layout = e("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, Tokens.space[2]),
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            TierBadge = e(Components.Badge, {
                label = "TIER " .. tostring(tier),
                variant = "gold",
                layoutOrder = 1,
            }),
            RebirthBadge = if rebirths > 0 then e(Components.Badge, {
                label = "R" .. tostring(rebirths),
                variant = "rarity",
                accent = Tokens.color.rarityEpic,
                layoutOrder = 2,
            }) else nil,
        }),
    })
end

return Balance
