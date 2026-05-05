--!strict
-- Logs each character's rig type at spawn. The placeholder animation IDs
-- in AnimationCatalog (522635514 RightSlash, 522638767 Lunge) are
-- R15-only. R15 animations silently fail to evaluate on an R6 rig:
-- LoadAnimation returns a track, track:Play() runs, but nothing moves.
-- This script makes the failure mode VISIBLE in Output instead of silent.
--
-- The Rojo project file forces AvatarType=R15 at the place level, so
-- every character should spawn as R15. If a warning prints below, the
-- place setting wasn't applied — open File → Game Settings → Avatar
-- and set Avatar Type = R15 manually.

local Players = game:GetService("Players")

local function checkRig(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then
        warn(string.format("[RigDiagnostic] %s spawned without a Humanoid", player.Name))
        return
    end
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        print(string.format("[RigDiagnostic] %s spawned as R15 — placeholder animations OK", player.Name))
    else
        warn(string.format(
            "[RigDiagnostic] %s spawned as %s (NOT R15). M1 / Slot1 sword animations will not play. " ..
            "Fix: File → Game Settings → Avatar → Avatar Type = R15.",
            player.Name, tostring(humanoid.RigType)
        ))
    end
end

local function bind(player: Player)
    if player.Character then checkRig(player, player.Character) end
    player.CharacterAdded:Connect(function(character)
        checkRig(player, character)
    end)
end

Players.PlayerAdded:Connect(bind)
for _, player in ipairs(Players:GetPlayers()) do
    bind(player)
end
