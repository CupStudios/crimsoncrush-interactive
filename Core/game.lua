local Updater = require("Utils.updater")

local VirtualScreen = require("Core.virtual_screen")
local Camera = require("Core.camera")
local EntityManager = require("Entities.entity_manager")
local Player = require("Entities.player")
local TrainingDummy = require("Entities.training_dummy")
local WillFactory = require("Wills.will_factory")

local MobileControls = require("Utils.mobile_controls")
local Effects = require("Utils.effects")
local SaveManager = require("Utils.save_manager")
local ReputationManager = require("Story.reputation_manager")
local DialogueBox = require("Story.dialogue_box")
local StoryManager = require("Story.story_manager")

local Game = {}
local toVirtualPoint

function Game.touchpressed(id, x, y)
    local virtualX, virtualY = toVirtualPoint(x, y)
    if StoryManager:touchpressed(id, virtualX, virtualY) then return end
    MobileControls:touchpressed(id, x, y)
end

function Game.touchmoved(id, x, y) MobileControls:touchmoved(id, x, y) end
function Game.touchreleased(id, x, y) MobileControls:touchreleased(id) end

local camera
local entityManager
local player

local BASE_WINDOW_WIDTH = 1600
local BASE_WINDOW_HEIGHT = 1200
local MIN_WINDOW_WIDTH = 400
local MIN_WINDOW_HEIGHT = 300
local WINDOWED_DESKTOP_PADDING = 0.92

local function getInitialWindowSize()
    local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
    local maxWindowWidth = math.max(MIN_WINDOW_WIDTH, math.floor(desktopWidth * WINDOWED_DESKTOP_PADDING))
    local maxWindowHeight = math.max(MIN_WINDOW_HEIGHT, math.floor(desktopHeight * WINDOWED_DESKTOP_PADDING))
    local scale = math.min(1, maxWindowWidth / BASE_WINDOW_WIDTH, maxWindowHeight / BASE_WINDOW_HEIGHT)

    return math.max(MIN_WINDOW_WIDTH, math.floor(BASE_WINDOW_WIDTH * scale)),
        math.max(MIN_WINDOW_HEIGHT, math.floor(BASE_WINDOW_HEIGHT * scale))
end

local function drawWorldGrid()
    love.graphics.setColor(0.16, 0.16, 0.18, 1)
    for x = -3200, 3200, 100 do
        love.graphics.line(x, -2400, x, 2400)
    end
    for y = -2400, 2400, 100 do
        love.graphics.line(-3200, y, 3200, y)
    end
end

function toVirtualPoint(x, y)
    return (x - VirtualScreen.offsetX) / VirtualScreen.scale, (y - VirtualScreen.offsetY) / VirtualScreen.scale
end

local function drawWorldMarkers()
    love.graphics.setColor(0.22, 0.35, 0.55, 1)
    love.graphics.rectangle("fill", -300, -180, 120, 120)

    love.graphics.setColor(0.75, 0.65, 0.25, 1)
    love.graphics.rectangle("fill", 360, 240, 90, 90)

    love.graphics.setColor(0.35, 0.65, 0.35, 1)
    love.graphics.circle("fill", 0, 0, 45)
end

local function drawBar(x, y, width, height, ratio, color, label)
    love.graphics.setColor(0.08, 0.08, 0.09, 0.9)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x, y, width * math.max(0, math.min(1, ratio)), height, 5, 5)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    love.graphics.print(label, x + 8, y + 4)
end


local function formatBytes(bytes)
    bytes = tonumber(bytes) or 0
    if bytes >= 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    elseif bytes >= 1024 then
        return string.format("%.1f KB", bytes / 1024)
    end
    return string.format("%d B", bytes)
end

