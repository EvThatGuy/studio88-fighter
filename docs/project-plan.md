# Studio 88 Fighter — Project Plan

> **Status:** Pivot in progress. This repository was forked from `studio88-roblox`
> (a working Roblox tycoon) on 2026-05-05. The tycoon code is being kept in
> place during Phase 0 as the source we audit, salvage useful foundations from,
> and then strip. The end goal of *this* repo is an arena fighting / combat
> game, not a tycoon.

---

## 1. What we are building

A Roblox arena fighting/combat game. Target features:

- Server-authoritative combat with hitbox detection
- Punch / block / stun core
- Multiple classes / fighter styles, each with distinct walkspeed and stamina
- Stamina or energy system
- Round-based PvP flow (lobby → countdown → match → results → return to lobby)
- Map rotation / randomizer
- Lobby + matchmaking
- Shop / menu UI
- NPCs where useful (training dummies, vendors, ambient)
- Powers, abilities, transformations (Rumble Fighter / Strongest Battlegrounds inspiration)
- Progression, balancing, polish
- Anti-exploit hardening
- Monetization (Game Passes + Dev Products) reusing the tycoon's plumbing

## 2. Repo state at pivot

This repo is **not blank**. It is a clone of `studio88-roblox` and contains a
playable tycoon (~80 source files). For planning purposes treat it as three
buckets:

### 2a. Reusable foundations (keep, refactor as needed)

- `default.project.json`, `wally.toml`, `wally.lock`, `Packages/` — Rojo + React baseline
- `publish.sh` — build pipeline
- `src/shared/Remotes.luau` — lazy `RemoteEvent` / `RemoteFunction` factory
- `src/shared/Types.luau` — typed shape patterns
- `src/shared/Constants.luau` — central config table pattern (will be rewritten for fighter)
- `src/server/DataStore.luau` — `pcall` + retry-with-backoff, versioned stores
- `src/server/Bootstrap.server.luau` — server entry sequencing
- `src/server/NotificationService.luau`, `NotificationToast.client.luau` — generic toast plumbing
- `src/server/Leaderstats.luau`, `StatsService.luau` — leaderstats pattern
- `src/server/GamePassService.luau`, `DevProductService.luau` — `MarketplaceService` wrappers w/ session caching
- `src/server/DiscordHook.luau` — outbound webhook for ops
- `src/server/HotReload.server.luau` — script hot-reload helper
- `src/server/CodesService.luau`, `ReferralService.luau` — promo plumbing (probably keep)
- `src/server/AchievementService.luau`, `XpService.luau` — generic enough to repurpose for combat progression

### 2b. Tycoon-specific gameplay (strip in Phase 0 audit)

`WorldBuilder`, `PlotAssigner`, `Dropper`, `Collector`, `UpgradeStation`,
`UpgradeButtonProxy`, `RebirthService`, `RebirthShopService`, `RebirthPadProxy`,
`PetService`, `PetStandService`, `DailyShopService`, `WeeklyTournament`,
`HourlyTributeService`, `PlotTeleportProxy`, `VisitService`, `VisitRandomProxy`,
`SquadBonusService`, `VaultRaidEvent`, `AfkAutoCollect`, `IdleReturnBonus`,
`SessionTimeBonus`, `CurrencyManager` (replace with combat-currency).

Most client widgets in `src/client/` (`HUD*`, `IncomeRateIndicator`,
`RebirthReadyNudge`, `TributeQuickClaim`, `EventBanner`, `BoostTimerHud`,
`CoinCollectFx`, `WeeklyTournamentWidget`, `DailyShopOverlay`, `QuestProgressPill`,
`PresenceBadge`, `WelcomeBanner`, `FootstepDust`) — strip or repurpose.

### 2c. Probably keep, audit later

`src/server/EventService.luau`, `ActivityFeedService.luau`,
`TutorialService.luau`, `TitleService.luau`, `AuraService.luau`,
`SpinService.luau`, `TradeService.luau`, `PerfBudgetProbe.server.luau`,
`StuckCharacterRescue.server.luau`, `AmbientAudio*`, `DailyLoginBonus.server.luau`
(daily-return retention works in any genre).

