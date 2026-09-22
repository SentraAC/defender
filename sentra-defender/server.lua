local function isSet(v)
    return v ~= nil and v ~= '' and v ~= 'change-me'
end

local configured = isSet(Config.ApiKey) and isSet(Config.Webhook)
if not configured then
    if not isSet(Config.ApiKey) then
        print('^1[sentra-defender] Missing API key. Get a free one at https://sentra.ac and set Config.ApiKey^0')
    end
    if not isSet(Config.Webhook) then
        print('^1[sentra-defender] Missing Config.Webhook — set your Discord webhook URL^0')
    end
    print('^1[sentra-defender] Resource disabled until configured.^0')
    return
end

local steamKey = GetConvar('steam_webApiKey', 'none')
if steamKey == 'none' or steamKey == '' then
    print('^3[sentra-defender] steam_webApiKey is not set in server.cfg — Steam will NOT be checked.^0')
    print('^3[sentra-defender] It is highly recommended to set it: set steam_webApiKey "your_key"^0')
end

local trustCache = {}

local function runCheck(src, name)
    local payload = {
        identifiers = GetPlayerIdentifiers(src),
        minTrust = Config.MinTrust,
        webhook = Config.Webhook
    }
    if #payload.identifiers == 0 then return end

    PerformHttpRequest('https://defender.sentra.ac/check', function(status, body)
        if status == 401 then
            print('^1[sentra-defender] Invalid API key. Get a free one at https://sentra.ac and set it in Config.ApiKey^0')
            return
        end
        if status ~= 200 then return end
        local data = body and json.decode(body)
        if not data or data.trust == nil then return end

        trustCache[src] = data.trust

        if data.trust <= Config.MinTrust then
            print(('[sentra-defender] %s -> %d%%'):format(name, data.trust))
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json',
        ['x-api-key'] = Config.ApiKey
    })
end

AddEventHandler('playerJoining', function()
    runCheck(source, GetPlayerName(source))
end)

AddEventHandler('playerDropped', function()
    trustCache[source] = nil
end)

-- Usage: exports['sentra-defender']:GetTrust(playerId)   -> trust %
local function getTrust(playerId)
    return trustCache[tonumber(playerId)]
end

exports('GetTrust', getTrust)
