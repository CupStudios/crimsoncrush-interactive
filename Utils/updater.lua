-- Utils/updater.lua
-- Updater multiplataforma con soporte HTTPS, redirecciones de GitHub y descarga segura.
local JSON = require("json")

local Updater = {
    current_version = "0.0.0",
    remote_version = "0.0.0",
    download_url = "",
    status = "idle",          -- "idle", "checking", "update_available", "up_to_date", "downloading", "ready", "error", "applied"
    progress = 0,
    error_message = "",
    version_file = "version.json",
    pending_file = "update_pending.love",
    thread = nil,
    channel_out = nil,
}

local function splitVersion(version)
    local parts = {}
    for part in tostring(version or ""):gmatch("%d+") do
        parts[#parts + 1] = tonumber(part) or 0
    end
    return parts
end

local function isVersionNewer(current, remote)
    local currentParts = splitVersion(current)
    local remoteParts = splitVersion(remote)
    local maxParts = math.max(#currentParts, #remoteParts, 3)

    for index = 1, maxParts do
        local currentPart = currentParts[index] or 0
        local remotePart = remoteParts[index] or 0
        if remotePart ~= currentPart then
            return remotePart > currentPart
        end
    end

    return false
end

local function normalizeManifestUrl(url)
    -- GitHub responde con 301 cuando se usa github.com/.../raw/...; usar raw.githubusercontent.com
    -- evita esa redirección y reduce fallos en LuaSocket/LuaSec en Windows.
    return tostring(url or "")
        :gsub("^http://", "https://")
        :gsub("^https://github%.com/([^/]+)/([^/]+)/raw/refs/heads/([^/]+)/(.+)$", "https://raw.githubusercontent.com/%1/%2/%3/%4")
        :gsub("^https://github%.com/([^/]+)/([^/]+)/raw/([^/]+)/(.+)$", "https://raw.githubusercontent.com/%1/%2/%3/%4")
end

function Updater:mountPendingUpdate()
    if self.update_mounted then return true end
    if not love.filesystem.getInfo(self.pending_file) then return false end

    local success = love.filesystem.mount(self.pending_file, "")
    self.update_mounted = success and true or false
    return self.update_mounted
end

function Updater:init()
    self.current_version = "1.0.0"
    self:mountPendingUpdate()

    if love.filesystem.getInfo(self.version_file) then
        local content = love.filesystem.read(self.version_file)
        local success, data = pcall(JSON.decode, JSON, content)
        if success and data and data.version then
            self.current_version = data.version
        else
            self.status = "error"
            self.error_message = "El archivo de versión local no es JSON válido."
        end
    else
        love.filesystem.write(self.version_file, JSON:encode({ version = self.current_version }))
    end
end

local NETWORK_THREAD_CODE = [[
    local mode, url, filename = ...
    require("love.filesystem")
    local chan = love.thread.getChannel("updater_output")
    local max_redirects = 5
    local user_agent = "CrimsonCrush-Updater/1.0 (LOVE)"

    local function pushError(message)
        chan:push({ "error", message })
    end

    local function getHeader(headers, name)
        if type(headers) ~= "table" then return nil end
        local expected = string.lower(name)
        for key, value in pairs(headers) do
            if string.lower(tostring(key)) == expected then
                return value
            end
        end
        return nil
    end

    local function isRedirect(code)
        code = tonumber(code)
        return code == 301 or code == 302 or code == 303 or code == 307 or code == 308
    end

    local function makeAbsoluteUrl(baseUrl, location)
        if not location or location == "" then return nil end
        if location:match("^https?://") then return location end
        local scheme, host = baseUrl:match("^(https?://)([^/]+)")
        if not scheme then return location end
        if location:sub(1, 1) == "/" then
            return scheme .. host .. location
        end
        return baseUrl:gsub("/[^/]*$", "/") .. location
    end

    local function getHttpModule(requestUrl)
        if requestUrl:match("^https://") then
            local ok, https = pcall(require, "ssl.https")
            if ok and https then return https end
            return nil, "HTTPS no disponible: instala LuaSec o usa el fallback curl/PowerShell."
        end

        local ok, http = pcall(require, "socket.http")
        if ok and http then return http end
        return nil, "LuaSocket no está disponible."
    end

    local function requestWithLua(requestUrl, sinkFactory)
        local currentUrl = requestUrl
        local lastCode = nil

        for redirect = 0, max_redirects do
            local http, moduleError = getHttpModule(currentUrl)
            if not http then return nil, moduleError, lastCode end

            local sink, getBody = sinkFactory()
            local _, code, headers = http.request({
                url = currentUrl,
                sink = sink,
                headers = { ["User-Agent"] = user_agent },
                redirect = false
            })
            lastCode = tonumber(code) or code

            if isRedirect(code) then
                local location = makeAbsoluteUrl(currentUrl, getHeader(headers, "location"))
                if not location then
                    return nil, "Redirección HTTP " .. tostring(code) .. " sin cabecera Location.", code
                end
                currentUrl = location
            elseif tonumber(code) == 200 then
                return getBody(), nil, code
            else
                return nil, "HTTP " .. tostring(code or "sin código") .. " al conectar con " .. currentUrl, code
            end
        end

        return nil, "Demasiadas redirecciones al conectar con GitHub.", lastCode
    end

    local function quoteCommandArgument(value)
        value = tostring(value or "")
        if package.config:sub(1, 1) == "\\" then
            return '"' .. value:gsub('"', '\\"') .. '"'
        end
        return "'" .. value:gsub("'", "'\\''") .. "'"
    end

    local function readProcess(command)
        local handle = io.popen(command, "r")
        if not handle then return nil end
        local output = handle:read("*a")
        local ok, _, exitCode = handle:close()
        if ok or exitCode == 0 then return output end
        return nil
    end

    local function fetchTextWithCommand(requestUrl)
        local quotedUrl = quoteCommandArgument(requestUrl)
        local curlCommand = "curl -L --fail --silent --show-error --max-time 45 --user-agent " .. quoteCommandArgument(user_agent) .. " " .. quotedUrl
        local output = readProcess(curlCommand)
        if output and output ~= "" then return output end

        if package.config:sub(1, 1) == "\\" then
            local psUrl = requestUrl:gsub("'", "''")
            local psCommand = "powershell -NoProfile -ExecutionPolicy Bypass -Command " .. quoteCommandArgument("$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (Invoke-WebRequest -UseBasicParsing -Uri '" .. psUrl .. "' -Headers @{ 'User-Agent' = '" .. user_agent .. "' }).Content")
            return readProcess(psCommand)
        end

        return nil
    end

    local function downloadWithCommand(requestUrl, outputPath)
        local quotedUrl = quoteCommandArgument(requestUrl)
        local quotedOutput = quoteCommandArgument(outputPath)
        local curlCommand = "curl -L --fail --silent --show-error --max-time 180 --user-agent " .. quoteCommandArgument(user_agent) .. " -o " .. quotedOutput .. " " .. quotedUrl
        local curlOk = os.execute(curlCommand)
        if curlOk == true or curlOk == 0 then return true end

        if package.config:sub(1, 1) == "\\" then
            local psUrl = requestUrl:gsub("'", "''")
            local psOutput = outputPath:gsub("'", "''")
            local psCommand = "powershell -NoProfile -ExecutionPolicy Bypass -Command " .. quoteCommandArgument("$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '" .. psUrl .. "' -OutFile '" .. psOutput .. "' -Headers @{ 'User-Agent' = '" .. user_agent .. "' }")
            local psOk = os.execute(psCommand)
            return psOk == true or psOk == 0
        end

        return false
    end

    local ok, err = pcall(function()
        if mode == "manifest" then
            local manifest, luaError = requestWithLua(url, function()
                local chunks = {}
                return require("ltn12").sink.table(chunks), function() return table.concat(chunks) end
            end)

            if not manifest or manifest == "" then
                manifest = fetchTextWithCommand(url)
            end

            if manifest and manifest ~= "" then
                chan:push({ "manifest_downloaded", manifest })
            else
                pushError((luaError or "No se pudo descargar el manifiesto.") .. " Verifica HTTPS, redirecciones y acceso a GitHub.")
            end
        elseif mode == "download" then
            if love.filesystem.getInfo(filename) then love.filesystem.remove(filename) end

            local _, luaError = requestWithLua(url, function()
                if love.filesystem.getInfo(filename) then love.filesystem.remove(filename) end
                return function(chunk)
                    if chunk then love.filesystem.append(filename, chunk) end
                    return true
                end, function() return filename end
            end)

            local info = love.filesystem.getInfo(filename)
            if not info or info.size == 0 then
                if love.filesystem.getInfo(filename) then love.filesystem.remove(filename) end
                local outputPath = love.filesystem.getSaveDirectory() .. "/" .. filename
                if downloadWithCommand(url, outputPath) then
                    info = love.filesystem.getInfo(filename)
                end
            end

            if info and info.size > 0 then
                chan:push({ "download_complete", filename, info.size })
            else
                pushError((luaError or "No se pudo descargar la actualización.") .. " Verifica que download_url apunte a un archivo .love público.")
            end
        else
            pushError("Modo de actualización desconocido: " .. tostring(mode))
        end
    end)

    if not ok then pushError("Error interno del actualizador: " .. tostring(err)) end
]]

function Updater:checkForUpdates(manifest_url)
    if self.status == "checking" or self.status == "downloading" then return end

    self.status = "checking"
    self.progress = 0
    self.error_message = ""
    self.download_url = ""
    self.remote_version = "0.0.0"

    self.channel_out = love.thread.getChannel("updater_output")
    self.channel_out:clear()
    self.thread = love.thread.newThread(NETWORK_THREAD_CODE)
    self.thread:start("manifest", normalizeManifestUrl(manifest_url))
end

function Updater:startDownload()
    if self.status ~= "update_available" or self.download_url == "" then return end

    self.status = "downloading"
    self.progress = 0
    self.error_message = ""

    self.channel_out = love.thread.getChannel("updater_output")
    self.channel_out:clear()
    self.thread = love.thread.newThread(NETWORK_THREAD_CODE)
    self.thread:start("download", normalizeManifestUrl(self.download_url), self.pending_file)
end

function Updater:update(dt)
    if not self.channel_out then return end

    while true do
        local msg = self.channel_out:pop()
        if not msg then break end

        local msg_type = msg[1]
        if msg_type == "manifest_downloaded" then
            local success, data = pcall(JSON.decode, JSON, msg[2])
            if success and data and data.version then
                self.remote_version = tostring(data.version)
                self.download_url = normalizeManifestUrl(data.download_url or data.url or "")

                if isVersionNewer(self.current_version, self.remote_version) then
                    if self.download_url == "" then
                        self.status = "error"
                        self.error_message = "La versión remota no incluye download_url."
                    else
                        self.status = "update_available"
                    end
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

    if not love.filesystem.getInfo(self.pending_file) then
        self.status = "error"
        self.error_message = "No se encontró el archivo de actualización descargado."
        return false
    end

    local success = love.filesystem.mount(self.pending_file, "")
    if success then
        love.filesystem.write(self.version_file, JSON:encode({ version = self.remote_version }))
        self.current_version = self.remote_version
        self.status = "applied"
        love.event.quit("restart")
        return true
    end

    self.status = "error"
    self.error_message = "La actualización descargada no es un archivo .love válido."
    return false
end

return Updater
