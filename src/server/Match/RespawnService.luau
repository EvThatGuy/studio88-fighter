--!strict
-- Owns respawn timing only. Match-level wins / losses are attributed in
-- MatchService.awardResults; this script just makes sure dead fighters
-- come back after RESPAWN_DELAY_SEC.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local RespawnService = {}

-- Disable Roblox's built-in 5s auto-respawn so we control timing.
Players.CharacterAutoLoads = true
Players.RespawnTime = Constants.RESPAWN_DELAY_SEC

local function bind(player: Player, character: Model)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    -- LoadCharacter is called automatically by Roblox after Players.RespawnTime
    -- when CharacterAutoLoads is true; the bind hook is reserved for any
    -- future post-death hooks (telemetry, killcam, etc).
    humanoid.Died:Connect(function()
        -- Hook intentionally empty; Players.RespawnTime drives respawn.
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
