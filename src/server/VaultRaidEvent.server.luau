--!strict
-- Vault Raid event. Periodic in-server boss that spawns at the lobby
-- pedestal. Players touch it to tag; boss is "killed" when N distinct
-- players have tagged it OR after a timeout. Coin pool splits among
-- taggers proportional to their tag count.
--
-- Per checklist: in-server raids drive social play. Boss is purely
-- additive — no PvP between players, no plot disruption.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))
local Leaderstats = require(script.Parent:WaitForChild("Leaderstats"))

local remotes = Remotes.get()

local CYAN = Color3.fromRGB(0, 240, 255)
local PINK = Color3.fromRGB(255, 46, 136)
local AMBER = Color3.fromRGB(255, 176, 0)
local DARK = Color3.fromRGB(8, 7, 13)

local activeBoss: Model? = nil
local tagCounts: {[number]: number} = {}
local lastTagAt: {[number]: number} = {}
local raidStartedAt = 0

local function buildBoss(): Model
    local model = Instance.new("Model")
    model.Name = "VaultRaider"

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(5, Constants.VAULT_RAID.BOSS_HEIGHT, 5)
    body.Position = Constants.VAULT_RAID.SPAWN_POSITION
    body.Anchored = true
    body.CanCollide = true
    body.Material = Enum.Material.Neon
    body.Color = PINK
    body.Transparency = 0.1
    body.Parent = model
    model.PrimaryPart = body

    local cap = Instance.new("Part")
    cap.Name = "Cap"
    cap.Size = Vector3.new(6, 2, 6)
    cap.Position = body.Position + Vector3.new(0, Constants.VAULT_RAID.BOSS_HEIGHT/2 + 1, 0)
    cap.Anchored = true
    cap.CanCollide = false
    cap.Material = Enum.Material.Neon
    cap.Color = CYAN
    cap.Shape = Enum.PartType.Ball
    cap.Parent = model

    local crown = Instance.new("Part")
    crown.Name = "Crown"
    crown.Size = Vector3.new(0.1, 0.1, 0.1)
    crown.Position = body.Position + Vector3.new(0, Constants.VAULT_RAID.BOSS_HEIGHT/2 + 4, 0)
    crown.Anchored = true
    crown.Transparency = 1
    crown.CanCollide = false
    crown.Parent = model
    local bb = Instance.new("BillboardGui")
    bb.Adornee = crown
    bb.Size = UDim2.new(0, 240, 0, 80)
    bb.AlwaysOnTop = true
    bb.Parent = crown
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text = "★ VAULT RAIDER ★"
    title.TextColor3 = AMBER
    title.TextStrokeTransparency = 0.2
    title.TextStrokeColor3 = DARK
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Parent = bb
    local sub = Instance.new("TextLabel")
    sub.Name = "TagCount"
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.BackgroundTransparency = 1
    sub.Text = "Tag to claim a share!"
    sub.TextColor3 = Color3.fromRGB(255, 255, 255)
    sub.TextStrokeTransparency = 0.4
    sub.Font = Enum.Font.Code
    sub.TextScaled = true
    sub.Parent = bb

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.LightEmission = 1
    pe.Color = ColorSequence.new(AMBER, PINK)
    pe.Speed = NumberRange.new(2, 5)
    pe.Lifetime = NumberRange.new(0.8, 1.6)
    pe.Rate = 24
    pe.SpreadAngle = Vector2.new(40, 40)
    pe.Acceleration = Vector3.new(0, 4, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1.4),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.Parent = body

    local pl = Instance.new("PointLight")
    pl.Brightness = 4
    pl.Range = 30
    pl.Color = AMBER
    pl.Parent = body

    CollectionService:AddTag(body, "Studio88VaultBoss")
    return model
end

local function distributeRewards()
    if not activeBoss then return end
    local pool = Constants.VAULT_RAID.COIN_POOL
    local totalTags = 0
    for _, n in pairs(tagCounts) do totalTags += n end
    if totalTags == 0 then return end
    local results = {}
    for userId, n in pairs(tagCounts) do
        local share = math.floor(pool * n / totalTags)
        local data = DataStore.getCached(userId)
        if data then
            data.coins += share
            data.lifetimeCoins += share
            Leaderstats.refresh(userId)
            local p = Players:GetPlayerByUserId(userId)
            if p then
                pcall(function()
                    remotes.BalanceUpdated:FireClient(p, data.coins, data.lifetimeCoins)
                end)
            end
        end
        table.insert(results, {userId = userId, tags = n, share = share})
        print(string.format("[VaultRaid] userId %d +%d coins (%d tags)", userId, share, n))
        -- XP for raid participation (1500 per Constants.XP_REWARDS)
        pcall(function()
            local XpService = require(script.Parent:WaitForChild("XpService"))
            XpService.award(userId, "raid_kill")
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.VaultRaidEnded:FireClient(p, {totalTags = totalTags, results = results, pool = pool})
        end)
    end
