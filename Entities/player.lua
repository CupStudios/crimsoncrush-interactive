-- Entities/player.lua
-- Entidad jugador: rectángulo placeholder con movimiento top-down WASD.
local Player = {}
Player.__index = Player

function Player.new(x, y)
    return setmetatable({
        id = nil,
        type = "player",
        x = x or 0,
        y = y or 0,
        width = 48,
        height = 64,
        speed = 280,
        color = {0.9, 0.15, 0.12, 1},
        dirX = 0,
        dirY = 1
    }, Player)
end

function Player:update(dt, entityManager)
    local dx, dy = 0, 0

    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    -- Normaliza el vector para que moverse en diagonal no sea más rápido.
    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / length, dy / length
        self.dirX, self.dirY = dx, dy
    end

    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt

    -- entityManager queda disponible para futuras colisiones, combate o consultas.
    self.entityManager = entityManager
end

function Player:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 6, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 6, 6)
end

return Player
