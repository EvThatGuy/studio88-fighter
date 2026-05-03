#!/bin/bash
# Autonomous V62+ publisher for Studio 88 Tycoon.
# Builds rbxlx from Rojo source, then POSTs to Open Cloud Places API.
# Discovered + cached 2026-05-03. Place 110157326326863 / Universe 10103735614.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RBXLX="$REPO_DIR/studio88-tycoon.rbxlx"
API_KEY_FILE="${ROBLOX_API_KEY_FILE:-$HOME/tmp/roblox-api-key.txt}"
PLACEID=110157326326863
UNIVERSE=10103735614

if [ ! -f "$API_KEY_FILE" ]; then
    echo "FATAL: API key file not found at $API_KEY_FILE" >&2
    exit 1
fi

API_KEY=$(tr -d '\r\n' < "$API_KEY_FILE")

echo "[publish] rojo build..."
rojo build "$REPO_DIR/default.project.json" -o "$RBXLX"

SIZE=$(stat -c %s "$RBXLX" 2>/dev/null || stat -f %z "$RBXLX")
echo "[publish] rbxlx size: $SIZE bytes"

echo "[publish] POST to Open Cloud..."
RESP=$(curl -s -w '\n%{http_code}' -X POST \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$RBXLX" \
    "https://apis.roblox.com/universes/v1/$UNIVERSE/places/$PLACEID/versions?versionType=Published")

BODY=$(echo "$RESP" | head -n -1)
CODE=$(echo "$RESP" | tail -n 1)

echo "[publish] HTTP $CODE"
echo "[publish] body: $BODY"

if [ "$CODE" != "200" ]; then
    exit 1
fi

VERSION=$(echo "$BODY" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('versionNumber','?'))" 2>/dev/null || echo "?")
echo "[publish] DONE — V$VERSION live at https://www.roblox.com/games/$PLACEID/Studio-88-Tycoon"
