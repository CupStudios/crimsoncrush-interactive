-- Entities/training_dummy.lua
-- Enemigo para probar daño, proyectiles, AoE, drops y pasivas on-hit.
local WillOrb = require("Entities.will_orb")
local M1 = require("Entities.m1")
local Interpolation = require("Utils.interpolation")

local TrainingDummy = {}
TrainingDummy.__index = TrainingDummy

function TrainingDummy.new(x, y)
    return setmetatable(
        {
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
            color = {0.45, 0.12, 0.55, 1},
            -- Físicas (Knockback)
            kx = 0,
            ky = 0,
            -- Animación
            attackAnimTimer = 0,
            visualRotation = 0,
            queuedAttack = nil,
            -- Combate
            physicalDamage = 4,
            stunTimer = 0,
            m1Timer = 0, -- Cooldown
            m1Combo = 0, -- Conteo de golpes (0 a 3)
            m1ComboReset = 0, -- Tiempo para perder el combo
            -- IA y Máquina de Estados
            speed = 130, -- Asegúrate de que tenga velocidad (por si estaba en 0)
            state = "neutral",
            decisionTimer = 0,
            baitTimer = 0,
            strafeDir = 1, -- 1 o -1 para caminar alrededor tuyo
            -- ESPECTRO DE PERSONALIDAD (Suma 1.0 en total)
            -- Ajusta estos números para que cada dummy sea distinto
            tendenciaNeutral = love.math.random(0.3, 0.5),
            tendenciaPasivo = love.math.random(0.1, 0.3),
            tendenciaOfensivo = love.math.random(0.2, 0.4),
            -- Debajo de tus otras variables de combate:
            sideDashCooldown = 0,
            frontBackDashCooldown = 0,
            isDashing = false,
            dashSpeed = 2000
        },
        TrainingDummy
    )
end

function TrainingDummy:receiveDamage(damage, source, entityManager)
    self.hp = self.hp - damage
    self.flashTimer = 0.15 -- Se pondrá blanco por 0.15 segundos

    -- Corrección: Si la vida llega a 0, muere y desaparece
    if self.hp <= 0 then
        self.destroyed = true
    end

    return damage
end

function TrainingDummy:m1(targetX, targetY, entityManager)
    if not entityManager or self.m1Timer > 0 then
        return
    end

    local myCenterX = self.x + self.width / 2
    local myCenterY = self.y + self.height / 2

    local angle = math.atan2(targetY - myCenterY, targetX - myCenterX)
    local attackDirX = math.cos(angle)
    local attackDirY = math.sin(angle)

    local hitOffset = 45
    local attackX = myCenterX + (attackDirX * hitOffset)
    local attackY = myCenterY + (attackDirY * hitOffset)

    -- Lógica del Combo y Dirección de Animación
    self.m1Combo = self.m1Combo + 1
    self.attackDirection = (self.m1Combo % 2 == 0) and 1 or -1

    local isFinisher = (self.m1Combo == 4)
    local duration = isFinisher and 2.0 or 0.3
    local finalDamage = self.physicalDamage
    local finalStun = 0.5
    local attackColor = {0.8, 0.4, 0.4}

    if isFinisher then
        finalDamage = self.physicalDamage * 2
        finalStun = 1.0
        attackColor = {1, 0.1, 0.1}
        self.m1Combo = 0
    end

    local attackInstance =
        M1.new(
        {
            owner = self,
            x = attackX,
            y = attackY,
            damage = finalDamage,
            isComboFinisher = isFinisher,
            stunDuration = finalStun,
            color = attackColor
        }
    )

    -- Encolamos el ataque para que la hitbox nazca después del Windup
    self.queuedAttack = attackInstance
    self.attackAnimTimer = 0.15

    self.m1Timer = duration
    self.m1ComboReset = 1.2
end

