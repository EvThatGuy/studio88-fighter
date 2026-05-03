--!strict
-- Boots every server-side service module exactly once at server start.
-- Required because the services are now ModuleScripts (renamed from Script
-- to fix the long-standing `require()`-on-Script architectural bug -- see
-- 2026-05-02). A ModuleScript's top-level code only fires on first require,
-- so without this kickoff the Players.PlayerAdded:Connect calls inside each
-- service never bind and the entire backend stays dormant.
--
-- DataStore MUST come first: every other service that hooks PlayerAdded
-- expects DataStore.getCached(userId) to already have data when their own
-- PlayerAdded handler runs. Event handlers fire in bind order.

local ServerScriptService = game:GetService("ServerScriptService")
local container = ServerScriptService:WaitForChild("Studio88")

local function load(name: string)
    local mod = container:WaitForChild(name, 10)
    if not mod then
        warn(string.format("[Bootstrap] missing service module: %s", name))
        return
    end
    if not mod:IsA("ModuleScript") then
        warn(string.format("[Bootstrap] %s is %s, expected ModuleScript",
            name, mod.ClassName))
        return
    end
    local ok, err = pcall(require, mod)
    if not ok then
        warn(string.format("[Bootstrap] FAILED to require %s: %s", name, tostring(err)))
    end
end

-- Foundation: persistence + leaderstats. Must bind PlayerAdded BEFORE any
-- consumer service so cache is populated by the time downstream handlers
-- read it.
load("DataStore")
load("Leaderstats")
-- AmbientAudio module is required by Collector + UpgradeStation. The
-- companion AmbientAudio.server.luau Script also boots it, but loading
-- here ensures the module is available even if require ordering races
-- with the bootstrap loop.
load("AmbientAudio")

-- Plot infrastructure: must exist before tutorial / collectibles can react.
load("PlotAssigner")
load("TutorialService")

-- Gameplay services. Order within this block doesn't matter -- each binds
-- its own independent PlayerAdded / remote handlers and they don't read
-- each other's state inside binding code.
load("AchievementService")
load("ActivityFeedService")
load("AfkAutoCollect")
load("AuraService")
load("CodesService")
load("DailyQuestService")
load("EventService")
load("GamePassService")
load("HourlyTributeService")
load("NotificationService")
load("PetService")
load("PetStandService")
load("RebirthService")
load("RebirthShopService")
load("ReferralService")
load("SpinService")
load("SquadBonusService")
load("StatsService")
load("TitleService")
load("UpgradeStation")
load("VisitService")

print("[Bootstrap] all 25 service modules required")
