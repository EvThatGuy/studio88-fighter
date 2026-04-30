--!strict
-- Per-player plot assignment. On join: find a free anchor (tagged
-- Studio88PlotAnchor, no Owner attribute), clone the template into the
-- workspace at that anchor's CFrame, stamp Owner=userId on every tagged
-- part inside the plot so Dropper / Collector / UpgradeButton can resolve
-- which player they belong to.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local plotTemplate: Model? = nil

local function getTemplate(): Model
    -- WorldBuilder runs synchronously at script start, but it lives in a
    -- different server script which may not have loaded yet on first frame
    -- under Rojo. Yield until template exists.
    local templates = ServerStorage:WaitForChild("Studio88Templates", 30)
    assert(templates, "Studio88Templates folder never appeared")
    plotTemplate = templates:WaitForChild("Plot", 30) :: Model
    assert(plotTemplate, "Plot template never appeared")
    return plotTemplate :: Model
end

local function findFreeAnchor(): BasePart?
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:IsA("BasePart") and not anchor:GetAttribute("OwnerUserId") then
            return anchor
        end
    end
    return nil
end

local function stampOwner(plot: Model, userId: number)
    -- Tag every owned part so the gameplay scripts can resolve player
    plot:SetAttribute("OwnerUserId", userId)
    for _, descendant in ipairs(plot:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant:SetAttribute("OwnerUserId", userId)
        end
    end
end

local function paintPlotName(plot: Model, player: Player)
    -- Find the Foundation and put the player's name floating over it
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local marker = Instance.new("Part")
    marker.Size = Vector3.new(0.1, 0.1, 0.1)
    marker.Position = foundation.Position + Vector3.new(0, 28, 0)
    marker.Anchored = true
    marker.Transparency = 1
    marker.CanCollide = false
    marker.Parent = plot

    local bg = Instance.new("BillboardGui")
    bg.Adornee = marker
    bg.Size = UDim2.new(0, 220, 0, 40)
    bg.AlwaysOnTop = true
    bg.Parent = marker

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = player.Name .. "'s plot"
    lbl.TextColor3 = Color3.fromRGB(248, 248, 242)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.3
    lbl.TextScaled = true
    lbl.Parent = bg
end

local function assign(player: Player)
    local template = plotTemplate or getTemplate()
    local anchor = findFreeAnchor()
    if not anchor then
        warn("[PlotAssigner] no free plot anchor for " .. player.Name .. "; server full?")
        return
    end
    anchor:SetAttribute("OwnerUserId", player.UserId)

    local clone = template:Clone()
    clone.Name = "Plot_" .. player.UserId
    -- Move whole model so foundation lands on the anchor's spot
    if clone.PrimaryPart then
        clone:PivotTo(CFrame.new(anchor.Position + Vector3.new(0, 0.5, 0))
            * CFrame.Angles(0, math.atan2(-anchor.Position.X, -anchor.Position.Z), 0))
    end
    clone.Parent = Workspace
    stampOwner(clone, player.UserId)
    paintPlotName(clone, player)

    print(string.format("[PlotAssigner] %s -> plot index %s",
        player.Name, tostring(anchor:GetAttribute("PlotIndex"))))
end

local function release(player: Player)
    local userId = player.UserId
    -- Free the anchor
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        if anchor:GetAttribute("OwnerUserId") == userId then
            anchor:SetAttribute("OwnerUserId", nil)
        end
    end
    -- Remove the plot model
    local plot = Workspace:FindFirstChild("Plot_" .. userId)
    if plot then plot:Destroy() end
end

-- Bootstrap: run after WorldBuilder has had a chance to populate
task.spawn(function()
    getTemplate()
    Players.PlayerAdded:Connect(assign)
    Players.PlayerRemoving:Connect(release)
    -- Catch any players who joined before this script connected
    for _, p in ipairs(Players:GetPlayers()) do assign(p) end
    print("[PlotAssigner] online")
end)
