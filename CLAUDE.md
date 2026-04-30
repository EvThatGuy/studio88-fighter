# Roblox Studio Project -- Claude Code Rules

You are building a Roblox tycoon experience inside this project. The goal is a 45-90 minute average session, daily-return loop, monetized via Game Passes + Creator Rewards. Adapted from the @starmexxx Apr 26 2026 playbook.

## Language

This project uses **Luau** -- not Lua, not JavaScript, not TypeScript.
Always write strict Luau with type annotations.

## Architecture

- Server scripts: `src/server/` (mounted at `ServerScriptService` in Studio)
- Client scripts: `src/client/` (mounted at `StarterPlayerScripts`)
- Shared modules: `src/shared/` (mounted at `ReplicatedStorage/Modules`)
- Use `RemoteEvents` for ALL client-server communication
- Use `RemoteFunctions` only when the client needs a synchronous reply (e.g. balance queries)
- Use `DataStoreService` for ALL persistent data, never client-side

## Roblox Services

Always use the `game:GetService()` pattern at the top of every script:

```lua
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
```

## Hard rules

- **Server-side validation on every currency / inventory transaction.** Never trust the client.
- Use `pcall()` on every `DataStoreService` call. Retry with backoff on failure.
- Use `task.spawn()` and `task.wait()`, never `coroutine.wrap()` or `wait()`.
- Type-annotate every function parameter and return. Use `local function foo(player: Player): boolean`.
- DataStores are versioned: when changing the player-data schema, bump the store name (`PlayerCurrency_v1` -> `_v2`) and write a migration in the load function.
- Game Passes are checked via `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` -- cache the result per session.
- Never block the main thread for more than 1 frame. If a heavy computation is needed, yield with `task.wait()`.

## Tycoon-specific patterns to default to

- **Currency tick**: server-only loop, `task.wait(1)` inside `task.spawn`, mutate `playerData[userId].coins` only on the server.
- **Daily login bonus**: track `os.time()` of last login in the DataStore, compare day-of-year, give escalating reward by streak (Day 1: 500, Day 7: 5000, Day 30: 50000). This is the single highest-impact feature for Creator Rewards return rate.
- **Upgrade tiers**: 5 tiers at 250 / 1000 / 5000 / 20000 / 100000 coins, each multiplies income or unlocks a new income source.
- **Leaderboard**: track lifetime coins earned (not current balance). Update every 10 seconds. Show top 10 on a billboard plus rank in personal HUD.
- **Game Passes**: 3 tiers -- Starter Pack (50-75 R$, 2x income for 30 min), VIP (200-300 R$, 1.5x permanent), Premium (500-800 R$, 3x permanent + auto-collect AFK).

## File naming

- Server scripts: `*.server.luau`
- Client scripts: `*.client.luau`
- Shared modules: `*.luau` (no suffix)

## When in doubt

Prefer correctness over cleverness. Prefer server-side over client-side. Prefer typed code over untyped. Prefer one good system shipped over five half-built systems.

## MCP

The `boshyxd/robloxstudio-mcp` server is wired up. You have 54 tools to manipulate the live Studio session: create instances, set properties, write scripts, read output logs, run playtests. Use them. Don't ask the human to drag things in Studio when you can do it yourself.
