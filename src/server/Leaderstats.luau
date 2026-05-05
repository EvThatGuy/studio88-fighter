--!strict
-- `leaderstats` is Roblox's built-in player-list convention: a Folder named
-- exactly "leaderstats" parented to the Player, with NumberValue / IntValue
-- children. The Esc menu and default top-right player list pick them up
-- automatically — zero client code required.
--
-- Fighter stats: KOs (lifetime knockouts), Wins (matches won), Level
-- (XP-derived). Server scripts that mutate cached PlayerData call
-- Leaderstats.refresh(userId) to push the latest values.

local Players = game:GetService("Players")

local DataStore = require(script.Parent:WaitForChild("DataStore"))

local Leaderstats = {}

local function ensureFolder(player: Player): Folder
    local existing = player:FindFirstChild("leaderstats")
    if existing and existing:IsA("Folder") then return existing end
    local folder = Instance.new("Folder")
    folder.Name = "leaderstats"

    local kos = Instance.new("IntValue")
    kos.Name = "KOs"
    kos.Parent = folder

    local wins = Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Parent = folder

    local level = Instance.new("IntValue")
    level.Name = "Level"
    level.Value = 1
    level.Parent = folder

    folder.Parent = player
    return folder
end

function Leaderstats.refresh(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local data = DataStore.getCached(userId)
    if not data then return end
    local folder = ensureFolder(player)
    local kos = folder:FindFirstChild("KOs") :: IntValue?
    local wins = folder:FindFirstChild("Wins") :: IntValue?
    local level = folder:FindFirstChild("Level") :: IntValue?
    if kos then kos.Value = data.knockouts end
    if wins then wins.Value = data.wins end
    if level then level.Value = data.xpLevel end
end

Players.PlayerAdded:Connect(function(player)
    -- DataStore.PlayerAdded fires too; both connect at module load. Order
    -- isn't guaranteed, so refresh once after a small wait to ensure the
    -- cache is populated.
    task.wait(0.5)
    Leaderstats.refresh(player.UserId)
end)

return Leaderstats
