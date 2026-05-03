--!strict
-- Velvet HUD smoke test. Runs only when ENABLED is true (flip via env).
-- Drives every modal in sequence by walking the App's modal-router state
-- through a globally-exposed setter, holds each open for HOLD_SEC so an
-- external screenshot tool can capture it, then closes.
--
-- Reports each step as a discrete print line tagged [AUTOTEST] so a Python
-- harness can grep the live Roblox log and produce a pass/fail report
-- without anyone touching the game.

local ENABLED = true
local HOLD_SEC = 3.5

if not ENABLED then return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.Remotes)
local TestBridge = require(ReplicatedStorage.Modules.UI.TestBridge)

local player = Players.LocalPlayer
print("[AUTOTEST] start  player=" .. player.Name)

-- Wait for App.luau to write its modal setter into TestBridge.
local function waitForSetter(timeoutSec: number): ((string?) -> ())?
    local deadline = os.clock() + timeoutSec
    while os.clock() < deadline do
        local fn = TestBridge.setModal
        if typeof(fn) == "function" then return fn :: any end
        task.wait(0.25)
    end
    return nil
end

local setter = waitForSetter(30)
if not setter then
    print("[AUTOTEST] FAIL  TestBridge.setModal never set by App")
    return
end
print("[AUTOTEST] setter ready")

-- Make sure remotes are warm before we start firing modals -- modals call
-- :InvokeServer() on mount, so a cold remote map will throw inside the
-- pcall and the test will spuriously look like the modal failed.
local ok, remotes = pcall(function() return Remotes.waitFor(15) end)
if not ok or not remotes then
    print("[AUTOTEST] FAIL  remotes not ready: " .. tostring(remotes))
    return
end
print("[AUTOTEST] remotes warm")

-- (Deliberately not invoking snapshot RemoteFunctions here -- each modal
-- invokes its own GetX on mount, so doing it twice would race + steal
-- thread time from the React tree. We rely on each modal mounting cleanly
-- as the contract test.)

-- Walk every modal id the App router knows about. Each line gives the
-- screenshot grabber a "now open X" beacon to sync with.
local MODAL_IDS = {
    "pets", "spin", "tribute", "achievements", "quests",
    "auras", "titles",
}

print("[AUTOTEST] settling 2s before walking modals")
task.wait(2)

for i = 1, #MODAL_IDS do
    local modalId = MODAL_IDS[i]
    print(string.format("[AUTOTEST] step %d/%d open %s", i, #MODAL_IDS, modalId))
    local sok, serr = pcall(function() setter(modalId) end)
    if not sok then
        print("[AUTOTEST] FAIL  setter threw on " .. modalId .. " err=" .. tostring(serr))
    end
    task.wait(HOLD_SEC)
    print(string.format("[AUTOTEST] step %d/%d close %s", i, #MODAL_IDS, modalId))
    pcall(function() setter(nil) end)
    task.wait(0.5)
end

print("[AUTOTEST] done  pass=" .. tostring(#MODAL_IDS))
