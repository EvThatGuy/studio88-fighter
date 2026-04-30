# Roblox tycoon project

Studio-side codebase for the AI-pipeline studio's Roblox track. Pairs with the `boshyxd/robloxstudio-mcp` MCP server so Claude Code can write Luau directly into a live Roblox Studio session.

## One-time setup

```bash
# 1. Wire the MCP server
claude mcp add robloxstudio -- npx -y robloxstudio-mcp@latest

# 2. Download the Studio plugin
curl -L "https://github.com/boshyxd/robloxstudio-mcp/releases/download/v2.5.1-plugin-fix/MCPPlugin.rbxmx" \
  -o ~/Documents/Roblox/MCPPlugin.rbxmx
```

In Roblox Studio:
1. Plugins -> Manage Plugins -> install from `~/Documents/Roblox/MCPPlugin.rbxmx`
2. Game Settings -> Security -> enable **Allow HTTP Requests**
3. Open a fresh Baseplate project (or load `Tycoon Template`)
4. Run `claude` in this directory

The MCP plugin gives Claude 54 tools into the live Studio session. Confirm the connection: ask Claude to run `get_place_info` -- it should reply with your current place name.

## Layout

```
roblox/
├── CLAUDE.md            # rules Claude reads on every command
├── README.md            # this file
└── src/
    ├── server/          # ServerScriptService -- authoritative game state
    ├── client/          # StarterPlayerScripts -- HUD, input
    └── shared/          # ReplicatedStorage/Modules -- types, constants, RemoteEvents
```

When syncing back to Studio, treat `src/server/*.server.luau` files as the canonical source. Studio is a deployment target, not the source of truth.

## First build

The four systems every tycoon needs (see CLAUDE.md for the prompts):

1. **CurrencyManager** (server) -- DataStore-backed coin balance + 1-second income tick
2. **UpgradeStation** (server + client) -- 5-tier purchase prompts, particle feedback on success
3. **Leaderboard** (server + client) -- lifetime coins, top 10, billboard + HUD rank
4. **DailyLoginBonus** (server) -- streak tracking, escalating reward up to 50K at Day 30

After those four ship, you have a working tycoon. Theme + assets are placement work.
