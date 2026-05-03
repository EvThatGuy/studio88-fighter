--!strict
-- Listens on the MessagingService topic "STUDIO88_HOTSWAP". When a payload
-- arrives, kicks every player with a one-line reason. Once everyone leaves
-- the server enters the empty-server reaper window and shuts down within
-- seconds, so the next rejoin lands on a fresh RCC running the latest
-- published version.
--
-- Trigger from terminal:
--   curl -X POST -H "x-api-key: $KEY" \
--     -H "Content-Type: application/json" \
--     -d '{"message":"hotswap","topic":"STUDIO88_HOTSWAP"}' \
--     "https://apis.roblox.com/messaging-service/v1/universes/$U/topics/STUDIO88_HOTSWAP"
--
-- This sidesteps the "Open Cloud publish doesn't kick existing servers"
-- gotcha that cost us 30 minutes on 2026-05-01.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local TOPIC = "STUDIO88_HOTSWAP"

local ok, conn = pcall(function()
    return MessagingService:SubscribeAsync(TOPIC, function(msg: any)
        local reason = "hotswap reload"
        if msg and typeof(msg.Data) == "string" and msg.Data ~= "" then
            reason = msg.Data
        end
        print("[HotReload] kicking " .. #Players:GetPlayers() .. " players: " .. reason)
        for _, p in ipairs(Players:GetPlayers()) do
            pcall(function() p:Kick(reason) end)
        end
    end)
end)

if ok then
    print("[HotReload] listening on " .. TOPIC)
else
    warn("[HotReload] failed to subscribe: " .. tostring(conn))
end
