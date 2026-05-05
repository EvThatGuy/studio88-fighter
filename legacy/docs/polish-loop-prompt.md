# Studio 88 Autonomous Polish + Acquisition Loop Prompt

Paste the block below into `/loop` (no interval — Claude will self-pace via `ScheduleWakeup`). It will keep working on Studio 88 across bug hunting, mobile/desktop UX, polish, retention features, gap closure, and client acquisition without further input.

---

## How to fire it

```
/loop
```

When prompted (or in the same line), paste the LOOP PROMPT below.

To stop the loop: just send any new message — the next ScheduleWakeup will not fire while you're directing the conversation.

---

## LOOP PROMPT

```
You are running an autonomous polish + acquisition loop for Studio 88 Tycoon
(Roblox; repo at C:\Users\Mgtda\Documents\game-studio\roblox; live game at
https://www.roblox.com/games/110157326326863/Studio-88-Tycoon).

Repo conventions you MUST honor:
- *.luau   = ModuleScript (require()-able)
- *.server.luau = Script (auto-runs server)
- *.client.luau = LocalScript (auto-runs client)
- Bootstrap.server.luau is the single server entry; do not add
  duplicate `module.server.luau` files for things already loaded
  there as ModuleScripts.
- Publish via `bash publish.sh` from repo root (uses ~/tmp/roblox-api-key.txt).
- Open Cloud is the ONLY publish path. Do NOT try cookie auth, do NOT
  open Studio for publishing, do NOT ask the user to publish.
- Stage explicitly with `git add <path>` (never `git add -A` — rival
  terminals may be in this repo).
- Roblox Open Cloud serves new versions to NEW server instances only.
  After publishing, existing RCC servers keep the OLD code for ~3min.

Each iteration, do exactly ONE of these tracks (rotate so no track
goes >3 iterations without attention). Pick the track based on what
the project most needs RIGHT NOW (read recent git log, scan open
TaskList items, look at PerfBudgetProbe / smoke output if available):

  TRACK A — BUG HUNT + SMOKE
    1. `git log --oneline -10` to see recent shipped work.
    2. Read 2-3 of the most recently changed files end-to-end.
    3. Look for: nil deref, missing parent guards, ambiguous Lua
       syntax (`(x :: T).Foo = ...` after `Instance.new`), forgotten
       `task.wait`, missed `if not state.active or ...` guards,
       events fired without pcall.
    4. If Studio MCP is connected (mcp__Roblox_Studio__list_roblox_studios),
       run a 60s play test, grab `get_console_output`, fix any
       red errors before publishing.
    5. Otherwise: ship the patch via the publish flow below.

  TRACK B — MOBILE UX PASS
    1. Pick one client widget under src/client/ (start with the
       newest ones: BoostTimerHud, SessionBonusCountdown,
       QuestProgressPill, StreakChip, IncomeRateIndicator,
       TributeQuickClaim, PresenceBadge, EventBanner, XpHudWidget).
    2. Verify: TextScaled true OR TextSize >= 12, touch targets
       >= 44px, no overlap with default Roblox top-bar (use
       IgnoreGuiInset = false), no hardcoded pixel positions
       that get clipped on a 360x640 phone screen.
    3. If a widget uses Position UDim2.new(0, 16, 0, 144)+, prefer
       UDim2.new(0, 16, 0, FractionOfScreen) for portrait-safe
       stacking, OR add a UIListLayout container so widgets stack
       cleanly when one is hidden.
    4. Add MouseButton1Click + TouchTap handlers (TextButton
       already covers both via Activated; prefer .Activated over
       .MouseButton1Click).
    5. Ship as one commit per widget polished.

  TRACK C — DESKTOP UX PASS
    1. Verify hover states on TextButtons (subtle stroke/fill change
       on .MouseEnter / .MouseLeave).
    2. Wire keyboard shortcuts via UserInputService for top
       actions (e.g., 'P' opens Pets, 'Q' opens Quests, 'I' opens
       Inventory, 'B' opens Spin Wheel, 'T' opens Trade if enabled,
       'M' opens Daily Shop). Do NOT collide with Roblox defaults
       (Esc, /, Tab, F9-F12, ` console).
    3. Add ContextActionService bindings so shortcuts also work
       on gamepad face buttons.
    4. One iteration = one shortcut family wired + tested.

  TRACK D — VISUAL POLISH ("CSS")
    1. Audit a single ScreenGui for:
       - Consistent SURFACE/AMBER/CYAN/DARK colors from the
         existing palette (don't introduce new shades — see
         existing widgets for the canonical RGB triplets).
       - UICorner radius 6-8 for chips, 10-12 for cards, 16+
         for modals.
       - UIStroke thickness 1, transparency 0.3-0.4 default,
         drop to 0.1-0.2 for urgency / emphasis.
       - UIPadding inside cards (4-8px) instead of margin
         arithmetic on every child.
       - Font: GothamBold for titles, Gotham for body.
    2. Animate state transitions with TweenService over 0.15-0.4s
       Sine InOut. Avoid linear tweens.
    3. One iteration = one ScreenGui sanded smooth.

  TRACK E — FEATURE / RETENTION IMPROVEMENT
    1. Check tycoon-retention-checklist (/skills folder if
       available, or docs/balance-changelog.md) for unshipped
       items. Common gaps:
       - Always-visible "next milestone" widget for an upgrade
         tier the player is close to
       - Server-broadcast top-earner ticker (already partially
         in ActivityFeedService — check if it has a corner UI)
       - Daily-quest auto-claim toast on completion
       - Pet inventory "favorite" toggle so the favorite always
         hatches first
       - Plot decoration cosmetics (cheap RP retention hook)
       - Auto-rebirth toggle for high-tier players
    2. ONE feature per iteration. Server changes go in *.luau
       (ModuleScript) loaded by Bootstrap, not *.server.luau.
    3. Wire any new RemoteEvent/RemoteFunction in
       src/shared/Remotes.luau (alphabetical block at the bottom).

  TRACK F — GAP / EMPTY STATE CLOSURE
    1. Grep for "TODO", "FIXME", "no_data", "TBD" — kill the
       lowest-effort one.
    2. Audit one modal or panel for empty states: does it say
       something useful when the list is empty? ("No quests yet
       — check back tomorrow!" beats a blank panel.)
    3. Verify every `pcall` that swallows an error logs WHY
       (`warn(...)` with context).
    4. Ship the fix.

  TRACK G — CLIENT ACQUISITION
    Studio 88 has zero acquisition wired. Cycle through:
      G1. Compose a build-in-public tweet about the most recent
          shipped feature (V12X). Append the entry as a JSON
          object {"text": "..."} to the array at
          ~/.cache/mgt-engagement/originals_queue.json (Phase 9
          posts under @ModernGrindTech pin reply). Voice rule:
          "shipped X today, here's why it matters" — NOT bot
          cadence. Keep under 270 chars to leave room for the
          reply chain.
      G2. Open the existing ReferralService server module and
          verify the in-game referral flow ends with a CLEAR
          UI prompt to share a code (referral chips, copy
          button, "+10K when your friend reaches tier 3"
          messaging). If missing, ship the UI.
      G3. Search for "Discord webhook" in the repo. If
          DiscordHook.luau still has a placeholder URL, do not
          paste a real one — flag it to the user instead.
          Otherwise, verify hot events (vault raid spawn,
          mythic hatch, tier 10 reach) are wired to fire.
      G4. Audit the game's Roblox listing surface area: does
          the welcome banner pitch the game in 1 sentence?
          Are pets/aura/title visible on first 30 seconds of
          gameplay?  (You cannot edit the Creator Hub listing
          itself — flag improvements to the user.)

PUBLISH FLOW (do this every time you ship code):
   git add <explicit paths>
   git commit -m "$(cat <<'EOF'
<conventional message>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
   )"
   git push origin main
   bash publish.sh
   # Confirm the "[publish] DONE — VNNN live" line appeared.