local function drawUpdaterStatus()
    love.graphics.setColor(1, 1, 1, 1)
    if Updater.status == "checking" then
        love.graphics.print("Buscando actualizaciones en GitHub...", 30, 1100)
    elseif Updater.status == "update_available" then
        love.graphics.print("¡Parche de código disponible! v" .. Updater.remote_version .. " (Presiona 'U' para descargar)", 30, 1100)
    elseif Updater.status == "up_to_date" then
        love.graphics.print("Juego actualizado: v" .. Updater.current_version, 30, 1100)
    elseif Updater.status == "downloading" then
        local percent = math.floor((Updater.progress or 0) * 100)
        local label = string.format("Descargando patch_code.love... %d%% (%s / %s)", percent, formatBytes(Updater.downloaded_bytes), formatBytes(Updater.size_bytes))
        drawBar(30, 1100, 520, 26, Updater.progress, {0.35, 0.7, 1, 1}, label)
    elseif Updater.status == "ready" then
        love.graphics.setColor(0.3, 0.8, 0.3, 1)
        love.graphics.print("Parche listo. Presiona 'Enter' para reiniciar y aplicar.", 30, 1100)
    elseif Updater.status == "applied" then
        love.graphics.setColor(0.3, 0.8, 0.3, 1)
        love.graphics.print("Parche aplicado. Reiniciando...", 30, 1100)
    elseif Updater.status == "rolled_back" then
        love.graphics.setColor(1, 0.8, 0.25, 1)
        love.graphics.print("An error was detected in the update. Rolling back to a safe version.", 30, 1100)
    elseif Updater.status == "error" then
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.print("Error de actualización: " .. Updater.error_message, 30, 1100)
    end
end

local function drawVirtualUi()
    -- La UI también vive en coordenadas virtuales 1600x1200, no en píxeles físicos.
    local will = player.will
    local reserveRatio = will.reserva_actual / will.reserva_maxima
    local outputRatio = will.output_actual / will.output_maximo
    local cooldownRatio = will.active.cooldown > 0 and (1 - will.active.timer / will.active.cooldown) or 1

    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 24, 24, 560, 246, 10, 10)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Resolución virtual fija: 1600x1200 (ratio 12:9)", 44, 44)
    love.graphics.print("Movimiento: WASD | Canalizar: E | Activar Will: Space/J", 44, 70)
    love.graphics.print(string.format("Jugador mundo: x=%.1f y=%.1f | HP: %.1f/%.1f", player.x, player.y, player.hp, player.maxHp), 44, 96)
    love.graphics.print(string.format("Will %s | Pasiva: %s | Activa: %s", will.archetype, will.passive.name, will.active.name), 44, 122)

    drawBar(44, 150, 460, 20, reserveRatio, {0.35, 0.55, 1, 1}, string.format("Reserva %.0f / %.0f", will.reserva_actual, will.reserva_maxima))
    drawBar(44, 178, 460, 20, outputRatio, {will.color[1], will.color[2], will.color[3], 1}, string.format("Output %.0f / %.0f | Coste %.0f", will.output_actual, will.output_maximo, will.active.energyCost))
    drawBar(44, 206, 460, 20, cooldownRatio, {0.95, 0.75, 0.25, 1}, string.format("Cooldown %.1fs", will.active.timer))
    love.graphics.print(string.format("Will XP: %.0f | K: spawnear dummy", player.willExperience), 44, 234)

    if will.lastError then
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.print(will.lastError, 560, 44)
    elseif will.lastPassiveText then
        love.graphics.setColor(0.65, 1, 0.65, 1)
        love.graphics.print(will.lastPassiveText, 560, 44)
    end
end

function Game.load()
    love.math.setRandomSeed(os.time())

    love.window.setTitle("Crimson Crush")
    local windowWidth, windowHeight = getInitialWindowSize()
    love.window.setMode(windowWidth, windowHeight, {
        resizable = true,
        minwidth = MIN_WINDOW_WIDTH,
        minheight = MIN_WINDOW_HEIGHT,
        fullscreen = false,
        fullscreentype = "desktop"
    })

    love.graphics.setDefaultFilter("nearest", "nearest")

    local uiFont = love.graphics.newFont(19) -- Puedes cambiar el 16 si la quieres más grande
    uiFont:setFilter("linear", "linear")
    love.graphics.setFont(uiFont)

    -- Iniciar el gestor de versiones
    Updater:init()

    -- URL de ejemplo apuntando a tu json de control en GitHub.
    -- If this boot is showing a rollback notice, do not immediately replace that
    -- message with the background "checking" status; the next launch will check again.
    local GITHUB_MANIFEST_URL = "https://raw.githubusercontent.com/CupStudios/crimsoncrush-interactive/main/version.json"
    if Updater.status ~= "rolled_back" then
        Updater:checkForUpdates(GITHUB_MANIFEST_URL)
    end

    Effects:load("Data/effects.json")

    VirtualScreen:update(love.graphics.getDimensions())
    camera = Camera.new(VirtualScreen.width, VirtualScreen.height)

    entityManager = EntityManager.new()

    local saveData = SaveManager.loadPlayer()
    ReputationManager:init(saveData and saveData.reputation)

    if saveData then
        local restoredWill = WillFactory.restoreMetatable(saveData.will)
        player = entityManager:add(Player.new(0, 0, restoredWill))
        SaveManager.applyPlayerData(player, saveData, WillFactory.restoreMetatable)
    else
        player = entityManager:add(Player.new(0, 0, WillFactory.generate()))
        SaveManager.savePlayer(player)
    end

    entityManager:add(TrainingDummy.new(320, 140))
    StoryManager:init({
        entityManager = entityManager,
        player = player,
        saveManager = SaveManager,
        reputationManager = ReputationManager
    })
