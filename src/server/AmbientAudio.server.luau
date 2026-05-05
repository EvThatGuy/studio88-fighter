--!strict
-- Boots AmbientAudio.luau on server start. Implementation is in the
-- ModuleScript so other services can also require() and call
-- playSpatial() for combat / UI SFX. This file just kicks off the
-- one-shot setup at boot.

-- Master kill switch for the placeholder Roblox-built-in audio loop.
-- While we wait for final fighter audio assets, ambient hum + UI pings
-- are silenced. This flag gates BOTH the boot loop AND every Sound-
-- creation function in AmbientAudio.luau (.startAmbient, .ensureUiPings,
-- .playSpatial), so no Sound instances are created on the server while
-- disabled.
--
-- Flip to true to re-enable (then re-record / replace the rbxasset://
-- placeholders in AmbientAudio.luau with real fighter assets).
local AMBIENT_AUDIO_ENABLED = false

local AmbientAudio = require(script.Parent:WaitForChild("AmbientAudio"))
AmbientAudio.ENABLED = AMBIENT_AUDIO_ENABLED

if not AMBIENT_AUDIO_ENABLED then
    print("[AmbientAudio] disabled (AMBIENT_AUDIO_ENABLED=false). Flip the flag in AmbientAudio.server.luau to re-enable.")
    return
end

AmbientAudio.startAmbient()
AmbientAudio.ensureUiPings()

print("[AmbientAudio] lobby ambient + UI pings ready")
