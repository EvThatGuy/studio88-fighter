--!strict
-- Velvet Studio HUD bootstrap.
--
-- Mounts the react-lua tree at PlayerGui/HUD_v2 and hides the legacy
-- Studio88HUD ScreenGui so they don't double-render.
--
-- Toggle USE_REACT_HUD = false to roll back to the legacy HUD without
-- removing this script. Once HUD_v2 has migrated all 24 features, the
-- legacy HUD.client.luau file can be deleted entirely.

local USE_REACT_HUD = true

if not USE_REACT_HUD then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.Parent.UI.App)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Hide the legacy ScreenGui as soon as it shows up so we don't paint two HUDs
-- on top of each other during the migration window.
task.spawn(function()
    local legacy = playerGui:WaitForChild("Studio88HUD", 10)
    if legacy and legacy:IsA("ScreenGui") then
        legacy.Enabled = false
    end
end)

local screen = Instance.new("ScreenGui")
screen.Name = "Studio88HUD_v2"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- Master scale: design canvas is 1080p; fold viewport delta into a single
-- root UIScale so child components don't have to do per-element math.
local scaleHolder = Instance.new("Frame")
scaleHolder.Name = "ScaleRoot"
scaleHolder.BackgroundTransparency = 1
scaleHolder.Size = UDim2.fromScale(1, 1)
scaleHolder.Parent = screen

local uiScale = Instance.new("UIScale")
uiScale.Name = "MasterScale"
uiScale.Parent = scaleHolder

local function recomputeScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    if not viewport then return end
    -- Cap upscaling so 4k monitors don't render absurdly chunky chrome.
    local raw = viewport.Y / 1080
    uiScale.Scale = math.clamp(raw, 0.7, 1.4)
end
recomputeScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recomputeScale)
end

-- LegacyRoot (synchronous render+effect commit). ConcurrentRoot was deferring
-- effects in a way that interacted badly with sibling effects that yielded
-- via Remotes.waitFor / RemoteFunction:InvokeServer -- a yielding useEffect
-- callback breaks the commit chain and silently kills downstream effects.
-- All effects in src/client/UI/* must wrap yields in task.spawn + cancelled
-- flag so the returned cleanup is synchronous.
local root = ReactRoblox.createLegacyRoot(scaleHolder)
root:render(React.createElement(App))

print("[HUD_v2] mounted")