end

local function endRaid(reason: string)
    if not activeBoss then return end
    local distinct = 0
    for _ in pairs(tagCounts) do distinct += 1 end
    print(string.format("[VaultRaid] ended: %s (%d unique taggers, %ds duration)",
        reason, distinct, os.time() - raidStartedAt))
    distributeRewards()
    if reason ~= "timeout" then
        local totalTags = 0
        for _, n in pairs(tagCounts) do totalTags += n end
        pcall(function()
            local DiscordHook = require(script.Parent:WaitForChild("DiscordHook"))
            DiscordHook.publishRaidKill(distinct, totalTags, Constants.VAULT_RAID.COIN_POOL)
        end)
    end
    if activeBoss.Parent then activeBoss:Destroy() end
    activeBoss = nil
    tagCounts = {}
    lastTagAt = {}
end

local function onBossTouched(hit: BasePart)
    local char = hit:FindFirstAncestorOfClass("Model")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local player = Players:GetPlayerFromCharacter(char)
    if not player then return end
    local now = os.time()
    if (now - (lastTagAt[player.UserId] or 0)) < Constants.VAULT_RAID.TAG_COOLDOWN_SEC then return end
    lastTagAt[player.UserId] = now
    tagCounts[player.UserId] = (tagCounts[player.UserId] or 0) + 1
    if activeBoss then
        for _, child in ipairs(activeBoss:GetDescendants()) do
            if child.Name == "TagCount" and child:IsA("TextLabel") then
                local distinct = 0
                for _ in pairs(tagCounts) do distinct += 1 end
                child.Text = string.format("%d players tagging!", distinct)
            end
        end
    end
    local distinct = 0
    for _ in pairs(tagCounts) do distinct += 1 end
    if distinct >= Constants.VAULT_RAID.KILL_TAGS then
        endRaid("killed by " .. distinct .. " players")
    end
end

local function startRaid()
    if activeBoss then return end
    activeBoss = buildBoss()
    activeBoss.Parent = Workspace
    tagCounts = {}
    lastTagAt = {}
    raidStartedAt = os.time()
    local body = activeBoss:FindFirstChild("Body") :: BasePart?
    if body then body.Touched:Connect(onBossTouched) end
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.VaultRaidSpawned:FireClient(p, {
                position = Constants.VAULT_RAID.SPAWN_POSITION,
                pool = Constants.VAULT_RAID.COIN_POOL,
                timeoutSec = Constants.VAULT_RAID.TIMEOUT_SEC,
            })
        end)
    end
    print(string.format("[VaultRaid] SPAWNED (pool %d, timeout %ds)",
        Constants.VAULT_RAID.COIN_POOL, Constants.VAULT_RAID.TIMEOUT_SEC))
    -- System chat broadcast so players away from the lobby know to come.
    -- TextChatService is the modern API; falls back to legacy chat if disabled.
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local generalChannel = TextChatService.TextChannels:FindFirstChild("RBXSystem")
            or TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if generalChannel and generalChannel:IsA("TextChannel") then
            generalChannel:DisplaySystemMessage(string.format(
                "★ A Vault Raider has appeared at the lobby! Tag for $%d pool (%ds)",
                Constants.VAULT_RAID.COIN_POOL, Constants.VAULT_RAID.TIMEOUT_SEC
            ))
        end
    end)
    task.delay(Constants.VAULT_RAID.TIMEOUT_SEC, function()
        if activeBoss then endRaid("timeout") end
    end)
end

task.spawn(function()
    task.wait(120)  -- initial settle
    while true do
        if #Players:GetPlayers() >= 1 then
            startRaid()
        end
        task.wait(Constants.VAULT_RAID.INTERVAL_SEC)
    end
end)

print(string.format("[VaultRaidEvent] armed (interval %ds, pool %d)",
    Constants.VAULT_RAID.INTERVAL_SEC, Constants.VAULT_RAID.COIN_POOL))
