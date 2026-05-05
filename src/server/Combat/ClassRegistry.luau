--!strict
-- Authoritative source for fighter classes at runtime. Reads
-- Constants.CLASSES, applies per-player class selection, and exposes
-- per-character stats (walkspeed, stamina cap, base punch damage).
--
-- Stub: Phase 1 wires SelectClass / ClassSelected remotes and applies
-- walkspeed on character spawn. Until then, every player runs as the
-- default class.

local Players = game:GetService("Players")

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))
local Remotes = require(Modules:WaitForChild("Remotes"))

local DataStore = require(script.Parent.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local ClassRegistry = {}

function ClassRegistry.classFor(userId: number)
    local data = DataStore.getCached(userId)
    local classId = (data and data.selectedClass) or Constants.DEFAULT_CLASS
    return Constants.CLASSES[classId] or Constants.CLASSES[Constants.DEFAULT_CLASS]
end

function ClassRegistry.applyToCharacter(player: Player, character: Model)
    local class = ClassRegistry.classFor(player.UserId)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = class.walkspeed
        humanoid.JumpHeight = Constants.BASE_JUMP_HEIGHT
        humanoid.UseJumpPower = false
    end
end

-- Pushes the OpenClassSelect prompt to the client if the player has never
-- explicitly chosen a class. Spawned in a task because waitForCached
-- yields up to ~10s while DataStore's GetAsync resolves.
local function maybePromptClassSelect(player: Player)
    task.spawn(function()
        local data = DataStore.waitForCached(player.UserId, 10)
        if not data then return end
        if data.hasChosenClass then return end
        if not player.Parent then return end -- left mid-load
        remotes.OpenClassSelect:FireClient(player)
    end)
end

local function bindCharacterEvents(player: Player)
    if player.Character then
        ClassRegistry.applyToCharacter(player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        ClassRegistry.applyToCharacter(player, character)
    end)
    maybePromptClassSelect(player)
end

Players.PlayerAdded:Connect(bindCharacterEvents)
for _, player in ipairs(Players:GetPlayers()) do
    bindCharacterEvents(player)
end

remotes.SelectClass.OnServerEvent:Connect(function(player: Player, classId: any)
    if typeof(classId) ~= "string" then return end
    if not Constants.CLASSES[classId] then return end
    local data = DataStore.getCached(player.UserId)
    if not data then return end
    data.selectedClass = classId
    data.hasChosenClass = true
    if player.Character then
        ClassRegistry.applyToCharacter(player, player.Character)
    end
    remotes.ClassSelected:FireClient(player, { classId = classId })
end)

remotes.GetClasses.OnServerInvoke = function(_player: Player)
    local list = {}
    for key, class in pairs(Constants.CLASSES) do
        table.insert(list, {
            id = class.id,
            key = key,
            displayName = class.displayName,
            walkspeed = class.walkspeed,
            staminaMax = class.staminaMax,
            punchDamage = class.punchDamage,
            blurb = class.blurb,
        })
    end
    return list
end

return ClassRegistry
