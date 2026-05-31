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

function AoeBlast:update(dt, entityManager)
    self.age = self.age + dt

    if not self.hasAppliedDamage then
        self.hasAppliedDamage = true
        local centerX = self.x + self.radius
        local centerY = self.y + self.radius

        -- Daño en lote: afectará a cualquier entidad futura con hp dentro del radio.
        for _, entity in ipairs(entityManager.entities) do
            if entity ~= self and entity ~= self.owner and entity.hp and not entity.destroyed then
                local entityCenterX = entity.x + entity.width / 2
                local entityCenterY = entity.y + entity.height / 2
                local dx = entityCenterX - centerX
                local dy = entityCenterY - centerY

                if dx * dx + dy * dy <= self.radius * self.radius then
                    local damage = self.damage
                    if entity.receiveDamage then
                        damage = entity:receiveDamage(damage, self.owner)
                    else
                        entity.hp = entity.hp - damage
                    end

                    if self.owner and self.owner.onDealDamage then
                        self.owner:onDealDamage(entity, damage)
                    end
                end
            end
        end
    end

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
