--!strict
-- 3D rebirth pad proxy. Each plot has a glowing cyan disc (built by
-- WorldBuilder, tagged Studio88RebirthPad). This proxy:
--   1. Routes ProximityPrompt.Triggered to RebirthService.attemptRebirth
--   2. Toggles the prompt's Enabled state when the player crosses the
--      eligibility threshold (max tier + lifetime gate met)
--   3. Updates the floating label so players who can't yet rebirth see
--      *why* (e.g. "REACH TIER 6 FIRST" / "EARN 50K MORE")
--
-- Cross-plot trigger is blocked: only the plot owner can fire their pad.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local RebirthService = require(script.Parent:WaitForChild("RebirthService.server"))

local function findPrompt(pad: Instance): ProximityPrompt?
    for _, child in ipairs(pad:GetChildren()) do
        if child:IsA("ProximityPrompt") then return child end
    end
    return nil
end

local function findLabel(pad: Instance): TextLabel?
    local plot = pad.Parent
    if not plot then return nil end
    local labelRoot = plot:FindFirstChild("RebirthLabelRoot")
    if not labelRoot then return nil end
    local bg = labelRoot:FindFirstChildWhichIsA("BillboardGui")
    if not bg then return nil end
    return bg:FindFirstChild("Label") :: TextLabel?
end

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local function refreshPad(pad: BasePart)
    local ownerUserId = pad:GetAttribute("OwnerUserId") :: number?
    local prompt = findPrompt(pad)
    local label = findLabel(pad)
    if not ownerUserId then
        if prompt then prompt.Enabled = false end
        if label then label.Text = "REBIRTH" end
        return
    end
    local data = DataStore.getCached(ownerUserId)
    local rb = (data and data.rebirths) or 0
    local atMaxRebirths = rb >= Constants.REBIRTH_MAX
    local eligible, reason, needed = RebirthService.checkEligibility(ownerUserId)
    if prompt then
        prompt.Enabled = eligible == true
        if eligible then
            local nextMult = 1 + (rb + 1) * Constants.REBIRTH_BONUS_PER
            prompt.ActionText = "Rebirth"
            prompt.ObjectText = string.format("perma x%.2f", nextMult)
        end
    end
    if label then
        if atMaxRebirths then
            label.Text = string.format("MAX REBIRTH (R%d)", rb)
        elseif eligible then
            local nextMult = 1 + (rb + 1) * Constants.REBIRTH_BONUS_PER
            label.Text = string.format("REBIRTH READY  x%.2f", nextMult)
        elseif reason == "min_tier" then
            label.Text = string.format("REACH TIER %d FIRST", #Constants.UPGRADE_TIERS)
        elseif reason == "insufficient_lifetime" then
            label.Text = string.format("EARN %s MORE", fmtCoins(needed or 0))
        else
            label.Text = "REBIRTH"
        end
    end
end

local function bind(pad: BasePart)
    local prompt = findPrompt(pad)
    if not prompt then return end
    prompt.Triggered:Connect(function(player)
        local ownerUserId = pad:GetAttribute("OwnerUserId")
        if ownerUserId ~= player.UserId then return end
        local ok, reason = RebirthService.attemptRebirth(player)
        if not ok then
            warn(string.format("[RebirthPadProxy] %s rejected: %s",
                player.Name, reason or "?"))
        end
        task.wait(0.1)
        refreshPad(pad)
    end)
    refreshPad(pad)
end

-- Periodic refresh sweep: lifetime coins tick up every second on the
-- CurrencyManager loop, so the pad's eligibility / label needs to update
-- without a player interaction. 2s cadence is plenty (the pad text
-- granularity is 0.1K so 2s of drift is invisible).
task.spawn(function()
    while true do
        task.wait(2)
        for _, pad in ipairs(CollectionService:GetTagged("Studio88RebirthPad")) do
            if pad:IsA("BasePart") and pad:GetAttribute("OwnerUserId") then
                refreshPad(pad)
            end
        end
    end
end)

for _, pad in ipairs(CollectionService:GetTagged("Studio88RebirthPad")) do
    if pad:IsA("BasePart") then bind(pad) end
end
CollectionService:GetInstanceAddedSignal("Studio88RebirthPad"):Connect(function(inst)
    if inst:IsA("BasePart") then bind(inst :: BasePart) end
end)

-- When a player leaves, scan their pad and reset the prompt so the next
-- assignee starts clean.
Players.PlayerRemoving:Connect(function(player)
    for _, pad in ipairs(CollectionService:GetTagged("Studio88RebirthPad")) do
        if pad:GetAttribute("OwnerUserId") == player.UserId then
            local prompt = findPrompt(pad)
            if prompt then prompt.Enabled = false end
            local label = findLabel(pad)
            if label then label.Text = "REBIRTH" end
        end
    end
end)

print("[RebirthPadProxy] bound to all in-world rebirth pads")
