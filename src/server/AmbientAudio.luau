--!strict
-- Lobby ambient audio + UI feedback sounds, exposed as a ModuleScript so
-- other server scripts can `require()` and call AmbientAudio.playSpatial.
-- All asset references use rbxasset:// paths shipped with every Roblox
-- client install — zero external dependencies, asset IDs cannot rot.
--
-- Bootstrap pattern: AmbientAudio.server.luau requires this module and
-- calls .startAmbient() + .ensureUiPings() once at server boot. Other
-- services (Collector, UpgradeStation, etc.) require this module to call
-- .playSpatial(soundKey, part, volume?).

local SoundService = game:GetService("SoundService")

local SOUND_PATHS = {
    ambient    = "rbxasset://sounds/uuhhh.mp3",                      -- ambient hum (Roblox built-in)
    coin       = "rbxasset://sounds/electronicpingshort.wav",        -- coin pickup
    tier_up    = "rbxasset://sounds/action_get_up.mp3",              -- tier-up celebrate
    purchase   = "rbxasset://sounds/electronicpingshort.wav",        -- successful purchase (bell.mp3 not shipped)
    fail       = "rbxasset://sounds/clickfast.mp3",                  -- rejection
    rebirth    = "rbxasset://sounds/action_jump.mp3",                -- prestige fanfare
}

-- Lobby ambient music rotation. We cycle through these every 90s so the
-- soundscape doesn't feel like a stuck loop. All paths are rbxasset://
-- verified loadable in V62 smoke (electronic, action, get_up confirmed
-- IsLoaded=true).
local AMBIENT_ROTATION = {
    "rbxasset://sounds/uuhhh.mp3",                -- "ambient hum" — primary
    "rbxasset://sounds/electronicpingshort.wav",  -- subtle electronic ticks
    "rbxasset://sounds/action_get_up.mp3",        -- low motion vibe
}

local AmbientAudio = {}

-- Set by AmbientAudio.server.luau at boot from its AMBIENT_AUDIO_ENABLED
-- flag. When false, every public function below is a no-op so no Sound
-- instances ever get created on the server (defensive — there are no
-- callers in the fighter tree today, but a future module that requires
-- this without going through the boot script would still respect the
-- gate).
AmbientAudio.ENABLED = true

local function makeSound(name: string, soundPath: string, volume: number, looped: boolean): Sound
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = soundPath
    s.Volume = volume
    s.Looped = looped
    s.PlayOnRemove = false
    return s
end

function AmbientAudio.startAmbient()
    if not AmbientAudio.ENABLED then return end
    local existing = SoundService:FindFirstChild("LobbyAmbient")
    if existing then existing:Destroy() end
    local s = makeSound("LobbyAmbient", AMBIENT_ROTATION[1], 0.15, true)
    s.Parent = SoundService
    s:Play()

    -- Rotate the SoundId every 90s. The Sound stays the same instance so
    -- existing references keep working — we just swap SoundId + restart.
    task.spawn(function()
        local idx = 1
        while s.Parent do
            task.wait(90)
            if not s.Parent then break end
            idx = (idx % #AMBIENT_ROTATION) + 1
            s.SoundId = AMBIENT_ROTATION[idx]
            s.TimePosition = 0
            s:Play()
        end
    end)
end

function AmbientAudio.ensureUiPings()
    if not AmbientAudio.ENABLED then return end
    local container = SoundService:FindFirstChild("Studio88UIPings")
    if container then container:Destroy() end
    container = Instance.new("Folder")
    container.Name = "Studio88UIPings"
    container.Parent = SoundService

    for key, soundPath in pairs(SOUND_PATHS) do
        if key ~= "ambient" then
            local volume = (key == "rebirth") and 0.5 or 0.3
            makeSound(key, soundPath, volume, false).Parent = container
        end
    end
end

-- Spatial one-shot: parent a Sound to the given part, play, GC after Play
-- completes. Volume default 0.4. Optional pitch (PlaybackSpeed) default 1.0.
-- Silent no-op if soundKey unknown.
function AmbientAudio.playSpatial(soundKey: string, attachTo: BasePart, volume: number?, pitch: number?)
    if not AmbientAudio.ENABLED then return end
    local soundPath = SOUND_PATHS[soundKey]
    if not soundPath or not attachTo then return end
    local s = Instance.new("Sound")
    s.SoundId = soundPath
    s.Volume = volume or 0.4
    s.PlaybackSpeed = pitch or 1.0
    s.PlayOnRemove = true
    s.Parent = attachTo
    s.Played:Once(function()
        task.delay(2, function() if s.Parent then s:Destroy() end end)
    end)
    s:Play()
end

return AmbientAudio
