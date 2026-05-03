# Studio 88 Tycoon — Visual Architecture

Catalog of the visual modules + their public contracts. Updated 2026-05-03 for V79.

## Convention
- `*.luau` = ModuleScript (require'd by other code)
- `*.server.luau` = Script (auto-runs at server start)
- `*.client.luau` = LocalScript (runs in StarterPlayerScripts)
- All visuals live under `src/server/Visuals/` (procedural model builders) or inline in WorldBuilder/PlotAssigner/LobbyDecor

## Procedural model builders (`src/server/Visuals/`)

### CoinModel.luau
Per-coin disc + sparkle + Trail. Tier-color and tier-rate-keyed.
- **Public**: `CoinModel.build(tier: number) -> BasePart`
- **Public**: `CoinModel.soundForTier(tier: number) -> (volume, pitch)` — used by Collector
- **Output**: cylinder Part tagged `Studio88Coin`, with rim weld + Sparkle particle + AngularVelocity tumble + light trail + Attachments
- **Perf**: 1 part + 1 weld + 1 particle (rate 2-8/sec) + 1 trail per coin. Coin lifetime 30s, spawn rate 1/sec/dropper. Max ~30 coins live = 30 trails + 30 particles. Inside budget.

### DropperModel.luau
Vending-machine chassis, replaces V61 cyan cube.
- **Public**: `DropperModel.build(pos, parent) -> Model`
- **Output**: 9-part Model with Body (tagged `Studio88Dropper`), Core, Glass, 4 rims, Spout, Marquee. Spout has drift particle + cyan PointLight.
- **Perf**: 9 parts + 1 particle + 1 light per plot.

### UpgradeButtonModel.luau
Arcade dome on metal pedestal.
- **Public**: `UpgradeButtonModel.build(pos, parent) -> Model`
- **Output**: 4-part Model with Pedestal, Stem, Dome (tagged `Studio88UpgradeButton`), DomeCore. Dome has UpgradeFX particle + amber PointLight + ProximityPrompt.
- **Perf**: 4 parts + 1 particle + 1 light per plot.

### RebirthPortalModel.luau
Glowing prestige portal.
- **Public**: `RebirthPortalModel.build(pos, parent) -> Model`
- **Output**: 5-part Model with Pad (tagged `Studio88RebirthPad`), Ring1, Ring2, Ring3, Beam. Beam has cyan PointLight + sparkle shower + ProximityPrompt.
- **Perf**: 5 parts + 1 particle + 1 light per plot.

### CollectorModel.luau
Vault-door receptacle.
- **Public**: `CollectorModel.build(pos, parent) -> Model`
- **Output**: 9-part Model with Pedestal, Catch (tagged `Studio88Collector` + CollectFX particle), DoorBackplate, Door (CylinderMesh), Handle + HandleCross (rotating brass), LabelHost (BillboardGui "COLLECT"), 2 SideWalls. Backlight + SpotLight.
- **Perf**: 9 parts + 1 particle + 2 lights per plot.

### PetModel.luau
Per-rarity creature silhouette for PetStandService.
- **Public**: `PetModel.build(rarity, color, pos, parent) -> Model`
- **Output**: Variable-part Model. Common = orb + sparkle. Uncommon = +head/eyes. Rare = +wings + ForceField aura. Epic = +tail + light. Legendary = +horns + brighter light.
- **Perf**: 1-9 parts + 1 sparkle + 0-1 light per equipped pet. Max 3 equipped per player.

### LobbyDecor.luau
3-tier pedestal, rotating sign, pillars, fountains, crystal centerpiece, stairs, teleport pads.
- **Public**: `LobbyDecor.build()` — idempotent
- **Output**: ~50 children including:
  - 3 cylinder pedestal tiers + cyan ring accent + brand decal SurfaceGui
  - 14-stud rotating sign tower with sparkle + central PointLight + brand text
  - 6 perimeter pillars (cyan/pink caps, alternating)
  - 4 cardinal-direction stair sets (16 steps + 16 neon edge strips)
  - Crystal centerpiece (3 stacked rotating diamonds, cyan/pink)
  - 6 plot teleport pads (cyan, with ProximityPrompt)
  - 2 corner fountains (marble base + cyan rim + water particles)
- **Perf**: ~75 parts + 4 particles + 2-8 lights (lights toggled by ownership)

### TierPlotDecor.luau
Per-tier additive plot overlays (border, posts, panels, spire, capstone ring).
- **Public**: `TierPlotDecor.build(plot, tier)`, `TierPlotDecor.clear(plot)`
- **Tier 1**: nothing (raw concrete foundation)
- **Tier 2**: + cyan border ring + 8 perimeter wall segments (with 12-stud walk-in gaps)
- **Tier 3**: + 4 corner accent posts with PointLights
- **Tier 4**: + 4 quadrant floor panels
- **Tier 5**: + central ForceField spire + amber light
- **Tier 6**: + capstone swirling particle ring (50/sec)

## Audio

### AmbientAudio.luau / AmbientAudio.server.luau
Lobby ambient + UI ping bank + spatial one-shots.
- **Public**: `AmbientAudio.startAmbient()` — rotating loop (3 tracks, 90s rotation)
- **Public**: `AmbientAudio.ensureUiPings()` — populates SoundService.Studio88UIPings folder
- **Public**: `AmbientAudio.playSpatial(soundKey, attachTo, volume?, pitch?)` — 6 keys: ambient/coin/tier_up/purchase/fail/rebirth
- **All paths**: `rbxasset://sounds/*` shipped with every Roblox client install — verified loadable in V62 smoke (bell.mp3 was the one that didn't ship).

## Client visual scripts

### WelcomeBanner.client.luau
Slide-in card on player join showing TIER + lifetime coins. Receives WelcomeBanner remote.

### TierUpFlash.client.luau
Full-screen tier-color flash + center "TIER X / x mult INCOME" toast on tier-up. Receives TierUpgraded remote.

### CoinCollectFx.client.luau
Floating "+N" text drift on every collect. Receives CoinCollectedFx remote (owner-only fire from Collector).

### FootstepDust.client.luau
Smoke puff under player feet when MoveDirection.Magnitude > 0.1, throttled 1/0.4s. Pure local — no remotes.

## Server stage scripts

### WorldBuilder.server.luau (the conductor)
Boots once: builds baseplate, spawn pedestal, plot template, plot anchors, leaderboard sign, lighting + atmosphere + bloom + skybox + day-night cycle.

### PlotAssigner.luau
Per-player plot assignment + tier paint + welcome arch + welcome mat + welcome banner + join chime + income chart loop.

### Collector.server.luau
Touched-event coin pickup + balance credit + spatial sound + chart sample + CoinCollectedFx remote.

### UpgradeStation.luau
Tier purchase logic. On capstone (tier 6), spawns 5-emitter fireworks + louder rebirth sound.

### PlotTeleportProxy.server.luau
Lobby teleport pad ownership refresh + tier-color paint + Triggered handler.

### PerfBudgetProbe.server.luau
30s loop: counts parts/particles/lights/surfaceGuis. Warns past budget. Caught the V69 coin SurfaceGui leak in 30s.

## Perf budget (V75 baseline)
- parts: 215 / 3000 (7%)
- particles: 33 / 50 (66%)
- lights: 21 / 30 (70%)
- surfaceGuis: 8 / 40 (20%)
- trails: 23 (no budget — short-lived)

## Publish workflow
```
./publish.sh
```
Builds rbxlx via `rojo build`, POSTs to Open Cloud Places API. Key cached at `~/tmp/roblox-api-key.txt`. Universe 10103735614 / Place 110157326326863.
