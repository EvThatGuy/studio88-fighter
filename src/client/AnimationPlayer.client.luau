--!strict
-- Client-side animation player. Subscribes to server-broadcast combat
-- events (CombatPhaseChanged, AbilityCast) and plays the corresponding
-- AnimationTrack from AnimationCatalog on the affected character.
--
-- Server authority: this script ONLY plays animations in reaction to
-- server-fired RemoteEvents. It never emits combat intent on its own;
-- CombatInput.client.luau owns the input → server requests path. If the
-- catalog has no asset wired for a key (assetIdFor → nil), the play
-- request is silently skipped, so an unconfigured catalog degrades to
-- "no animation" without breaking gameplay.
--
-- AnimationTracks are cached per (character × catalogKey) so we avoid
-- reloading the same Animation every press. The cache is GC'd when the
-- character leaves the workspace (CharacterRemoving / Destroy).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationCatalog = require(Modules:WaitForChild("AnimationCatalog"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local remotes = Remotes.waitFor()

-- per-character AnimationTrack cache: characterModel → {[key]: AnimationTrack}
local trackCache: {[Model]: {[string]: AnimationTrack}} = {}
-- currently-playing track per character (for Stop on transition)
local activeTrack: {[Model]: AnimationTrack?} = {}
-- per-attacker M1 combo step + last-fire timestamp (for cycling M1_1..4)
type M1State = { step: number, lastAt: number }
local m1State: {[number]: M1State} = {}

local M1_RESET_AFTER = 2.0   -- seconds without an attack → combo reset to step 1

local function cleanupCharacter(character: Model)
    trackCache[character] = nil
    activeTrack[character] = nil
end

local function bindCharacter(character: Model)
    character.AncestryChanged:Connect(function(_, parent)
        if not parent then cleanupCharacter(character) end
    end)
    character.Destroying:Connect(function() cleanupCharacter(character) end)
end

local function getAnimator(character: Model): Animator?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then return animator end
    -- Animator instance is created by Roblox at character load; allow a
    -- brief wait in case we're called mid-spawn.
    return humanoid:WaitForChild("Animator", 5) :: Animator?
end

local function loadTrack(character: Model, key: string): AnimationTrack?
    local assetUrl = AnimationCatalog.assetIdFor(key)
    if not assetUrl then return nil end
    local cache = trackCache[character]
    if not cache then
        cache = {}
        trackCache[character] = cache
        bindCharacter(character)
    end
    local existing = cache[key]
    if existing then return existing end
    local animator = getAnimator(character)
    if not animator then return nil end

    local anim = Instance.new("Animation")
    anim.Name = "Studio88_" .. key
    anim.AnimationId = assetUrl
    local ok, trackOrErr = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok then
        warn(string.format("[AnimationPlayer] failed to load %s (%s): %s", key, assetUrl, tostring(trackOrErr)))
        return nil
    end
    local track = trackOrErr :: AnimationTrack
    local flags = AnimationCatalog.flagsFor(key)
    if flags.Looped ~= nil then
        track.Looped = flags.Looped
    end
    cache[key] = track
    return track
end

local function stopActive(character: Model, fadeOut: number?)
    local track = activeTrack[character]
    activeTrack[character] = nil
    if track and track.IsPlaying then
        local ok, err = pcall(function() track:Stop(fadeOut or 0.1) end)
        if not ok then
            warn(string.format("[AnimationPlayer] stop failed: %s", tostring(err)))
        end
    end
end

local function playOn(character: Model, key: string)
    local track = loadTrack(character, key)
    if not track then return end
    local flags = AnimationCatalog.flagsFor(key)
    -- Stop the prior active track with this track's fade-out so the
    -- transition feels continuous.
    stopActive(character, flags.FadeOut)
    track:Play(flags.FadeIn or 0.1)
    activeTrack[character] = track
    if flags.Looped ~= true then
        -- Clear the active reference once a one-shot finishes naturally,
        -- so an idle-phase event doesn't try to Stop a finished track.
        local conn: RBXScriptConnection? = nil
        conn = track.Stopped:Connect(function()
            if conn then conn:Disconnect() end
            if activeTrack[character] == track then
                activeTrack[character] = nil
            end
        end)
    end
end

local function characterFor(userId: number): Model?
    local player = Players:GetPlayerByUserId(userId)
    if not player then return nil end
    return player.Character
end

local function nextM1Key(userId: number): string
    local now = os.clock()
    local s = m1State[userId]
    if (not s) or (now - s.lastAt > M1_RESET_AFTER) then
        s = { step = 1, lastAt = now }
    else
        s.step = (s.step % 4) + 1
        s.lastAt = now
    end
    m1State[userId] = s
    return "M1_" .. tostring(s.step)
end

-- ── CombatPhaseChanged ────────────────────────────────────────────────
remotes.CombatPhaseChanged.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    local userId = tonumber(payload.userId)
    local newPhase = tostring(payload.phase)
    if not userId then return end
    local character = characterFor(userId)
    if not character then return end

    if newPhase == "attacking" then
        playOn(character, nextM1Key(userId))
    elseif newPhase == "blocking" then
        playOn(character, "Block")
    elseif newPhase == "dodging" then
        playOn(character, "Dodge")
    elseif newPhase == "stunned" then
        playOn(character, "Hitstun")
    elseif newPhase == "idle" then
        stopActive(character)
    end
end)

-- ── AbilityCast ───────────────────────────────────────────────────────
remotes.AbilityCast.OnClientEvent:Connect(function(payload: any)
    if typeof(payload) ~= "table" then return end
    local userId = tonumber(payload.casterUserId)
    if not userId then return end
    local character = characterFor(userId)
    if not character then return end
    local slotIndex = tonumber(payload.slotIndex) or 1
    if slotIndex < 1 or slotIndex > 4 then slotIndex = 1 end
    playOn(character, "Ability_Slot" .. tostring(slotIndex) .. "_Cast")
end)

-- ── Cleanup ───────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    m1State[player.UserId] = nil
end)
