--!strict
-- World 3D upgrade buttons (created by WorldBuilder per plot) carry a
-- ProximityPrompt. When triggered, this proxy calls UpgradeStation's
-- validated `attemptPurchase` directly so we don't expose a separate
-- bypass path. Cross-plot interaction is blocked: a player can only
-- trigger their own plot's prompt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local UpgradeStation = require(script.Parent:WaitForChild("UpgradeStation.server"))

local function findPrompt(button: Instance): ProximityPrompt?
    for _, child in ipairs(button:GetChildren()) do
        if child:IsA("ProximityPrompt") then return child end
    end
    return nil
end

local function refreshLabel(button: Instance, ownerUserId: number?)
    local plot = button.Parent
    if not plot then return end
    local labelRoot = plot:FindFirstChild("UpgradeLabelRoot")
    if not labelRoot then return end
    local bg = labelRoot:FindFirstChildWhichIsA("BillboardGui")
    if not bg then return end
    local lbl = bg:FindFirstChild("Label") :: TextLabel?
    if not lbl then return end

    local currentTier = 1
    if ownerUserId then
        local data = DataStore.getCached(ownerUserId)
        if data then currentTier = data.upgradeTier end
    end
    local nextTier = currentTier + 1
    local spec = Constants.UPGRADE_TIERS[nextTier]
    if spec then
        lbl.Text = "TIER " .. nextTier .. "  $" .. spec.cost
    else
        lbl.Text = "MAX TIER"
    end
end

local function bind(button: BasePart)
    local prompt = findPrompt(button)
    if not prompt then return end
    prompt.Triggered:Connect(function(player)
        local ownerUserId = button:GetAttribute("OwnerUserId")
        if ownerUserId ~= player.UserId then
            -- Not your plot. Silently ignore.
            return
        end
        local ok, reason = UpgradeStation.attemptPurchase(player)
        if not ok then
            warn(string.format("[UpgradeButtonProxy] %s rejected: %s",
                player.Name, reason or "?"))
        end
        task.wait(0.1)
        refreshLabel(button, ownerUserId)
    end)
    refreshLabel(button, button:GetAttribute("OwnerUserId"))
end

for _, b in ipairs(CollectionService:GetTagged("Studio88UpgradeButton")) do
    if b:IsA("BasePart") then bind(b) end
end
CollectionService:GetInstanceAddedSignal("Studio88UpgradeButton"):Connect(function(inst)
    if inst:IsA("BasePart") then bind(inst :: BasePart) end
end)

print("[UpgradeButtonProxy] bound to all in-world upgrade buttons")
