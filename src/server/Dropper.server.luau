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
local DataStore = require(script.Parent:WaitForChild("DataStore.server"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService.server"))

local COIN_LIFETIME_SEC = 30  -- safety despawn if it slides off
local COIN_VALUE_BY_TIER = {1, 2, 5, 12, 30, 80}  -- mirrors UPGRADE_TIERS incomeMult

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local GOLD = Color3.fromRGB(255, 215, 0)

local function colorForTier(tier: number): Color3
    if tier >= 5 then return GOLD
    elseif tier >= 4 then return PINK
    elseif tier >= 3 then return AMBER
    else return CYAN end
end

local function spawnCoin(emitter: BasePart, ownerUserId: number, tier: number)
    local coin = Instance.new("Part")
    coin.Name = "Studio88Coin"
    coin.Shape = Enum.PartType.Ball
    coin.Size = Vector3.new(1.2, 1.2, 1.2)
    coin.Position = emitter.Position
    coin.Material = Enum.Material.Neon
    coin.Color = colorForTier(tier)
    coin.TopSurface = Enum.SurfaceType.Smooth
    coin.BottomSurface = Enum.SurfaceType.Smooth
    coin.CanCollide = true
    coin:SetAttribute("OwnerUserId", ownerUserId)
    coin:SetAttribute("Value", COIN_VALUE_BY_TIER[math.clamp(tier, 1, #COIN_VALUE_BY_TIER)])
    coin:SetAttribute("Tier", tier)
    CollectionService:AddTag(coin, "Studio88Coin")

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
