--!strict
-- Silences Roblox's engine-inserted RbxCharacterSounds (footsteps, falling,
-- jumping, dying, splash, etc.) on the local character. These get parented
-- to HumanoidRootPart shortly after CharacterAdded by the default
-- RbxCharacterSounds LocalScript that the engine inserts into
-- Players.LocalPlayer.PlayerScripts. They routinely play during spawn /
-- respawn / falling state transitions, which is what the "random sound
-- that won't go away" in Studio test is.
--
-- Strategy: zero their Volume (rather than destroy) so the engine script
-- doesn't error trying to Play a missing instance. Watch ChildAdded on
-- HRP because RbxCharacterSounds may parent its sounds AFTER our first
-- pass.

local Players = game:GetService("Players")

local SILENCED_NAMES: {[string]: boolean} = {
    Climbing = true,
    Died = true,
    FreeFalling = true,
    GettingUp = true,
    Jumping = true,
    Landing = true,
    Running = true,
    Splash = true,
    Swimming = true,
}

local function silence(sound: Sound)
    sound.Volume = 0
    pcall(function() sound:Stop() end)
end

local function bindHRP(hrp: BasePart)
    for _, child in ipairs(hrp:GetChildren()) do
        if child:IsA("Sound") and SILENCED_NAMES[child.Name] then
            silence(child)
        end
    end
    hrp.ChildAdded:Connect(function(child)
        if child:IsA("Sound") and SILENCED_NAMES[child.Name] then
            silence(child)
        end
    end)
end

local function onCharacter(character: Model)
    local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    if hrp then bindHRP(hrp) end
end

local player = Players.LocalPlayer
if player.Character then onCharacter(player.Character) end
player.CharacterAdded:Connect(onCharacter)
