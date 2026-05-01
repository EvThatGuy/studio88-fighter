--!strict
-- Crown renderer. Reacts to LeaderboardUpdated and applies a particle
-- crown above the top-3 lifetime-coin players' characters in this server.
-- Pure client-side; no server-side state. Re-applied on respawn via
-- CharacterAdded.
--
-- Visual: a small crown made of 3 ParticleEmitters (or a single rotating
-- BillboardGui). For simplicity we use a BillboardGui with a unicode
-- crown glyph color-coded per rank (gold/silver/bronze).
--
-- Sister to AuraRenderer + TitleRenderer; same character-attachment
-- pattern. Lives in its own script so leaderboard logic doesn't bleed
-- into the HUD or AuraRenderer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.waitFor()

local BB_NAME = "Studio88CrownBB"
-- Above the title (which sits at +3.5) so they don't overlap
local CROWN_OFFSET = Vector3.new(0, 5.0, 0)

local RANK_COLOR: {[number]: Color3} = {
    [1] = Color3.fromRGB(255, 215,  0),   -- gold
    [2] = Color3.fromRGB(192, 192, 192),  -- silver
    [3] = Color3.fromRGB(205, 127,  50),  -- bronze
}
local RANK_GLYPH: {[number]: string} = {
    [1] = "♛  #1  ♛",
    [2] = "♕  #2  ♕",
    [3] = "♕  #3  ♕",
}

-- userId -> rank (1, 2, 3) currently rendered
local userRank: {[number]: number?} = {}

local function findHRP(player: Player): BasePart?
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearCrown(player: Player)
    local hrp = findHRP(player)
    if not hrp then return end
    local existing = hrp:FindFirstChild(BB_NAME)
    if existing then existing:Destroy() end
end

local function applyCrown(player: Player, rank: number)
    local hrp = findHRP(player)
    if not hrp then return end
    local existing = hrp:FindFirstChild(BB_NAME)
    if existing then existing:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = BB_NAME
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 160, 0, 24)
    bb.StudsOffset = CROWN_OFFSET
    bb.AlwaysOnTop = true
    bb.MaxDistance = 100
    bb.Parent = hrp

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = RANK_GLYPH[rank] or ("#" .. rank)
    lbl.TextColor3 = RANK_COLOR[rank] or Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = bb
end

local function refreshFor(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local rank = userRank[userId]
    if rank then
        applyCrown(player, rank)
    else
        clearCrown(player)
    end
end

remotes.LeaderboardUpdated.OnClientEvent:Connect(function(rows: {any})
    if typeof(rows) ~= "table" then return end
    -- Build new rank map: only top 3 rows produce a rank
    local newRanks: {[number]: number} = {}
    for i = 1, math.min(3, #rows) do
        local row = rows[i]
        if row and row.userId then
            newRanks[row.userId] = i
        end
    end
    -- Diff against current; clear crowns that lost their rank, apply new ones
    for userId in pairs(userRank) do
        if not newRanks[userId] then
            local player = Players:GetPlayerByUserId(userId)
            if player then clearCrown(player) end
        end
    end
    userRank = newRanks
    for userId in pairs(newRanks) do
        task.spawn(function()
            for _ = 1, 5 do
                local player = Players:GetPlayerByUserId(userId)
                if player and findHRP(player) then
                    refreshFor(userId)
                    return
                end
                task.wait(0.4)
            end
        end)
    end
end)

local function onCharacterAdded(player: Player)
    return function()
        task.wait(0.5)
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
    userRank[p.UserId] = nil
end)

print("[CrownRenderer] mounted")
