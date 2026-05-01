--!strict
-- Collectors listen for Touched events from Studio88Coin parts. On hit:
-- credit the coin's Value to the owner's balance + lifetime, fire
-- BalanceUpdated, despawn the coin. Server-authoritative — clients can't
-- spawn coins because the Coin attribute "OwnerUserId" is server-set.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner.server"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats.server"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService.server"))

local remotes = Remotes.get()

local function onCollect(collector: BasePart, hit: BasePart)
    if not CollectionService:HasTag(hit, "Studio88Coin") then return end
    local ownerUserId = hit:GetAttribute("OwnerUserId")
    local value = hit:GetAttribute("Value") or 1
    if not ownerUserId then
        hit:Destroy()
        return
    end
    -- Make sure the collector belongs to the same player as the coin --
    -- prevents cross-plot cheese where one player's coin lands in another's
    -- collector.
    if collector:GetAttribute("OwnerUserId") ~= ownerUserId then
        return
    end
    local data = DataStore.getCached(ownerUserId)
    if not data then
        hit:Destroy()
        return
    end
    data.coins += value
    data.lifetimeCoins += value
    hit:Destroy()

    -- Burst the collector's particle emitter so the eye sees the credit land
    local fx = collector:FindFirstChild("CollectFX") :: ParticleEmitter?
    if fx then
        pcall(function() fx:Emit(8) end)
    end

    -- Refresh the plot's stats board with the new lifetime total. This is
    -- per-collect so it spams a bit; UpdateStatsBoard is a string-set on a
    -- TextLabel, cheap. If a future profiling pass shows it's hot we can
    -- throttle to once per second.
    local plot = PlotAssigner.getPlotFor(ownerUserId)
    if plot then
        PlotAssigner.updateStatsBoard(plot, data.upgradeTier, data.lifetimeCoins)
    end

    Leaderstats.refresh(ownerUserId)

    local player = Players:GetPlayerByUserId(ownerUserId)
    if player then
        pcall(function()
            remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
        end)
    end

    -- Daily quest hook: each collected drop counts as 1 toward
    -- collect-N-drops-today. Conveyor coins arrive at ~1/sec at tier 1,
    -- so a 25-drop easy quest finishes inside ~30 seconds at the door.
    DailyQuestService.bumpProgress(ownerUserId,
        Constants.QUEST_KIND.COLLECT_DROPS_TODAY, 1)
end

local function bind(collector: BasePart)
    collector.Touched:Connect(function(hit) onCollect(collector, hit) end)
end

-- Bind to existing + future collectors
for _, c in ipairs(CollectionService:GetTagged("Studio88Collector")) do
    if c:IsA("BasePart") then bind(c) end
end
CollectionService:GetInstanceAddedSignal("Studio88Collector"):Connect(function(inst)
    if inst:IsA("BasePart") then bind(inst :: BasePart) end
end)

print("[Collector] bound to all Studio88Collector parts")
