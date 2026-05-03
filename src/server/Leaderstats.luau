--!strict
-- `leaderstats` is Roblox's built-in player-list convention: a Folder named
-- exactly "leaderstats" parented to the Player, with NumberValue/IntValue
-- children. The Esc menu and default top-right player list pick them up
-- automatically -- zero client code required.
--
-- We expose three stats: Coins (current spendable balance), Tier
-- (1..#UPGRADE_TIERS), and Rebirths (prestige count). Server scripts that
-- mutate cached PlayerData call Leaderstats.refresh(userId) to push the
-- latest values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStore = require(script.Parent:WaitForChild("DataStore"))

local Leaderstats = {}

local function ensureFolder(player: Player): Folder
    local existing = player:FindFirstChild("leaderstats")
    if existing and existing:IsA("Folder") then return existing end
    local folder = Instance.new("Folder")
    folder.Name = "leaderstats"
    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = folder
    local tier = Instance.new("IntValue")
    tier.Name = "Tier"
    tier.Value = 1
    tier.Parent = folder
    local rebirths = Instance.new("IntValue")
    rebirths.Name = "Rebirths"
    rebirths.Value = 0
    rebirths.Parent = folder
    folder.Parent = player
    return folder
end

function Leaderstats.refresh(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local data = DataStore.getCached(userId)
    if not data then return end
    local folder = ensureFolder(player)
    local coinsVal = folder:FindFirstChild("Coins") :: IntValue?
    local tierVal = folder:FindFirstChild("Tier") :: IntValue?
    local rebirthVal = folder:FindFirstChild("Rebirths") :: IntValue?
    -- IntValue caps at int32; clamp huge balances so we don't overflow
    if coinsVal then coinsVal.Value = math.clamp(data.coins, 0, 2147483647) end
    if tierVal then tierVal.Value = data.upgradeTier end
    if rebirthVal then rebirthVal.Value = data.rebirths or 0 end
end

-- Bootstrap: populate at join + on every cache landing
Players.PlayerAdded:Connect(function(player)
    -- DataStore PlayerAdded loads asynchronously; poll briefly so we don't
    -- create the folder with stale defaults
    task.spawn(function()
        for _ = 1, 10 do
            if DataStore.getCached(player.UserId) then break end
            task.wait(0.3)
        end
        ensureFolder(player)
        Leaderstats.refresh(player.UserId)
    end)
end)

print("[Leaderstats] mounted (Coins + Tier + Rebirths in Esc menu player list)")

return Leaderstats
