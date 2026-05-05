--!strict
-- Boot-time scrub: destroy stray Sound instances left over in the place
-- file under Workspace and SoundService. Earlier dev iterations may have
-- left a Sound parented somewhere Rojo doesn't manage, which then keeps
-- playing in every Studio test. Our own audio (AmbientAudio + HitFx) is
-- created at runtime AFTER this script runs, so it's unaffected.
--
-- Scope: top-level children only — we don't walk the full descendant tree
-- because that would clobber sounds attached to props (e.g. a custom map's
-- door creak). The "random sound" failure mode is a free-floating Sound
-- in SoundService or Workspace that nothing references.

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local removed = 0

local function scrubChildren(container: Instance)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Sound") then
            pcall(function() child:Stop() end)
            child:Destroy()
            removed += 1
        end
    end
end

scrubChildren(SoundService)
scrubChildren(Workspace)

print(string.format("[AudioScrub] removed %d stray Sound instance(s) from Workspace + SoundService at boot", removed))
