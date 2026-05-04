--!strict
-- Top-left "next session bonus" countdown card. Tells players how long
-- until the next 15/30/60-min session-time bonus drops, so they don't
-- leave session right before earning a chunk of coins. Sits below the
-- presence badge.
--
-- Polls GetSessionBonus every 5s to get authoritative activeSeconds
-- (server gates AFK), and ticks down locally between polls. Re-polls on
-- SessionBonusGranted to advance to the next tier instantly.
--
-- Hidden when all tiers are claimed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local SURFACE = Color3.fromRGB(20, 17, 31)
local DIM = Color3.fromRGB(180, 180, 195)

local cardRef: Frame? = nil
local titleRef: TextLabel? = nil
local subRef: TextLabel? = nil
local strokeRef: UIStroke? = nil

-- snapshot
local activeSeconds = 0
local tiers: {{ seconds: number, reward: number, label: string, claimed: boolean }} = {}
local lastPollAt = os.clock()

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(math.floor(n)) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.1fM", n / 1000000)
end

local function fmtTime(s: number): string
    if s < 0 then s = 0 end
    if s < 60 then return string.format("%ds", math.ceil(s)) end
    local m = math.floor(s / 60)
    local rem = math.floor(s - m * 60)
    return string.format("%d:%02d", m, rem)
end

local function nextTier()
    for _, t in ipairs(tiers) do
        if not t.claimed then return t end
    end
    return nil
end

local function makeCard()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88SessionBonus")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88SessionBonus"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 71
    sg.Parent = pg

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0, 0)
    card.Position = UDim2.new(0, 16, 0, 184)  -- below presence badge (y=144 + 32 + 8 spacing)
    card.Size = UDim2.new(0, 200, 0, 48)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Visible = false
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card
    strokeRef = stroke

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 18)
    title.Position = UDim2.new(0, 8, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "NEXT BONUS"
    title.TextColor3 = CYAN
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card
    titleRef = title

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -16, 0, 22)
    sub.Position = UDim2.new(0, 8, 0, 22)
    sub.BackgroundTransparency = 1
    sub.Text = "+0 in 0:00"
    sub.TextColor3 = AMBER
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = card
    subRef = sub

    cardRef = card
end

local function applyState()
    if not cardRef or not cardRef.Parent or not titleRef or not subRef or not strokeRef then return end
    local nt = nextTier()
    if not nt then
        cardRef.Visible = false
        return
    end
    cardRef.Visible = true
    local remaining = nt.seconds - activeSeconds
    if remaining < 0 then remaining = 0 end
    titleRef.Text = string.format("NEXT BONUS — %s", nt.label or "")
    subRef.Text = string.format("+%s in %s", fmtCoins(nt.reward), fmtTime(remaining))
    -- Color shifts to amber under 60s, white-amber otherwise
    if remaining <= 60 then
        subRef.TextColor3 = AMBER
        strokeRef.Color = AMBER
        strokeRef.Transparency = 0.2
    else
        subRef.TextColor3 = AMBER
        strokeRef.Color = CYAN
        strokeRef.Transparency = 0.4
    end
end

local function poll()
    local ok, snap = pcall(function() return remotes.GetSessionBonus:InvokeServer() end)
    if not ok or typeof(snap) ~= "table" then return end
    activeSeconds = tonumber(snap.activeSeconds) or 0
    tiers = {}
    if typeof(snap.tiers) == "table" then
        for _, t in ipairs(snap.tiers) do
            table.insert(tiers, {
                seconds = tonumber(t.seconds) or 0,
                reward = tonumber(t.reward) or 0,
                label = tostring(t.label or ""),
                claimed = t.claimed == true,
            })
        end
    end
    lastPollAt = os.clock()
    applyState()
end

makeCard()

-- Initial poll, then every 5s
task.spawn(function()
    task.wait(2)  -- let leaderstats + presence badge render first
    poll()
    while true do
        task.wait(5)
        poll()
    end
end)

-- Local 1Hz tick: extrapolate activeSeconds between server polls so the
-- countdown feels live rather than jumping every 5s.
task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = os.clock() - lastPollAt
        local extrap = activeSeconds + elapsed
        local nt = nextTier()
        if nt and subRef and cardRef and cardRef.Parent then
            local remaining = nt.seconds - extrap
            if remaining < 0 then remaining = 0 end
            subRef.Text = string.format("+%s in %s", fmtCoins(nt.reward), fmtTime(remaining))
            if remaining <= 60 and strokeRef then
                strokeRef.Color = AMBER
                strokeRef.Transparency = 0.2
            end
        end
    end
end)

-- On grant, immediately mark tier claimed locally (server snapshot will
-- confirm on next poll) so countdown jumps to next tier without waiting.
remotes.SessionBonusGranted.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    local idx = tonumber(payload.tierIdx)
    if idx and tiers[idx] then
        tiers[idx].claimed = true
    end
    -- Force a fresh poll after a tier grant; server may have advanced.
    poll()
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    makeCard()
    applyState()
end)

print("[SessionBonusCountdown] client ready")
