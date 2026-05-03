# Studio 88 — Balance Changelog

Per-publish gameplay/balance changes. Visual changes documented separately in `docs/visual-architecture.md`.

## V95 — 2026-05-03

### Idle return bonus (offline earnings)
- New `IdleReturnBonus.server.luau` grants offline-earnings bonus on rejoin
- `data.lastLogoutUnix` stamped in `DataStore.onPlayerRemoving`
- On rejoin: `bonus = floor(min(now - lastLogoutUnix, 3600) * tierIncomePerSec / 4)`
- 1/4 reduction so active play stays the path
- Skip `<60s` (alt-tab) and new-player (no prior logout)
- Toast: slide-in "WELCOME BACK / Earned $X offline (Ym away)" 4s hold
- New `IdleReturnBonusGranted` RemoteEvent + `IdleReturnBonusToast.client.luau`

## V94 — 2026-05-03

### Pet stand multiplier label
- `PetStandService` adds floating "x2.50 PET BOOST" label above the pet stand
- Computed via sumAdd of equipped pet rarity mults
- Visible to plot visitors — social proof for the gacha grind

### Visitor reward (both-sides win)
- `VisitService` now tips BOTH sides of a visit (was owner-only)
- Visitor gets `Constants.VISIT_VISITOR_REWARD_COINS = 100` flat
- Flat (not tier-scaled) so tier-1 visitors aren't disadvantaged when visiting tier-6 plots
- Compounds the social viral loop per checklist mechanic 5

## V92 — 2026-05-03

### Cheat-detection sanity check
- `CurrencyManager.tick` now sanity-checks `gain == expected` per tick
- Mismatch logs warn once per 5min per player (`lastCheatWarnAt` throttle)
- Surfaces future exploit attempts without blocking gameplay
- Real anti-cheat would need historical-baseline coin/sec ceiling

## V91 — 2026-05-03

### Pet collection progress in snapshot
- `PetService.snapshot` now returns `uniquePetCount`, `totalPetCount`, `collectionBonusPct` (50)
- HUD modal can render "OWNED 7/10 — +50% income when complete" without client-side math

## V90 — 2026-05-03

### Rebirth-ready nudge toast (D1→D7 conversion ceremony)
- `RebirthPadProxy.server.luau` tracks per-userId `lastEligible` state
- Fires `RebirthReadyNudge` remote on `false→true` transition
- New `src/client/RebirthReadyNudge.client.luau` renders center-screen toast
- First-rebirth: amber accent, "★ REBIRTH UNLOCKED ★", 4.5s hold, actionable copy
- Subsequent: cyan, "REBIRTH READY", 2.5s, compact
- Solves "rebirth pad's always-on particle didn't telegraph eligibility flip"

## V89 — 2026-05-03

### Live event timestamps refresh
- Old `launch_weekend` (May 2025) and `gta6_hype_week` (Nov 2025) were dead
- New: `launch_weekend` Fri May 8 → Mon May 11 2026, `gta6_hype_week` Nov 12-19 2026

### FTUE first-3 coin auto-credit
- `Dropper.server.luau` auto-credits first 3 coins per player at dropper position
- 50 each = 150 free coins + +N text fires immediately
- Solves "player bounces in <30s before reaching conveyor"
- Per-player counter, reset on `PlayerRemoving`

### Income mult cap monitoring
- `CurrencyManager` now logs cap-hits via 60s sweep loop
- `local capHits = 0` upvalue declared at file scope
- `warn` if hits > 0 in last 60s + reset counter

## V88 — 2026-05-03

### Anti-AFK on session timer
- `SessionTimeBonus` rewrote to use `activeSeconds` instead of raw join elapsed
- 15s tick checks `Humanoid.MoveDirection.Magnitude > 0.05` OR last move within `AFK_THRESHOLD_SEC=60`
- Standing in lobby for 60s without movement pauses the timer
- Threshold checks use `activeSeconds`, not wall-clock

### Partner code slots
- Added `PARTNER_1/2/3` to `Constants.CODES`
- Each: `reward=5000, expiresUnix=0` (disabled), `maxGlobalRedemptions=5000`
- Activate by setting `expiresUnix` to a future timestamp

## V87 — 2026-05-03

### `INCOME_MULT_CAP=50000` hard ceiling
- `CurrencyManager.multiplierFor` clamps mult to 50000
- Theoretical max for fully-decked player ~72,000x base; cap leaves end-game headroom but bounds exploit damage

### Session-time bonuses
- `SessionTimeBonus.server.luau` (new) auto-grants 15min/30min/60min bonuses (2K/5K/15K coins)
- Per-session reset on `PlayerRemoving` (not cumulative across rejoins)
- Fires `SessionBonusGranted` remote + `LogCustomEvent("SessionTimeBonus", ...)`

## V86 — 2026-05-03

