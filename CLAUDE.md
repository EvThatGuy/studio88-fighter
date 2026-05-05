# Roblox Studio Project — Claude Code Rules

> **Project pivot (2026-05-05).** This repo was forked from `studio88-roblox`
> (a working tycoon) and is being repurposed into an arena fighting / combat
> game. Tycoon-era code lives under `legacy/` for reference / salvage during
> Phase 0 — it is **not** mounted into Rojo. Read `docs/project-plan.md` for
> the open-source-base evaluation strategy and the phased roadmap.

You are building a Roblox arena fighting / combat game inside this project.
Target session: 5–15 minute matches in a round-based PvP loop, with class
selection, stamina-driven combat, and per-match progression. Long-term
retention via daily login + cosmetic unlocks + monetization (Game Passes +
Dev Products) reusing patterns from the tycoon.

## Language

This project uses **Luau** — not Lua, not JavaScript, not TypeScript.
Always write strict Luau with type annotations.

## Architecture

- Server scripts: `src/server/` (mounted at `ServerScriptService.Studio88`)
- Client scripts: `src/client/` (mounted at `StarterPlayerScripts.Studio88`)
- Shared modules: `src/shared/` (mounted at `ReplicatedStorage.Modules`)
- Use `RemoteEvents` for ALL client-server communication
- Use `RemoteFunctions` only when the client needs a synchronous reply
- Use `DataStoreService` for ALL persistent data, never client-side

Server scaffolding (Phase 0):

- `src/server/Combat/` — `ClassRegistry`, `StaminaService`, `HitboxService`, `CombatService`
- `src/server/Match/` — `MapRotation`, `MatchService`
- `src/server/Abilities/` — `AbilityRuntime` (Phase 3)
- `src/server/DataStore.luau`, `Leaderstats.luau`, `Bootstrap.server.luau` — foundation

## Roblox Services

Always use the `game:GetService()` pattern at the top of every script:

```lua
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
```

## Hard rules (unchanged from tycoon era — these are foundation rules)

- **Server-side validation on every combat / inventory transaction.** Never
  trust the client. Hit RPCs are rate-limited; hitbox queries run from the
  server's view of the attacker's CFrame, not client-reported positions.
- Use `pcall()` on every `DataStoreService` call. Retry with backoff on
  failure.
- Use `task.spawn()` and `task.wait()`, never `coroutine.wrap()` or `wait()`.
- Type-annotate every function parameter and return. Use
  `local function foo(player: Player): boolean`.
- DataStores are versioned: when changing PlayerData, bump the store name
  (`PlayerData_fighter_v1` → `_v2`) and write a migration in DataStore.luau.
- Game Passes are checked via `MarketplaceService:UserOwnsGamePassAsync` —
  cache the result per session.
- Never block the main thread for more than 1 frame. Yield with `task.wait()`.

## Fighter-specific patterns to default to

- **Server-authoritative combat.** Client emits intent (`PunchRequest`,
  `BlockRequest`, etc.); server runs hitbox queries, stamina checks,
  damage application. Client is purely a renderer for server state.
- **Stamina ledger.** `Constants.STAMINA_*` defines costs and regen rates;
  `StaminaService.tryConsume(player, amount)` is the gate every action
  passes through.
- **Class registry.** `Constants.CLASSES` is the source of truth for
  walkspeed, stamina cap, base punch damage. `ClassRegistry.applyToCharacter`
  applies stats on `CharacterAdded`.
- **Hitbox queries.** Use OverlapParams against a box in front of the
  attacker's HRP. Filter out the attacker. Only damage characters with a
  Humanoid and Health > 0. Phase 1 ports the elomala MuchachoHitbox flow
  through `HitboxService` as the canonical implementation.
- **Match state machine.** `MatchService` cycles
  `lobby → countdown → active → results`. Constants own the durations.
  The phase is broadcast to every client via `MatchStateChanged`.
- **Anti-exploit.** `Constants.RPC_COOLDOWNS` clamps every action RPC.
  `Constants.MAX_MOVE_PER_SEC` clamps any client-reported position delta.
- **Daily login** retains the tycoon's mechanic: track `os.time()` of last
  login, compare day-of-year, give escalating XP reward by streak. This is
  the highest-impact retention feature and is genre-agnostic.
- **Game Passes**: 3 tiers — Starter Pack / VIP / Premium — but rewards are
  cosmetic + class-access flavoured for the fighter, not income multipliers.

## File naming

- Server scripts: `*.server.luau`
- Client scripts: `*.client.luau`
- Shared modules: `*.luau` (no suffix)

## Source provenance & licensing rules

- The open-source bases listed in `docs/project-plan.md` are
  **references / accelerators**, not direct imports.
- **Never copy** raw assets, animations, UI, audio, maps, or `rbxassetid://`
  references from those sources into this repo.
- Any extracted scripts land first in `src/imported/<source>/` so the diff
  is reviewable. They graduate to `src/server` / `src/client` only after a
  wrapper / adapter exists and the source is read line-by-line.
- **DO NOT USE** `IIIStatusIII/Roblox-Uncopylocked-Games` — license risk.

## When in doubt

Prefer correctness over cleverness. Prefer server-side over client-side.
Prefer typed code over untyped. Prefer one good system shipped over five
half-built systems.

## MCP

The `boshyxd/robloxstudio-mcp` server is wired up. You have 54 tools to
manipulate the live Studio session: create instances, set properties, write
scripts, read output logs, run playtests. Use them. Don't ask the human to
drag things in Studio when you can do it yourself.
