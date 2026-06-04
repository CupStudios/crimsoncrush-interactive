-- Utils/updater.lua
--[[
    Auto-updater for Crimson Crush: Interactive.

    Design goals:
    1) Download script-only delta patches (patch_code.love) instead of full game bundles.
    2) Report true byte progress from the worker thread to the main thread.
    3) Mount patches safely and provide rollback helpers so a broken patch can be deleted
       before the next clean restart.

    Expected remote manifest (version.json):
    {
      "version": "1.0.2",
      "download_url": "https://.../game.love",        -- legacy full package for old clients
      "patch_url": "https://.../patch_code.love",    -- script-only package for this updater
      "size_bytes": 123456                            -- patch_code.love size
    }

    Optional aliases are also accepted for compatibility:
      patch_url / code_patch_url / url  -> download_url
      patch_size_bytes / content_length -> size_bytes
]]
local JSON = require("json")

local VERSION_FILE = "version.json"

local function readBundledVersion()
    local content = love.filesystem.read(VERSION_FILE)
    if not content then return "1.0.0" end

    local success, data = pcall(JSON.decode, JSON, content)
    if success and data and data.version then
        return tostring(data.version)
    end

    return "1.0.0"
end

local FACTORY_VERSION = readBundledVersion()
local PATCH_FILE = "patch_code.love"
local ROLLBACK_NOTICE_FILE = "rollback_notice.txt"
local UPDATE_CHANNEL = "updater_output"

