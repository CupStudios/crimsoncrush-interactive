-- Utils/interpolation.lua
local Interpolation = {}

-- Linear Interpolation (Lerp): Movimiento constante y directo
function Interpolation.lerp(a, b, t)
    return a + (b - a) * t
end

-- OutSine Easing: Empieza rápido y frena suavemente (Perfecto para el Windup)
function Interpolation.outSine(a, b, t)
    return a + (b - a) * math.sin(t * math.pi / 2)
end

return Interpolation