---

## 3. Open-Source Base Evaluation Strategy

Rather than building combat from scratch, we will evaluate four open-source
Roblox combat references. **None will be copied wholesale into this repo.**
We extract concepts and reviewed scripts only, port them into the Rojo tree
under clean adapters.

### 3a. Primary combat base — `elomala/Fighting-game`
- **URL:** https://github.com/elomala/Fighting-game
- **Why:** Closest match to our combat core. Real Roblox fighting game with
  multiple classes, server-sided hitboxes (`MuchachoHitbox` module), stamina
  tied to health, per-class walkspeed, started 2022, playable but incomplete.
- **Use as:** primary combat starting point.
- **Extract:** server-sided hitbox flow, class struct, stamina/health
  relationship, per-class movement, combat state machine.
- **Caveat:** **No animations included** — Roblox doesn't allow sharing them.
  We must record / commission our own.

### 3b. Game-loop scaffolding — `dwmk/RobloxGames` → `Broken.`
- **URL:** https://github.com/dwmk/RobloxGames
- **Why:** PvP arena with map randomizer, round timer, shop, menu, NPCs.
- **Use as:** lobby/round/shop/menu/NPC scaffolding reference.
- **Extract:** match state machine, round timer, map randomizer logic, shop
  UI structure, NPC patterns.

### 3c. Ability reference — `dwmk/RobloxGames` → `Bangla Battlegrounds`
- **Why:** Unfinished combat-and-abilities game inspired by Strongest
  Battlegrounds. Closer to our powers/transformations vision.
- **Use as:** **reference only** for ability structure ideas. Do not import
  scripts wholesale.

### 3d. Combat reference — DevForum simple combat system
- **URL:** https://devforum.roblox.com/t/open-source-simple-combat-system-with-blocking-and-stun/2484521
- **Use as:** small reference for punch/block/stun patterns. Validate our own
  combat flow against this; don't treat as a base.

### 3e. Lobby reference — DevForum 2019 open-sourced fighting game
- **URL:** https://devforum.roblox.com/t/open-sourced-fighting-game/292048
- **Use as:** older reference for lobby + round flow. Use only if `Broken.`
  doesn't cover something.

### 3f. DO NOT USE — `IIIStatusIII/Roblox-Uncopylocked-Games`
- **Reason:** Hundreds of popular games scraped from YouTube/Discord. Most
  appear copied or unlicensed. Real legal + Roblox enforcement risk.
- **Rule:** Do not import, copy, or reference this repo anywhere in this
  project — including in commit messages, comments, or docs.

---

## 4. .rbxl → Rojo Extraction Workflow

The source projects ship as `.rbxl` files, not Rojo-native trees. The
extraction process for any source repo is:

1. **Clone or download outside this repo.** Use `~/refs/<repo-name>/` or
   similar — never inside `studio88-fighter/`.
2. **Open the `.rbxl` in Roblox Studio.** Read-only mind-set.
3. **Inspect:** scripts, modules, remotes, services, UI, folder structure.
4. **Inventory** useful systems in a working notes file (do not commit it
   into the repo until reviewed).
5. **Confirm license** for the source repo. If unclear, do not extract.
6. **Extract individual scripts manually** — copy text into a scratch file,
   read it carefully, rewrite as needed.
7. **Convert to our Rojo structure.** Rename to our conventions
   (`*.server.luau`, `*.client.luau`, plain `*.luau` for shared modules).
8. **Land imported code in `src/imported/<source>/`** for the first PR so
   provenance is obvious in `git log`. Move into the canonical `src/server`,
   `src/client`, `src/shared` tree only after a wrapper/adapter is built.
9. **Build adapters/wrappers** so imported logic is called through *our*
   interfaces, not threaded through the codebase.
10. **Never import** raw assets, animations, UI, audio, maps from these
    sources. Strip Roblox `rbxassetid://` references and replace with our
    own asset IDs (or empty placeholders).

---

