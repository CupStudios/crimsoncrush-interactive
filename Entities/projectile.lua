-- Entities/projectile.lua
-- Entidad temporal creada por Wills de tipo Proyectil.
local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(config)
    local directionX = config.directionX or 0
    local directionY = config.directionY or 1
    local length = math.sqrt(directionX * directionX + directionY * directionY)

    if length == 0 then
        directionX, directionY, length = 0, 1, 1
    end

    return setmetatable({
        id = nil,
        type = "projectile",
        owner = config.owner,
        x = (config.x or 0) - 8,
        y = (config.y or 0) - 8,
        width = 16,
        height = 16,
        speed = config.speed or 600,
        directionX = directionX / length,
        directionY = directionY / length,
        damage = config.damage or 1,
        lifetime = config.lifetime or 1,
        age = 0,
        color = config.color or {1, 1, 1, 1}
    }, Projectile)
end

function Projectile:update(dt)
    self.age = self.age + dt
    self.x = self.x + self.directionX * self.speed * dt
    self.y = self.y + self.directionY * self.speed * dt

    -- La colisión AABB contra enemigos se resuelve centralizadamente en EntityManager.
    if self.age >= self.lifetime then
        self.destroyed = true
    end
end

function Projectile:draw()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.92)
    love.graphics.circle("fill", self.x + self.width / 2, self.y + self.height / 2, self.width / 2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", self.x + self.width / 2, self.y + self.height / 2, self.width / 2)
end

return Projectile
