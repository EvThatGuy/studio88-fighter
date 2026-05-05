# Manual TODO

Things that must be done by a human in Roblox Studio, Creator Hub, or
through external tooling — they cannot be done from this repo's source
files alone. Everything here is **blocking** for the marked phase or has
a real gameplay / business impact noted next to it.

Order is rough priority, top first.

---

## Test the current build

**Before doing any of the items below**, pull the latest `main`, run
`rojo serve`, and play in Studio:

1. File → New → Baseplate.
2. Plugins → Rojo → Connect (default `localhost:34872`).
3. File → Test → Local Server, **2 players** (or play solo and use the
   training dummies in the arena).
4. Validate the loop works:
   - press **C** → class picker opens, selecting a class persists.
   - **M1** punches; targets take damage; KO numbers replicate.
   - **F-hold** blocks; damage reduced to 15%.
   - **Q** dodges (consumes 25 stamina).
   - **1** fires the class's first ability (Striker dash, Bruiser ground
     slam, Swift double-jump) on cooldown.
   - Match cycles `LOBBY → STARTING SOON → MATCH ACTIVE → MATCH OVER`.
   - VICTORY/DEFEAT banner shows on results.
   - Wins/losses persist across rejoin.
5. Tell me anything that's broken or feels off.

---

## Animations (P1 — required for the game to feel like a fighter)

Roblox does NOT allow sharing animations between accounts, so the
elomala / dwmk reference projects ship none. The fighter currently
swings with **no visible animation**, which makes it hard to tell when a
punch is happening and ruins game-feel.

### What's needed (minimum MVP)

- 1 punch animation (left or right hand, ~0.3s)
- 1 block stance (held pose)
- 1 dodge animation (~0.4s, sideways body lean)
- 1 hit-react / stun animation (~0.6s)
- 3 ability animations (one each for Striker dash, Bruiser ground slam,
  Swift double-jump)

### How to get them (cheapest → most expensive)

1. **Roblox Toolbox free animations.** In Studio: View → Toolbox →
   Models → search "punch animation", "block animation", etc. Filter to
   "Group Creations" / Roblox-staff-published assets so the licensing is
   clear. Note the `rbxassetid://N` for each asset.
2. **Record yourself in Roblox Studio Animation Editor** (free, built-in:
   Plugins → Animation Editor). Lower quality but unlimited.
3. **Commission on the Roblox Marketplace or Fiverr** — typical $5–25 per
   animation for entry-level fighter animations.

### Wiring once you have the assetIds

