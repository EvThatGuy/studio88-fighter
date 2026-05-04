--!strict
-- Bottom-right tribute quick-claim button. Polls HourlyTribute snapshot
-- every 30s; if stacks > 0, shows "$X TRIBUTE" button that auto-claims
-- all available stacks. Hidden when stacks=0. Pulses when capped (4
-- stacks) so player knows they're losing accumulation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local remotes = Remotes.waitFor()

local AMBER = Color3.fromRGB(255, 176, 0)
local PINK = Color3.fromRGB(255, 46, 136)
local DARK = Color3.fromRGB(8, 7, 13)
local SURFACE = Color3.fromRGB(20, 17, 31)

local function fmtCoins(n: number): string
    if n < 1000 then return tostring(n) end
    if n < 1000000 then return string.format("%.1fK", n / 1000) end
    return string.format("%.2fM", n / 1000000)
end

local sg: ScreenGui? = nil
local btnRef: TextButton? = nil
local pulseConn: thread? = nil

local function ensure()
    local pg = player:WaitForChild("PlayerGui")
    if sg and sg.Parent then return end
    local newSg = Instance.new("ScreenGui")
    newSg.Name = "Studio88TributeQuickClaim"
    newSg.ResetOnSpawn = false
    newSg.IgnoreGuiInset = false
    newSg.DisplayOrder = 73
    newSg.Parent = pg
    sg = newSg

    local newBtn = Instance.new("TextButton")
    newBtn.AnchorPoint = Vector2.new(1, 1)
    newBtn.Position = UDim2.new(1, -16, 1, -16)
    newBtn.Size = UDim2.new(0, 200, 0, 50)
    newBtn.BackgroundColor3 = AMBER
    newBtn.BorderSizePixel = 0
    newBtn.Text = ""
    newBtn.TextColor3 = DARK
    newBtn.Font = Enum.Font.GothamBold
    newBtn.TextScaled = true
    newBtn.AutoButtonColor = true
    newBtn.Visible = false
    newBtn.Parent = newSg
    Instance.new("UICorner", newBtn).CornerRadius = UDim.new(0, 10)
    btnRef = newBtn

    newBtn.MouseButton1Click:Connect(function()
        remotes.ClaimHourlyTribute:FireServer()
        if btnRef then btnRef.Visible = false end
    end)
end

local function refresh()
    local btn = btnRef
    if not btn or not btn.Parent then return end
    pcall(function()
        local snap = remotes.GetHourlyTribute:InvokeServer()
        if not snap or not snap.available then
            btn.Visible = false
            return
        end
        local stacks = snap.stacks or 0
        if stacks <= 0 then
            btn.Visible = false
            return
        end
        local total = math.floor((snap.perStack or 0) * stacks)
        btn.Text = string.format("CLAIM $%s TRIBUTE (%d)", fmtCoins(total), stacks)
        btn.Visible = true
        local cap = snap.cap or 4
        if pulseConn then task.cancel(pulseConn); pulseConn = nil end
        if stacks >= cap then
            pulseConn = task.spawn(function()
                while btnRef and btnRef.Visible do
                    TweenService:Create(btn,
                        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                        {BackgroundColor3 = PINK}):Play()
                    task.wait(0.6)
                    TweenService:Create(btn,
                        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                        {BackgroundColor3 = AMBER}):Play()
                    task.wait(0.6)
                end
            end)
        else
            btn.BackgroundColor3 = AMBER
        end
    end)
end

ensure()
player.CharacterAdded:Connect(function() task.wait(0.3); ensure(); refresh() end)
remotes.HourlyTributeClaimed.OnClientEvent:Connect(function() refresh() end)

task.spawn(function()
    task.wait(2)
    while true do
        refresh()
        task.wait(30)
    end
end)

print("[TributeQuickClaim] client ready")
