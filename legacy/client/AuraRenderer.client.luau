--!strict
-- Renders Trail attachments on every player's character based on
-- AuraReplicate broadcasts from the server. Visual-only; no game state
-- here. The aura def is looked up locally from Constants.AURAS so the
-- server payload only needs (userId, auraId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.waitFor()

local TRAIL_NAME = "Studio88AuraTrail"
local ATT_TOP_NAME = "Studio88AuraAttTop"
local ATT_BOTTOM_NAME = "Studio88AuraAttBottom"

local auraById: {[string]: any} = {}
for _, a in ipairs(Constants.AURAS) do auraById[a.id] = a end

-- userId -> equipped auraId. The renderer keeps its own map so it can
-- re-apply when a character respawns (CharacterAdded after Equip).
local userAura: {[number]: string?} = {}

local function findCharacterRoot(player: Player): BasePart?
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearTrail(player: Player)
    local hrp = findCharacterRoot(player)
    if not hrp then return end
    local existing = hrp:FindFirstChild(TRAIL_NAME)
    if existing then existing:Destroy() end
    local at = hrp:FindFirstChild(ATT_TOP_NAME); if at then at:Destroy() end
    local ab = hrp:FindFirstChild(ATT_BOTTOM_NAME); if ab then ab:Destroy() end
end

local function applyTrail(player: Player, auraId: string)
    local def = auraById[auraId]
    if not def then return end
    local hrp = findCharacterRoot(player)
    if not hrp then return end
    -- Clean any prior aura on this character first
    local existing = hrp:FindFirstChild(TRAIL_NAME)
    if existing then existing:Destroy() end

    local attTop = hrp:FindFirstChild(ATT_TOP_NAME) :: Attachment?
    if not attTop then
        attTop = Instance.new("Attachment")
        attTop.Name = ATT_TOP_NAME
        attTop.Position = Constants.AURA_TRAIL.ATTACHMENT_OFFSET
        attTop.Parent = hrp
    end
    local attBot = hrp:FindFirstChild(ATT_BOTTOM_NAME) :: Attachment?
    if not attBot then
        attBot = Instance.new("Attachment")
        attBot.Name = ATT_BOTTOM_NAME
        attBot.Position = -Constants.AURA_TRAIL.ATTACHMENT_OFFSET
        attBot.Parent = hrp
    end

    local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
    local trail = Instance.new("Trail")
    trail.Name = TRAIL_NAME
    trail.Attachment0 = attTop
    trail.Attachment1 = attBot
    trail.Lifetime = Constants.AURA_TRAIL.LIFETIME
    trail.Color = ColorSequence.new(color)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, Constants.AURA_TRAIL.TRANSPARENCY_START),
        NumberSequenceKeypoint.new(1, Constants.AURA_TRAIL.TRANSPARENCY_END),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, Constants.AURA_TRAIL.WIDTH_START),
        NumberSequenceKeypoint.new(1, Constants.AURA_TRAIL.WIDTH_END),
    })
    trail.LightEmission = 0.6
    trail.FaceCamera = true
    trail.Parent = hrp
end

local function refreshFor(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local auraId = userAura[userId]
    if auraId then
        applyTrail(player, auraId)
    else
        clearTrail(player)
    end
end

remotes.AuraReplicate.OnClientEvent:Connect(function(userId: number, auraId: string?)
    userAura[userId] = auraId
    -- Defer slightly so a freshly-respawned character has its HRP
    task.spawn(function()
        for _ = 1, 5 do
            local player = Players:GetPlayerByUserId(userId)
            if player and findCharacterRoot(player) then
                refreshFor(userId)
                return
            end
            task.wait(0.4)
        end
    end)
end)

-- Re-apply trails on respawn
local function onCharacterAdded(player: Player)
    return function()
        task.wait(0.5) -- HRP usually exists immediately, but be defensive
        refreshFor(player.UserId)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(onCharacterAdded(p))
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(onCharacterAdded(p))
end)

Players.PlayerRemoving:Connect(function(p)
    userAura[p.UserId] = nil
end)

print("[AuraRenderer] mounted")
