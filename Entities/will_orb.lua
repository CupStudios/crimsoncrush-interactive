-- Entities/will_orb.lua
-- Recurso del mapa que el jugador recoge por colisión AABB.
local Effects = require("Utils.effects")

local WillOrb = {}
WillOrb.__index = WillOrb

function WillOrb.new(config)
    local size = config.size or 28

    return setmetatable({
        id = nil,
        type = "will_orb",
        x = (config.x or 0) - size / 2,
        y = (config.y or 0) - size / 2,
        width = size,
        height = size,
        radius = size / 2,
        speed = 0,
        cantidad_energia = config.cantidad_energia or 25,
        tipo = config.tipo or "reserva",
        pulse = love.math.random() * math.pi * 2,
        isWithinAura = false
    }, WillOrb)
end

function WillOrb:collect(player)
    if self.tipo == "reserva" then
        local will = player.will
        will.reserva_actual = math.min(will.reserva_maxima, will.reserva_actual + self.cantidad_energia)
        will.lastPassiveText = string.format("Orbe +%.0f reserva", self.cantidad_energia)
    elseif self.tipo == "experiencia" then
        player.willExperience = (player.willExperience or 0) + self.cantidad_energia
        player.will.lastPassiveText = string.format("Will XP +%.0f", self.cantidad_energia)
    end
    Effects:emit("orb_consume", self.x, self.y)

    self.destroyed = true
end

function WillOrb:update(dt)
    self.pulse = self.pulse + dt * 5
end

function WillOrb:draw()
    local bob = math.sin(self.pulse) * 3
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2 + bob
    local glowScale = self.isWithinAura and 1.8 or 1.25

    if self.tipo == "reserva" then
        love.graphics.setColor(0.2, 0.55, 1, 0.22)
    else
        love.graphics.setColor(0.95, 0.75, 0.2, 0.22)
    end
    love.graphics.circle("fill", centerX, centerY, self.radius * glowScale)

    if self.tipo == "reserva" then
        love.graphics.setColor(0.25, 0.7, 1, 1)
    else
        love.graphics.setColor(1, 0.85, 0.25, 1)
    end
    love.graphics.circle("fill", centerX, centerY, self.radius)

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle("line", centerX, centerY, self.radius)
end

return WillOrb
