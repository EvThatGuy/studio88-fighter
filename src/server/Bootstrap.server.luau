--!strict
-- Boots every server-side service module exactly once at server start.
-- Services are ModuleScripts; their top-level code only fires on first
-- require(), so this kickoff is what binds Players.PlayerAdded handlers.
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

local function loadFolder(folderName: string, services: {string})
    local folder = container:WaitForChild(folderName, 10)
    if not folder then
        warn(string.format("[Bootstrap] missing folder: %s", folderName))
        return
    end
    for _, name in ipairs(services) do
        local mod = folder:WaitForChild(name, 10)
        if not mod then
            warn(string.format("[Bootstrap] missing service: %s/%s", folderName, name))
            continue
        end
        if not mod:IsA("ModuleScript") then
            warn(string.format("[Bootstrap] %s/%s is %s, expected ModuleScript",
                folderName, name, mod.ClassName))
            continue
        end
        local ok, err = pcall(require, mod)
        if not ok then
            warn(string.format("[Bootstrap] FAILED to require %s/%s: %s",
                folderName, name, tostring(err)))
        end
    end
end

-- Foundation: data + leaderstats first, before anyone reads cache
load("DataStore")
load("Leaderstats")
load("AntiCheat")

-- Combat services (Phase 1 scaffolding; stubs until elomala port lands)
loadFolder("Combat", { "ClassRegistry", "StaminaService", "HitboxService", "CombatService", "DummyService" })

-- Match flow (Phase 2 scaffolding)
loadFolder("Match", { "MapRotation", "MatchService", "DuelService", "RespawnService", "SpawnProtection" })

-- Abilities (Phase 3 — first slice: 1 ability per class)
loadFolder("Abilities", { "AbilityLibrary", "AbilityRuntime" })

print("[Bootstrap] fighter server boot complete")
