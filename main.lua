local VirtualScreen = require("Core.virtual_screen")
local Camera = require("Core.camera")
local EntityManager = require("Entities.entity_manager")
local Player = require("Entities.player")
local TrainingDummy = require("Entities.training_dummy")

local camera
local entityManager
local player

local function drawWorldGrid()
    love.graphics.setColor(0.16, 0.16, 0.18, 1)
    for x = -2400, 2400, 100 do
        love.graphics.line(x, -1800, x, 1800)
    end
    for y = -1800, 1800, 100 do
        love.graphics.line(-2400, y, 2400, y)
    end
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

local function drawVirtualUi()
    -- La UI también vive en coordenadas virtuales 1200x900, no en píxeles físicos.
    local will = player.will
    local reserveRatio = will.reserva_actual / will.reserva_maxima
    local outputRatio = will.output_actual / will.output_maximo
    local cooldownRatio = will.active.cooldown > 0 and (1 - will.active.timer / will.active.cooldown) or 1

    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", 24, 24, 520, 218, 10, 10)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Resolución virtual fija: 1200x900 (ratio 12:9)", 44, 44)
    love.graphics.print("Movimiento: WASD | Canalizar: E | Activar Will: Space/J", 44, 70)
    love.graphics.print(string.format("Jugador mundo: x=%.1f y=%.1f | HP: %.1f/%.1f", player.x, player.y, player.hp, player.maxHp), 44, 96)
    love.graphics.print(string.format("Will %s | Pasiva: %s | Activa: %s", will.archetype, will.passive.name, will.active.name), 44, 122)

    drawBar(44, 150, 460, 20, reserveRatio, {0.35, 0.55, 1, 1}, string.format("Reserva %.0f / %.0f", will.reserva_actual, will.reserva_maxima))
    drawBar(44, 178, 460, 20, outputRatio, {will.color[1], will.color[2], will.color[3], 1}, string.format("Output %.0f / %.0f | Coste %.0f", will.output_actual, will.output_maximo, will.active.energyCost))
    drawBar(44, 206, 460, 20, cooldownRatio, {0.95, 0.75, 0.25, 1}, string.format("Cooldown %.1fs", will.active.timer))

    if will.lastError then
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.print(will.lastError, 560, 44)
    elseif will.lastPassiveText then
        love.graphics.setColor(0.65, 1, 0.65, 1)
        love.graphics.print(will.lastPassiveText, 560, 44)
    end
end

function love.load()
    love.math.setRandomSeed(os.time())

    love.window.setTitle("CrimsonCrush - Base top-down 12:9")
    love.window.setMode(1200, 900, {
        resizable = true,
        minwidth = 400,
        minheight = 300
    })

    love.graphics.setDefaultFilter("nearest", "nearest")

    VirtualScreen:update(love.graphics.getDimensions())
    camera = Camera.new(VirtualScreen.width, VirtualScreen.height)

    entityManager = EntityManager.new()
    player = entityManager:add(Player.new(0, 0))
    entityManager:add(TrainingDummy.new(320, 140))
    entityManager:add(TrainingDummy.new(-260, -120))
end

function love.resize(width, height)
    -- Recalcula dinámicamente escala y barras negras al cambiar el tamaño real.
    VirtualScreen:update(width, height)
end

function love.update(dt)
    entityManager:update(dt)
    camera:follow(player, dt)
end

function love.keypressed(key)
    if key == "space" or key == "j" then
        player:useWillAbility(entityManager)
    end
end

function love.draw()
    -- 1) Limpia toda la ventana real en negro. Lo que no cubra el área virtual
    -- escalada se verá como letterboxing/pillarboxing.
    VirtualScreen:drawBlackBars()

    -- 2) Entra al sistema virtual: desde aquí se dibuja en coordenadas 1200x900.
    VirtualScreen:apply()

    -- Fondo del área de juego virtual; no usa coordenadas físicas de la ventana.
    love.graphics.setColor(0.08, 0.08, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, VirtualScreen.width, VirtualScreen.height)

    -- 3) Entra al sistema de cámara: las entidades se dibujan con coordenadas
    -- de mundo y la cámara aplica la traslación mundo -> pantalla virtual.
    camera:apply()
    drawWorldGrid()
    drawWorldMarkers()
    entityManager:draw()
    camera:release()

    -- 4) UI virtual encima del mundo, sin cámara pero manteniendo escala 12:9.
    drawVirtualUi()

    -- 5) Sale del sistema virtual y restaura coordenadas físicas de Löve2D.
    VirtualScreen:release()
end
