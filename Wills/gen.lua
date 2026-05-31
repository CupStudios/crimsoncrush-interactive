-- pools.lua
local WillPools = {}

-- 1. Arquetipos
WillPools.arquetipos = {
    { nombre = "Bélico",    bono_atq = 1.3, bono_def = 0.9, color = {1, 0.2, 0.2} },
    { nombre = "Eterno",    bono_atq = 0.8, bono_def = 1.4, color = {0.2, 0.8, 0.4} },
    { nombre = "Fluido",    bono_atq = 1.0, bono_def = 1.0, color = {0.2, 0.5, 1.0} }
}

-- 2. Pasivas Mecánicas
WillPools.pasivas = {
    {
        id = "vampirismo",
        nombre = "Sifón de Esencia",
        descripcion = "Curas un 5% del daño infligido.",
        al_infligir_daño = function(player, enemigo, daño)
            player.hp = math.min(player.max_hp, player.hp + (daño * 0.05))
        end
    },
    {
        id = "inercia",
        nombre = "Impulso Cinético",
        descripcion = "Moverte aumenta tu barra de Will gradualmente.",
        al_moverse = function(player, dt)
            player.will_power = math.min(player.max_will, player.will_power + (10 * dt))
        end
    }
}

-- 3. Comportamientos de Habilidades (Efectos lógicos)
WillPools.efectos_habilidad = {
    proyectil = function(player, skill_data)
        -- Lógica para spawnear un proyectil en el mapa top-down
        local p = {
            x = player.x, y = player.y,
            vx = player.dir_x * skill_data.velocidad,
            vy = player.dir_y * skill_data.velocidad,
            daño = player.atq * skill_data.multiplicador_daño
        }
        table.insert(Mapa.proyectiles, p)
    end,
    
    area_de_efecto = function(player, skill_data)
        -- Lógica para una explosión o zona alrededor del jugador
        Explosion.crear(player.x, player.y, skill_data.radio, player.atq * skill_data.multiplicador_daño)
    end
}

return WillPools
