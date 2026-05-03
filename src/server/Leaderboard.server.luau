--!strict
-- OrderedDataStore-backed leaderboard. Top N by lifetime coins (never
-- decreases). Refresh every Constants.LEADERBOARD_REFRESH_SEC; broadcast to
-- all clients via LeaderboardUpdated.
--
-- Why lifetime not balance: a player who hoards never falls off the board
-- after a big upgrade purchase. Lifetime coins == cumulative dedication.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))
local DataStore = require(script.Parent:WaitForChild("DataStore"))

local remotes = Remotes.get()

local LB_KEY = "LifetimeCoins_" .. Constants.DATASTORE_VERSION
-- Studio publish-gate guard. Same pattern as DataStore.luau.
local odsStore: OrderedDataStore? = nil
do
    local ok, result = pcall(function()
        return DataStoreService:GetOrderedDataStore(LB_KEY)
    end)
    if ok then
        odsStore = result
    else
        warn("[Leaderboard] disabled in this place -- " .. tostring(result))
    end
end

local function publishCurrentPlayers()
    if not odsStore then return end -- Studio without API access
    for _, player in ipairs(Players:GetPlayers()) do
        local data = DataStore.getCached(player.UserId)
        if data then
            local ok, err = pcall(function()
                (odsStore :: OrderedDataStore):SetAsync(tostring(player.UserId), data.lifetimeCoins)
            end)
            if not ok then
                warn("[Leaderboard] SetAsync failed for " .. player.Name .. ": " .. tostring(err))
            end
        end
    end
end

local function fetchTopN(): {{userId: number, name: string, lifetimeCoins: number}}
    local out = {}
    if not odsStore then return out end -- Studio without API access
    local ok, page = pcall(function()
        return (odsStore :: OrderedDataStore):GetSortedAsync(false, Constants.LEADERBOARD_TOP_N)
    end)
    if not ok or not page then
        warn("[Leaderboard] GetSortedAsync failed: " .. tostring(page))
        return out
    end
    local entries = page:GetCurrentPage()
    for _, entry in ipairs(entries) do
        local userId = tonumber(entry.key)
        if userId then
            local nameOk, name = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            table.insert(out, {
                userId = userId,
                name = nameOk and name or ("user:" .. userId),
                lifetimeCoins = entry.value,
            })
        end
    end
    return out
end

local PINK = Color3.fromRGB(255, 46, 136)
local TEXT = Color3.fromRGB(248, 248, 242)
local CYAN = Color3.fromRGB(0, 240, 255)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local function paintSign(rows: {{userId: number, name: string, lifetimeCoins: number}})
    -- Walk every tagged Studio88LeaderboardPanel and paint identical rows
    -- into its SurfaceGui.Rows frame. Cheap text re-render; runs every 10s.
    for _, panel in ipairs(CollectionService:GetTagged("Studio88LeaderboardPanel")) do
        local sg = panel:FindFirstChildWhichIsA("SurfaceGui")
        if not sg then continue end
        local frame = sg:FindFirstChildWhichIsA("Frame")
        if not frame then continue end
        local rowsFrame = frame:FindFirstChild("Rows") :: Frame?
        if not rowsFrame then continue end
        for _, child in ipairs(rowsFrame:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        if #rows == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 32)
            lbl.BackgroundTransparency = 1
            lbl.Text = "(no entries yet -- be the first)"
            lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
            lbl.Font = Enum.Font.Code
            lbl.TextScaled = true
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = rowsFrame
        else
            for i, row in ipairs(rows) do
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 0, 32)
                lbl.BackgroundTransparency = 1
                lbl.Text = string.format("%2d. %-14s  %s", i, row.name:sub(1, 14), fmtCoins(row.lifetimeCoins))
                lbl.TextColor3 = (i == 1) and PINK or (i <= 3 and CYAN or TEXT)
                lbl.Font = Enum.Font.Code
                lbl.TextScaled = true
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.LayoutOrder = i
                lbl.Parent = rowsFrame
            end
        end
    end
end

local function refreshAndBroadcast()
    publishCurrentPlayers()
    local rows = fetchTopN()
    paintSign(rows)
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            remotes.LeaderboardUpdated:FireClient(player, rows)
        end)
    end
end

local function loop()
    -- Initial wait so DataStore has loaded everyone joining at t0
    task.wait(5)
    while true do
        refreshAndBroadcast()
        task.wait(Constants.LEADERBOARD_REFRESH_SEC)
    end
end

-- Push the freshly-joined player's most recent leaderboard so they have
-- something to render before the next global refresh tick.
Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        task.wait(2)
        local rows = fetchTopN()
        pcall(function()
            remotes.LeaderboardUpdated:FireClient(player, rows)
        end)
    end)
end)

task.spawn(loop)

print("[Leaderboard] refreshing every " .. Constants.LEADERBOARD_REFRESH_SEC .. "s, top " .. Constants.LEADERBOARD_TOP_N)
