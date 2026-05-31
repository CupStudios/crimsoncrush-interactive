-- Entities/player.lua
-- Entidad jugador: rectángulo placeholder con movimiento top-down WASD y Will RNG.
local WillFactory = require("Wills.will_factory")
local M1 = require("Entities.m1") -- Asegúrate de importar el nuevo módulo

local Player = {}
Player.__index = Player

function Player.new(x, y)
    return setmetatable({
        id = nil,
        type = "player",
        x = x or 0,
        y = y or 0,
        width = 48,
        height = 64,
        speed = 280,
        hp = 100,
        maxHp = 100,
        physicalDamage = 6,
        willExperience = 0,
        color = {0.9, 0.15, 0.12, 1},
        dirX = 0,
        dirY = 1,
        will = WillFactory.generate(),
	isBlocking = false,
	stunTimer = 0,
	m1Timer = 0,        -- Cooldown de 0.3s
	m1Combo = 0,        -- En qué golpe del combo vamos (0 a 3)
	m1ComboReset = 0   -- Tiempo para perder el combo si dejas de atacar
    }, Player)
end

function Player:update(dt, entityManager)
    if self.stunTimer > 0 then
        self.stunTimer = self.stunTimer - dt
        self.isBlocking = false -- Si te stunean, rompen tu guardia
        return -- Salimos del update: no te mueves, no atacas, no canalizas Will
    end

    if self.m1Timer > 0 then self.m1Timer = self.m1Timer - dt end
    
    if self.m1ComboReset > 0 then 
        self.m1ComboReset = self.m1ComboReset - dt
        if self.m1ComboReset <= 0 then self.m1Combo = 0 end -- Reinicia el combo
    end
    self.isBlocking = love.mouse.isDown(2) or love.keyboard.isDown("f")

    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    local isMoving = dx ~= 0 or dy ~= 0

    -- Normaliza el vector para que moverse en diagonal no sea más rápido.
    if isMoving then
        local length = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / length, dy / length
        self.dirX, self.dirY = dx, dy
    end

    local currentSpeed = self.isBlocking and (self.speed * 0.4) or self.speed

    self.x = self.x + dx * currentSpeed * dt
    self.y = self.y + dy * currentSpeed * dt

    self.entityManager = entityManager
    self.will:update(dt)
    self.will:updateChanneling(self, dt, love.keyboard.isDown("e"))

    -- Hook de pasiva por movimiento: pasivas como Inercia pueden cargar output.
    if isMoving then
        self.will:onMove(self, dt)
    end
end

function Player:useWillAbility(entityManager)
    return self.will:tryActivate(self, entityManager or self.entityManager)
end

function Player:m1(mouseX, mouseY)
    if not self.entityManager or self.m1Timer > 0 then return end

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

    local attackInstance = M1.new({
        owner = self,
        x = attackX,
        y = attackY,
        damage = finalDamage,
        isComboFinisher = isFinisher,
        stunDuration = finalStun,
        color = attackColor
    })

    self.entityManager:add(attackInstance)

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
    self.will:drawAura(self)

    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 6, 6)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 6, 6)
end

return Player
