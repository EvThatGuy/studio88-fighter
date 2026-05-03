--!strict
-- Floating "+N" text on every coin collect. Spawns a quick BillboardGui
-- attached to a tiny anchor part at the collector position, drifts up
-- 6 studs over 0.7s while fading + scaling, then GCs.
--
-- Color-keyed by coin tier (cyan -> amber -> pink -> gold) so high-tier
-- collects feel different from tier-1 grind.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local _player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local function colorForTier(tier: number): Color3
    if tier >= 5 then return Color3.fromRGB(255, 215, 0) end
    if tier >= 4 then return Color3.fromRGB(255, 46, 136) end
    if tier >= 3 then return Color3.fromRGB(255, 176, 0) end
    return Color3.fromRGB(0, 240, 255)
end

local function spawn(payload)
    if typeof(payload) ~= "table" then return end
    local worldPos = payload.worldPos
    if typeof(worldPos) ~= "Vector3" then return end
    local value = tonumber(payload.value) or 0
    local tier = tonumber(payload.tier) or 1
    if value <= 0 then return end

    local anchor = Instance.new("Part")
    anchor.Name = "Studio88CoinFxAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = worldPos + Vector3.new(0, 4, 0)
    anchor.Anchored = true
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Massless = true
    anchor.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Adornee = anchor
    bb.Size = UDim2.new(0, 100, 0, 40)
    bb.AlwaysOnTop = true
    bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "+" .. value
    lbl.TextColor3 = colorForTier(tier)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = Color3.fromRGB(8, 7, 13)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = bb

    -- Drift up + fade
    local startPos = anchor.Position
    TweenService:Create(anchor,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = startPos + Vector3.new(0, 6, 0)}):Play()
    TweenService:Create(lbl,
        TweenInfo.new(0.7, Enum.EasingStyle.Linear),
        {TextTransparency = 1, TextStrokeTransparency = 1}):Play()

    task.delay(0.8, function()
        if anchor.Parent then anchor:Destroy() end
    end)
end

remotes.CoinCollectedFx.OnClientEvent:Connect(spawn)

print("[CoinCollectFx] client ready")
