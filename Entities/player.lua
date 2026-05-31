-- Entities/player.lua
local WillFactory = require("Wills.will_factory")
local M1 = require("Entities.m1")
local Interpolation = require("Utils.interpolation")
local MobileControls = require("Utils.mobile_controls") -- ¡INTEGRADO!

local Player = {}
Player.__index = Player

function Player.new(x, y)
    return setmetatable({
        id = nil, type = "player", x = x or 0, y = y or 0,
        width = 48, height = 64, speed = 280,
        hp = 100, maxHp = 100, physicalDamage = 6,
        willExperience = 0, color = {0.9, 0.15, 0.12, 1},
        dirX = 0, dirY = 1, will = WillFactory.generate(),
        isBlocking = false, stunTimer = 0, m1Timer = 0,
        m1Combo = 0, m1ComboReset = 0,
        attackAnimTimer = 0, visualRotation = 0, queuedAttack = nil,
        kx = 0, ky = 0,
        
        -- Dash
        isDashing = false, dashTimer = 0,
        sideDashCooldown = 0, frontBackDashCooldown = 0,
        dashSpeed = 2000
    }, Player)
end

function Player:update(dt, entityManager)
    -- [1] Animación (Ahora delegada a la función que acabamos de crear)
    self:updateAnimation(dt, entityManager)

    -- [2] Físicas (Knockback y Fricción)
    self.x = self.x + self.kx * dt
    self.y = self.y + self.ky * dt
    self.kx = self.kx * 0.85
    self.ky = self.ky * 0.85

    -- [3] Stun y Timers
    if self.stunTimer > 0 then
        self.stunTimer = self.stunTimer - dt
        self.isBlocking = false
        return
    end

    if self.m1Timer > 0 then self.m1Timer = self.m1Timer - dt end
    if self.m1ComboReset > 0 then
        self.m1ComboReset = self.m1ComboReset - dt
        if self.m1ComboReset <= 0 then self.m1Combo = 0 end
    end

    -- [4] Inputs (Mobile + Keyboard)
    local joyX, joyY = MobileControls:getJoystickVector()
    local dx = (love.keyboard.isDown("d") and 1 or 0) - (love.keyboard.isDown("a") and 1 or 0) + joyX
    local dy = (love.keyboard.isDown("s") and 1 or 0) - (love.keyboard.isDown("w") and 1 or 0) + joyY
    
    local dashPressed = love.keyboard.isDown("q") or MobileControls:isActionPressed("dash")
    if dashPressed then
        if not self.isDashing then
            local isSide = (dx ~= 0 and dy == 0)
            if isSide and self.sideDashCooldown <= 0 then
                self.kx, self.ky = dx * self.dashSpeed, dy * self.dashSpeed
                self.sideDashCooldown = 1.0
                self.isDashing = true
                self.dashTimer = 0.15
            elseif not isSide and self.frontBackDashCooldown <= 0 then
                self.kx, self.ky = dx * self.dashSpeed, dy * self.dashSpeed
                self.frontBackDashCooldown = 2.0
                self.isDashing = true
                self.dashTimer = 0.15
            end
        end
    end

    if self.isDashing then
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then self.isDashing = false end
    else
        local isMoving = dx ~= 0 or dy ~= 0
        if isMoving then
            local length = math.sqrt(dx * dx + dy * dy)
            dx, dy = dx / length, dy / length
            self.dirX, self.dirY = dx, dy
            
            local currentSpeed = (love.keyboard.isDown("f") or MobileControls:isActionPressed("block")) and (self.speed * 0.4) or self.speed
            self.x = self.x + dx * currentSpeed * dt
            self.y = self.y + dy * currentSpeed * dt
        end
    end

    -- [5] Will y otros
    self.isBlocking = love.keyboard.isDown("f") or MobileControls:isActionPressed("block")
    self.entityManager = entityManager
    self.will:update(dt)
    self.will:updateChanneling(self, dt, love.keyboard.isDown("e") or MobileControls:isActionPressed("charge"))

    if (dx ~= 0 or dy ~= 0) then
        self.will:onMove(self, dt)
    end
end

function Player:useWillAbility(entityManager)
    return self.will:tryActivate(self, entityManager or self.entityManager)
end

