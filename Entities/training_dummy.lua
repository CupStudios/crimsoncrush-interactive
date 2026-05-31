-- Entities/training_dummy.lua
-- Enemigo placeholder para probar daño, proyectiles, AoE, drops y pasivas on-hit.
local WillOrb = require("Entities.will_orb")
local M1 = require("Entities.m1")

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
        hitFlash = 0,
        isBlocking = false,
        
        physicalDamage = 4,
        stunTimer = 0,
        m1Timer = 0,        -- Cooldown de 0.3s
        m1Combo = 0,        -- En qué golpe del combo vamos (0 a 3)
        m1ComboReset = 0   -- Tiempo para perder el combo si dejas de atacar
    }, TrainingDummy)
end

function TrainingDummy:receiveDamage(damage, source, entityManager)
    self.hp = self.hp - damage
    self.flashTimer = 0.15 -- Se pondrá blanco por 0.15 segundos
    return damage
end

-- Entities/training_dummy.lua
-- Asegúrate de importar el M1 al inicio del archivo del Dummy también.

function TrainingDummy:m1(targetX, targetY, entityManager)
    if not entityManager or self.m1Timer > 0 then return end

    local myCenterX = self.x + self.width / 2
    local myCenterY = self.y + self.height / 2

    -- Trigonometría: Ángulo hacia el objetivo (el jugador)
    local angle = math.atan2(targetY - myCenterY, targetX - myCenterX)
    
    local attackDirX = math.cos(angle)
    local attackDirY = math.sin(angle)

    local hitOffset = 45
    local attackX = myCenterX + (attackDirX * hitOffset)
    local attackY = myCenterY + (attackDirY * hitOffset)

    -- Lógica del Combo del Dummy
    self.m1Combo = self.m1Combo + 1
    local isFinisher = (self.m1Combo == 4)
    
    -- Cooldown que sufrirá el Dummy
    local duration = isFinisher and 2.0 or 0.3
    
    local finalDamage = self.physicalDamage 
    local finalStun = 0.5 -- El Dummy también aplica 0.5s de stun
    local attackColor = {0.8, 0.4, 0.4} 

    if isFinisher then
        finalDamage = self.physicalDamage * 2
        finalStun = 1.0
        attackColor = {1, 0.1, 0.1}
        self.m1Combo = 0
    end

    local attackInstance = M1.new({
        owner = self,
        x = attackX,
        y = attackY,
        damage = finalDamage,
        isComboFinisher = isFinisher,
        stunDuration = finalStun,
        color = attackColor
    })

    entityManager:add(attackInstance)

    -- El Dummy también sufre los 2 segundos de recovery si falla el 4to golpe
    self.m1Timer = duration 
    self.m1ComboReset = 1.2
end

function TrainingDummy:update(dt, entityManager)
    -- 1. Gestión de Timers (Ejecutados UNA sola vez)
    if (self.flashTimer or 0) > 0 then self.flashTimer = self.flashTimer - dt end
    if (self.m1Timer or 0) > 0 then self.m1Timer = self.m1Timer - dt end
    
    if self.m1ComboReset > 0 then 
        self.m1ComboReset = self.m1ComboReset - dt
        if self.m1ComboReset <= 0 then self.m1Combo = 0 end
    end

    -- 2. Gestión del Stun (Si está stuneado, no se mueve ni ataca)
    if (self.stunTimer or 0) > 0 then
        self.stunTimer = self.stunTimer - dt
        return -- Salida temprana: no procesa IA ni movimiento
    end

    -- 3. Lógica de IA
    local player = entityManager:getPlayer()
    if not player then return end

    local myCenterX = self.x + self.width / 2
    local myCenterY = self.y + self.height / 2
    local pCenterX = player.x + player.width / 2
    local pCenterY = player.y + player.height / 2

    local dx = pCenterX - myCenterX
    local dy = pCenterY - myCenterY
    local distance = math.sqrt(dx*dx + dy*dy)

    -- IA de Combate
    if distance > 100 then 
        -- Estado Neutral/Ofensivo: Persigue si está lejos
        self.isBlocking = false
        self.x = self.x + (dx / distance) * 150 * dt
        self.y = self.y + (dy / distance) * 150 * dt
    else
        -- Estado de Rango de Combate: Decide entre atacar o bloquear
        if self.m1Timer <= 0 then
            self.isBlocking = false
            self:m1(pCenterX, pCenterY, entityManager)
        else
            -- Bloqueo activo (30% de probabilidad para simular reacción)
            self.isBlocking = love.math.random() > 0.7 
        end
    end
end

-- El Dummy necesita su propia copia exacta de la función m1() que le pusimos al jugador, 
-- pero usando `self.physicalDamage` del Dummy.

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

    -- Lógica de color: Si el timer es mayor a 0, se pone blanco
    if (self.flashTimer or 0) > 0 then
        love.graphics.setColor(1, 1, 1, 1) 
    else
        -- Color original del Dummy
        love.graphics.setColor(0.45, 0.12, 0.55, 1)
    end
    
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8, 8)

    -- Borde y UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 8, 8)

    love.graphics.setColor(0.95, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y - 12, self.width * hpRatio, 6, 3, 3)
end

return TrainingDummy
