-- Utils/save_manager.lua
-- Guardado persistente de Crimson Crush usando json.lua y love.filesystem.
local JSON = require("json")

local SaveManager = {
    filename = "savegame.json"
}

local function serializableCopy(value, seen)
    if type(value) ~= "table" then
        if type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then
            return nil
        end
        return value
    end

    seen = seen or {}
    if seen[value] then
        return nil
    end
    seen[value] = true

    local copy = {}
    for key, child in pairs(value) do
        if type(key) ~= "function" and type(key) ~= "userdata" and type(child) ~= "function" then
            copy[key] = serializableCopy(child, seen)
        end
    end

    seen[value] = nil
    return copy
end

function SaveManager.buildPlayerData(player)
    return {
        hp = player.hp,
        maxHp = player.maxHp,
        willExperience = player.willExperience or 0,
        will = serializableCopy(player.will)
    }
end

function SaveManager.savePlayer(player)
    if not player then
        return false, "No hay jugador para guardar"
    end

    local saveData = SaveManager.buildPlayerData(player)
    local jsonText = JSON:encode_pretty(saveData)
    return love.filesystem.write(SaveManager.filename, jsonText)
end

function SaveManager.loadPlayer()
    if not love.filesystem.getInfo(SaveManager.filename) then
        return nil, "No existe guardado previo"
    end

    local jsonText, readError = love.filesystem.read(SaveManager.filename)
    if not jsonText then
        return nil, readError or "No se pudo leer el guardado"
    end

    local ok, decoded = pcall(function()
        return JSON:decode(jsonText)
    end)

    if not ok or type(decoded) ~= "table" then
        return nil, "Guardado inválido"
    end

    return decoded
end

function SaveManager.applyPlayerData(player, saveData, restoreWill)
    if not player or type(saveData) ~= "table" then
        return false
    end

    player.maxHp = saveData.maxHp or player.maxHp
    player.hp = math.min(saveData.hp or player.maxHp, player.maxHp)
    player.willExperience = saveData.willExperience or player.willExperience or 0

    if saveData.will and restoreWill then
        player.will = restoreWill(saveData.will) or player.will
    end

    return true
end

return SaveManager
