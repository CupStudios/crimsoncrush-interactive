-- Wills/will_factory.lua
-- Fábrica RNG para crear Wills procedurales e integrarlos con el EntityManager.
local Projectile = require("Entities.projectile")
local AoeBlast = require("Entities.aoe_blast")

local WillFactory = {}

local ARCHETYPES = {
    {
        name = "Bélico",
        description = "Aumenta la fuerza a costa de eficiencia defensiva.",
        strengthMultiplier = 1.35,
        cooldownMultiplier = 1.08
    },
    {
        name = "Eterno",
        description = "Reservas estables y cooldowns más largos.",
        strengthMultiplier = 0.9,
        cooldownMultiplier = 1.2
    },
    {
        name = "Fluido",
        description = "Canalización ágil y cooldowns reducidos.",
        strengthMultiplier = 1.0,
        cooldownMultiplier = 0.82
    },
    {
        name = "Voraz",
        description = "Gran output ofensivo con coste energético mayor.",
        strengthMultiplier = 1.18,
        cooldownMultiplier = 0.95
    }
}

local PASSIVES = {
    {
        id = "siphon",
        name = "Sifón de Esencia",
        description = "Cura al jugador un porcentaje del daño infligido.",
        onDamageDealt = function(will, player, target, damage)
            local healing = damage * will.passivePower
            player.hp = math.min(player.maxHp, player.hp + healing)
            will.lastPassiveText = string.format("Sifón +%.1f HP", healing)
        end
    },
    {
        id = "inertia",
        name = "Inercia Cinética",
        description = "Moverse convierte una pequeña parte de la reserva en output.",
        onMove = function(will, player, dt)
            local flow = will.output_maximo * will.passivePower * dt
            will:transferEnergy(flow)
            will.lastPassiveText = "Inercia canalizando"
        end
    },
    {
        id = "ember",
        name = "Ascua Interna",
        description = "Regenera lentamente reservas al moverse.",
        onMove = function(will, player, dt)
            local regen = math.max(1, will.reserva_maxima * will.passivePower * dt)
            will.reserva_actual = math.min(will.reserva_maxima, will.reserva_actual + regen)
            will.lastPassiveText = "Reserva regenerada"
        end
    }
}

local function randomFloat(min, max)
    return min + (max - min) * love.math.random()
end

local function randomColor()
    return {
        love.math.random(70, 255) / 255,
        love.math.random(70, 255) / 255,
        love.math.random(70, 255) / 255,
        1
    }
end

local function biasedRange(minValue, maxValue, exponent)
    -- Curva no lineal: elevar el RNG concentra la mayoría de resultados cerca
    -- del mínimo y hace que los valores altos sean anomalías.
    local t = love.math.random() ^ exponent
    return math.floor(minValue + (maxValue - minValue) * t)
end

local function generateReserveMax()
    local roll = love.math.random()

    -- Aproximadamente 88% de Wills quedan bajo 1,000 de reserva.
    if roll <= 0.88 then
        return biasedRange(20, 999, 2.8)
    end

    -- 11% entran en rangos raros medios.
    if roll <= 0.99 then
        return biasedRange(1000, 25000, 3.4)
    end

    -- 1% puede alcanzar anomalías de seis cifras.
    return biasedRange(25000, 200000, 4.6)
end

local function generateOutputMax(reserveMax)
    local roll = love.math.random()
    local output

    -- El output también está sesgado hacia valores bajos y se acota para que
    -- sea proporcional a la reserva en Wills comunes.
    if roll <= 0.9 then
        output = biasedRange(5, 400, 3.0)
    elseif roll <= 0.99 then
        output = biasedRange(401, 12000, 3.6)
    else
        output = biasedRange(12001, 100000, 4.8)
    end

    local proportionalCap = math.max(5, math.floor(reserveMax * randomFloat(0.18, 0.55)))
    return math.min(output, 100000, proportionalCap)
end

local function buildActiveSkill(will)
    local skillType = love.math.random() < 0.55 and "projectile" or "aoe"
    local cooldown = randomFloat(1.2, 4.5) * will.cooldownMultiplier
    local energyCost = math.max(3, math.floor(will.output_maximo * randomFloat(0.22, 0.45)))

    if skillType == "projectile" then
        return {
            type = "projectile",
            name = "Lanza de Will",
            cooldown = cooldown,
            timer = 0,
            energyCost = energyCost,
            projectileSpeed = randomFloat(520, 820),
            lifetime = randomFloat(0.75, 1.35),
            damageMultiplier = randomFloat(1.1, 2.4)
        }
    end

    return {
        type = "aoe",
        name = "Pulso de Dominio",
        cooldown = cooldown,
        timer = 0,
        energyCost = energyCost,
        radius = randomFloat(70, 165),
        lifetime = randomFloat(0.22, 0.42),
        damageMultiplier = randomFloat(0.85, 1.8)
    }
