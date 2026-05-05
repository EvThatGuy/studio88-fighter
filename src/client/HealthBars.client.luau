--!strict
-- Renders a slim health bar above every player's character (including
-- the local player). Pure client-side; reads Humanoid.Health each
-- HealthChanged. Self-cleans when characters get destroyed.

local Players = game:GetService("Players")

local LOCAL_USERID = Players.LocalPlayer.UserId

local PINK = Color3.fromRGB(255, 46, 136)
local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local RED = Color3.fromRGB(255, 80, 80)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function attach(humanoid: Humanoid, character: Model, isLocal: boolean)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then return end

    -- Avoid duplicates if attach() runs twice (e.g. from multiple events)
    if head:FindFirstChild("Studio88_HealthBar") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Studio88_HealthBar"
    billboard.Size = UDim2.fromOffset(120, 18)
    billboard.StudsOffset = Vector3.new(0, 2.4, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 100
    billboard.Parent = head

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = SURFACE
    backdrop.BackgroundTransparency = 0.25
    backdrop.BorderSizePixel = 0
    backdrop.Parent = billboard

    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 4)
    backCorner.Parent = backdrop

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = isLocal and CYAN or PINK
    fill.BorderSizePixel = 0
    fill.Parent = backdrop

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    local function update()
        local hp = humanoid.Health
        local mx = humanoid.MaxHealth
        if mx <= 0 then
            fill.Size = UDim2.fromScale(0, 1)
            return
        end
        local frac = math.clamp(hp / mx, 0, 1)
        fill.Size = UDim2.fromScale(frac, 1)
        if frac < 0.25 then
            fill.BackgroundColor3 = RED
        elseif frac < 0.5 then
            fill.BackgroundColor3 = AMBER
        else
            fill.BackgroundColor3 = isLocal and CYAN or PINK
        end
    end
    update()
    humanoid.HealthChanged:Connect(update)
    humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
end

local function bindCharacter(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then return end
    -- Wait for Head to exist; on first spawn it can lag the Humanoid by a frame.
    if not character:FindFirstChild("Head") then
        character:WaitForChild("Head", 5)
    end
    attach(humanoid, character, player.UserId == LOCAL_USERID)
end

local function bindPlayer(player: Player)
    if player.Character then bindCharacter(player, player.Character) end
    player.CharacterAdded:Connect(function(character)
        bindCharacter(player, character)
    end)
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end
