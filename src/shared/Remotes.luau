--!strict
-- Lazily creates the RemoteEvent / RemoteFunction folder under
-- ReplicatedStorage and exposes typed accessors. Server scripts call
-- Remotes.get() at startup; client scripts call Remotes.waitFor() since
-- replication may not have happened yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local Remotes = {}

local FOLDER_NAME = "Studio88Remotes"

local REMOTE_NAMES = {
    -- Combat: client → server
    {name = "PunchRequest", class = "RemoteEvent"},
    {name = "BlockRequest", class = "RemoteEvent"},
    {name = "DodgeRequest", class = "RemoteEvent"},
    {name = "AbilityRequest", class = "RemoteEvent"},
    -- Combat: server → client
    {name = "HitLanded", class = "RemoteEvent"},
    {name = "StaminaUpdated", class = "RemoteEvent"},
    {name = "CombatPhaseChanged", class = "RemoteEvent"},
    {name = "AbilityCast", class = "RemoteEvent"},
    -- Class selection
    {name = "SelectClass", class = "RemoteEvent"},
    {name = "ClassSelected", class = "RemoteEvent"},
    {name = "GetClasses", class = "RemoteFunction"},
    -- Match flow
    {name = "MatchStateChanged", class = "RemoteEvent"},
    {name = "GetMatchState", class = "RemoteFunction"},
    -- Generic
    {name = "NotificationToast", class = "RemoteEvent"},
    -- Retention
    {name = "DailyBonusGranted", class = "RemoteEvent"},
    -- Monetization
    {name = "GetPassOwnership", class = "RemoteFunction"},
    {name = "PassPurchased", class = "RemoteEvent"},
}

local function ensureFolder(): Folder
    local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if existing then
        assert(existing:IsA("Folder"), FOLDER_NAME .. " exists but isn't a Folder")
        return existing
    end
    if not RunService:IsServer() then
        error(FOLDER_NAME .. " not yet replicated; call Remotes.waitFor() on client")
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = ReplicatedStorage
    return folder
end

local function ensureRemote(folder: Folder, spec: {name: string, class: string}): Instance
    local existing = folder:FindFirstChild(spec.name)
    if existing then return existing end
    if not RunService:IsServer() then
        error("Remote '" .. spec.name .. "' missing on client; server hasn't created it yet")
    end
    local remote = Instance.new(spec.class)
    remote.Name = spec.name
    remote.Parent = folder
    return remote
end

function Remotes.get(): Types.RemoteMap
    local folder = ensureFolder()
    local map = {}
    for _, spec in ipairs(REMOTE_NAMES) do
        map[spec.name] = ensureRemote(folder, spec)
    end
    return map :: any
end

function Remotes.waitFor(timeoutSec: number?): Types.RemoteMap
    local timeout = timeoutSec or 10
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, timeout)
    if not folder then error("Studio88Remotes folder never replicated") end
    local map = {}
    for _, spec in ipairs(REMOTE_NAMES) do
        local r = folder:WaitForChild(spec.name, timeout)
        if not r then error("Remote '" .. spec.name .. "' never replicated") end
        map[spec.name] = r
    end
    return map :: any
end

return Remotes