end

local Will = {}
Will.__index = Will

function Will:transferEnergy(amount)
    if amount <= 0 or self.reserva_actual <= 0 or self.output_actual >= self.output_maximo then
        return 0
    end

    local transferable = math.min(amount, self.reserva_actual, self.output_maximo - self.output_actual)
    self.reserva_actual = self.reserva_actual - transferable
    self.output_actual = self.output_actual + transferable
    return transferable
end

function Will:update(dt)
    if self.active.timer > 0 then
        self.active.timer = math.max(0, self.active.timer - dt)
    end
end

function Will:updateChanneling(player, dt, isChanneling)
    self.isChanneling = isChanneling

    if not isChanneling then
        return
    end

    local flowPerSecond = math.max(12, self.output_maximo * 0.9)
    self:transferEnergy(flowPerSecond * dt)
end

function Will:onMove(player, dt)
    if self.passive.onMove then
        self.passive.onMove(self, player, dt)
    end
end

function Will:onDamageDealt(player, target, damage)
    if self.passive.onDamageDealt then
        self.passive.onDamageDealt(self, player, target, damage)
    end
end

function Will:tryActivate(player, entityManager)
    if self.active.timer > 0 then
        self.lastError = "Habilidad en cooldown"
        return false
    end

    if self.output_actual < self.active.energyCost then
        self.lastError = "Output insuficiente: canaliza con E"
        return false
    end

    self.output_actual = self.output_actual - self.active.energyCost
    self.active.timer = self.active.cooldown
    self.lastError = nil

    if self.active.type == "projectile" then
        local directionX, directionY = player.dirX, player.dirY
        if directionX == 0 and directionY == 0 then
            directionY = 1
        end

        entityManager:add(Projectile.new({
            owner = player,
            x = player.x + player.width / 2,
            y = player.y + player.height / 2,
            directionX = directionX,
            directionY = directionY,
            speed = self.active.projectileSpeed,
            damage = self.strength * self.active.damageMultiplier,
            lifetime = self.active.lifetime,
            color = self.color
        }))
    else
        entityManager:add(AoeBlast.new({
            owner = player,
            x = player.x + player.width / 2,
            y = player.y + player.height / 2,
            radius = self.active.radius,
            damage = self.strength * self.active.damageMultiplier,
            lifetime = self.active.lifetime,
            color = self.color
        }))
    end

    return true
end

function Will:getAuraRadius(player)
    local chargeRatio = self.output_maximo > 0 and (self.output_actual / self.output_maximo) or 0
    local pulse = 6 * math.sin(love.timer.getTime() * 12)
    return math.max(player.width, player.height) * 0.9 + chargeRatio * 42 + pulse
end

function Will:getAuraCircle(player)
    return {
        x = player.x + player.width / 2,
        y = player.y + player.height / 2,
        radius = self:getAuraRadius(player)
    }
end

function Will:drawAura(player)
    if not self.isChanneling then
        return
    end

    local aura = self:getAuraCircle(player)

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.24)
    love.graphics.circle("fill", aura.x, aura.y, aura.radius)

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.88)
    love.graphics.circle("line", aura.x, aura.y, aura.radius)
end

function WillFactory.generate()
    local archetype = ARCHETYPES[love.math.random(#ARCHETYPES)]
    local reserveMax = generateReserveMax()
    local outputMax = generateOutputMax(reserveMax)
    local passive = PASSIVES[love.math.random(#PASSIVES)]

    local will = setmetatable({
        archetype = archetype.name,
        archetypeDescription = archetype.description,
        strength = math.floor(randomFloat(8, 28) * archetype.strengthMultiplier),
        cooldownMultiplier = archetype.cooldownMultiplier,
        reserva_maxima = reserveMax,
        -- El Will nace con sus reservas disponibles; el output empieza vacío y debe cargarse con E.
        reserva_actual = reserveMax,
        output_maximo = outputMax,
        output_actual = 0,
        passive = passive,
        passivePower = randomFloat(0.04, 0.1),
        color = randomColor(),
        isChanneling = false,
        lastError = nil,
        lastPassiveText = nil
    }, Will)

    will.active = buildActiveSkill(will)
    return will
end

return WillFactory