local Updater = {
    factory_version = FACTORY_VERSION,
    current_version = "0.0.0",
    remote_version = "0.0.0",
    download_url = "",
    size_bytes = 0,
    downloaded_bytes = 0,
    status = "idle",          -- idle/checking/update_available/up_to_date/downloading/ready/error/applied/rolled_back
    progress = 0,
    error_message = "",
    rollback_message = "",
    version_file = VERSION_FILE,
    patch_file = PATCH_FILE,
    thread = nil,
    channel_out = nil,
    patch_mounted = false,
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

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

local function normalizeGitHubUrl(url)
    -- GitHub often returns a 301 for github.com/.../raw/... URLs. raw.githubusercontent.com
    -- is the direct endpoint and avoids that redirect path in older LuaSocket/LuaSec builds.
    return tostring(url or "")
        :gsub("^http://", "https://")
        :gsub("^https://github%.com/([^/]+)/([^/]+)/raw/refs/heads/([^/]+)/(.+)$", "https://raw.githubusercontent.com/%1/%2/%3/%4")
        :gsub("^https://github%.com/([^/]+)/([^/]+)/raw/([^/]+)/(.+)$", "https://raw.githubusercontent.com/%1/%2/%3/%4")
end

local function readJsonFile(path)
    if not love.filesystem.getInfo(path) then return nil end

    local content = love.filesystem.read(path)
    local success, data = pcall(JSON.decode, JSON, content)
    if success then return data end
    return nil
end

local function writeVersion(version)
    love.filesystem.write(VERSION_FILE, JSON:encode({ version = version }))
end

function Updater:hasPatchFile()
    return love.filesystem.getInfo(self.patch_file) ~= nil
end

function Updater:mountPatch()
    -- The patch is mounted at the root (""), so a script-only patch containing paths like
    -- Core/game.lua or Entities/player.lua overlays those files while all unpatched assets
    -- remain readable from the base installation.
    if self.patch_mounted then return true end
    if not self:hasPatchFile() then return false end

    local success = love.filesystem.mount(self.patch_file, "")
    self.patch_mounted = success and true or false
    return self.patch_mounted
end

-- Backwards-compatible name used by older main.lua integrations.
function Updater:mountPendingUpdate()
    return self:mountPatch()
end

function Updater:deletePatch()
    if self.patch_mounted and love.filesystem.unmount then
        pcall(love.filesystem.unmount, self.patch_file)
    end

    if self:hasPatchFile() then
        love.filesystem.remove(self.patch_file)
    end
    self.patch_mounted = false
end

function Updater:writeRollbackNotice(message)
    love.filesystem.write(ROLLBACK_NOTICE_FILE, tostring(message or "An error was detected in the update. Rolling back to a safe version."))
end

function Updater:consumeRollbackNotice()
    if not love.filesystem.getInfo(ROLLBACK_NOTICE_FILE) then return end

    self.rollback_message = love.filesystem.read(ROLLBACK_NOTICE_FILE) or ""
    love.filesystem.remove(ROLLBACK_NOTICE_FILE)
    if self.rollback_message ~= "" then
        self.status = "rolled_back"
    end
end

function Updater:rollbackToFactoryVersion(errorMessage)
    -- Called from the guarded startup path. It removes the broken patch, resets the local
    -- version to the installer version, stores a notice for the next clean boot, and restarts.
    local notice = "An error was detected in the update. Rolling back to a safe version."
    if errorMessage and errorMessage ~= "" then
        notice = notice .. "\n" .. tostring(errorMessage)
    end

    self:deletePatch()
    writeVersion(self.factory_version)
    self.current_version = self.factory_version
    self.status = "rolled_back"
    self.rollback_message = notice
    self:writeRollbackNotice(notice)
    love.event.quit("restart")
end

function Updater:init()
    self.current_version = self.factory_version
    self:mountPatch()

    local data = readJsonFile(self.version_file)
    if data and data.version then
        self.current_version = tostring(data.version)
    elseif not love.filesystem.getInfo(self.version_file) then
        writeVersion(self.current_version)
    else
        self.status = "error"
        self.error_message = "El archivo de versión local no es JSON válido."
    end

    self:consumeRollbackNotice()
end

local NETWORK_THREAD_CODE = [[
    local mode, url, filename, expectedSize = ...
    require("love.filesystem")

    expectedSize = tonumber(expectedSize) or 0
    if expectedSize <= 1 then expectedSize = 0 end

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
            return nil, "HTTPS no disponible en Lua; se intentará fallback externo si existe."
        end

        local ok, http = pcall(require, "socket.http")
        if ok and http then return http end
        return nil, "LuaSocket no está disponible."
    end

    local function requestWithLua(requestUrl, sinkFactory)
        local currentUrl = requestUrl
        local lastCode = nil

        for _ = 0, max_redirects do
            local http, moduleError = getHttpModule(currentUrl)
            if not http then return nil, moduleError, lastCode end

            local sink, finish = sinkFactory()
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
                return finish(headers), nil, code
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

    local function execute(command)
        local ok = os.execute(command)
        return ok == true or ok == 0
    end

    local function fetchTextWithCommand(requestUrl)
        local curlCommand = "curl -L --fail --silent --show-error --max-time 45 --user-agent " .. quoteCommandArgument(user_agent) .. " " .. quoteCommandArgument(requestUrl)
        local output = readProcess(curlCommand)
        if output and output ~= "" then return output end

        if package.config:sub(1, 1) == "\\" then
            local psUrl = requestUrl:gsub("'", "''")
            local script = "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; (Invoke-WebRequest -UseBasicParsing -Uri '" .. psUrl .. "' -Headers @{ 'User-Agent' = '" .. user_agent .. "' }).Content"
            return readProcess("powershell -NoProfile -ExecutionPolicy Bypass -Command " .. quoteCommandArgument(script))
        end

        return nil
    end

    local function downloadWithCommand(requestUrl, outputPath)
        local curlCommand = "curl -L --fail --silent --show-error --max-time 180 --user-agent " .. quoteCommandArgument(user_agent) .. " -o " .. quoteCommandArgument(outputPath) .. " " .. quoteCommandArgument(requestUrl)
        if execute(curlCommand) then return true end

        if package.config:sub(1, 1) == "\\" then
            local psUrl = requestUrl:gsub("'", "''")
            local psOutput = outputPath:gsub("'", "''")
            local script = "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '" .. psUrl .. "' -OutFile '" .. psOutput .. "' -Headers @{ 'User-Agent' = '" .. user_agent .. "' }"
            return execute("powershell -NoProfile -ExecutionPolicy Bypass -Command " .. quoteCommandArgument(script))
        end

        return false
    end

    local ok, err = pcall(function()
        if mode == "manifest" then
            local manifest, luaError = requestWithLua(url, function()
                local chunks = {}
                return require("ltn12").sink.table(chunks), function()
                    return table.concat(chunks)
                end
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

            local accumulatedBytes = 0
            local _, luaError = requestWithLua(url, function()
                if love.filesystem.getInfo(filename) then love.filesystem.remove(filename) end

                return function(chunk)
                    if chunk then
                        love.filesystem.append(filename, chunk)
                        accumulatedBytes = accumulatedBytes + #chunk
                        chan:push({ "download_progress", accumulatedBytes, expectedSize })
                    end
                    return true
                end, function(headers)
                    local contentLength = tonumber(getHeader(headers, "content-length")) or 0
                    return { filename = filename, bytes = accumulatedBytes, size = expectedSize > 0 and expectedSize or contentLength }
                end
            end)

            local info = love.filesystem.getInfo(filename)
            if not info or info.size == 0 then
                if love.filesystem.getInfo(filename) then love.filesystem.remove(filename) end
                local outputPath = love.filesystem.getSaveDirectory() .. "/" .. filename
                if downloadWithCommand(url, outputPath) then
                    info = love.filesystem.getInfo(filename)
                    if info then
                        chan:push({ "download_progress", info.size or 0, expectedSize > 0 and expectedSize or info.size or 0 })
                    end
                end
            end

            if info and info.size > 0 then
                chan:push({ "download_complete", filename, info.size })
            else
                pushError((luaError or "No se pudo descargar la actualización.") .. " Verifica que download_url apunte a un patch_code.love público.")
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
    self.downloaded_bytes = 0
    self.size_bytes = 0
    self.error_message = ""
    self.download_url = ""
    self.remote_version = "0.0.0"

    self.channel_out = love.thread.getChannel(UPDATE_CHANNEL)
    self.channel_out:clear()
    self.thread = love.thread.newThread(NETWORK_THREAD_CODE)
    self.thread:start("manifest", normalizeGitHubUrl(manifest_url))
end

function Updater:startDownload()
    if self.status ~= "update_available" or self.download_url == "" then return end

    self.status = "downloading"
    self.progress = 0
    self.downloaded_bytes = 0
    self.error_message = ""

    self.channel_out = love.thread.getChannel(UPDATE_CHANNEL)
    self.channel_out:clear()
    self.thread = love.thread.newThread(NETWORK_THREAD_CODE)
    self.thread:start("download", normalizeGitHubUrl(self.download_url), self.patch_file, self.size_bytes)
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
                self.download_url = normalizeGitHubUrl(data.patch_url or data.code_patch_url or data.download_url or data.url or "")
                self.size_bytes = tonumber(data.size_bytes or data.patch_size_bytes or data.content_length) or 0

                if isVersionNewer(self.current_version, self.remote_version) then
                    if self.download_url == "" then
                        self.status = "error"
                        self.error_message = "La versión remota no incluye download_url/patch_url."
                    elseif not self.download_url:match("patch_code%.love") then
                        self.status = "error"
                        self.error_message = "El manifiesto debe apuntar al parche de código patch_code.love."
                    else
                        self.status = "update_available"
                    end
                else
                    self.status = "up_to_date"
                    self.progress = 1
                end
            else
                self.status = "error"
                self.error_message = "Estructura de datos de actualización inválida."
            end
        elseif msg_type == "download_progress" then
            self.downloaded_bytes = tonumber(msg[2]) or self.downloaded_bytes
            self.size_bytes = math.max(self.size_bytes, tonumber(msg[3]) or 0)
            if self.size_bytes > 0 then
                self.progress = clamp(self.downloaded_bytes / self.size_bytes, 0, 1)
            else
                self.progress = 0
            end
        elseif msg_type == "download_complete" then
            self.downloaded_bytes = tonumber(msg[3]) or self.downloaded_bytes
            if self.size_bytes <= 0 then
                self.size_bytes = self.downloaded_bytes
            end
            if self.size_bytes > 0 and self.downloaded_bytes < self.size_bytes then
                self.status = "error"
                self.error_message = "La descarga quedó incompleta. Intenta de nuevo."
            else
                self.status = "ready"
                self.progress = 1
            end
        elseif msg_type == "error" then
            self.status = "error"
            self.error_message = msg[2]
        end
    end
end

function Updater:applyAndRestart()
    if self.status ~= "ready" then return false end

    if not self:hasPatchFile() then
        self.status = "error"
        self.error_message = "No se encontró patch_code.love en el directorio de guardado."
        return false
    end

    local success = self:mountPatch()
    if success then
        writeVersion(self.remote_version)
        self.current_version = self.remote_version
        self.status = "applied"
        love.event.quit("restart")
        return true
    end

    self.status = "error"
    self.error_message = "patch_code.love no es un archivo .love válido."
    return false
end

return Updater