function Player:m1(mouseX, mouseY)
    if not self.entityManager or self.m1Timer > 0 then
        return
    end

    local playerCenterX = self.x + self.width / 2
    local playerCenterY = self.y + self.height / 2

    -- Trigonometría: Ángulo hacia el mouse
    local angle = math.atan2(mouseY - playerCenterY, mouseX - playerCenterX)

    -- Convertimos el ángulo en un vector de dirección (dirX, dirY)
    local attackDirX = math.cos(angle)
    local attackDirY = math.sin(angle)

    local hitOffset = 45
    local attackX = playerCenterX + (attackDirX * hitOffset)
    local attackY = playerCenterY + (attackDirY * hitOffset)

    -- Lógica del Combo
    self.m1Combo = self.m1Combo + 1
    self.attackDirection = (self.m1Combo % 2 == 0) and 1 or -1
    local isFinisher = (self.m1Combo == 4)

    -- Calculamos el cooldown del atacante
    local duration = isFinisher and 2.0 or 0.3

    local finalDamage = self.physicalDamage
    local finalStun = 0.5 -- ¡Los golpes 1, 2 y 3 ahora aturden 0.5s!
    local attackColor = {0.8, 0.8, 0.8}

    if isFinisher then
        finalDamage = self.physicalDamage * 2
        finalStun = 1.0 -- El 4to golpe aturde por 1 segundo completo
        attackColor = {1, 0.2, 0.2} -- Rojo para indicar el golpe fuerte
        self.m1Combo = 0 -- Reiniciamos el combo tras el golpe final
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

    -- En vez de spawnearlo inmediatamente, lo encolamos
    self.queuedAttack = attackInstance
    self.attackAnimTimer = 0.15 -- 0.15s de animación antes del impacto

    -- Aplicamos los timers usando nuestra variable calculada
    self.m1Timer = duration
    self.m1ComboReset = 1.2 -- Si pasa 1.2s sin atacar, vuelve al golpe 1
end

function Player:onDealDamage(target, damage)
    -- Hook preparado para robo de vida, buffs al golpear y futuras mecánicas de combate.
    self.will:onDamageDealt(self, target, damage)
end

function Player:getAuraCircle()
    if not self.will.isChanneling then
        return nil
    end

    return self.will:getAuraCircle(self)
end

function Player:draw()
    if self.will and self.will.drawAura then
        self.will:drawAura(self)
    end

    love.graphics.push()

    -- 1. Movemos la "cámara matemática" al centro exacto del jugador
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    love.graphics.translate(centerX, centerY)

    -- 2. Rotamos el eje
    love.graphics.rotate(self.visualRotation or 0)

    -- 3. Dibujamos el rectángulo (como el centro ya está desplazado,
    -- lo dibujamos desde -mitad_ancho y -mitad_alto)
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", -self.width / 2, -self.height / 2, self.width, self.height, 6, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", -self.width / 2, -self.height / 2, self.width, self.height, 6, 6)

    love.graphics.pop() -- Restauramos la cámara
end

function Player:updateAnimation(dt, entityManager)
    if (self.attackAnimTimer or 0) > 0 then
        self.attackAnimTimer = self.attackAnimTimer - dt

        -- Calculamos cuánto tiempo ha pasado desde que inició el ataque (de 0 a 0.15)
        local elapsed = 0.15 - math.max(0, self.attackAnimTimer)

        -- Alternamos la dirección en base al combo (+1 o -1)
        local dir = self.attackDirection or 1
        local windupAngle = math.rad(30) * dir
        local strikeAngle = math.rad(-35) * dir -- Contrario al windup

        if elapsed <= 0.10 then
            -- FASE 1: WINDUP (0s a 0.1s)
            local progress = elapsed / 0.10
            self.visualRotation = Interpolation.outSine(0, windupAngle, progress)
        else
            -- FASE 2: GOLPE (0.1s a 0.15s)
            local progress = (elapsed - 0.10) / 0.05
            self.visualRotation = Interpolation.lerp(windupAngle, strikeAngle, progress)
        end

        -- Exactamente cuando el timer termina, nace la hitbox
        if self.attackAnimTimer <= 0 and self.queuedAttack then
            entityManager:add(self.queuedAttack)
            self.queuedAttack = nil
        end
    else
        -- RECOVERY SUAVE: Si no está atacando, el cuerpo regresa al centro fluidamente
        if (self.visualRotation or 0) ~= 0 then
            self.visualRotation = Interpolation.lerp(self.visualRotation, 0, 15 * dt)
            if math.abs(self.visualRotation) < 0.01 then
                self.visualRotation = 0
            end
        end
    end
end

return Player

