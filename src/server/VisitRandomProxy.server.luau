--!strict
-- Visit Random Plot pad proxy. Listens for ProximityPrompt.Triggered on
-- the central pad (tagged Studio88VisitRandomPad). Picks a random
-- claimed plot anchor belonging to another player + delegates to
-- VisitService.attemptVisit (which has all the validation, cooldown,
-- and tip-both-sides logic).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local VisitService = require(script.Parent:WaitForChild("VisitService"))

local function pickRandomTarget(triggerer: Player): number?
    local candidates = {}
    for _, anchor in ipairs(CollectionService:GetTagged("Studio88PlotAnchor")) do
        local ownerId = anchor:GetAttribute("OwnerUserId")
        if ownerId and ownerId ~= triggerer.UserId then
            -- Verify owner is still in server (visiting offline is a no-op)
            if Players:GetPlayerByUserId(ownerId) then
                table.insert(candidates, ownerId)
            end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

local function bind(pad: BasePart)
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end
    prompt.Triggered:Connect(function(player)
        local target = pickRandomTarget(player)
        if not target then
            -- No other plots claimed; surface a brief reason to client?
            -- For now silent; visitor sees the pad but no target available.
            print(string.format("[VisitRandom] %s tapped pad but no other plots claimed",
                player.Name))
            return
        end
        VisitService.attemptVisit(player, target)
    end)
end

-- Wait for LobbyDecor to build, then bind
task.spawn(function()
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        local pads = CollectionService:GetTagged("Studio88VisitRandomPad")
        if #pads > 0 then
            for _, pad in ipairs(pads) do
                if pad:IsA("BasePart") then bind(pad) end
            end
            print(string.format("[VisitRandomProxy] bound %d random-visit pad(s)", #pads))
            return
        end
        task.wait(0.5)
    end
    warn("[VisitRandomProxy] no Studio88VisitRandomPad found after 30s")
end)
-- Pick up future pads (e.g. Hot Reload of LobbyDecor)
CollectionService:GetInstanceAddedSignal("Studio88VisitRandomPad"):Connect(function(inst)
    if inst:IsA("BasePart") then bind(inst :: BasePart) end
end)
