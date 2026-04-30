# Roblox tycoon project

Studio-side codebase for Studio 88's Roblox track. The world is generated at
runtime by `WorldBuilder.server.luau` so the codebase is the source of truth;
the place file is just a deployment target.

## What ships out of the box (playable v1)

On first server start, `WorldBuilder` constructs:

- 400×400 stud baseplate, dark concrete with neon-pink seam grid
- Center spawn pad (neon pink, 20×20)
- Floating "STUDIO 88 TYCOON v1" billboard above spawn
- 6 plot anchors arranged on a 110-stud-radius ring around spawn (4 active + 2 reserved for growth)
- Leaderboard sign tower north of spawn (top-10 lifetime coins)
- Lighting tuned to Vice-City dusk (ClockTime 19.5, magenta fog)

When a player joins, `PlotAssigner` clones a plot template into a free
anchor. Each plot has:

- **Cyan dropper** (visible, neon) — emits coins every second at the
  player's current upgrade tier
- **Conveyor belt** (Vector3Value-driven SurfaceVelocity) — coins ride from
  dropper to collector
- **Pink collector** (neon, semi-transparent) — coins touch this, owner's
  balance gets credited, coin despawns
- **Amber upgrade button** with ProximityPrompt — hold E to buy next tier
- Floating "TIER N $cost" label updates after each purchase

Server-authoritative throughout. Coin spawn rate scales with tier (1/2/5/12/30/80
per tick) so the visual flow matches the actual income.

## One-time setup

```bash
# 1. Wire the MCP server (optional, for live Studio control)
claude mcp add robloxstudio -- npx -y robloxstudio-mcp@latest

# 2. Install Rojo (the Roblox project sync tool)
#    Either via Foreman (recommended): https://github.com/Roblox/foreman
#    Or download a release: https://github.com/rojo-rbx/rojo/releases
#    Drop rojo.exe somewhere on PATH.

# 3. Install the Rojo Studio plugin (one-time):
#    Plugins > Manage Plugins > Find "Rojo" > Install
```

## Open and play (90 seconds)

```bash
cd ~/Documents/game-studio/roblox
rojo serve
```

Then in Roblox Studio:

1. **File → New → Baseplate** (fresh empty place)
2. **Plugins → Rojo → Connect** (default `localhost:34872`)
3. **Sync** — the toolbar shows green; all `src/server/*.server.luau` files
   appear under `ServerScriptService/Studio88`, `src/shared/*.luau` under
   `ReplicatedStorage/Modules`, `src/client/HUD.client.luau` under
   `StarterPlayerScripts/Studio88`
4. **Press Play** (top toolbar). On the first frame:
   - WorldBuilder logs `[WorldBuilder] constructing scene v1...`
   - PlotAssigner logs `[PlotAssigner] David -> plot index 1`
   - Dropper logs `[Dropper] online; spawning coins per 1s`
   - HUD mounts in the top-left of the screen
5. **Walk to your plot** (any of the 6 ring anchors). Coins start dropping.
   Touch the collector or watch them slide; balance updates live in the HUD.
6. **Walk to the amber upgrade button** on your plot. Hold E. If you've got
   enough coins (250 for tier 2), the purchase succeeds, the dropper coins
   change color, income jumps.

The leaderboard sign 50 studs north of spawn updates every 10 seconds with
the top 10 lifetime-coins across the global Roblox population (uses
OrderedDataStore).

## Layout

```
roblox/
├── CLAUDE.md                   rules Claude reads on every command
├── README.md                   this file
├── default.project.json        Rojo: src/server -> ServerScriptService.Studio88,
│                               src/shared -> ReplicatedStorage.Modules,
│                               src/client -> StarterPlayerScripts.Studio88
└── src/
    ├── shared/
    │   ├── Constants.luau      tier table, daily-login table, pass IDs
    │   ├── Types.luau          PlayerData / LeaderboardRow / RemoteMap
    │   └── Remotes.luau        lazy-create RemoteEvent + RemoteFunction
    ├── server/
    │   ├── WorldBuilder.server.luau    one-shot scene constructor (idempotent)
    │   ├── PlotAssigner.server.luau    clones plot template per joining player
    │   ├── DataStore.server.luau       pcall-wrapped DataStore + retry-with-backoff
    │   ├── CurrencyManager.server.luau 1Hz tick -- baseline trickle even without coins
    │   ├── Dropper.server.luau         physical coin emitter per plot
    │   ├── Collector.server.luau       Touched -> credit balance + despawn
    │   ├── UpgradeStation.server.luau  exports attemptPurchase(player); RemoteEvent + proxy share it
    │   ├── UpgradeButtonProxy.server.luau   ProximityPrompt -> attemptPurchase
    │   ├── DailyLoginBonus.server.luau streak tracking, escalating reward
    │   └── Leaderboard.server.luau     OrderedDataStore broadcast every 10s
    └── client/
        └── HUD.client.luau     balance + tier + top-10 leaderboard panel
```

