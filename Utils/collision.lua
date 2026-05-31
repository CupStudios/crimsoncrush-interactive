-- Utils/collision.lua
-- Funciones matemáticas puras de colisión para el mundo top-down.
local Collision = {}

function Collision.aabb(a, b)
    return a.x < b.x + b.width
        and a.x + a.width > b.x
        and a.y < b.y + b.height
        and a.y + a.height > b.y
end

function Collision.circleCircle(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local radiusSum = a.radius + b.radius
    return dx * dx + dy * dy <= radiusSum * radiusSum
end

function Collision.entityCenter(entity)
    return entity.x + entity.width / 2, entity.y + entity.height / 2
end

function Collision.entityCircle(entity, radius)
    local centerX, centerY = Collision.entityCenter(entity)
    return {
        x = centerX,
        y = centerY,
        radius = radius or math.max(entity.width, entity.height) / 2
    }
end

return Collision
