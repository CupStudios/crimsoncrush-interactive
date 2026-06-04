-- main.lua
-- Minimal bootloader. The real game lives in Core/game.lua so patched game code can
-- be loaded under pcall and safely rolled back if a downloaded patch is broken.
local Updater = require("Utils.updater")

local unpackArgs = table.unpack or unpack
local game = nil
local bootError = nil
local bootTraceback = nil

local function captureError(message)
    return debug.traceback(tostring(message), 2)
end

local function rollbackPatchedStartup(errorMessage)
    if Updater.patch_mounted or Updater:hasPatchFile() then
        Updater:rollbackToFactoryVersion(errorMessage)
        return true
    end
    return false
end

local function guardedCall(callbackName, ...)
    if bootError then return nil end
    if not game or not game[callbackName] then return nil end

    local args = { ... }
    local success, result = xpcall(function()
        return game[callbackName](unpackArgs(args))
    end, captureError)

    if not success then
        if rollbackPatchedStartup(result) then return nil end
        error(result)
    end

    return result
end

-- Mount patch_code.love first, then load patched modules inside xpcall. If a script-only
-- patch has syntax errors or missing requires, the error is caught here instead of
-- bricking startup before the updater can delete the patch.
Updater:mountPatch()
local bootSuccess, bootResult = xpcall(function()
    game = require("Core.game")
end, captureError)

if not bootSuccess then
    bootError = true
    bootTraceback = bootResult
end

function love.load(...)
    if bootError then
        if rollbackPatchedStartup(bootTraceback) then return end
        error(bootTraceback)
    end

    guardedCall("load", ...)
end

function love.quit(...)
    return guardedCall("quit", ...)
end

function love.resize(...)
    return guardedCall("resize", ...)
end

function love.update(...)
    return guardedCall("update", ...)
end

function love.draw(...)
    return guardedCall("draw", ...)
end

function love.keypressed(...)
    return guardedCall("keypressed", ...)
end

function love.mousepressed(...)
    return guardedCall("mousepressed", ...)
end

function love.touchpressed(...)
    return guardedCall("touchpressed", ...)
end

function love.touchmoved(...)
    return guardedCall("touchmoved", ...)
end

function love.touchreleased(...)
    return guardedCall("touchreleased", ...)
end
