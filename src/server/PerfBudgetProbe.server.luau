--!strict
-- Runtime perf budget probe. Visual upgrades have added a lot of parts +
-- particles + lights, and 60% of Roblox DAU plays on low-end Android
-- (3-year-old phones with throttled GPUs). Frame rate tanks fast when
-- part counts cross ~3000 or active particle emitters cross ~50.
--
-- Every 30s, log:
--   - total Workspace BasePart count
--   - active ParticleEmitter count
--   - active PointLight + SpotLight + SurfaceLight count
--   - active SurfaceGui count
--
-- If any cross the soft budget, warn so future visual additions are
-- caught before they ship to mobile players.

local Workspace = game:GetService("Workspace")

local BUDGETS = {
    parts = 3000,
    particles = 50,
    lights = 30,
    surfaceGuis = 25,
}

local function audit()
    local parts = 0
    local particles = 0
    local lights = 0
    local surfaceGuis = 0
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") then
            parts += 1
        elseif inst:IsA("ParticleEmitter") then
            if inst.Enabled then particles += 1 end
        elseif inst:IsA("Light") then
            if inst.Enabled then lights += 1 end
        elseif inst:IsA("SurfaceGui") then
            surfaceGuis += 1
        end
    end
    local violations = {}
    if parts > BUDGETS.parts then table.insert(violations, string.format("parts=%d/%d", parts, BUDGETS.parts)) end
    if particles > BUDGETS.particles then table.insert(violations, string.format("particles=%d/%d", particles, BUDGETS.particles)) end
    if lights > BUDGETS.lights then table.insert(violations, string.format("lights=%d/%d", lights, BUDGETS.lights)) end
    if surfaceGuis > BUDGETS.surfaceGuis then table.insert(violations, string.format("surfaceGuis=%d/%d", surfaceGuis, BUDGETS.surfaceGuis)) end
    if #violations > 0 then
        warn(string.format("[PerfBudget] OVER BUDGET: %s", table.concat(violations, ", ")))
    else
        print(string.format("[PerfBudget] parts=%d particles=%d lights=%d surfaceGuis=%d (within budget)",
            parts, particles, lights, surfaceGuis))
    end
end

task.spawn(function()
    -- Wait 10s for WorldBuilder to populate
    task.wait(10)
    while true do
        audit()
        task.wait(30)
    end
end)
