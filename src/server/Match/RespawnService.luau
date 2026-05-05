--!strict
-- When a Humanoid dies, count it for whoever last hit them (Phase 4 will
-- track explicit attribution; for now the killer is whoever has the last
-- damage event in CombatService — but since Humanoid.Died fires before
-- we could plumb that, this MVP just respawns after a delay).
-- Awards a loss to the dead player's persistent record on each death.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent.Parent:WaitForChild("Leaderstats"))

local RespawnService = {}

local function bind(player: Player, character: Model)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local awarded = false
    humanoid.Died:Connect(function()
        if awarded then return end
        awarded = true
        local data = DataStore.getCached(player.UserId)
        if data then
            data.losses += 1
            data.matchesPlayed += 1
            Leaderstats.refresh(player.UserId)
        end
        task.wait(Constants.RESPAWN_DELAY_SEC)
        if player.Parent then
            player:LoadCharacter()
        end
    end)
end

local function bindPlayer(player: Player)
    if player.Character then bind(player, player.Character) end
    player.CharacterAdded:Connect(function(character)
        bind(player, character)
    end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end

return RespawnService
