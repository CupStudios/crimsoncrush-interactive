-- Entities/training_dummy.lua
-- Enemigo placeholder para probar daño, proyectiles, AoE, drops y pasivas on-hit.
local WillOrb = require("Entities.will_orb")

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
        maxHp = 120,
        hitFlash = 0
    }, TrainingDummy)
end

function TrainingDummy:receiveDamage(damage)
    self.hp = self.hp - damage
    self.hitFlash = 0.14

    if self.hp <= 0 then
        self.destroyed = true
    end

    return damage
end

function TrainingDummy:update(dt)
    self.hitFlash = math.max(0, self.hitFlash - dt)
end

function TrainingDummy:onDestroy(entityManager)
    -- 50% de probabilidad de soltar un Will Orb en la posición exacta del enemigo.
    if love.math.random() <= 0.5 then
        local orbType = love.math.random() < 0.75 and "reserva" or "experiencia"
        local amount = orbType == "reserva" and love.math.random(20, 90) or love.math.random(5, 25)

        entityManager:add(WillOrb.new({
            x = self.x + self.width / 2,
            y = self.y + self.height / 2,
            cantidad_energia = amount,
            tipo = orbType
        }))
    end
end

function TrainingDummy:draw()
    local hpRatio = math.max(0, self.hp / self.maxHp)

    if self.hitFlash > 0 then
        love.graphics.setColor(1, 0.9, 0.95, 1)
    else
        love.graphics.setColor(0.45, 0.12, 0.55, 1)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8, 8)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 8, 8)

    love.graphics.setColor(0.95, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y - 12, self.width * hpRatio, 6, 3, 3)
end

return TrainingDummy