NEVER:
   - Mock the database / DataStore in tests (we got burned;
     integration only)
   - Skip git hooks (--no-verify)
   - Force push main
   - Delete unfamiliar files / branches without asking
   - Wait > 270s with ScheduleWakeup unless you have a real
     reason to commit to a long sleep (cache TTL is 5min)
   - Run smoke against Studio if Studio is unreachable —
     just publish and let new RCC instances pick it up

LOOP HYGIENE:
   - Each iteration MUST update or close at least one TaskList
     item. Don't let the task list grow stale.
   - Every 5 iterations, write a 2-line status line to
     docs/balance-changelog.md so the user can audit progress
     without reading every commit.
   - If you ship 3 publishes in a row without a smoke pass,
     force a smoke (TRACK A) on the next iteration even if
     something else feels more pressing.
   - Dynamic pacing: pick ScheduleWakeup delaySeconds in the
     [60, 270] range during active work (cache stays warm),
     [1200, 1800] during pure idle waits. Never 300s.

CONTINUE THE LOOP until:
   - User sends a new message (don't ScheduleWakeup if they
     redirected),
   - You hit a hard blocker requiring a paste-action from
     David (e.g., real Discord webhook URL, real productId,
     gamepass enable in Creator Hub) — in that case, summarize
     the blocker in 3 bullets and stop,
   - publish.sh fails twice in a row with the same error.

Start by reading `git log --oneline -5`, picking the track that
makes most sense given the last 5 commits + current TaskList,
and shipping ONE thing.
```

---

## Track rotation default (if undecided)

A → B → E → C → D → G → F → A …

That gives bug hunting after each publish wave, alternates UX
work between mobile (high-priority) and desktop, slips polish
in regularly, hits acquisition every 6th iteration, and saves
gap-closure for tail cleanup.

## Notes

- The loop calls `ScheduleWakeup` itself; you do not need
  CronCreate.
- The prompt is self-pacing — Claude picks the delay based on
  what it kicked off (e.g., 90s if waiting for a publish to
  propagate to fresh RCC instances, 1200s if there's nothing
  to watch).
- To kill the loop without ScheduleWakeup re-firing, just
  reply to Claude in the same conversation; the next firing
  is suppressed automatically when the user is active.
