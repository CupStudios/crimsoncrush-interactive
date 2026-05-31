-- Core/camera.lua
-- Cámara top-down simple que sigue suavemente a un objetivo del mundo.
local Camera = {}
Camera.__index = Camera

function Camera.new(virtualWidth, virtualHeight)
    return setmetatable({
        x = 0,
        y = 0,
        virtualWidth = virtualWidth,
        virtualHeight = virtualHeight,
        followSmoothing = 10
    }, Camera)
end

function Camera:follow(target, dt)
    if not target then
        return
    end

    -- La cámara apunta al centro del jugador para colocarlo cerca del centro
    -- de la pantalla virtual.
    local targetX = target.x + target.width / 2 - self.virtualWidth / 2
    local targetY = target.y + target.height / 2 - self.virtualHeight / 2

    -- Seguimiento suave independiente del framerate.
    local amount = 1 - math.exp(-self.followSmoothing * dt)
    self.x = self.x + (targetX - self.x) * amount
    self.y = self.y + (targetY - self.y) * amount
end

function Camera:apply()
    -- Esta traslación se ejecuta DENTRO de la resolución virtual.
    -- Convierte coordenadas de mundo a coordenadas visibles de juego:
    -- pantalla_virtual = mundo - camara.
    love.graphics.push()
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:release()
    love.graphics.pop()
end

return Camera
