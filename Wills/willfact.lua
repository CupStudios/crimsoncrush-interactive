-- will_factory.lua
local Pools = require("Wills.gen")
local WillFactory = {}

function WillFactory.generarNuevoWill()
    local nuevo_will = {}
    
    -- 1. Seleccionar Arquetipo
    local arquetipo = Pools.arquetipos[love.math.random(#Pools.arquetipos)]
    nuevo_will.arquetipo = arquetipo.nombre
    nuevo_will.color = arquetipo.color
    
    -- 2. Generar Estadísticas base influenciadas por el arquetipo
    nuevo_will.stats = {
        fuerza = love.math.random(10, 20) * arquetipo.bono_atq,
        defensa = love.math.random(5, 15) * arquetipo.bono_def,
        will_cooldown = love.math.random(80, 120) / 100 -- Multiplicador de CD (0.8x a 1.2x)
    }
    
    -- 3. Heredar Pasiva
    local pasiva_elegida = Pools.pasivas[love.math.random(#Pools.pasivas)]
    nuevo_will.pasiva = {
        id = pasiva_elegida.id,
        nombre = pasiva_elegida.nombre,
        descripcion = pasiva_elegida.descripcion,
        ejecutar = pasiva_elegida.al_infligir_daño or pasiva_elegida.al_moverse,
        disparador = pasiva_elegida.al_infligir_daño and "on_hit" or "on_move"
    }
    
    -- 4. Generar Habilidad Activa Procedural
    -- Elegimos un tipo de comportamiento base (ej. proyectil) y aleatorizamos sus propiedades
    local tipos_skill = {"proyectil", "area_de_efecto"}
    local tipo_elegido = tipos_skill[love.math.random(#tipos_skill)]
    
    nuevo_will.habilidad = {
        tipo = tipo_elegido,
        cooldown = (love.math.random(2, 6)) * nuevo_will.stats.will_cooldown,
        timer = 0,
        logica = Pools.efectos_habilidad[tipo_elegido]
    }
    
    -- Inicializar variables específicas según el tipo de habilidad generado
    if tipo_elegido == "proyectil" then
        nuevo_will.habilidad.velocidad = love.math.random(300, 500)
        nuevo_will.habilidad.multiplicador_daño = love.math.random(12, 25) / 10 -- 1.2x a 2.5x
        nuevo_will.habilidad.nombre = "Destello " .. arquetipo.nombre
    elseif tipo_elegido == "area_de_efecto" then
        nuevo_will.habilidad.radio = love.math.random(50, 100)
        nuevo_will.habilidad.multiplicador_daño = love.math.random(20, 40) / 10
        nuevo_will.habilidad.nombre = "Colapso " .. arquetipo.nombre
    end
    
    return nuevo_will
end

return WillFactory
