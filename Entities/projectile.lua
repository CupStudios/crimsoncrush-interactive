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

function Projectile:update(dt, entityManager)
    self.age = self.age + dt
    self.x = self.x + self.directionX * self.speed * dt
    self.y = self.y + self.directionY * self.speed * dt

    if self.age >= self.lifetime then
        self.destroyed = true
        return
    end

    -- Hook de daño preparado para enemigos/NPCs futuros con hp y receiveDamage.
    for _, entity in ipairs(entityManager.entities) do
        if entity ~= self and entity ~= self.owner and entity.hp and not entity.destroyed then
            local overlaps = self.x < entity.x + entity.width
                and self.x + self.width > entity.x
                and self.y < entity.y + entity.height
                and self.y + self.height > entity.y

            if overlaps then
                local damage = self.damage
                if entity.receiveDamage then
                    damage = entity:receiveDamage(damage, self.owner)
                else
                    entity.hp = entity.hp - damage
                end

                if self.owner and self.owner.onDealDamage then
                    self.owner:onDealDamage(entity, damage)
                end

                self.destroyed = true
                return
            end
        end
    end
end

function Projectile:draw()
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.92)
    love.graphics.circle("fill", self.x + self.width / 2, self.y + self.height / 2, self.width / 2)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", self.x + self.width / 2, self.y + self.height / 2, self.width / 2)
end

return Projectile