## Hard rules followed

- **Server-side validation** on every currency / tier transaction.
  Cross-plot collection is blocked at the Collector by comparing
  `OwnerUserId` attributes between the coin and the collector.
- **`pcall()` on every `DataStoreService` call** with retry-with-backoff
  (up to 4 attempts, exponential).
- **`task.spawn()` / `task.wait()`** throughout. No `wait()`,
  no `coroutine.wrap()`.
- **Type annotations** on every function parameter and return.
- **Versioned DataStore** (`PlayerData_v1`); migration table in
  `DataStore.server.luau` runs forward when `Constants.DATASTORE_VERSION`
  bumps.
- **Game Pass IDs default to 0** -- `MarketplaceService` calls short-circuit
  via the `passId == 0` check until you create the actual passes in
  Creator Hub.

## Building a .rbxl for double-click playtest

```bash
rojo build -o studio88-tycoon.rbxlx
```

That XML place file can be double-clicked to open in Studio. Useful for
non-coder playtesters.

## v1 polish layer (already shipped)

- **Per-tier plot art** — `Constants.TIER_PLOT_ART` defines a
  Material/Color pair for each tier. `PlotAssigner.applyTierArt` paints the
  foundation, fired at plot assignment (returning players) and on every
  successful upgrade in `UpgradeStation`. Tier 1 = raw concrete, Tier 6 =
  neon pink capstone.
- **Tier-up FX** — `TierUpgraded` RemoteEvent fires to the client on
  successful purchase. HUD shows a center-screen "TIER N UNLOCKED" toast
  and a 0.6s pink screen flash.
- **Daily login HUD popup** — `DailyBonusGranted` RemoteEvent fires on
  streak-eligible login. HUD shows an amber "DAY N STREAK +X coins" toast
  for 5s.
- **World particle FX** — `WorldBuilder.makeParticle` mounts a
  `ParticleEmitter` on the dropper (cyan→pink drift), collector (pink
  ambient + 8-particle burst on each collect via `Collector.server.luau`),
  and upgrade button (amber drift + 30-particle burst on tier-up via
  `UpgradeStation`). Uses the built-in `rbxasset://textures/particles/sparkles_main.dds`
  so no external asset dependency.
- **Per-plot stats board** — Each plot has a `StatsBoard` SurfaceGui (20x8
  studs, mounted at the back of the lot at y=12) showing TIER, +N/sec
  income, and lifetime coins. `PlotAssigner.updateStatsBoard` is called at
  plot assignment, on every collect (cheap TextLabel string-set), and at
  tier upgrade. Visible from across the spawn ring so you can see who's
  winning at a glance.
- **Purchase rejection feedback** — `PurchaseRejected` RemoteEvent fires
  from `UpgradeStation` on every reject path (`no_data`, `max_tier`,
  `insufficient_coins` with the missing-coin delta). HUD shows a 3s amber
  toast with reason-specific copy and plays `Constants.SOUND_IDS.purchase_fail`.

## Sound design (scaffolded, IDs blank)

`Constants.SOUND_IDS` exposes three slots — `tier_up`, `daily_bonus`,
`purchase_fail` — that the HUD's `playSound` helper consumes. Each slot is
empty (`""`) by default, which means silence: the helper short-circuits if
the ID isn't a real `rbxassetid://N` string.

Pick assets from Roblox's free sound library (in Studio: View → Toolbox →
Audio), grab their IDs, and paste them in:

```lua
Constants.SOUND_IDS = {
    tier_up     = "rbxassetid://9120000000",  -- replace with real id
    daily_bonus = "rbxassetid://9120000001",
    purchase_fail = "rbxassetid://9120000002",
}
```

Once filled, the existing toasts in `HUD.client.luau` start playing the
sounds automatically — no further wiring needed.

## What's NOT in v1 yet

- 3 Game Passes (Starter Pack / VIP / Premium) — `Constants.GAME_PASSES.*`
  IDs are placeholders; the multiplier code already reads them, you just
  need to create the passes in Creator Hub and paste the asset IDs.
- Custom GUI for the upgrade button preview (currently a BillboardGui
  text label).
