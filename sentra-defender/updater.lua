local REPO   = 'SentraAC/defender'
local BRANCH = 'main'
local RAW    = ('https://raw.githubusercontent.com/%s/%s/'):format(REPO, BRANCH)

local FILES = { 'fxmanifest.lua', 'server.lua', 'updater.lua' }

local resource     = GetCurrentResourceName()
local localVersion = GetResourceMetadata(resource, 'version', 0) or '0.0.0'

local function log(msg)
    print('^5[sentra-defender]^7 ' .. msg)
end

local function parse(v)
    local a, b, c = tostring(v):match('(%d+)%.(%d+)%.(%d+)')
    return (tonumber(a) or 0) * 1e6 + (tonumber(b) or 0) * 1e3 + (tonumber(c) or 0)
end

local function httpGet(url, cb)
    PerformHttpRequest(url, function(status, body)
        cb(status == 200 and body or nil)
    end, 'GET')
end

local function download(index, files, done)
    if index > #files then return done(true) end
    local file = files[index]
    httpGet(RAW .. file, function(body)
        if not body then
            log(('^1failed to download %s — update aborted^7'):format(file))
            return done(false)
        end
        SaveResourceFile(resource, file, body, -1)
        download(index + 1, files, done)
    end)
end

CreateThread(function()
    if Config and Config.AutoUpdate == false then return end

    httpGet(RAW .. 'fxmanifest.lua', function(body)
        if not body then
            log('could not reach GitHub — skipping update check')
            return
        end

        local remoteVersion =
            body:match("version%s+'([^']+)'") or body:match('version%s+"([^"]+)"')
        if not remoteVersion then
            log('could not read remote version — skipping update check')
            return
        end

        if parse(remoteVersion) <= parse(localVersion) then
            log(('up to date (v%s)'):format(localVersion))
            return
        end

        log(('new version available: v%s -> v%s, updating...'):format(localVersion, remoteVersion))
        download(1, FILES, function(ok)
            if ok then
                log(('^2updated to v%s — restart the resource to apply^7'):format(remoteVersion))
            end
        end)
    end)
end)
