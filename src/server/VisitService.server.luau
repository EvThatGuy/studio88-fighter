--!strict
-- Visit Plot. Lets a player teleport their character above another
-- player's plot Foundation in the same server. Server-authoritative
-- with a per-user cooldown to prevent abuse.
--
-- Compounds with the social-proof cosmetic stack: visiting a player
-- shows you their pet stand, equipped aura, equipped title, and any
-- crown they're wearing -- the payoff for the whole flex pipeline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner.server"))

local remotes = Remotes.get()

local VisitService = {}

-- userId -> last visit unix
local lastVisit: {[number]: number} = {}

local function pushReject(player: Player, reason: string, retryInSec: number?)
    pcall(function()
        remotes.VisitRejected:FireClient(player, reason, retryInSec)
    end)
end

function VisitService.attemptVisit(player: Player, targetUserId: any): (boolean, string?)
    if typeof(targetUserId) ~= "number" then
        pushReject(player, "bad_request")
        return false, "bad_request"
    end
    local now = os.time()
    local last = lastVisit[player.UserId] or 0
    local elapsed = now - last
    if elapsed < Constants.VISIT_COOLDOWN_SEC then
        pushReject(player, "cooldown", Constants.VISIT_COOLDOWN_SEC - elapsed)
        return false, "cooldown"
    end
    if targetUserId == player.UserId then
        pushReject(player, "is_self")
        return false, "is_self"
    end
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then
        pushReject(player, "not_in_server")
        return false, "not_in_server"
    end
    local plot = PlotAssigner.getPlotFor(targetUserId)
    if not plot then
        pushReject(player, "no_plot")
        return false, "no_plot"
    end
    local foundation = plot:FindFirstChild("Foundation") :: BasePart?
    if not foundation then
        pushReject(player, "no_foundation")
        return false, "no_foundation"
    end
    local char = player.Character
    if not char then
        pushReject(player, "no_character")
        return false, "no_character"
    end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then
        pushReject(player, "no_hrp")
        return false, "no_hrp"
    end
    -- Teleport: above the foundation so we don't clip into the floor or
    -- collide with droppers/collectors. SetPrimaryPartCFrame works for
    -- both seated and free-floating characters.
    local landingCFrame = CFrame.new(foundation.Position
        + Vector3.new(0, Constants.VISIT_HEIGHT_OFFSET, 0))
    char:PivotTo(landingCFrame)
    lastVisit[player.UserId] = now
    print(string.format("[VisitService] %s -> %s's plot",
        player.Name, target.Name))
    return true, nil
end

remotes.VisitPlayer.OnServerEvent:Connect(function(player: Player, targetUserId: any)
    VisitService.attemptVisit(player, targetUserId)
end)

Players.PlayerRemoving:Connect(function(p)
    lastVisit[p.UserId] = nil
end)

print(string.format("[VisitService] ready (cooldown %ds)", Constants.VISIT_COOLDOWN_SEC))

return VisitService
