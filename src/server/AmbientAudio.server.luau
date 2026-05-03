--!strict
-- Boots AmbientAudio.luau on server start. Implementation is in the
-- ModuleScript so other services can also require() and call
-- playSpatial() for collect/tier-up SFX. This file just kicks off the
-- one-shot setup at boot.

local AmbientAudio = require(script.Parent:WaitForChild("AmbientAudio"))

AmbientAudio.startAmbient()
AmbientAudio.ensureUiPings()

print("[AmbientAudio] lobby ambient + UI pings ready")
