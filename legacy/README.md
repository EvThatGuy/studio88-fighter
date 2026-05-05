# Legacy tycoon code

Everything in this directory is pre-pivot tycoon code from `studio88-roblox`,
moved here on 2026-05-05 when this repo became `studio88-fighter`. **Rojo
does not mount this directory** (`default.project.json` only references
`src/`). It exists as reference / salvage material during Phase 0 of the
fighter project plan (`docs/project-plan.md`).

Salvage rules:

- Anything you pull out of `legacy/` must be reviewed line-by-line and
  rewritten against the fighter `PlayerData` shape in `src/shared/Types.luau`.
- Don't `require()` from `legacy/` in `src/`. Copy-paste the relevant code
  into a clean fighter module and delete what you don't need.
- The tycoon DataStore schema (`PlayerData_v15`) is incompatible with the
  fighter schema (`PlayerData_fighter_v1`). Existing tycoon player data
  will not migrate to fighter saves; this is intentional — the fighter is
  a new game from the player's perspective.

Layout mirrors the original tycoon `src/` tree:

- `legacy/server/` — `WorldBuilder`, `PlotAssigner`, `Dropper`, `Collector`,
  `UpgradeStation`, `RebirthService`, `PetService`, `DailyShopService`,
  `WeeklyTournament`, `VaultRaidEvent`, `GamePassService`, `DevProductService`,
  `AchievementService`, `XpService`, `EventService`, `ActivityFeedService`,
  `DailyLoginBonus`, `TutorialService`, `TitleService`, `AuraService`,
  `SpinService`, `TradeService`, `CodesService`, `ReferralService`,
  `StatsService`, `Leaderboard`, `NotificationService`, `DiscordHook`,
  `DataStore`, `Leaderstats`, `Bootstrap`, plus the `Visuals/` directory.
- `legacy/client/` — every tycoon HUD widget and overlay (HUD, HUD_v2,
  TutorialOverlay, DailyShopOverlay, RebirthReadyNudge, etc.) plus the
  full `UI/` React tree.
- `legacy/docs/` — `balance-changelog.md`, `polish-loop-prompt.md`,
  `visual-architecture.md`.

Once the fighter ships and a system is no longer needed for reference,
delete the corresponding `legacy/` files.
