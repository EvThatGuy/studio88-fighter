--!strict
-- Limited-time events. Server-side scanner that walks Constants.LIVE_EVENTS
-- every EVENT_SCAN_INTERVAL_SEC and decides which (if any) is currently
-- active. Exposes a multiplier read by CurrencyManager so the income
-- boost stacks with all other multipliers.
--
-- Cross-server consistency: os.time() is universal across Roblox servers,
-- so all servers in this universe enter/exit the same event window at
-- the same wall-clock moment. No MemoryStore required.
--
-- Player-facing: when active state flips, fires EventStateChanged to all
-- clients with the active event's metadata + remaining seconds. New
-- joiners get the same event via the join-time push (Players.PlayerAdded).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.get()

local EventService = {}

type ActiveEvent = {
    id: string,
    name: string,
    sub: string,
    multiplier: number,
    startUnix: number,
    endUnix: number,
    color: string,
}

local current: ActiveEvent? = nil

-- Find the FIRST event currently active (intersecting now). If multiple
-- events overlap, the earliest one in LIVE_EVENTS wins -- we don't stack
-- two LT multipliers at once because that's confusing for players.
local function findActive(now: number): ActiveEvent?
    for _, e in ipairs(Constants.LIVE_EVENTS) do
        if now >= e.startUnix and now < e.endUnix then
            return e
        end
    end
    return nil
end

-- Income multiplier read by CurrencyManager. 1.0 if no event is active.
function EventService.getMultiplier(): number
    return (current and current.multiplier) or 1.0
end

-- The currently-active event, if any. Used by the join-push and HUD.
function EventService.getActive(): ActiveEvent?
    return current
end

local function buildPayload(): {active: boolean, event: any?, endsInSec: number?}
    if not current then
        return { active = false }
    end
    return {
        active = true,
        event = {
            id = current.id,
            name = current.name,
            sub = current.sub,
            multiplier = current.multiplier,
            color = current.color,
        },
        endsInSec = math.max(0, current.endUnix - os.time()),
    }
end

local function broadcast()
    local payload = buildPayload()
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.EventStateChanged:FireClient(p, payload)
        end)
    end
end

local function pushTo(player: Player)
    pcall(function()
        remotes.EventStateChanged:FireClient(player, buildPayload())
    end)
end

local function scan()
    local now = os.time()
    local next_ = findActive(now)
    -- Same event id ticking down: re-broadcast every other scan so HUD
    -- countdown stays accurate without flooding remotes.
    if next_ and current and next_.id == current.id then
        broadcast()
        return
    end
    -- State transition (event began or ended)
    if next_ ~= current then
        if next_ then
            print(string.format("[EventService] event '%s' started (mult x%.2f, ends in %ds)",
                next_.id, next_.multiplier, next_.endUnix - now))
            pcall(function()
                AnalyticsService:LogCustomEvent(Players, Constants.ANALYTICS_EVENTS.EVENT_ACTIVE, 1, {
                    custom_field_1 = next_.id,
                })
            end)
        else
            print(string.format("[EventService] event '%s' ended",
                current and current.id or "?"))
        end
        current = next_
        broadcast()
    end
end

task.spawn(function()
    -- Boot: pick whatever's active right now and announce it. Subsequent
    -- scans handle transitions in/out.
    scan()
    while true do
        task.wait(Constants.EVENT_SCAN_INTERVAL_SEC)
        scan()
    end
end)

-- Push current state to fresh joiners so they see the countdown immediately.
Players.PlayerAdded:Connect(function(p)
    task.wait(1)  -- give Remotes folder time to replicate
    pushTo(p)
end)

print(string.format("[EventService] ready (%d events configured, scan every %ds)",
    #Constants.LIVE_EVENTS, Constants.EVENT_SCAN_INTERVAL_SEC))

return EventService