Paste them into a new `Constants.ANIMATIONS` table (I'll add the empty
table when you're ready) and update `CombatService` to load + play them
on punch / block / dodge events. About 30 minutes of code work after the
assets exist.

---

## Sound IDs (P1 — combat feels flat without hit / block thuds)

The codebase already wires sound hooks; they just no-op when the IDs
are empty strings.

### What to fill

`src/shared/Constants.luau` → `Constants.SOUND_IDS`:

```lua
SOUND_IDS = {
    hit = "rbxassetid://...",        -- meaty punch impact
    block = "rbxassetid://...",      -- metallic clang or thud
    stun = "rbxassetid://...",       -- daze loop
    match_start = "rbxassetid://...",-- bell or buzzer
    match_end = "rbxassetid://...",  -- closing horn
    level_up = "rbxassetid://...",
    daily_bonus = "rbxassetid://...",
}
```

### How to get them

In Studio: View → Toolbox → Audio → search "punch", "fight bell", etc.
Click an asset, copy its `rbxassetid://N` from the right-hand inspector,
paste into the constants. ~5 minutes total once you're in Studio.

---

## Game Pass / Dev Product asset IDs (P4 — monetization)

Placeholders default to `0` which short-circuits all marketplace calls.
No monetization until you create the products in Creator Hub.

### What to create

In **Creator Hub → your experience → Monetization**:

**Game Passes** (one-time purchases):
- **Starter Pack** — 99 R$ — small XP / cosmetic kit (suggested copy:
  "100 free XP + amber name color")
- **VIP** — 199 R$ — cosmetic + name color (suggested: "permanent pink
  name + VIP chat tag")
- **Premium** — 499 R$ — early class access (suggested: "unlock all
  classes + premium-only auras")

**Dev Products** (consumable / repeatable):
- TBD — fighter doesn't have an obvious consumable economy yet (no coins).
  Defer until Phase 4 progression design.

### Wiring after creation

Paste the asset IDs into `src/shared/Constants.luau`:

```lua
Constants.GAME_PASSES = {
    STARTER_PACK = 12345678,
    VIP = 12345679,
    PREMIUM = 12345680,
}
```

Then I rebuild a fighter `GamePassService` (the legacy one in
`legacy/server/` reads tycoon-coupled income multipliers; needs a clean
port to fighter cosmetic / class-access perks). Tell me when the IDs
exist and I'll do the port.

---

## Source inventory of open-source bases (P0 — blocks Phase 2 onwards)

The project plan (`docs/project-plan.md` §3 + §4) calls for cloning the
reference repos to your local machine, opening the `.rbxl` in Studio,
and writing up `docs/source-inventory.md`. **I cannot do this from the
sandbox** — `git clone` to github.com works for ls-remote but the
sandbox blocks non-trivial fetches, and I can't run Studio.

### What to do

Outside this repo (e.g. in `~/refs/` on your Windows machine):

```powershell
mkdir refs
cd refs
git clone https://github.com/elomala/Fighting-game
git clone https://github.com/dwmk/RobloxGames
```

For each `.rbxl` file in the dwmk repo (`Broken.rbxl`,
`Bangla Battlegrounds.rbxl`):

1. Double-click to open in Studio.
2. Browse the Explorer pane: ServerScriptService, ReplicatedStorage,
   StarterPlayer, Workspace.
3. Note interesting scripts — names, ~LOC, what they do.
4. Check the repo's `LICENSE` file (or root README). If there's no
   license, we cannot use the code. Document that explicitly.
5. Write findings into `docs/source-inventory.md` in this repo. Suggested
   shape per row:

   ```
   - [path/in/.rbxl] — ~50 LOC — handles match countdown — license: MIT
   ```

Once that doc exists I can extract scripts into `src/imported/<source>/`
and start the Phase 2 match-flow port.

---

## License verification (P0 — legal blocker before any code import)

For each of the four reference sources, check and record license:

- `elomala/Fighting-game` — check repo root for LICENSE file
- `dwmk/RobloxGames` — same
- DevForum simple combat system thread — check post for explicit license
  grant (usually "open source" or "free to use")
- DevForum 2019 fighting game thread — same

If a source has **no explicit license**, it is **not** "open source" by
default — it's all-rights-reserved. We do not import from it. Document
the finding (so future-us doesn't re-check) and move on.

`IIIStatusIII/Roblox-Uncopylocked-Games` is already on the DO-NOT-USE
list per `CLAUDE.md` and `docs/project-plan.md`.

---

## Discord webhook URL (P4 — ops alerting)

The legacy `DiscordHook.luau` (in `legacy/server/`) publishes high-signal
events to a Discord channel. To bring it back for the fighter:

1. In your Discord server: channel settings → Integrations → Webhooks
   → New Webhook → Copy URL.
2. Tell me the URL (or paste into a file I can read). Note the URL is a
   secret-ish thing — anyone with it can post to your channel; it can't
   read or take destructive action.
3. I rewrite a fighter-flavored DiscordHook that publishes:
   - Match results (winner / scores / map)
   - Anti-cheat kicks
   - Server crashes (via `BindToClose`)

---

## Place / Universe configuration in Creator Hub (P0 once ready to ship)

Currently this is a Rojo-only project. To actually publish:

1. In Creator Hub, create an Experience (universe) with one Place inside.
2. Note the **Universe ID** and **Place ID**.
3. Set them in the Studio publish dialog OR run `rojo upload` against
   them after `rojo build`.
4. **DataStore writes only work in published places**, not in
   New-Baseplate placeholder sessions. Until publish, every restart
   wipes player progress in Studio. (The code degrades gracefully —
   `DataStore.luau` falls back to cache-only with a warn message.)

`publish.sh` is a placeholder; update it with your universe/place IDs
once you have them.

---

## Maps (P2 — replaces the placeholder arena)

The current `Arena/WorldBuilder.server.luau` builds a 200×200 box at
runtime. For real maps:

1. **Author maps in Studio**, parented under `ServerStorage.Maps.<name>`.
   Each map should be a `Model` with at least:
   - A `SpawnA` part (Vector3 spawn point or `SpawnLocation`)
   - A `SpawnB` part (or N spawn points for >2 player matches)
   - A `Boundary` part chain (kills players who fall off)
   - Walls / cover / props as desired
2. Save the place file. Push.
3. Tell me the map names; I'll wire `MapRotation.pickNext` to clone the
   chosen map into `Workspace` between rounds, rather than the runtime
   `WorldBuilder` script.

The existing `Arena/WorldBuilder.server.luau` should then move to
`legacy/` (it's only useful while there are no real maps).

---

## Combat balance (P4 — after ~10 hours of playtesting)

Numbers in `Constants.luau` are placeholder. After you've played a few
matches with friends, give me feedback on:

- Punch damage feel (currently 8 base / class-modified up to 11)
- Stamina costs — does running out feel rare / fair / oppressive?
- Block reduction (currently 85%)
- Stun duration (currently 0.6s)
- Match length (currently 3:00)
- Ability cooldowns (4s dash / 8s slam / 2s double-jump)

I'll make a "feedback batch" PR adjusting numbers when you have data.

---

## When in doubt

If you're not sure whether something is a manual or automatic task, ask.
Default assumption: anything requiring Studio Animation Editor, Creator
Hub, Discord/external services, real money, or licensing decisions is
manual. Anything that's purely Luau code in this repo is something I
can do.
