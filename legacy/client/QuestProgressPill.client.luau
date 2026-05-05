--!strict
-- Top-right "active quest" pill. Surfaces the ONE quest closest to
-- completion (or first un-claimed if none in progress) so players see
-- visible forward motion as they play. Hidden when all 3 daily quests
-- are claimed.
--
-- Snapshot polled every 6s + reflected on QuestProgressed/QuestClaimed
-- pushes for instant feedback. Click opens the full Daily Quests modal
-- via a chat command fallback (HUD already wires the modal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local CYAN = Color3.fromRGB(0, 240, 255)
local AMBER = Color3.fromRGB(255, 176, 0)
local GREEN = Color3.fromRGB(80, 220, 120)
local SURFACE = Color3.fromRGB(20, 17, 31)

local cardRef: Frame? = nil
local titleRef: TextLabel? = nil
local barBgRef: Frame? = nil
local barFillRef: Frame? = nil
local strokeRef: UIStroke? = nil

type Quest = {
    id: string, kind: string, target: number, reward: number,
    label: string, progress: number, claimed: boolean, complete: boolean,
}
local quests: { Quest } = {}

local function fmt(n: number): string
    if n < 1000 then return tostring(math.floor(n)) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.1fM", n / 1000000)
end

-- Pick the active quest to surface:
-- 1. If any unclaimed-but-complete -> show it (urgent, "CLAIM!")
-- 2. Else closest to completion (highest progress/target ratio) un-claimed
-- 3. Else nil = hide
local function pickActive(): Quest?
    local readyToClaim: Quest? = nil
    local best: Quest? = nil
    local bestRatio = -1
    for _, q in ipairs(quests) do
        if q.claimed then continue end
        if q.complete then
            readyToClaim = q
            break
        end
        local ratio = (q.target > 0) and (q.progress / q.target) or 0
        if ratio > bestRatio then
            bestRatio = ratio
            best = q
        end
    end
    return readyToClaim or best
end

local function makeCard()
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("Studio88QuestPill")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "Studio88QuestPill"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 71
    sg.Parent = pg

    -- TextButton (not Frame) so .Activated covers both desktop click and
    -- mobile tap. Visible+button only matters when complete=true; the
    -- click handler is gated on the active quest's complete flag.
    local card = Instance.new("TextButton")
    card.AnchorPoint = Vector2.new(1, 0)
    card.Position = UDim2.new(1, -16, 0, 72)  -- below boost timer (y=16-64)
    card.Size = UDim2.new(0, 220, 0, 50)
    card.BackgroundColor3 = SURFACE
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Text = ""               -- we use child labels, not the button's own text
    card.AutoButtonColor = false -- avoid Roblox's default darken-on-hover
    card.Visible = false
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = CYAN
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = card
    strokeRef = stroke

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "QUEST"
    title.TextColor3 = CYAN
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = card
    titleRef = title

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, 0, 0, 8)
    barBg.Position = UDim2.new(0, 0, 1, -8)
    barBg.AnchorPoint = Vector2.new(0, 1)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 36, 56)
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)
    barBgRef = barBg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.Position = UDim2.new(0, 0, 0, 0)
    barFill.BackgroundColor3 = AMBER
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)
    barFillRef = barFill

    cardRef = card
end

local function applyState()
    if not cardRef or not cardRef.Parent or not titleRef or not barFillRef or not strokeRef then return end
    local q = pickActive()
    if not q then
        cardRef.Visible = false
        return
    end
    cardRef.Visible = true
    local pct = (q.target > 0) and math.clamp(q.progress / q.target, 0, 1) or 0
    if q.complete then
        titleRef.Text = string.format("CLAIM: %s (+%s)", q.label, fmt(q.reward))
        titleRef.TextColor3 = GREEN
        barFillRef.BackgroundColor3 = GREEN
        strokeRef.Color = GREEN
        strokeRef.Transparency = 0.1
    else
        titleRef.Text = string.format("%s — %s/%s", q.label, fmt(q.progress), fmt(q.target))
        titleRef.TextColor3 = CYAN
        barFillRef.BackgroundColor3 = AMBER
        strokeRef.Color = CYAN
        strokeRef.Transparency = 0.4
    end
    barFillRef.Size = UDim2.new(pct, 0, 1, 0)
end

local function poll()
    local ok, snap = pcall(function() return remotes.GetDailyQuests:InvokeServer() end)
    if not ok or typeof(snap) ~= "table" or typeof(snap.quests) ~= "table" then return end
    quests = {}
    for _, q in ipairs(snap.quests) do
        table.insert(quests, {
            id = tostring(q.id or ""),
            kind = tostring(q.kind or ""),
            target = tonumber(q.target) or 0,
            reward = tonumber(q.reward) or 0,
            label = tostring(q.label or ""),
            progress = tonumber(q.progress) or 0,
            claimed = q.claimed == true,
            complete = q.complete == true,
        })
    end
    applyState()
end

makeCard()

-- One-tap claim: when the active quest is complete (CLAIM state), tapping
-- the pill fires ClaimQuest for it. Optimistically mark claimed locally so
-- the pill updates instantly; QuestClaimed broadcast will reconcile if the
-- claim was rejected (server sends QuestRejected in that case, ignored
-- here -- a re-poll will pick the next active quest).
if cardRef and cardRef:IsA("TextButton") then
    cardRef.Activated:Connect(function()
        local q = pickActive()
        if not q then return end
        if not q.complete or q.claimed then return end
        pcall(function() remotes.ClaimQuest:FireServer(q.id) end)
        q.claimed = true
        applyState()
    end)
end

task.spawn(function()
    task.wait(2)
    poll()
    while true do
        task.wait(6)
        poll()
    end
end)

-- React to live progress events to feel snappy between polls.
remotes.QuestProgressed.OnClientEvent:Connect(function(questId: any, progress: any, target: any)
    local id = tostring(questId or "")
    for _, q in ipairs(quests) do
        if q.id == id then
            q.progress = math.min(tonumber(target) or q.target, tonumber(progress) or q.progress)
            q.complete = q.progress >= q.target
            break
        end
    end
    applyState()
end)

remotes.QuestClaimed.OnClientEvent:Connect(function(questId: any)
    local id = tostring(questId or "")
    for _, q in ipairs(quests) do
        if q.id == id then
            q.claimed = true
            break
        end
    end
    applyState()
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    makeCard()
    applyState()
end)

print("[QuestProgressPill] client ready")
