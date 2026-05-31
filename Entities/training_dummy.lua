-- Entities/training_dummy.lua
-- Enemigo placeholder para probar daño, proyectiles, AoE y pasivas on-hit.
local TrainingDummy = {}
TrainingDummy.__index = TrainingDummy

function TrainingDummy.new(x, y)
    return setmetatable({
        id = nil,
        type = "enemy",
        x = x or 260,
        y = y or 120,
        width = 56,
        height = 56,
        speed = 0,
        hp = 120,
        maxHp = 120
    }, TrainingDummy)
end

function TrainingDummy:receiveDamage(damage)
    self.hp = self.hp - damage

    if self.hp <= 0 then
        self.destroyed = true
    end

    return damage
end

function TrainingDummy:draw()
    local hpRatio = math.max(0, self.hp / self.maxHp)

    love.graphics.setColor(0.45, 0.12, 0.55, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8, 8)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 8, 8)

    love.graphics.setColor(0.95, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y - 12, self.width * hpRatio, 6, 3, 3)
end

return TrainingDummy