function TrainingDummy:update(dt, entityManager)
    -- 1. Físicas de empuje (Knockback) y fricción
    self.x = self.x + (self.kx or 0) * dt
    self.y = self.y + (self.ky or 0) * dt
    self.kx = (self.kx or 0) * 0.85
    self.ky = (self.ky or 0) * 0.85

    -- 2. Gestión de Timers
    if (self.flashTimer or 0) > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    if (self.m1Timer or 0) > 0 then
        self.m1Timer = self.m1Timer - dt
    end

    if self.m1ComboReset > 0 then
        self.m1ComboReset = self.m1ComboReset - dt
        if self.m1ComboReset <= 0 then
            self.m1Combo = 0
        end
    end

    -- 3. Animación de Combate (Windup e Interpolación)
    if (self.attackAnimTimer or 0) > 0 then
        self.attackAnimTimer = self.attackAnimTimer - dt
        local elapsed = 0.15 - math.max(0, self.attackAnimTimer)
        local dir = self.attackDirection or 1
        local windupAngle = math.rad(30) * dir
        local strikeAngle = math.rad(-35) * dir

        if elapsed <= 0.10 then
            local progress = elapsed / 0.10
            self.visualRotation = Interpolation.outSine(0, windupAngle, progress)
        else
            local progress = (elapsed - 0.10) / 0.05
            self.visualRotation = Interpolation.lerp(windupAngle, strikeAngle, progress)
        end

        -- Nace la hitbox
        if self.attackAnimTimer <= 0 and self.queuedAttack then
            entityManager:add(self.queuedAttack)
            self.queuedAttack = nil
        end
    else
        -- Recovery visual
        if (self.visualRotation or 0) ~= 0 then
            self.visualRotation = Interpolation.lerp(self.visualRotation, 0, 15 * dt)
            if math.abs(self.visualRotation) < 0.01 then
                self.visualRotation = 0
            end
        end
    end

    -- 4. Gestión del Stun
    if (self.stunTimer or 0) > 0 then
        self.stunTimer = self.stunTimer - dt
        return -- Si está stuneado, no procesa IA
    end

    -- 5. Lógica de IA (Máquina de Estados y Teoría del Juego)
    local player = entityManager:getPlayer()
    if not player then
        return
    end

    local myCenterX = self.x + self.width / 2
    local myCenterY = self.y + self.height / 2
    local pCenterX = player.x + player.width / 2
    local pCenterY = player.y + player.height / 2

    local dx = pCenterX - myCenterX
    local dy = pCenterY - myCenterY
    local distance = math.sqrt(dx * dx + dy * dy)
    local angleToPlayer = math.atan2(dy, dx)

    -- A) GESTIÓN DE TIMERS DE IA
    if (self.baitTimer or 0) > 0 then
        self.baitTimer = self.baitTimer - dt
    end

    self.decisionTimer = (self.decisionTimer or 0) - dt
    if self.decisionTimer <= 0 then
        local roll = love.math.random() -- Un número entre 0 y
        -- Selector ponderado
        if roll < self.tendenciaNeutral then
            self.state = "neutral"
        elseif roll < self.tendenciaNeutral + self.tendenciaPasivo then
            self.state = "pasivo"
        else
            self.state = "ofensivo"
        end

        -- Ajuste dinámico basado en tendencia
        if self.state == "ofensivo" then
            -- Los ofensivos cambian de decisión más rápido para presionar
            self.decisionTimer = self.decisionTimer * 0.7
        elseif self.state == "pasivo" then
            -- Los pasivos son más lentos al cambiar de táctica
            self.decisionTimer = self.decisionTimer * 1.5
        end
        self.strafeDir = love.math.random(0, 1) == 0 and 1 or -1
    end

    -- B) LECTURA DEL OPONENTE: WHIFF PUNISH (Castigo)
    -- Si el jugador falló un M1 pesado y está en cooldown alto (> 1 segundo)
    if player.m1Timer and player.m1Timer >= 1.0 then
        self.state = "ofensivo" -- Cambia a ofensivo de inmediato
        self.decisionTimer = 2.0 -- Mantiene la agresión
    end

    -- C) EJECUCIÓN DEL ESTADO ACTUAL

    -- --- LÓGICA DE DASH MEJORADA ---
    
    local canDash = (self.sideDashCooldown <= 0 or self.frontBackDashCooldown <= 0)
    
    -- MIXUP: Dash si el jugador bloquea (Inicia el mixup de forma agresiva)
    if player.isBlocking and distance > 50 and distance < 250 and canDash then
        self.state = "ofensivo" -- Cambiamos a ofensivo para que ataque al llegar
        local dx = pCenterX - myCenterX
        local dy = pCenterY - myCenterY
        local len = math.sqrt(dx*dx + dy*dy)
        self.kx, self.ky = (dx/len) * self.dashSpeed * 1.5, (dy/len) * self.dashSpeed * 1.5
        self.sideDashCooldown, self.frontBackDashCooldown = 1.0, 2.0
        self.decisionTimer = 0.15
        
    -- DASH NORMAL (Ofensivo, Neutral o Pasivo)
    elseif distance > 60 and distance < 200 and canDash then
        -- Probabilidad de dashear: 10% si está en neutral/pasivo, 30% si es ofensivo
        local dashChance = (self.state == "ofensivo") and 0.3 or 0.1
        
        if love.math.random() < dashChance then
            local dx = pCenterX - myCenterX
            local dy = pCenterY - myCenterY
            local len = math.sqrt(dx*dx + dy*dy)
            self.kx, self.ky = (dx/len) * self.dashSpeed, (dy/len) * self.dashSpeed
            
            self.sideDashCooldown = 1.0
            self.frontBackDashCooldown = 2.0
            
            -- ¡CRUCIAL! Si dasheamos, forzamos el estado ofensivo para que ataque
            self.state = "ofensivo"
        end
    end

    if self.state == "neutral" then
        -- ESTADO NEUTRAL: Spacing (Mantiene la distancia entre 80 y 120 px)
        self.isBlocking = love.math.random() < 0.02 -- Bloquea un 2% del tiempo (toques rápidos)

        local moveDx, moveDy = 0, 0
        if distance < 80 then
            -- Si estás muy cerca, retrocede
            moveDx = -math.cos(angleToPlayer)
            moveDy = -math.sin(angleToPlayer)
        elseif distance > 120 then
            -- Si estás muy lejos, se acerca
            moveDx = math.cos(angleToPlayer)
            moveDy = math.sin(angleToPlayer)
        else
            -- Si está en la zona ideal, camina lateralmente (Strafe) para buscar un ángulo
            moveDx = math.cos(angleToPlayer + (math.pi / 2 * self.strafeDir))
            moveDy = math.sin(angleToPlayer + (math.pi / 2 * self.strafeDir))
        end

        self.x = self.x + moveDx * self.speed * dt
        self.y = self.y + moveDy * self.speed * dt
    elseif self.state == "pasivo" then
        -- ESTADO PASIVO: Defensa pura. Retrocede todo el tiempo con la guardia arriba
        self.isBlocking = true
        if distance < 200 then
            self.x = self.x - math.cos(angleToPlayer) * self.speed * dt
            self.y = self.y - math.sin(angleToPlayer) * self.speed * dt
        end
    elseif self.state == "ofensivo" then
        -- ESTADO OFENSIVO: Agresión y Mixups
        self.isBlocking = false

        if distance > 45 then
            -- Cierra la distancia rápidamente
            self.x = self.x + math.cos(angleToPlayer) * self.speed * dt
            self.y = self.y + math.sin(angleToPlayer) * self.speed * dt
            self.decisionTimer = 0
        else
            -- Está en rango de M1

            -- LÓGICA DE MIXUP (BAIT):
            -- Si tú estás bloqueando, el Dummy tiene una pequeña probabilidad de "pausarse"
            -- por 0.5s para engañarte y hacer que sueltes el bloqueo.
            if player.isBlocking and self.baitTimer <= 0 and love.math.random() < 0.03 then
                self.baitTimer = 0.5
            end

            -- Lanza el ataque si no está "baiteando" y tiene su cooldown limpio
            if self.m1Timer <= 0 and self.baitTimer <= 0 then
                self:m1(pCenterX, pCenterY, entityManager)
            end
        end
    end
end

function TrainingDummy:onDestroy(entityManager)
    if love.math.random() <= 0.5 then
        local orbType = love.math.random() < 0.75 and "reserva" or "experiencia"
        local amount = orbType == "reserva" and love.math.random(20, 90) or love.math.random(5, 25)

        entityManager:add(
            WillOrb.new(
                {
                    x = self.x + self.width / 2,
                    y = self.y + self.height / 2,
                    cantidad_energia = amount,
                    tipo = orbType
                }
            )
        )
    end
end

function TrainingDummy:draw()
    local hpRatio = math.max(0, self.hp / self.maxHp)

    if (self.flashTimer or 0) > 0 then
        love.graphics.setColor(1, 1, 1, 1)
    else
        local c = self.color or {0.45, 0.12, 0.55, 1}
        love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
    end

    love.graphics.push()
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.visualRotation or 0)

    love.graphics.rectangle("fill", -self.width / 2, -self.height / 2, self.width, self.height, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", -self.width / 2, -self.height / 2, self.width, self.height, 8, 8)
    love.graphics.pop()

    love.graphics.setColor(0.95, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y - 12, self.width * hpRatio, 6, 3, 3)
end

return TrainingDummy

