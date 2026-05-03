--!strict
-- Discord webhook publisher. Server-side ONLY (HttpService:PostAsync from
-- the client is forbidden by Roblox; only server can hit external URLs).
--
-- Publishes high-signal events to a Discord channel: legendary pet
-- hatches, capstone (tier 6) reaches, weekly tournament winners, vault
-- raid kills. Other services call DiscordHook.publish*() functions.
--
-- The webhook URL must be set in a placeholder constant below — David
-- creates the webhook in the Discord channel settings, pastes the URL.
-- Until set, all publish*() calls no-op silently (no errors).
--
-- Throttling: per-event-kind cooldown so a hatch storm doesn't ping
-- Discord 50 times in a minute.

local HttpService = game:GetService("HttpService")

local DiscordHook = {}

-- PASTE WEBHOOK URL HERE (Discord channel settings → Integrations →
-- Webhooks → Copy URL). Empty string = disabled.
local WEBHOOK_URL = ""

local THROTTLE_SEC: {[string]: number} = {
    legendary_hatch = 30,   -- max 1 hatch ping per 30s
    capstone_reach = 60,    -- max 1 capstone ping per 60s
    raid_kill = 120,        -- max 1 raid result per 2min
    weekly_winner = 3600,   -- max 1 weekly winners ping per hour
}

local lastPublishedAt: {[string]: number} = {}

local function postEmbed(title: string, description: string, color: number, kind: string)
    if WEBHOOK_URL == "" then return end
    local now = os.time()
    local cooldown = THROTTLE_SEC[kind] or 30
    if (now - (lastPublishedAt[kind] or 0)) < cooldown then return end
    lastPublishedAt[kind] = now

    local payload = {
        embeds = {{
            title = title,
            description = description,
            color = color,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {text = "Studio 88 Tycoon"},
        }},
    }
    local body = HttpService:JSONEncode(payload)

    -- Async POST so a slow Discord doesn't tank the server tick
    task.spawn(function()
        local ok, err = pcall(function()
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then
            warn("[DiscordHook] post failed (" .. kind .. "): " .. tostring(err))
        end
    end)
end

function DiscordHook.publishLegendaryHatch(playerName: string, petName: string, eggId: string)
    postEmbed(
        "★ Legendary Hatch ★",
        string.format("**%s** hatched **%s** from %s", playerName, petName, eggId),
        0xFFB000,  -- amber
        "legendary_hatch"
    )
end

function DiscordHook.publishCapstoneReach(playerName: string, rebirths: number)
    postEmbed(
        "🏆 Capstone Tier Reached",
        string.format("**%s** hit Tier 6 (rebirth #%d)", playerName, rebirths),
        0xFF2E88,  -- pink
        "capstone_reach"
    )
end

function DiscordHook.publishRaidKill(taggers: number, totalTags: number, pool: number)
    postEmbed(
        "⚔️ Vault Raid Defeated",
        string.format("%d players + %d total tags claimed $%d pool",
            taggers, totalTags, pool),
        0x00F0FF,  -- cyan
        "raid_kill"
    )
end

function DiscordHook.publishWeeklyWinners(weekKey: string, winners: {{name: string, weeklyEarned: number}})
    if #winners == 0 then return end
    local lines = {string.format("**Week %s** top earners:", weekKey)}
    for i = 1, math.min(10, #winners) do
        table.insert(lines, string.format("`%2d.` **%s** — $%d", i, winners[i].name, winners[i].weeklyEarned))
    end
    postEmbed(
        "★ Weekly Tournament ★",
        table.concat(lines, "\n"),
        0xFFB000,  -- amber
        "weekly_winner"
    )
end

if WEBHOOK_URL == "" then
    print("[DiscordHook] DISABLED (set WEBHOOK_URL in module to enable)")
else
    print("[DiscordHook] armed (" .. #WEBHOOK_URL .. " char URL)")
end

return DiscordHook
