--!strict
-- Spawns "coin" parts on a timer at each plot's Emitter point. The coins
-- ride the conveyor (SurfaceVelocity), touch the Collector, grant balance,
-- despawn. Coin spawn rate scales with the owner's upgrade tier so the
-- visual feedback matches the actual income.
--
-- A coin is a 1-stud sphere coloured by tier (cyan -> amber -> pink). It
-- has its `OwnerUserId` attribute set so the Collector knows whose balance
-- to credit when touched.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local CoinModel = require(script.Parent:WaitForChild("Visuals"):WaitForChild("CoinModel"))

-- Per-player counter of how many of their first-3 coins have been
-- auto-credited (without the player needing to walk to the conveyor).
-- Cleared on PlayerRemoving so re-joins re-trigger the FTUE assist.
-- Solves the D1 hook problem where new players bounce in <30s before
-- their first coin reaches the collector naturally.
local FTUE_AUTO_COLLECT_COUNT = 3
local FTUE_AUTO_COLLECT_VALUE = 50  -- credit a slightly-bigger first coin so the +N feels noticeable
local autoCollected: {[number]: number} = {}
Players.PlayerRemoving:Connect(function(p) autoCollected[p.UserId] = nil end)

local COIN_LIFETIME_SEC = 30  -- safety despawn if it slides off
local COIN_VALUE_BY_TIER = {1, 2, 5, 12, 30, 80}  -- mirrors UPGRADE_TIERS incomeMult

local function spawnCoin(emitter: BasePart, ownerUserId: number, tier: number)
    -- CoinModel.build returns a coin Part already tagged Studio88Coin and
    -- styled per tier (cylinder disc + glowing rim + sparkle). We attach
    -- ownership + value attributes here; collector logic stays unchanged.
    local coin = CoinModel.build(tier)
    coin.Position = emitter.Position
    coin:SetAttribute("OwnerUserId", ownerUserId)
    coin:SetAttribute("Value", COIN_VALUE_BY_TIER[math.clamp(tier, 1, #COIN_VALUE_BY_TIER)])
    coin:SetAttribute("Tier", tier)

    -- Kick it forward so it rides the conveyor's surface velocity
    local push = Instance.new("BodyVelocity")
    push.MaxForce = Vector3.new(1e5, 0, 1e5)
    push.Velocity = Vector3.new(8, 0, 0)
    push.P = 5000
    push.Parent = coin

    coin.Parent = Workspace

    -- Velocity assist for ~1s, then let physics take over
    task.delay(1, function() if push.Parent then push:Destroy() end end)
    -- Safety despawn with a brief poof so unclaimed coins fade visibly
    -- instead of vanishing silently. Keeps animation cost minimal: 1
    -- particle Emit() then GC.
    task.delay(COIN_LIFETIME_SEC, function()
        if not coin.Parent then return end
        local sparkle = coin:FindFirstChildWhichIsA("ParticleEmitter")
        if sparkle then pcall(function() sparkle:Emit(8) end) end
        task.delay(0.4, function() if coin.Parent then coin:Destroy() end end)
    end)
end

local function ownerOf(part: BasePart): Player?
    local userId = part:GetAttribute("OwnerUserId")
    if not userId then return nil end
    return Players:GetPlayerByUserId(userId)
end

-- --- main loop -------------------------------------------------------------

local function loop()
    while true do
        task.wait(Constants.TICK_SECONDS)
        for _, dropper in ipairs(CollectionService:GetTagged("Studio88Dropper")) do
            local player = ownerOf(dropper)
            if player then
                local data = DataStore.getCached(player.UserId)
                if data then
                    -- Walk up to the Plot model (named "Plot_<userId>"). In V62
                    -- the dropper Body is nested in a Dropper Model, so Emitter
                    -- is a grandparent-sibling, not a direct sibling. Use
                    -- FindFirstAncestor on the player's plot to be robust to
                    -- either nesting depth.
                    local plot = dropper:FindFirstAncestor("Plot_" .. player.UserId)
                    local emitter = plot and plot:FindFirstChild("Emitter") :: BasePart?
                    if emitter then
                        spawnCoin(emitter, player.UserId, data.upgradeTier)
                        TutorialService.advance(player.UserId, "02_first_coin_spawned")
                        -- FTUE D1 hook: auto-credit the player's first 3
                        -- coins so they see the +N text + balance increment
                        -- without needing to reach the conveyor. New players
                        -- bounce in <30s on average; manually walking 18
                        -- studs from spawn to conveyor is ~6 of those seconds.
                        local count = autoCollected[player.UserId] or 0
                        if count < FTUE_AUTO_COLLECT_COUNT then
                            autoCollected[player.UserId] = count + 1
                            data.coins += FTUE_AUTO_COLLECT_VALUE
                            data.lifetimeCoins += FTUE_AUTO_COLLECT_VALUE
                            -- Push balance update + use the existing
                            -- CoinCollectedFx so the floating "+N" plays
                            -- at the dropper position
                            local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
                            local remotes = Remotes.get()
                            pcall(function()
                                remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
                                remotes.CoinCollectedFx:FireClient(player, {
                                    value = FTUE_AUTO_COLLECT_VALUE,
                                    tier = data.upgradeTier,
                                    worldPos = dropper.Position,
                                })
                            end)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(loop)
print("[Dropper] online; spawning coins per " .. Constants.TICK_SECONDS .. "s")
