--!strict
-- Map rotation registry. Reads Constants.MAPS, exposes pickNext() for
-- MatchService to call between rounds. Phase 2 wires real maps cloned
-- from ServerStorage into Workspace; until then this hands back stub
-- entries so the data path is exercised.

local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Constants = require(Modules:WaitForChild("Constants"))

local MapRotation = {}

local lastIndex = 0

function MapRotation.pickNext(): {id: string, displayName: string}
    if #Constants.MAPS == 0 then
        return {id = "none", displayName = "No Map Configured"}
    end
    lastIndex = (lastIndex % #Constants.MAPS) + 1
    return Constants.MAPS[lastIndex]
end

function MapRotation.list()
    return Constants.MAPS
end

return MapRotation
