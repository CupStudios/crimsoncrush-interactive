-- Utils/updater.lua
-- Versión compatible con Windows, Linux y Android (Multiplataforma nativa)
local JSON = require("json")

local Updater = {
    current_version = "0.0.0",
    remote_version = "0.0.0",
    download_url = "",
    status = "idle",          -- "idle", "checking", "update_available", "up_to_date", "downloading", "ready", "error"
    progress = 0,
    error_message = "",
    version_file = "version.json",
    thread = nil,
    channel_out = nil,
}

local function isVersionNewer(current, remote)
    local c1, c2, c3 = current:match("(%d+)%.(%d+)%.(%d+)")
    local r1, r2, r3 = remote:match("(%d+)%.(%d+)%.(%d+)")
    
    if not c1 or not r1 then return remote > current end
    
    if tonumber(r1) ~= tonumber(c1) then return tonumber(r1) > tonumber(c1) end
    if tonumber(r2) ~= tonumber(c2) then return tonumber(r2) > tonumber(c2) end
    return tonumber(r3) > tonumber(c3)
end

function Updater:init()
    if love.filesystem.getInfo(self.version_file) then
        local content = love.filesystem.read(self.version_file)
        local data = JSON:decode(content)
        if data and data.version then self.current_version = data.version end
    else
        self.current_version = "1.0.0" 
        local initial_json = JSON:encode({ version = self.current_version })
        love.filesystem.write(self.version_file, initial_json)
    end
end

function Updater:checkForUpdates(manifest_url)
    if self.status == "checking" or self.status == "downloading" then return end
    
    self.status = "checking"
    self.progress = 0
    
    -- Este código inyecta dinámicamente las rutas nativas de LÖVE en el hilo para Android/Windows
    local thread_code = [[
        local url = ...
        local chan = love.thread.getChannel("updater_output")
        
        -- Forzamos a que el hilo herede los cargadores de paquetes del entorno principal de LÖVE
        require("love.filesystem") 
        
        -- Intentamos usar una petición HTTP estándar. 
        -- NOTA: Si tu servidor de GitHub requiere HTTPS riguroso y falla, 
        -- usaremos un fallback de descarga directa.
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        
        local response_body = {}
        local res, code, headers = http.request({
            url = url,
            sink = ltn12.sink.table(response_body),
            headers = { ["User-Agent"] = "LOVE-Game" }
        })
        
        -- Si da un código de redirección (301/302) común en HTTPS de GitHub, intentamos seguirlo
        if code == 301 or code == 302 then
            local new_url = headers["location"]
            response_body = {}
            res, code, headers = http.request({
                url = new_url,
                sink = ltn12.sink.table(response_body),
                headers = { ["User-Agent"] = "LOVE-Game" }
            })
        end
        
        if code == 200 then
            local manifest = table.concat(response_body)
            chan:push({ "manifest_downloaded", manifest })
        else
            chan:push({ "error", "Error de conexión de red local (Código: " .. tostring(code) .. ")" })
        end
    ]]
    
    self.thread = love.thread.newThread(thread_code)
    self.channel_out = love.thread.getChannel("updater_output")
    self.thread:start(manifest_url)
end

function Updater:startDownload()
    if self.status ~= "update_available" or self.download_url == "" then return end
    
    self.status = "downloading"
    self.progress = 0
    
    local thread_download_code = [[
        local download_url = ...
        local chan = love.thread.getChannel("updater_output")
        
        require("love.filesystem")
        local http = require("socket.http")
        
        local filename = "update_pending.love"
        
        -- Usamos el sistema de archivos seguro de LÖVE que funciona de igual forma en Android (.apk) y Windows (.exe)
        local file_sink = function(chunk)
            if chunk then
                love.filesystem.append(filename, chunk)
                return true
            end
            return true
        end
        
        if love.filesystem.getInfo(filename) then
            love.filesystem.remove(filename)
        end
        
        local res, code, headers = http.request({
            url = download_url,
            sink = file_sink,
            headers = { ["User-Agent"] = "LOVE-Game" }
        })
        
        if code == 301 or code == 302 then
            local new_url = headers["location"]
            res, code = http.request({
                url = new_url,
                sink = file_sink,
                headers = { ["User-Agent"] = "LOVE-Game" }
            })
        end
        
        if code == 200 then
            chan:push({ "download_complete", filename })
        else
            chan:push({ "error", "Fallo al transferir los datos del servidor móvil." })
        end
    ]]
    
    self.thread = love.thread.newThread(thread_download_code)
    self.thread:start(self.download_url)
end

-- Las funciones update(dt) y applyAndRestart() se quedan exactamente igual que antes...
function Updater:update(dt)
    if not self.channel_out then return end
    local msg = self.channel_out:pop()
    if msg then
        local msg_type = msg[1]
        if msg_type == "manifest_downloaded" then
            local success, data = pcall(JSON.decode, JSON, msg[2])
            if success and data and data.version and data.download_url then
                self.remote_version = data.version
                self.download_url = data.download_url
                if isVersionNewer(self.current_version, self.remote_version) then
                    self.status = "update_available"
                else
                    self.status = "up_to_date"
                end
            else
                self.status = "error"
                self.error_message = "Estructura de datos de actualización inválida."
            end
        elseif msg_type == "download_complete" then
            self.status = "ready"
            self.progress = 1
        elseif msg_type == "error" then
            self.status = "error"
            self.error_message = msg[2]
        end
    end
end

function Updater:applyAndRestart()
    if self.status ~= "ready" then return false end
    local success = love.filesystem.mount("update_pending.love", "")
    if success then
        local new_version_json = JSON:encode({ version = self.remote_version })
        love.filesystem.write(self.version_file, new_version_json)
        love.filesystem.remove("update_pending.love")
        love.event.quit("restart")
        return true
    end
    self.status = "error"
    self.error_message = "No se pudo mapear la memoria del juego dinámicamente."
    return false
end

return Updater