## 5. Phased roadmap

Original Phase 0/1 estimate from the playbook was ~4–5 weeks combined.
Open-source extraction can compress that to ~1 week each in the best case,
*if* extraction is clean. Budget pessimistically until we've actually
inventoried the sources.

### Phase 0 — Foundation audit & extraction setup (1 week)

- [ ] Audit `src/` against the keep / strip / audit-later buckets in §2.
  Open one PR per bucket so the diff is reviewable.
- [ ] Strip §2b tycoon-only files. Move client widgets that are clearly
  tycoon-only to `legacy/` (deletable) so a partial revert is possible.
- [ ] Rewrite `CLAUDE.md` rules section: replace tycoon patterns with
  fighter patterns (combat, rounds, classes, stamina, hitboxes).
- [ ] Rewrite `README.md` for the fighter project; archive the tycoon
  README under `docs/legacy-tycoon-readme.md`.
- [ ] Clone reference repos to `~/refs/`. Open each `.rbxl` in Studio.
- [ ] Produce `docs/source-inventory.md` listing useful scripts/modules
  per source repo with one-line descriptions and license check status.

### Phase 1 — Combat core from `elomala/Fighting-game` (1 week)

- [ ] Extract server hitbox module (likely `MuchachoHitbox` derivative)
  into `src/imported/elomala/`. Read every line.
- [ ] Build `src/shared/CombatTypes.luau` — `FighterClass`, `HitboxSpec`,
  `DamageEvent`, `StaminaState` types.
- [ ] Build `src/server/Combat/` adapters: `HitboxService`, `StaminaService`,
  `CombatStateMachine`, `ClassRegistry`.
- [ ] Wire one playable class end-to-end (punch + block + stun, no abilities)
  with server validation.
- [ ] Smoke-test replication: 2 clients, server-authoritative damage.
- [ ] Add anti-exploit guards: rate-limit hit RPCs, validate hitbox origin
  against character CFrame, never trust client-reported damage.

### Phase 2 — Match flow from `Broken.` (1 week)

- [ ] Extract lobby/round/map-rotation patterns into `src/imported/dwmk-broken/`.
- [ ] Build `src/server/Match/` services: `LobbyService`, `RoundService`,
  `MapRotation`, `MatchStateMachine`.
- [ ] Build `src/client/Match/` widgets: lobby UI, countdown, scoreboard,
  results screen.
- [ ] Add `src/server/Maps/` registry; ship 1 placeholder arena map.
- [ ] Wire end-to-end: lobby → countdown → match → results → lobby.

### Phase 3 — Custom powers & transformations (2 weeks)

- [ ] Reference Bangla Battlegrounds for ability *structure* only. Design
  our own ability spec.
- [ ] Build `src/shared/AbilitySpec.luau` — typed ability definition format.
- [ ] Build `src/server/Abilities/` runtime: cast, cooldown, charge, combo.
- [ ] Build transformation system (timed buff with VFX hooks, separate from
  base class).
- [ ] Ship 3 abilities + 1 transformation per class as MVP.

### Phase 4 — Progression, polish, monetization, hardening (2–3 weeks)

- [ ] Reuse `XpService`, `AchievementService` for combat progression.
- [ ] Reuse `GamePassService`, `DevProductService` for monetization.
  Define 3 passes (Starter / VIP / Premium) and 2–3 dev products.
- [ ] Reuse `DailyLoginBonus` for retention.
- [ ] Balancing pass: per-class damage, stamina costs, ability cooldowns.
- [ ] Anti-exploit pass: audit every RemoteEvent for server-side validation,
  add rate-limits, add server-side speed clamp, validate teleports.
- [ ] Polish: hit FX, sound, screen shake, stun VFX.
- [ ] Analytics: extend `DiscordHook` for ops alerts; add basic match
  telemetry to a DataStore.

---

## 6. Technical risks

