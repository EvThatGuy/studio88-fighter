--!strict
-- UI command registry. HUD + overlay scripts call register() with a
-- named callback (e.g. "openPets", "openSpin"). KeyboardShortcuts /
-- chat commands / gamepad bindings invoke them via invoke(name).
--
-- Decouples input → action so we can add shortcuts without touching
-- HUD internals + without dealing with TextButton.MouseButton1Click
-- being un-fireable from script. Registration is idempotent: a later
-- register() with the same name wins (handy for hot-reload).
--
-- All invokes are pcall-wrapped so a broken handler in one modal
-- can't poison the keyboard system as a whole.

local UICommands = {}

local handlers: {[string]: () -> ()} = {}

function UICommands.register(name: string, fn: () -> ()): ()
    handlers[name] = fn
end

function UICommands.invoke(name: string): boolean
    local fn = handlers[name]
    if not fn then return false end
    local ok, err = pcall(fn)
    if not ok then
        warn(string.format("[UICommands] handler '%s' errored: %s",
            name, tostring(err)))
    end
    return true
end

function UICommands.has(name: string): boolean
    return handlers[name] ~= nil
end

function UICommands.list(): {string}
    local names = {}
    for k in pairs(handlers) do table.insert(names, k) end
    table.sort(names)
    return names
end

return UICommands
