-- Entities/m1.lua
-- Entidad temporal de daño físico (M1) en área creada por ataques básicos M1.
local M1 = {}
M1.__index = M1

function M1.new(config)
    local radius = 35 -- Puedes ajustar el tamaño del golpe aquí

    return setmetatable({
        id = nil,
        type = "m1_attack",
        owner = config.owner,
        x = (config.x or 0) - radius,
        y = (config.y or 0) - radius,
        width = radius * 2,
        height = radius * 2,
        speed = 0,
        radius = radius,
        lifetime = config.lifetime or 0.15,
        age = 0,
        hasAppliedDamage = false,
        color = config.color or {1, 1, 1, 1},
        
        isComboFinisher = config.isComboFinisher or false,
        damage = config.damage or 5,
    	stunDuration = config.stunDuration or 0.5, -- Por defecto 0.5s como pediste
    	cooldownToApply = config.cooldownToApply or 0.3, -- Cooldown que el jugador debe esperar
    }, M1)
end

function M1:update(dt)
    self.age = self.age + dt

    -- Al pasar el tiempo de vida, el EntityManager la limpiará automáticamente
    if self.age >= self.lifetime then
        self.destroyed = true
    end
end

function M1:draw()
    -- Efecto de desvanecimiento sutil (Fade out)
    local alpha = math.max(0, 1 - self.age / self.lifetime)
    local centerX = self.x + self.radius
    local centerY = self.y + self.radius

    -- Relleno del círculo de golpe
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.25 * alpha)
    love.graphics.circle("fill", centerX, centerY, self.radius)

    -- Borde del círculo de golpe
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.8 * alpha)
    love.graphics.circle("line", centerX, centerY, self.radius)
end

return M1
