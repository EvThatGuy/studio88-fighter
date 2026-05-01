--!strict
-- Renders earned-title BillboardGui above each player's character. Listens
-- for TitleReplicate broadcasts. Sister to AuraRenderer; visual-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local remotes = Remotes.waitFor()

local BB_NAME = "Studio88TitleBB"
local TITLE_OFFSET = Vector3.new(0, 3.5, 0) -- studs above HRP (above the default nametag)

-- userId -> {titleId, name, color={r,g,b}}
local userTitle: {[number]: any} = {}

local function findHRP(player: Player): BasePart?
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clearTitle(player: Player)
    local hrp = findHRP(player)
    if not hrp then return end
    local existing = hrp:FindFirstChild(BB_NAME)
    if existing then existing:Destroy() end
end

local function applyTitle(player: Player, payload: any)
    local hrp = findHRP(player)
    if not hrp then return end
    local existing = hrp:FindFirstChild(BB_NAME)
    if existing then existing:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = BB_NAME
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 200, 0, 28)
    bb.StudsOffset = TITLE_OFFSET
    bb.AlwaysOnTop = true
    bb.MaxDistance = 80
    bb.Parent = hrp

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "[ " .. (payload.name or payload.titleId or "?") .. " ]"
    if payload.color then
        lbl.TextColor3 = Color3.fromRGB(payload.color[1], payload.color[2], payload.color[3])
    else
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    lbl.TextStrokeTransparency = 0.2
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Parent = bb
end

local function refreshFor(userId: number)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    local data = userTitle[userId]
    if data and data.titleId then
        applyTitle(player, data)
    else
        clearTitle(player)
    end
end

remotes.TitleReplicate.OnClientEvent:Connect(function(userId: number, titleId: string?, name: string?, color: {number}?)
    userTitle[userId] = titleId and { titleId = titleId, name = name, color = color } or nil
    task.spawn(function()
        for _ = 1, 5 do
            local player = Players:GetPlayerByUserId(userId)
            if player and findHRP(player) then
                refreshFor(userId)
                return
            end
            task.wait(0.4)
        end
    end)
end)

local function onCharacterAdded(player: Player)
    return function()
        task.wait(0.5)
        refreshFor(player.UserId)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(onCharacterAdded(p))
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(onCharacterAdded(p))
end)

Players.PlayerRemoving:Connect(function(p)
    userTitle[p.UserId] = nil
end)

print("[TitleRenderer] mounted")