| Risk | Severity | Mitigation |
|---|---|---|
| **License unverified.** Source repos may not have permissive licenses despite being public. | High | Confirm license before extracting any code. Do not import if unclear. Document license per source in `docs/source-inventory.md`. |
| **Animation gap.** elomala/Fighting-game ships no animations. | High | Budget time to record / commission. Ship MVP with placeholder animations from Roblox toolbox (free, licensed) and replace later. |
| **Asset/audio/UI restrictions.** Source `rbxassetid://` references may point to creators' private assets. | High | Strip all `rbxassetid://` from extracted scripts. Use only Roblox's free library or our own uploads. |
| **Code quality inconsistency.** Source projects are unfinished. Patterns will conflict with our hard rules (typed Luau, server-authoritative, pcall'd DataStore). | Medium | Treat extraction as porting, not copy-paste. Rewrite to our conventions. Reject anything that wires client-side currency/state. |
| **Security / exploit surface.** Imported RemoteEvents may be naive — trusting client damage, position, hit targets. | High | Phase 1 includes mandatory anti-exploit pass per imported RemoteEvent. Default deny. |
| **Rewrite needed after prototyping.** Imported combat may not feel right; we may ship MVP and rewrite combat in Phase 4. | Medium | Build adapters from day 1 so combat internals can be swapped without touching match flow / UI. |
| **Integration complexity** between elomala (combat) and dwmk-broken (match flow) — different conventions, naming, services. | Medium | Adapter layer + shared `CombatTypes.luau` is the seam. Imported code talks to our types, not each other. |
| **Repo gets messy** — clean blank repo turns into a copy-paste graveyard. | High | Keep `src/imported/` as a quarantine. Code only graduates to `src/server` / `src/client` after a wrapper exists and the original is deleted. |
| **Tycoon legacy clutter.** Stripped tycoon code half-deleted, half-referenced. | Medium | Phase 0 is one focused PR. Either delete or move to `legacy/` — don't leave dead code in active paths. |

---

## 7. Implementation checklist (run before importing anything)

- [ ] Clone reference repos to `~/refs/` — **outside** this repo.
- [ ] Open each `.rbxl` in Roblox Studio. Browse, do not edit.
- [ ] Inventory useful scripts/modules in `docs/source-inventory.md`.
  Include path, ~LOC, license status, intended use.
- [ ] Confirm license for each source repo. Do not import without one.
- [ ] Land Phase 0 first: clean foundation, tycoon stripped, rules updated.
- [ ] Extract scripts into `src/imported/<source>/` only after individual
  read-through.
- [ ] Build wrapper / adapter in `src/server/` or `src/shared/` that
  consumes imported code via our typed interfaces.
- [ ] Keep custom powers/transformations system in `src/server/Abilities/`
  separate from imported combat code.
- [ ] Write a server-authority replication test for combat in Phase 1
  before Phase 2 starts.
- [ ] Strip every `rbxassetid://` from imported code. Replace with our IDs
  or empty strings.
- [ ] Reject imports of any audio, UI, animation, map, mesh, or texture
  asset from the source repos. Roblox-toolbox-free or our own uploads only.

---

## 8. What these references give us — and what they don't

**They give us:**
- Hitbox detection patterns
- Server-sided combat examples
- Round / match flow scaffolding
- Basic state management
- A working baseplate to iterate from
- Shop / menu / NPC reference patterns
- Ability structure inspiration

**They do not give us:**
- Final combat feel
- Animations
- Rumble Fighter–style powers and transformations
- Long-term architecture decisions
- Our progression system
- Balancing
- Polish
- Monetization wiring (we already have plumbing from the tycoon)
- Anti-exploit hardening
- Code quality standards
- Clean Rojo architecture
- Final game identity

---

## 9. Open questions for the next pass

- Confirm license status for each source repo before Phase 0 ends.
- Decide tycoon-strip strategy: hard delete vs `legacy/` archive folder.
- Decide whether `WorldBuilder` pattern (runtime scene generation) survives,
  or if the fighter uses authored maps in Studio.
- Decide whether to keep `src/client/HUD.client.luau` as-is and re-skin, or
  rewrite from scratch.
- Decide animation pipeline: in-house recording vs commission vs toolbox-only
  for MVP.