end

function Game.quit()
    if player then
        SaveManager.savePlayer(player)
    end
end

function Game.resize(width, height)
    -- Recalcula dinámicamente escala y barras negras al cambiar el tamaño real.
    VirtualScreen:update(width, height)
end

function Game.update(dt)
    Updater:update(dt)

    if DialogueBox:isActive() then
        DialogueBox:update(dt)
        return
    end

    StoryManager:update(dt, player)
    entityManager:update(dt)
    Effects:update(dt)
    camera:follow(player, dt)

    -- M1 Táctil: Si presionan el botón M1, llamamos al ataque
    -- Nota: Usamos MobileControls:isActionPressed("m1")
    if MobileControls:isActionPressed("m1") then
        -- Disparamos hacia donde apunta el joystick (o una dirección por defecto)
        local jx, jy = MobileControls:getJoystickVector()
        local targetX = player.x + (jx * 200)
        local targetY = player.y + (jy * 200)
        player:m1(targetX, targetY)
    end

    -- Will Táctil: Si presionan el botón Will
    if MobileControls:isActionPressed("will") then
        if player:useWillAbility(entityManager) then
            Effects:emit("will_cast", player.x + player.width / 2, player.y + player.height / 2, { color = player.will.color })
        end
    end
end

function Game.keypressed(key)
    if StoryManager:keypressed(key) then
        return
    end

    if key == "space" or key == "j" then
        if player:useWillAbility(entityManager) then
            Effects:emit("will_cast", player.x + player.width / 2, player.y + player.height / 2, { color = player.will.color })
        end
    elseif key == "k" then
        local angle = love.math.random() * math.pi * 2
        local distance = love.math.random(180, 420)
        local spawnX = player.x + math.cos(angle) * distance
        local spawnY = player.y + math.sin(angle) * distance
        entityManager:add(TrainingDummy.new(spawnX, spawnY))
    end

    if key == "u" and Updater.status == "update_available" then
        Updater:startDownload()
    elseif key == "return" and Updater.status == "ready" then
        Updater:applyAndRestart()
    end
end

function Game.mousepressed(x, y, button)
    local virtualX, virtualY = toVirtualPoint(x, y)
    if StoryManager:mousepressed(virtualX, virtualY, button) then
        return
    end

    -- Si es móvil o estamos usando controles táctiles, ignoramos el mouse
    -- para evitar el doble registro.
    if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then return end

    if button == 1 then
        local virtualMouseX, virtualMouseY = VirtualScreen:getMousePosition()
        local worldMouseX, worldMouseY = camera:getWorldCoords(virtualMouseX, virtualMouseY)
        player:m1(worldMouseX, worldMouseY)
    end
end

function Game.draw()
    -- 1) Limpia toda la ventana real en negro. Lo que no cubra el área virtual
    -- escalada se verá como letterboxing/pillarboxing.
    VirtualScreen:drawBlackBars()

    -- 2) Entra al sistema virtual: desde aquí se dibuja en coordenadas 1600x1200.
    VirtualScreen:apply()

    -- Fondo del área de juego virtual; no usa coordenadas físicas de la ventana.
    love.graphics.setColor(0.08, 0.08, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, VirtualScreen.width, VirtualScreen.height)

    -- 3) Entra al sistema de cámara: las entidades se dibujan con coordenadas
    -- de mundo y la cámara aplica la traslación mundo -> pantalla virtual.
    camera:apply()
    drawWorldGrid()
    drawWorldMarkers()
    StoryManager:drawWorld()
    entityManager:draw()
    Effects:draw()
    camera:release()

    -- 4) UI virtual encima del mundo, sin cámara pero manteniendo escala 12:9.
    drawVirtualUi()

    MobileControls:draw() -- Dibujar controles encima de todo
    StoryManager:drawUi()

    drawUpdaterStatus()

    -- 5) Sale del sistema virtual y restaura coordenadas físicas de Löve2D.
    VirtualScreen:release()
end

return Game
