--!strict
-- Ability runtime. Phase 3 designs an `AbilitySpec` typed shape (charge,
-- cooldown, cost, effect) and registers per-class abilities. Until then
-- this is a stub that accepts AbilityRequest events and rejects them all
-- with a "not implemented" log so the wire is exercised.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Remotes"))

local remotes = Remotes.get()

local AbilityRuntime = {}

remotes.AbilityRequest.OnServerEvent:Connect(function(player: Player, abilityId: any)
    -- Phase 3: validate abilityId against class registry, check cooldown +
    -- stamina + casting state, run effect.
    if typeof(abilityId) ~= "string" then return end
    -- no-op for now
end)

return AbilityRuntime
