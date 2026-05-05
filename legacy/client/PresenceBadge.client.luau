--!strict
-- Top-bar player count badge. Shows "👥 N" when squad inactive, "👥 N · +25%"
-- when squad bonus active (count ≥ threshold). Updates from
-- ServerPresenceChanged broadcasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local labelRef: TextLabel? = nil
local strokeRef: UIStroke? = nil

local function makeBadge()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88PresenceBadge")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88PresenceBadge"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 71
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0, 0)
    card.Position = UDim2.new(0, 16, 0, 144)  -- below leaderstats + tournament widget
    card.Size = UDim2.new(0, 140, 0, 32)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local newStroke = Instance.new("UIStroke")
    newStroke.Color = CYAN
    newStroke.Thickness = 1
    newStroke.Transparency = 0.4
    newStroke.Parent = card
    strokeRef = newStroke

    local newLabel = Instance.new("TextLabel")
    newLabel.Size = UDim2.new(1, -16, 1, -8)
    newLabel.Position = UDim2.new(0, 8, 0, 4)
    newLabel.BackgroundTransparency = 1
    newLabel.Text = "👥 1"
    newLabel.TextColor3 = CYAN
    newLabel.Font = Enum.Font.GothamBold
    newLabel.TextScaled = true
    newLabel.TextXAlignment = Enum.TextXAlignment.Left
    newLabel.Parent = card
    labelRef = newLabel
end

makeBadge()
player.CharacterAdded:Connect(function() task.wait(0.3); makeBadge() end)

remotes.ServerPresenceChanged.OnClientEvent:Connect(function(payload)
    if not labelRef or not labelRef.Parent or not payload then return end
    local count = payload.count or 1
    local active = payload.squadActive == true
    if active then
        labelRef.Text = string.format("👥 %d · +25%%", count)
        labelRef.TextColor3 = AMBER
        if strokeRef then strokeRef.Color = AMBER end
    else
        labelRef.Text = string.format("👥 %d", count)
        labelRef.TextColor3 = CYAN
        if strokeRef then strokeRef.Color = CYAN end
    end
end)

print("[PresenceBadge] client ready")
