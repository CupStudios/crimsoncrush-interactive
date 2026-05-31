-- Entities/aoe_blast.lua
-- Entidad temporal de daño en área creada por Wills tipo AoE.
local AoeBlast = {}
AoeBlast.__index = AoeBlast

function AoeBlast.new(config)
    local radius = config.radius or 96

    return setmetatable({
        id = nil,
        type = "aoe_blast",
        owner = config.owner,
        x = (config.x or 0) - radius,
        y = (config.y or 0) - radius,
        width = radius * 2,
        height = radius * 2,
        speed = 0,
        radius = radius,
        damage = config.damage or 1,
        lifetime = config.lifetime or 0.3,
        age = 0,
        hasAppliedDamage = false,
        color = config.color or {1, 1, 1, 1}
    }, AoeBlast)
end

function AoeBlast:update(dt)
    self.age = self.age + dt

    -- El daño círculo-círculo se resuelve centralizadamente en EntityManager.
    if self.age >= self.lifetime then
        self.destroyed = true
    end
end

function AoeBlast:draw()
    local alpha = math.max(0, 1 - self.age / self.lifetime)
    local centerX = self.x + self.radius
    local centerY = self.y + self.radius

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.18 * alpha)
    love.graphics.circle("fill", centerX, centerY, self.radius)

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.9 * alpha)
    love.graphics.circle("line", centerX, centerY, self.radius)
end

return AoeBlast
