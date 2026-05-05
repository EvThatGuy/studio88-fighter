--!strict
-- Server-side upgrade purchase handler. Two entry points:
--   1. Client RemoteEvent (PurchaseUpgrade) -- legacy / programmatic
--   2. Direct attemptPurchase(player) call from UpgradeButtonProxy -- 3D
--      ProximityPrompt path. Same validation either way.
--
-- Validates funds against the *server's* cached balance, deducts cost,
-- increments tier, fires BalanceUpdated. Never trusts the client's
-- declared tier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local PlotAssigner = require(script.Parent:WaitForChild("PlotAssigner"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))
local DailyQuestService = require(script.Parent:WaitForChild("DailyQuestService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local AmbientAudio = require(script.Parent:WaitForChild("AmbientAudio"))

local remotes = Remotes.get()

-- Module-level table so other server scripts can require this file and call
-- the same validated logic. (require() returns this table.)
local UpgradeStation = {}

local function pushRejection(player: Player, reason: string, needed: number?)
    pcall(function()
        remotes.PurchaseRejected:FireClient(player, reason, needed)
    end)
end

function UpgradeStation.attemptPurchase(player: Player): (boolean, string?)
    local data = DataStore.getCached(player.UserId)
    if not data then
        pushRejection(player, "no_data")
        return false, "no_data"
    end
    local nextTier = data.upgradeTier + 1
    local tierSpec = Constants.UPGRADE_TIERS[nextTier]
    if not tierSpec then
        pushRejection(player, "max_tier")
        return false, "max_tier"
    end
    if data.coins < tierSpec.cost then
        pushRejection(player, "insufficient_coins", tierSpec.cost - data.coins)
        return false, "insufficient_coins"
    end
    data.coins -= tierSpec.cost
    data.upgradeTier = nextTier
    -- Push fresh balance immediately so HUD doesn't wait for next tick
    pcall(function()
        remotes.BalanceUpdated:FireClient(player, data.coins, data.lifetimeCoins)
    end)
    -- Repaint the plot to match the new tier and fire FX on the client
    local plot = PlotAssigner.getPlotFor(player.UserId)
    if plot then
        PlotAssigner.applyTierArt(plot, nextTier)
        PlotAssigner.updateStatsBoard(plot, nextTier, data.lifetimeCoins)
        -- Burst the upgrade button particle emitter for a celebratory pop.
        -- V62 nests the button in a Model — find UpgradeFX recursively so
        -- it works regardless of layout depth.
        local btn = plot:FindFirstChild("UpgradeButton")
        if btn then
            local fx = btn:FindFirstChild("UpgradeFX", true) :: ParticleEmitter?
            if fx then
                pcall(function() fx:Emit(30) end)
            end
            -- Tier-up celebration sound at the upgrade button position
            local soundAnchor = btn:IsA("BasePart") and btn or btn:FindFirstChildWhichIsA("BasePart", true)
            if soundAnchor then
                pcall(function() AmbientAudio.playSpatial("tier_up", soundAnchor, 0.5) end)
            end
        end
        -- Capstone fireworks: tier 6 = the visual peak. Spawn 5 short-lived
        -- particle bursts arrayed around the foundation, GC after 3.5s.
        if nextTier >= #Constants.UPGRADE_TIERS then
            pcall(function()
                local DiscordHook = require(script.Parent:WaitForChild("DiscordHook"))
                DiscordHook.publishCapstoneReach(player.Name, data.rebirths or 0)
            end)
            -- Server-wide chat announce so other players see social proof.
            -- Throttled to 1/min globally so a busy server doesn't spam
            -- (lastCapstoneAnnounceAt is a file-scope counter declared
            -- below in the require chain so all UpgradeStation calls share it).
            pcall(function()
                local TextChatService = game:GetService("TextChatService")
                local ch = TextChatService.TextChannels:FindFirstChild("RBXSystem")
                    or TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if ch and ch:IsA("TextChannel") then
                    local now = os.time()
                    if (now - (_G.Studio88LastCapstoneAnnounceAt or 0)) >= 60 then
                        _G.Studio88LastCapstoneAnnounceAt = now
                        ch:DisplaySystemMessage(string.format(
                            "🏆 %s reached the capstone tier (rebirth #%d)!",
                            player.Name, data.rebirths or 0
                        ))
                    end
                end
            end)
            local foundation = plot:FindFirstChild("Foundation") :: BasePart?
            if foundation then
                pcall(function()
                    local FOUNTAIN_COLORS = {
                        Color3.fromRGB(255, 215, 0),    -- gold
                        Color3.fromRGB(255, 46, 136),   -- pink
                        Color3.fromRGB(0, 240, 255),    -- cyan
                        Color3.fromRGB(255, 176, 0),    -- amber
                        Color3.fromRGB(255, 255, 255),  -- white
                    }
                    for i = 1, 5 do
                        local angle = math.rad((i - 1) * 72)
                        local fxAnchor = Instance.new("Part")
                        fxAnchor.Name = "CapstoneFx"
                        fxAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
                        fxAnchor.Position = foundation.Position + Vector3.new(
                            math.cos(angle) * 18,
                            foundation.Size.Y / 2 + 4,
                            math.sin(angle) * 18
                        )
                        fxAnchor.Anchored = true
                        fxAnchor.Transparency = 1
                        fxAnchor.CanCollide = false
                        fxAnchor.CanQuery = false
                        fxAnchor.CanTouch = false
                        fxAnchor.Parent = plot

                        local pe = Instance.new("ParticleEmitter")
                        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                        pe.LightEmission = 1
                        pe.Color = ColorSequence.new(FOUNTAIN_COLORS[i])
                        pe.Speed = NumberRange.new(14, 22)
                        pe.Lifetime = NumberRange.new(1.5, 2.5)
                        pe.Rate = 80
                        pe.SpreadAngle = Vector2.new(35, 35)
                        pe.Acceleration = Vector3.new(0, -10, 0)  -- arc back down
                        pe.Size = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.6),
                            NumberSequenceKeypoint.new(0.5, 1.4),
                            NumberSequenceKeypoint.new(1, 0.4),
                        })
                        pe.Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.2),
                            NumberSequenceKeypoint.new(0.6, 0.5),
                            NumberSequenceKeypoint.new(1, 1),
                        })
                        pe.Parent = fxAnchor

                        -- Stop emitting after 1.5s so total visual duration is ~3.5s
                        task.delay(1.5, function() if pe.Parent then pe.Enabled = false end end)
                        task.delay(4, function() if fxAnchor.Parent then fxAnchor:Destroy() end end)
                    end
                end)
                -- Capstone celebration sound — louder than regular tier-up
                pcall(function() AmbientAudio.playSpatial("rebirth", foundation, 0.7) end)
            end
        end
    end
    Leaderstats.refresh(player.UserId)
    pcall(function()
        remotes.TierUpgraded:FireClient(player, nextTier, tierSpec.incomeMult)
    end)
    DailyQuestService.bumpProgress(player.UserId,
        Constants.QUEST_KIND.TIER_UPS_TODAY, 1)
    TutorialService.advance(player.UserId, "04_first_upgrade")
    pcall(function()
        local XpService = require(script.Parent:WaitForChild("XpService"))
        XpService.award(player.UserId, "tier_up")
    end)
    pcall(function()
        local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
        AchievementService.evaluate(player.UserId)
    end)
    print(string.format("[UpgradeStation] %s -> tier %d (cost %d paid)",
        player.Name, nextTier, tierSpec.cost))
    return true, nil
end

-- RemoteEvent path (clients can still trigger if they have direct access)
remotes.PurchaseUpgrade.OnServerEvent:Connect(function(player: Player)
    local ok, reason = UpgradeStation.attemptPurchase(player)
    if not ok then
        warn(string.format("[UpgradeStation] %s purchase rejected: %s",
            player.Name, reason or "?"))
    end
end)

print("[UpgradeStation] ready (" .. (#Constants.UPGRADE_TIERS - 1) .. " tier upgrades)")

return UpgradeStation
