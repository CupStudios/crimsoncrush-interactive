-- Entities/entity_manager.lua
-- Handler centralizado para registrar, actualizar, colisionar y dibujar entidades del mundo.
local Collision = require("Utils.collision")

local EntityManager = {}
EntityManager.__index = EntityManager

function EntityManager.new()
    return setmetatable({
        entities = {},
        byId = {},
        nextId = 1
    }, EntityManager)
end

function EntityManager:add(entity)
    assert(type(entity) == "table", "EntityManager:add espera una tabla de entidad")

    entity.id = entity.id or self.nextId
    self.nextId = math.max(self.nextId, entity.id + 1)

    -- Propiedades base comunes para que todos los objetos sean homogéneos.
    entity.type = entity.type or "generic"
    entity.x = entity.x or 0
    entity.y = entity.y or 0
    entity.width = entity.width or 32
    entity.height = entity.height or 32
    entity.speed = entity.speed or 0

    table.insert(self.entities, entity)
    self.byId[entity.id] = entity
    return entity
end

function EntityManager:getById(id)
    return self.byId[id]
end

function EntityManager:getByType(entityType)
    local matches = {}

    for _, entity in ipairs(self.entities) do
        if entity.type == entityType and not entity.destroyed then
            table.insert(matches, entity)
        end
    end

    return matches
end

function EntityManager:getPlayer()
    for _, entity in ipairs(self.entities) do
        if entity.type == "player" and not entity.destroyed then
            return entity
        end
    end

    return nil
end

function EntityManager:damageEntity(entity, damage, source)
    local appliedDamage = damage

    if entity.receiveDamage then
        appliedDamage = entity:receiveDamage(damage, source, self)
    else
        entity.hp = entity.hp - damage
        if entity.hp <= 0 then
            entity.destroyed = true
        end
    end

    if source and source.onDealDamage then
        source:onDealDamage(entity, appliedDamage)
    end

    return appliedDamage
end

function EntityManager:handleProjectileEnemyCollisions()
    for _, projectile in ipairs(self.entities) do
        if projectile.type == "projectile" and not projectile.destroyed then
            for _, enemy in ipairs(self.entities) do
                if enemy.type == "enemy" and not enemy.destroyed and Collision.aabb(projectile, enemy) then
                    self:damageEntity(enemy, projectile.damage, projectile.owner)
                    projectile.destroyed = true
                    break
                end
            end
        end
    end
end

function EntityManager:handleM1EnemyCollisions()
    for _, m1 in ipairs(self.entities) do
        if m1.type == "m1_attack" and not m1.destroyed and not m1.hasAppliedDamage then
            -- Cambiamos "enemy" por "target" para que sirva tanto para el jugador como para dummies
            for _, target in ipairs(self.entities) do
                -- REGLA DE ORO: Tiene HP, no está destruido, NO es el dueño, y NO son del mismo bando
                if target.hp and not target.destroyed and target ~= m1.owner and target.type ~= m1.owner.type then
                    if Collision.aabb(m1, target) then
                        -- Lógica de Bloqueo
                        if target.isBlocking and not m1.isComboFinisher then
                            self:damageEntity(target, m1.damage * 0.1, m1.owner)
                        else
                            -- Impacto directo o Rompimiento de Guardia (4to golpe)
                            self:damageEntity(target, m1.damage, m1.owner)

                            -- Si es el golpe final, calculamos el empuje matemático
                            if m1.isComboFinisher then
                                local dx = target.x - m1.owner.x
                                local dy = target.y - m1.owner.y
                                local distance = math.sqrt(dx * dx + dy * dy)

                                if distance > 0 then
                                    local knockbackForce = 800 -- Ajusta este número para empujar más o menos
                                    target.kx = (dx / distance) * knockbackForce
                                    target.ky = (dy / distance) * knockbackForce
                                end
                            end

                            if (m1.stunDuration or 0) > 0 then
                                target.stunTimer = m1.stunDuration
                            end
                        end

                        m1.hasAppliedDamage = true
                        break
                    end
                end
            end
        end
    end
end

function EntityManager:handleAoeEnemyCollisions()
    for _, aoe in ipairs(self.entities) do
        if aoe.type == "aoe_blast" and not aoe.destroyed and not aoe.hasAppliedDamage then
            aoe.hasAppliedDamage = true
            local aoeCircle = {
                x = aoe.x + aoe.radius,
                y = aoe.y + aoe.radius,
                radius = aoe.radius
            }

            for _, enemy in ipairs(self.entities) do
                if enemy.type == "enemy" and not enemy.destroyed then
                    local enemyCircle = Collision.entityCircle(enemy)

                    if Collision.circleCircle(aoeCircle, enemyCircle) then
                        self:damageEntity(enemy, aoe.damage, aoe.owner)
                    end
                end
            end
        end
    end
end

function EntityManager:handlePlayerOrbCollisions()
    local player = self:getPlayer()

    if not player then
        return
    end

    local auraCircle = nil
    if player.getAuraCircle then
        auraCircle = player:getAuraCircle()
    end

    for _, orb in ipairs(self.entities) do
        if orb.type == "will_orb" and not orb.destroyed then
            orb.isWithinAura = false

            -- Colisión círculo-círculo del aura: por ahora no recoge el orbe,
            -- pero deja una señal visual y un hook claro para magnetismo futuro.
            if auraCircle then
                local orbCircle = Collision.entityCircle(orb, orb.radius)
                orb.isWithinAura = Collision.circleCircle(auraCircle, orbCircle)
            end

            -- Interacción real de recursos: AABB jugador-orbe.
            if Collision.aabb(player, orb) then
                orb:collect(player)
            end
        end
    end
end

function EntityManager:resolveCollisions()
    self:handleProjectileEnemyCollisions()
    self:handleAoeEnemyCollisions()
    self:handleM1EnemyCollisions()
    self:handlePlayerOrbCollisions()
end

function EntityManager:removeDestroyed()
    for index = #self.entities, 1, -1 do
        local entity = self.entities[index]

        if entity.destroyed then
            if entity.onDestroy and not entity.didRunDestroy then
                entity.didRunDestroy = true
                entity:onDestroy(self)
            end

            self.byId[entity.id] = nil
            table.remove(self.entities, index)
        end
    end
end

function EntityManager:update(dt)
    for _, entity in ipairs(self.entities) do
        if not entity.destroyed and entity.update then
            entity:update(dt, self)
        end
    end

    self:resolveCollisions()
    self:removeDestroyed()
end

function EntityManager:draw()
    for _, entity in ipairs(self.entities) do
        if not entity.destroyed and entity.draw then
            entity:draw()
        end
    end
end

return EntityManager
