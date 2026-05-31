-- Entities/entity_manager.lua
-- Handler centralizado para registrar, actualizar y dibujar entidades del mundo.
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

function EntityManager:update(dt)
    for _, entity in ipairs(self.entities) do
        if entity.update then
            entity:update(dt, self)
        end
    end
end

function EntityManager:draw()
    for _, entity in ipairs(self.entities) do
        if entity.draw then
            entity:draw()
        end
    end
end

return EntityManager
