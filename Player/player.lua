-- player.lua
local WillFactory = require("../Wills/will_factory")

local Player = {}

function Player.load()
    Player.x = 400
    Player.y = 300
    Player.speed = 200
    Player.hp = 100
    Player.max_hp = 100
    Player.atq = 10 -- Daño base del personaje sin Will
    Player.will_power = 0
    Player.max_will = 100
    Player.dir_x = 1
    Player.dir_y = 0

    -- ¡El RNG decide tu Will al empezar!
    Player.will = WillFactory.generarNuevoWill()
end

function Player.update(dt)
    -- 1. Movimiento básico
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = -1 end
    if love.keyboard.isDown("s") then dy = 1 end
    if love.keyboard.isDown("a") then dx = -1 end
    if love.keyboard.isDown("d") then dx = 1 end
    
    if dx ~= 0 or dy ~= 0 then
        Player.x = Player.x + dx * Player.speed * dt
        Player.y = Player.y + dy * Player.speed * dt
        Player.dir_x, Player.dir_y = dx, dy
        
        -- TRIGGER DE PASIVA: Si la pasiva reacciona al movimiento
        if Player.will.pasiva.disparador == "on_move" then
            Player.will.pasiva.ejecutar(Player, dt)
        end
    end
    
    -- 2. Manejo de Cooldown de la habilidad del Will
    if Player.will.habilidad.timer > 0 then
        Player.will.habilidad.timer = Player.will.habilidad.timer - dt
    end
end

function Player.m1()

end

function Player.usarHabilidad()
    local skill = Player.will.habilidad
    if skill.timer <= 0 then
        -- Ejecuta la función lógica que el RNG le asignó
        skill.logica(Player, skill)
        skill.timer = skill.cooldown
        print("¡Usaste " .. skill.nombre .. "!")
    else
        print("Habilidad en cooldown...")
    end
end

function Player.infligirDañoAEnemigo(enemigo, daño_base)
    -- Calcular daño final sumando la fuerza del Will generado
    local daño_final = daño_base + Player.will.stats.fuerza
    enemigo.hp = enemigo.hp - daño_final
    
    -- TRIGGER DE PASIVA: Si la pasiva reacciona al golpear
    if Player.will.pasiva.disparador == "on_hit" then
        Player.will.pasiva.ejecutar(Player, enemigo, daño_final)
    end
end

return Player
