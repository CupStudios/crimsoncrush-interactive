-- Wills/will_factory.lua
-- Fábrica RNG para crear Wills procedurales e integrarlos con el EntityManager.
local Projectile = require("Entities.projectile")
local AoeBlast = require("Entities.aoe_blast")

local WillFactory = {}

local ARCHETYPES = {
    {
        id = "dominio",
        name = "Dominio",
        description = "Somete el espacio cercano con presión de aura: fuerte, pesado y lento.",
        strengthMultiplier = 1.22,
        cooldownMultiplier = 1.35,
        color = {0.62, 0.22, 1.0, 1},
        active = {
            type = "aoe",
            name = "Supresión de Aura",
            energyCostRatio = 0.38,
            cooldown = 4.8,
            radius = 185,
            lifetime = 0.38,
            damageMultiplier = 1.35,
            stunDuration = 1.35,
            knockbackForce = 220
        }
    },
    {
        id = "supervivencia",
        name = "Supervivencia",
        description = "Condensa output en un impulso físico brutal: mucha fuerza y cooldown largo.",
        strengthMultiplier = 1.75,
        cooldownMultiplier = 1.55,
        color = {1.0, 0.34, 0.16, 1},
        active = {
            type = "projectile",
            name = "Impulso de Sobrecarga",
            energyCostRatio = 0.46,
            cooldown = 5.6,
            projectileSpeed = 980,
            lifetime = 0.16,
            damageMultiplier = 3.9,
            stunDuration = 0.65,
            knockbackForce = 1050
        }
    },
    {
        id = "vectorial",
        name = "Vectorial",
        description = "Redirige fuerzas con control geométrico equilibrado.",
        strengthMultiplier = 1.05,
        cooldownMultiplier = 1.0,
        color = {0.15, 0.82, 1.0, 1},
        active = {
            type = "aoe",
            name = "Rechazo Absoluto",
            energyCostRatio = 0.28,
            cooldown = 3.0,
            radius = 92,
            lifetime = 0.24,
            damageMultiplier = 0.65,
            stunDuration = 0.25,
            knockbackForce = 1850
        }
    },
    {
        id = "perceptivo",
        name = "Perceptivo",
        description = "Ataca huecos de atención con bajo daño y recuperación casi inmediata.",
        strengthMultiplier = 0.82,
        cooldownMultiplier = 0.48,
        color = {0.88, 0.9, 1.0, 1},
        active = {
            type = "projectile",
            name = "Punto Ciego",
            energyCostRatio = 0.18,
            cooldown = 1.25,
            projectileSpeed = 1350,
            lifetime = 0.34,
            damageMultiplier = 0.38,
            stunDuration = 1.05,
            knockbackForce = 120,
            invisible = true
        }
    },
    {
        id = "entropia",
        name = "Entropía",
        description = "Rompe el equilibrio del área con un fogonazo carísimo y devastador.",
        strengthMultiplier = 1.5,
        cooldownMultiplier = 1.28,
        color = {1.0, 0.92, 0.18, 1},
        active = {
            type = "aoe",
            name = "Fogonazo de Cero",
            energyCostRatio = 0.82,
            cooldown = 4.4,
            radius = 132,
            lifetime = 0.3,
            damageMultiplier = 4.25,
            stunDuration = 0.75,
            knockbackForce = 520
        }
    },
    {
        id = "vacio",
        name = "Vacío",
        description = "Corta la distancia como si el espacio no existiera e ignora defensas.",
        strengthMultiplier = 1.28,
        cooldownMultiplier = 0.9,
        color = {0.08, 0.08, 0.12, 1},
        active = {
            type = "projectile",
            name = "Corte Espacial",
            energyCostRatio = 0.42,
            cooldown = 2.7,
            projectileSpeed = 1900,
            lifetime = 0.55,
            damageMultiplier = 2.65,
            stunDuration = 0.35,
            knockbackForce = 420,
            ignoreBlock = true
        }
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

local ARCHETYPE_BY_NAME = {}
local PASSIVE_BY_ID = {}

for _, archetype in ipairs(ARCHETYPES) do
    ARCHETYPE_BY_NAME[archetype.name] = archetype
    ARCHETYPE_BY_NAME[archetype.id] = archetype
end

for _, passive in ipairs(PASSIVES) do
    PASSIVE_BY_ID[passive.id] = passive
end

local function randomFloat(min, max)
    return min + (max - min) * love.math.random()
end

local function copyColor(color)
    return {color[1], color[2], color[3], color[4] or 1}
end

local function clonePassive(passive)
    return {
        id = passive.id,
        name = passive.name,
        description = passive.description
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

local function withVariation(value, percent)
    local spread = percent or 0.08
    return value * randomFloat(1 - spread, 1 + spread)
end

local function buildActiveSkill(will)
    local archetype = ARCHETYPE_BY_NAME[will.archetype] or ARCHETYPES[1]
    local active = archetype.active
    local energyCost = math.max(3, math.floor(will.output_maximo * active.energyCostRatio))

    if active.type == "projectile" then
        return {
            type = "projectile",
            name = active.name,
            cooldown = withVariation(active.cooldown * will.cooldownMultiplier, 0.05),
            timer = 0,
            energyCost = energyCost,
            projectileSpeed = withVariation(active.projectileSpeed, 0.04),
            lifetime = withVariation(active.lifetime, 0.04),
            damageMultiplier = withVariation(active.damageMultiplier, 0.06),
            stunDuration = active.stunDuration or 0,
            knockbackForce = active.knockbackForce or 0,
            invisible = active.invisible or false,
            ignoreBlock = active.ignoreBlock or false
        }
    end

    return {
        type = "aoe",
        name = active.name,
        cooldown = withVariation(active.cooldown * will.cooldownMultiplier, 0.05),
        timer = 0,
        energyCost = energyCost,
        radius = withVariation(active.radius, 0.05),
        lifetime = withVariation(active.lifetime, 0.05),
        damageMultiplier = withVariation(active.damageMultiplier, 0.06),
        stunDuration = active.stunDuration or 0,
        knockbackForce = active.knockbackForce or 0,
        ignoreBlock = active.ignoreBlock or false
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
    local passive = self.passive and PASSIVE_BY_ID[self.passive.id]
    if passive and passive.onMove then
        passive.onMove(self, player, dt)
    end
end

function Will:onDamageDealt(player, target, damage)
    local passive = self.passive and PASSIVE_BY_ID[self.passive.id]
    if passive and passive.onDamageDealt then
        passive.onDamageDealt(self, player, target, damage)
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
            stunDuration = self.active.stunDuration,
            knockbackForce = self.active.knockbackForce,
            invisible = self.active.invisible,
            ignoreBlock = self.active.ignoreBlock,
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
            stunDuration = self.active.stunDuration,
            knockbackForce = self.active.knockbackForce,
            ignoreBlock = self.active.ignoreBlock,
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

function WillFactory.restoreMetatable(willData)
    if type(willData) ~= "table" then
        return nil
    end

    local archetype = ARCHETYPE_BY_NAME[willData.archetype] or ARCHETYPES[1]
    willData.archetype = archetype.name
    willData.archetypeDescription = willData.archetypeDescription or archetype.description
    willData.cooldownMultiplier = willData.cooldownMultiplier or archetype.cooldownMultiplier
    willData.strength = willData.strength or math.floor(12 * archetype.strengthMultiplier)
    willData.reserva_maxima = willData.reserva_maxima or 100
    willData.reserva_actual = math.min(willData.reserva_actual or willData.reserva_maxima, willData.reserva_maxima)
    willData.output_maximo = willData.output_maximo or math.max(5, math.floor(willData.reserva_maxima * 0.25))
    willData.output_actual = math.min(willData.output_actual or 0, willData.output_maximo)
    willData.color = willData.color or copyColor(archetype.color)
    willData.isChanneling = false
    willData.lastError = nil

    local passive = willData.passive and PASSIVE_BY_ID[willData.passive.id] or PASSIVES[1]
    willData.passive = clonePassive(passive)
    willData.passivePower = willData.passivePower or randomFloat(0.04, 0.1)

    setmetatable(willData, Will)

    if not willData.active or willData.active.name ~= archetype.active.name then
        willData.active = buildActiveSkill(willData)
    else
        willData.active.timer = willData.active.timer or 0
        willData.active.energyCost = willData.active.energyCost or math.max(3, math.floor(willData.output_maximo * archetype.active.energyCostRatio))
    end

    return willData
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
        passive = clonePassive(passive),
        passivePower = randomFloat(0.04, 0.1),
        color = copyColor(archetype.color),
        isChanneling = false,
        lastError = nil,
        lastPassiveText = nil
    }, Will)

    will.active = buildActiveSkill(will)
    return will
end

return WillFactory
