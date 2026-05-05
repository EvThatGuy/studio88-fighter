--!strict
-- Typed ability definition. Each ability has a stable id, display name,
-- stamina cost, cooldown, and a server-side `effect` function. The
-- effect runs with the casting player as the only argument and is
-- expected to do its own damage / movement / VFX-replication.
--
-- Phase 3 expands this with charge windows, combo input, area indicator
-- previews. For now this shape is the minimum to wire one ability per
-- class end-to-end.

export type AbilitySpec = {
    id: string,
    displayName: string,
    classId: string,           -- references Constants.CLASSES key
    staminaCost: number,
    cooldownSec: number,
    blurb: string,
    -- The actual gameplay effect, invoked server-side. Returning false
    -- aborts the cast (charges + cooldown not applied) — useful for
    -- target-required abilities that can't find anything to hit.
    effect: (player: Player) -> boolean,
}

export type AbilityCardForClient = {
    id: string,
    displayName: string,
    classId: string,
    staminaCost: number,
    cooldownSec: number,
    blurb: string,
}

return {}
