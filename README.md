# Studio 88 Fighter

Roblox arena fighting / combat game. Forked from `studio88-roblox` (a
working tycoon) on 2026-05-05; the tycoon code lives under `legacy/` for
reference / salvage. This repo is the source of truth — Rojo only mounts
`src/`.

See **[`docs/project-plan.md`](docs/project-plan.md)** for the full
roadmap, open-source-base evaluation strategy, technical risks, and
phased implementation plan.

## Status

**Phase 0 — foundation in progress.** Tycoon-specific gameplay (plots,
droppers, rebirths, pets, daily-shop, etc.) has been moved to `legacy/`
and will not load in Studio. The active tree contains:

- Server scaffolding for combat (`Combat/`), match flow (`Match/`), and
  abilities (`Abilities/`) — typed stubs ready to receive the elomala
  combat port and the dwmk match-flow patterns.
- A clean fighter `DataStore` schema (`fighter_v1`).
- Foundational utilities preserved from the tycoon: ambient audio, hot
  reload, perf budget probe, character rescue, leaderstats.

## Architecture

```
studio88-fighter/
├── CLAUDE.md                   rules Claude reads on every command
├── README.md                   this file
├── default.project.json        Rojo: src/server → ServerScriptService.Studio88,
│                               src/shared → ReplicatedStorage.Modules,
│                               src/client → StarterPlayerScripts.Studio88
├── docs/project-plan.md        forward-looking plan + open-source strategy
├── legacy/                     pre-pivot tycoon code, NOT mounted by Rojo
└── src/
    ├── shared/
    │   ├── Constants.luau      classes, stamina tuning, match flow, passes
    │   ├── Types.luau          PlayerData / MatchState / RemoteMap (fighter shape)
    │   └── Remotes.luau        lazy RemoteEvent / RemoteFunction registry
    ├── server/
    │   ├── DataStore.luau          pcall + retry; fighter_v1 schema
    │   ├── Bootstrap.server.luau   require all service modules at start
    │   ├── Leaderstats.luau        KOs / Wins / Level
    │   ├── Combat/
    │   │   ├── ClassRegistry.luau   applies class walkspeed on CharacterAdded
    │   │   ├── StaminaService.luau  per-player stamina ledger + regen
    │   │   ├── HitboxService.luau   server-side OverlapParams query
    │   │   └── CombatService.luau   punch / block / dodge state machine
    │   ├── Match/
    │   │   ├── MapRotation.luau     pickNext() between rounds
    │   │   └── MatchService.luau    lobby → countdown → active → results
    │   └── Abilities/
    │       └── AbilityRuntime.luau  stub; Phase 3 wires AbilitySpec
    └── client/
        └── NotificationToast.client.luau   generic toast renderer
```

## Setup

```bash
# Rojo (https://github.com/rojo-rbx/rojo/releases)
# drop rojo.exe somewhere on PATH

# Wally (https://wally.run) — already declared in wally.toml
wally install
```

## Run in Studio

```bash
rojo serve
```

Then in Roblox Studio: File → New → Baseplate, Plugins → Rojo → Connect.
Press Play. Server boots; `[Bootstrap] fighter server boot complete` logs.
Combat / match scaffolding is wired but matches won't actually play
without two clients in the place — Phase 1 is the first end-to-end test.

## Build a `.rbxl` for double-click playtest

```bash
rojo build -o studio88-fighter.rbxlx
```

## Hard rules (server-authoritative everything)

See [`CLAUDE.md`](CLAUDE.md) for the full list. Highlights:

- Combat is **server-authoritative**. Client emits intent; server validates
  stamina, runs hitbox query, applies damage.
- Every `DataStoreService` call is `pcall`-wrapped with retry-with-backoff.
- Every function parameter and return is type-annotated.
- DataStore is versioned (`PlayerData_fighter_v1`); migrations live in
  `DataStore.luau`.
- Per-RPC cooldowns clamp every client request via `Constants.RPC_COOLDOWNS`.

## What's NOT in Phase 0

- Animations (Roblox doesn't allow sharing; record / commission in Phase 1+).
- Game Pass / Dev Product asset IDs (placeholders default to 0; create in
  Creator Hub then patch `Constants.GAME_PASSES` / `Constants.DEV_PRODUCTS`).
- Real maps (Phase 2 — single placeholder entry until then).
- Abilities + transformations (Phase 3).
- Progression UI, shop UI, lobby UI (Phase 2 + 4).
