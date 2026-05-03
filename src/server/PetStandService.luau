--!strict
-- 3D Pet Stand. Above each player's plot Foundation, render floating
-- BillboardGui badges for every currently-equipped pet. Visible to all
-- players in the server -- a "look at this guy's setup" flex that
-- compounds with the gacha + fusion loops.
--
-- Refreshed on:
--   - player plot assignment (via PlayerAdded -> wait for plot)
--   - pet equip / unequip (PetService calls refreshFor on commit)
--   - pet hatch (covers the case where a fresh pet is auto-equip-able)
--
-- All instances live under Plot/PetStand so plot teardown takes them
-- with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner"))

local PetStandService = {}

local STAND_NAME = "PetStand"
local STAND_OFFSET = Vector3.new(0, 14, 0) -- above foundation
local BADGE_SPACING = 5

local petById: {[string]: any} = {}
for _, p in ipairs(Constants.PETS) do petById[p.id] = p end

local function clearStand(plot: Model)
    local existing = plot:FindFirstChild(STAND_NAME)
    if existing then existing:Destroy() end
end

local function buildBadge(parent: Instance, def: any, rarityColor: {number}): Part
    local part = Instance.new("Part")
    part.Size = Vector3.new(2.5, 2.5, 2.5)
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(rarityColor[1], rarityColor[2], rarityColor[3])
    part.Transparency = 0.2
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Parent = parent

    local bb = Instance.new("BillboardGui")
    bb.Adornee = part
    bb.Size = UDim2.new(0, 160, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = false
    bb.Parent = part

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, 0, 0, 22)
    nameL.BackgroundTransparency = 1
    nameL.Text = def.name
    nameL.TextColor3 = Color3.fromRGB(rarityColor[1], rarityColor[2], rarityColor[3])
    nameL.Font = Enum.Font.GothamBold
    nameL.TextStrokeTransparency = 0.3
    nameL.TextScaled = true
    nameL.Parent = bb

    local rarL = Instance.new("TextLabel")
    rarL.Size = UDim2.new(1, 0, 0, 18)
    rarL.Position = UDim2.new(0, 0, 0, 24)
    rarL.BackgroundTransparency = 1
    rarL.Text = string.upper(def.rarity)
    rarL.TextColor3 = Color3.fromRGB(248, 248, 242)
    rarL.Font = Enum.Font.Code
    rarL.TextStrokeTransparency = 0.5
    rarL.TextScaled = true
    rarL.TextTransparency = 0.2
    rarL.Parent = bb

    return part
end

function PetStandService.refreshFor(userId: number)
    local plot = PlotAssigner.getPlotFor(userId)
    if not plot then return end
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then return end
    local data = DataStore.getCached(userId)
    if not data then return end

    clearStand(plot)
    if not data.equippedPetIds or #data.equippedPetIds == 0 then return end

    -- Resolve uids to defs (some uids may have been consumed by fusion;
    -- silently skip those).
    local petByUid: {[string]: any} = {}
    for _, p in ipairs(data.pets or {}) do petByUid[p.uid] = p end

    local active = {}
    for _, uid in ipairs(data.equippedPetIds) do
        local p = petByUid[uid]
        if p then
            local def = petById[p.petId]
            if def then
                table.insert(active, {def = def, rarity = p.rarity})
            end
        end
    end
    if #active == 0 then return end

    local stand = Instance.new("Folder")
    stand.Name = STAND_NAME
    stand.Parent = plot

    local center = foundation.Position + STAND_OFFSET
    local count = #active
    local startX = -((count - 1) * BADGE_SPACING) / 2

    for i, entry in ipairs(active) do
        local rcolor = Constants.PET_RARITY_COLORS[entry.rarity] or {200, 200, 200}
        local part = buildBadge(stand, entry.def, rcolor)
        part.Position = center + Vector3.new(startX + (i - 1) * BADGE_SPACING, 0, 0)
        -- Spin via SpinningPart attribute that a client can read, OR use
        -- BodyAngularVelocity. Anchored parts can't have BAV, so we tween
        -- via a coroutine on the server. Keep cheap: 0.5 rad/s.
        task.spawn(function()
            local angle = 0
            while part.Parent do
                angle += 0.04
                part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, angle, 0)
                task.wait(0.05)
            end
        end)
    end
end

-- ---- Hooks --------------------------------------------------------------

-- Initial render after the player gets a plot. PlotAssigner.assign runs in
-- its own PlayerAdded handler; we wait a generous beat then refresh.
Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        for _ = 1, 10 do
            if PlotAssigner.getPlotFor(player.UserId) then
                PetStandService.refreshFor(player.UserId)
                return
            end
            task.wait(0.5)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    -- Plot is destroyed by PlotAssigner; nothing for us to clean
end)

return PetStandService
