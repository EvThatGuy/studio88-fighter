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
    -- Safety despawn
    task.delay(COIN_LIFETIME_SEC, function()
        if coin.Parent then coin:Destroy() end
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
                    -- Find the emitter sibling of this dropper
                    local plot = dropper.Parent
                    local emitter = plot and plot:FindFirstChild("Emitter") :: BasePart?
                    if emitter then
                        spawnCoin(emitter, player.UserId, data.upgradeTier)
                        TutorialService.advance(player.UserId, "02_first_coin_spawned")
                    end
                end
            end
        end
    end
end

task.spawn(loop)
print("[Dropper] online; spawning coins per " .. Constants.TICK_SECONDS .. "s")
