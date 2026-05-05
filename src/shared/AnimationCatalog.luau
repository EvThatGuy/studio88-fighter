--!strict
-- AnimationCatalog
--
-- Single source of truth for every combat / ability animation used by the
-- fighter. The client-side `AnimationPlayer.client.luau` reads this
-- catalog, instantiates `Animation` objects, and loads them onto each
-- character's `Humanoid.Animator` on demand. The server is authoritative
-- on combat state (Punch / Block / Dodge / abilities); animations play
-- on the client in reaction to server-fired RemoteEvents
-- (`CombatPhaseChanged`, `AbilityCast`).
--
-- ─────────────────────────────────────────────────────────────────────
-- Catalog format
-- ─────────────────────────────────────────────────────────────────────
-- `ASSETS[key]` = either:
--   * `""` (empty string) — no animation wired yet; AnimationPlayer
--     silently skips loading. This is the default for placeholder keys.
--   * `"rbxassetid://<n>"` — full URL form.
--   * `"<n>"` (a bare numeric string) — auto-prefixed with `rbxassetid://`
--     by `AnimationCatalog.assetIdFor(key)`.
--
-- `FLAGS[key]` (optional) = `{Looped=bool?, FadeIn=number?, FadeOut=number?}`.
-- Defaults: `Looped = false`, `FadeIn = 0.1`, `FadeOut = 0.1`. Any key
-- without a FLAGS entry uses the defaults.
--
-- ─────────────────────────────────────────────────────────────────────
-- Swapping in custom animation IDs
-- ─────────────────────────────────────────────────────────────────────
-- 1. Author the animation in Roblox Studio (View → Animation Editor) OR
--    import a recording from Moon Animator 2.
-- 2. Right-click the saved KeyframeSequence → **Save to Roblox**. This
--    uploads it and gives you an asset ID (visible in the Asset URL,
--    e.g. `1234567890`).
-- 3. Replace the corresponding `""` in `ASSETS` below:
--      `M1_1 = "1234567890",`  (or `"rbxassetid://1234567890"`).
-- 4. Save the file. `HotReload.server.luau` will pick the change up
--    on the next hot-reload trigger; no full server restart needed.
--
-- ─────────────────────────────────────────────────────────────────────
-- Rig requirement
-- ─────────────────────────────────────────────────────────────────────
-- All animations MUST be authored against an **R15** rig. R6 rigs use a
-- different motor format and the AnimationTrack will silently fail to
-- evaluate. Studio's New Baseplate template defaults to R15.
--
-- ─────────────────────────────────────────────────────────────────────
-- Where each key fires from (audit trail)
-- ─────────────────────────────────────────────────────────────────────
--   Combat (CombatService.setPhase → Remotes.CombatPhaseChanged):
--     "attacking" → cycles through M1_1 → M1_2 → M1_3 → M1_4 per attacker
--     "blocking"  → Block (looped while held)
--     "dodging"   → Dodge (one-shot, ~0.4s)
--     "stunned"   → Hitstun (one-shot, ~0.6s)
--     "idle"      → stops any active track
--
--   Abilities (AbilityRuntime → Remotes.AbilityCast):
--     slotIndex 1..4 → Ability_Slot1_Cast .. Ability_Slot4_Cast
--
--   Reserved (not fired by current code):
--     M2_Heavy   → no M2 RemoteEvent yet; reserved for the heavy attack
--                   when CombatService grows an M2 path.
--     Knockdown  → reserved; trigger when Humanoid.Health drops to 0.
--     Wakeup     → reserved; trigger on respawn (RespawnService).

local AnimationCatalog = {}

