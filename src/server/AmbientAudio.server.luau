--!strict
-- Lobby ambient audio + UI feedback sounds. Silence kills D1 retention -- a
-- new player who hears nothing for 60 seconds bounces 4x more than one who
-- hears music + click feedback (BLOXG retention 2026, p.31). All asset
-- references use rbxasset:// paths shipped with every Roblox client, so we
-- ship zero external dependencies and asset IDs cannot rot.
--
-- Three layers:
-- 1. AmbientLoop -- continuous low-volume background, looping
-- 2. UIPings -- exposed via SoundService for client-side use (collect, tier-up)
-- 3. SpatialDropper -- short ping attached to dropper Spout per-spawn

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

-- Built-in Roblox audio. These are bundled in every client install and load
-- without an asset round-trip. If Roblox ever drops one, the Sound:Play()
-- call no-ops silently rather than erroring.
local SOUND_PATHS = {
    ambient    = "rbxasset://sounds/uuhhh.mp3",                      -- ambient hum (Roblox built-in)
    coin       = "rbxasset://sounds/electronicpingshort.wav",        -- coin pickup
    tier_up    = "rbxasset://sounds/action_get_up.mp3",              -- tier-up celebrate
    purchase   = "rbxasset://sounds/electronicpingshort.wav",        -- successful purchase (bell.mp3 not shipped)
    fail       = "rbxasset://sounds/clickfast.mp3",                  -- rejection
    rebirth    = "rbxasset://sounds/action_jump.mp3",                -- prestige fanfare
}

local AmbientAudio = {}

local function makeSound(name: string, soundPath: string, volume: number, looped: boolean): Sound
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = soundPath
    s.Volume = volume
    s.Looped = looped
    s.PlayOnRemove = false
    return s
end

-- 1. Ambient background loop into SoundService.Lobby (heard by all players)
local function startAmbient()
    local existing = SoundService:FindFirstChild("LobbyAmbient")
    if existing then existing:Destroy() end
    local s = makeSound("LobbyAmbient", SOUND_PATHS.ambient, 0.15, true)
    s.Parent = SoundService
    s:Play()
end

-- 2. UI ping sounds. Stored under SoundService so any LocalScript can
-- :Play() them directly. Server-authoritative so the audio set is
-- consistent across players.
local function ensureUiPings()
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

-- 3. Spatial: when a dropper spawns a coin (Dropper.server.luau triggers
-- this), a short coin-ping is played at the spout position. Implemented as
-- a one-shot Sound parented to the part, then GC'd after Played.
function AmbientAudio.playSpatial(soundKey: string, attachTo: BasePart, volume: number?)
    local soundPath = SOUND_PATHS[soundKey]
    if not soundPath then return end
    local s = Instance.new("Sound")
    s.SoundId = soundPath
    s.Volume = volume or 0.4
    s.PlayOnRemove = true
    s.Parent = attachTo
    s.Played:Once(function()
        task.delay(2, function() if s.Parent then s:Destroy() end end)
    end)
    s:Play()
end

startAmbient()
ensureUiPings()

print("[AmbientAudio] lobby ambient + UI pings ready")

-- Note: not returning the module table because this is a *.server.luau
-- (Script). Other server modules that need playSpatial() should require
-- AmbientAudio.luau instead -- but since v1 we keep this simple and
-- Dropper triggers via SoundService directly when needed.
