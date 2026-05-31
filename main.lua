local VirtualScreen = require("Core.virtual_screen")
local Camera = require("Core.camera")
local EntityManager = require("Entities.entity_manager")
local Player = require("Entities.player")

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

local function drawVirtualUi()
    -- La UI también vive en coordenadas virtuales 1200x900, no en píxeles físicos.
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 24, 24, 440, 106, 10, 10)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Resolución virtual fija: 1600x1200 (ratio 12:9)", 44, 44)
    love.graphics.print("Movimiento: WASD", 44, 70)
    love.graphics.print(string.format("Jugador mundo: x=%.1f y=%.1f", player.x, player.y), 44, 96)
end

function love.load()
    love.window.setTitle("Crimson Crush")
    love.window.setMode(1600, 1200, {
        resizable = true,
        minwidth = 400,
        minheight = 300
    })

    love.graphics.setDefaultFilter("nearest", "nearest")

    VirtualScreen:update(love.graphics.getDimensions())
    camera = Camera.new(VirtualScreen.width, VirtualScreen.height)

    entityManager = EntityManager.new()
    player = entityManager:add(Player.new(0, 0))
end

function love.resize(width, height)
    -- Recalcula dinámicamente escala y barras negras al cambiar el tamaño real.
    VirtualScreen:update(width, height)
end

function love.update(dt)
    entityManager:update(dt)
    camera:follow(player, dt)
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