### GTA6HYPE expiry fix
- Was `1763510400` (2025-11-18) — already expired in production!
- Now `1795046400` (2026-11-18) — day before actual GTA6 launch Nov 19 2026
- Source: project memory `project_game_studio_2026-04-28.md`

### FTUE funnel extended 5 → 7 steps
- Added `06_first_rebirth` (D1→D7 conversion moment per retention checklist)
- Added `07_first_egg_hatched` (gacha entry point)
- Wired via `TutorialService.advance` from `RebirthService.attemptRebirth` and `PetService.attemptHatch`
- Roblox dashboard `LogOnboardingFunnelStepEvent` reports per-step drop-off

## V85 — 2026-05-03

### Spin GRAND PRIZE segment
- Added `grand_jackpot` segment (weight 0.1 vs ~89 sum = 0.11% chance)
- Reward: 1hr (3600s) pet boost — transformative for active players
- Per checklist mechanic 4: "one ~0.1% odds GRAND PRIZE keeps tension at the table"

### Quest reward bumps (medium 2×, hard 3×)
- MEDIUM: 1500→3000 reward (was ~10% bonus over natural earn time, now ~25%)
- HARD: 8K→25K reward, rebirth quest 10K→40K (rebirth = D1→D7 conversion priority)
- Easy quests left unchanged (small target, small reward = proportional)

## V84 — 2026-05-03

### UPGRADE_TIERS smoothed
- Was: 250/1K/5K/20K/100K (4-5× jumps tier 4-6 = mid-tier wall)
- Now: 250/1K/4K/14K/50K (~3-4× consistent)
- D7 cohort can reach capstone in ~75min vs old ~2hr
- Capstone reachable inside D7 cohort window per BLOXG retention data

### Day-7 streak egg promoted
- Was: standard_egg (biasTier 2)
- Now: luxury_egg (biasTier 3, rare-or-better skewed)
- Matches the MYTHIC label added in V82 — proportional reward delivery

### PET_BOOST cost ROI fix
- Was: 1M tier-6 cost = net LOSS even with 3 legendaries equipped (612K delta vs 1M cost)
- Now: 350K tier-6 cost = ~2× ROI for engaged player (220/sec → 440/sec for 15min = +198K vs 100K cost)
- Full new scale: 500/2K/8K/30K/100K/350K

## V83 — 2026-05-03

### Pet rarity weight rebalance
- Was: common 60, uncommon 25, rare 10, epic 4, legendary 1
- Now: common 55, uncommon 25, rare 12, epic 7, legendary 1
- Net rare+ chance up from 15% → 19% — softens rare→epic cliff
- Mid-tier players who hit 5+ commons in a row felt stuck
- Legendary chance unchanged (still 1/100)

### Roblox Premium income bonus
- Added `Constants.ROBLOX_PREMIUM_INCOME_MULT = 1.25` (+25% income)
- Wired in `CurrencyManager.multiplierFor` via `Player.MembershipType == Enum.MembershipType.Premium`
- Per checklist mechanic 7: ~12% of Roblox DAU has Premium, Roblox actively promotes Premium-eligible games
- Free upside; does NOT gate any core gameplay (anti-pattern check passed)

## V82 — 2026-05-03 (the big balance pivot)

### First-rebirth gate fixed (CRITICAL)
- Was: 100K lifetime + max tier requirement (~1.5-2hr first rebirth)
- Now: 1500 lifetime + tier 2 requirement (~10min first rebirth)
- Subsequent rebirths still require 100K + max tier (real grind)
- Constants: `REBIRTH_FIRST_MIN_TIER=2`, `REBIRTH_FIRST_MIN_LIFETIME_COINS=1500`
- Logic: `RebirthService.checkEligibility` branches by `data.rebirths == 0`
- Per checklist: 10-15min first rebirth is THE D1→D7 conversion moment

### Leaderboard top-50
- Was: top-10 (anti-pattern per checklist — unreachable for non-whales)
- Now: top-50 in payload (in-world sign renders top-20 due to panel real estate)
- Constants: `LEADERBOARD_TOP_N = 50`
- Sign title pulls from constant: `"TOP " .. Constants.LEADERBOARD_TOP_N .. " -- LIFETIME"`

### Day-7 jackpot UX
- Added `Constants.DAILY_BONUS_LABELS` with `{tag, jackpot}` per milestone day
  - Day 1=WELCOME, Day 7=MYTHIC, Day 14=ULTIMATE, Day 21=ASCENDANT, Day 30=TRANSCENDENT
- New `GetDailyStreakSchedule` RemoteFunction returns
  `{day, coins, tag, jackpot, eggGrant, claimed, current}` per row
- Any HUD modal can render the day-7 carrot from day 1 of streak

## Reference

- Empirical playbook: `~/.claude/skills/tycoon-retention-checklist/SKILL.md`
- BLOXG benchmarks: D1=30%, D7=12%, D30=5.1% — first 7 days = monetization window
- 83% of D1 cohort gone by D30 — design budget should target D1→D7 not D30+
