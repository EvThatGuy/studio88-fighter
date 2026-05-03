--!strict
-- Lobby teleport pads (LobbyDecor.PlotTeleportPad1..6) jump the player
-- to their plot foundation if they own one. Maintains:
--   1. Per-pad ProximityPrompt enabled state — disabled if player doesn't
--      own that PlotIndex
--   2. Per-pad color — tier-keyed when owned, grey when not
--   3. Teleport on Triggered: ownership-check + CFrame the character to
--      the plot's Foundation top
--
-- Refresh sweep runs every 2s (cheap — 6 pads * 1 player loop). Also
-- refreshes on PlayerAdded so newly-spawned players see correct state.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner"))

local function findPads(): {BasePart}
    local container = Workspace:FindFirstChild("Studio88LobbyDecor")
    if not container then return {} end
    local out = {}
    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("BasePart") and c.Name:match("^PlotTeleportPad%d+$") then
            table.insert(out, c)
        end
    end
    return out
end

-- For each pad, find the player whose PlotIndex matches the pad's
-- PlotIndex, light it in their tier color, enable the prompt for THEM
-- (server-side prompt is global; we toggle Enabled on triggered-by-not-
-- owner inside the handler).
local function refreshPad(pad: BasePart)
    local idx = pad:GetAttribute("PlotIndex")
    if not idx then return end
    -- Find the anchor with PlotIndex matching this pad
    local ownerUserId: number? = nil
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:GetAttribute("PlotIndex") == idx then
            ownerUserId = anchor:GetAttribute("OwnerUserId")
            break
        end
    end
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if ownerUserId then
        local data = DataStore.getCached(ownerUserId)
        local tier = (data and data.upgradeTier) or 1
        local tierSpec = Constants.TIER_OBELISK[tier] or Constants.TIER_OBELISK[1]
        pad.Color = (tierSpec and tierSpec.color) or Color3.fromRGB(0, 240, 255)
        pad.Transparency = 0.1
        if prompt then
            prompt.Enabled = true
            prompt.ObjectText = "Plot " .. idx
        end
    else
        pad.Color = Color3.fromRGB(60, 65, 78)
        pad.Transparency = 0.4
        if prompt then prompt.Enabled = false end
    end
end

local function onTriggered(pad: BasePart, player: Player)
    local idx = pad:GetAttribute("PlotIndex")
    if not idx then return end
    -- Resolve plot via the same anchor lookup
    local plotOwnerId: number? = nil
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:GetAttribute("PlotIndex") == idx then
            plotOwnerId = anchor:GetAttribute("OwnerUserId")
            break
        end
    end
    if plotOwnerId ~= player.UserId then
        -- Not your pad. Silent.
        return
    end
    local plot = PlotAssigner.getPlotFor(player.UserId)
    if not plot then return end
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    -- Land 6 studs above foundation center so the player drops onto it
    hrp.CFrame = CFrame.new(foundation.Position + Vector3.new(0, foundation.Size.Y / 2 + 6, 0))
end

local function bind(pad: BasePart)
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end
    prompt.Triggered:Connect(function(player) onTriggered(pad, player) end)
    refreshPad(pad)
end

-- Wait for LobbyDecor to be built (WorldBuilder runs synchronously but
-- in a different script — yield until pads exist).
task.spawn(function()
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        local pads = findPads()
        if #pads >= 6 then
            for _, pad in ipairs(pads) do bind(pad) end
            print(string.format("[PlotTeleportProxy] bound %d pads", #pads))
            break
        end
        task.wait(0.5)
    end

    -- Refresh sweep every 2s — covers tier-ups + ownership transfers
    while true do
        task.wait(2)
        for _, pad in ipairs(findPads()) do refreshPad(pad) end
    end
end)