AnimationCatalog.ASSETS = {
    -- Light attack combo string. CombatService fires "attacking" once per
    -- M1; the AnimationPlayer cycles through M1_1 → M1_4 on rapid presses.
    -- Placeholder values are the Roblox-default R15 sword RightSlash
    -- (522635514) and Lunge (522638767) — public, free, stable since
    -- 2017. These are tool-tied animations but evaluate as arm-swing
    -- motions on a tool-less character, which reads convincingly as a
    -- punch. Cycling between two IDs gives the combo string visible
    -- variety even before custom animations are recorded.
    -- TODO(custom): record 4 distinct light-attack swings; jab → cross →
    -- hook → spin (or whatever the fighter style calls for).
    M1_1 = "rbxassetid://522635514",   -- placeholder: Sword RightSlash
    M1_2 = "rbxassetid://522638767",   -- placeholder: Sword Lunge (forward thrust)
    M1_3 = "rbxassetid://522635514",   -- placeholder: Sword RightSlash (repeat for cycling)
    M1_4 = "rbxassetid://522638767",   -- placeholder: Sword Lunge (repeat for cycling)

    -- Heavy attack. Combat code does not yet emit M2 RemoteEvents; the
    -- entry is reserved so the catalog stays stable when wired.
    -- TODO(combat): wire an M2 / RightMouseButton path through
    -- CombatInput.client.luau → CombatService → setPhase("attacking_heavy").
    M2_Heavy = "rbxassetid://522638767",  -- placeholder: Sword Lunge (committed forward thrust)

    -- Defensive states.
    -- TODO(custom): Block stance is held while F is down; should be a
    -- low-motion guard pose, looped. No good free Roblox-published
    -- equivalent exists — a looping idle would not read as "blocking".
    -- Leaving blank so AnimationPlayer skips it cleanly until you record
    -- a real guard pose in Studio Animation Editor.
    Block = "",
    -- TODO(custom): Dodge is a 0.4s sidestep / roll. No stable free
    -- equivalent. Recommended: record a quick CFrame-driven roll keyframe
    -- in Studio Animation Editor (~12 frames, Linear easing).
    Dodge = "",

    -- Reaction states.
    -- TODO(custom): Hitstun is a 0.6s flinch (head tilt + small recoil).
    -- TODO(custom): Knockdown / Wakeup not yet triggered by code (Phase 4
    --   — wire when RespawnService grows a death-staging path).
    Hitstun = "",
    Knockdown = "",
    Wakeup = "",

    -- Ability casts. Slot index = position in the class's ability list:
    --   Striker  Slot1 = striker_dash         (forward burst — Lunge fits)
    --   Bruiser  Slot1 = bruiser_ground_slam  (downward stomp — Lunge is OK as wind-up placeholder)
    --   Swift    Slot1 = swift_double_jump    (mid-air boost)
    -- Slot1 placeholder uses the Sword Lunge animation since it reads as
    -- a committed forward action — fits Striker dash best, OK for the
    -- others as a wind-up. Slot2..4 are not yet bound to any ability so
    -- they remain blank.
    -- TODO(custom): record one cast animation per ability (or share if
    -- the cast pose is the same — e.g. all "shoulder dip + arm throw").
    Ability_Slot1_Cast = "rbxassetid://522638767",  -- placeholder: Sword Lunge
    Ability_Slot2_Cast = "",
    Ability_Slot3_Cast = "",
    Ability_Slot4_Cast = "",

    -- Locomotion / idle (Roblox-default R15 animations from the public
    -- Animate script — these IDs are stable and shipped with every
    -- Roblox client install). Currently consumed only as fallbacks; the
    -- standard Animate script handles ambient locomotion. Listed here
    -- so future client-driven idle / movement overrides have a default.
    Idle = "rbxassetid://507766388",
    Walk = "rbxassetid://507777826",
    Run  = "rbxassetid://913376220",
    Jump = "rbxassetid://507765000",
    Fall = "rbxassetid://507767968",
}

AnimationCatalog.FLAGS = {
    Block   = {Looped = true,  FadeIn = 0.1,  FadeOut = 0.15},
    Dodge   = {Looped = false, FadeIn = 0.05, FadeOut = 0.1},
    Hitstun = {Looped = false, FadeIn = 0.05, FadeOut = 0.1},

    M1_1 = {Looped = false, FadeIn = 0.05, FadeOut = 0.08},
    M1_2 = {Looped = false, FadeIn = 0.05, FadeOut = 0.08},
    M1_3 = {Looped = false, FadeIn = 0.05, FadeOut = 0.08},
    M1_4 = {Looped = false, FadeIn = 0.05, FadeOut = 0.08},
    M2_Heavy = {Looped = false, FadeIn = 0.08, FadeOut = 0.12},

    Ability_Slot1_Cast = {Looped = false, FadeIn = 0.06, FadeOut = 0.1},
    Ability_Slot2_Cast = {Looped = false, FadeIn = 0.06, FadeOut = 0.1},
    Ability_Slot3_Cast = {Looped = false, FadeIn = 0.06, FadeOut = 0.1},
    Ability_Slot4_Cast = {Looped = false, FadeIn = 0.06, FadeOut = 0.1},

    Idle = {Looped = true, FadeIn = 0.2, FadeOut = 0.2},
    Walk = {Looped = true, FadeIn = 0.2, FadeOut = 0.2},
    Run  = {Looped = true, FadeIn = 0.2, FadeOut = 0.2},
}

-- Returns the rbxassetid URL for a key, or nil if not configured.
function AnimationCatalog.assetIdFor(key: string): string?
    local raw = AnimationCatalog.ASSETS[key]
    if raw == nil or raw == "" then return nil end
    if string.match(raw, "^rbxassetid://") then return raw end
    if tonumber(raw) ~= nil then return "rbxassetid://" .. raw end
    return raw
end

export type AnimationFlags = {
    Looped: boolean?,
    FadeIn: number?,
    FadeOut: number?,
}

function AnimationCatalog.flagsFor(key: string): AnimationFlags
    return AnimationCatalog.FLAGS[key] or {}
end

return AnimationCatalog
