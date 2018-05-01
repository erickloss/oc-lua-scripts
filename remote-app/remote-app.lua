local event = require("event")

local function _createRemoteActionCallback(remoteAddress, listeners, sender)
    return function(event, localAddress, _remoteAddress, port, distance, command, ...)
        if _remoteAddress == remoteAddress then
            if type(listeners) == "table" then
                local commandListener = listeners[command]
                if commandListener == nil then
                    print("no listener for command " .. command)
                else
                    commandListener(sender, ...)
                end
            elseif type(listeners) == "function" then
                listeners(command, sender, ...)
            else
                print("received command:")
                print(command)
                for k, v in pairs({ ... }) do print(k .. ":" .. v) end
            end
        end
    end
end

local function _startRemoteAccess(callbackIdKey, callback)
    if os.getenv(callbackIdKey) == nil then
        os.setenv(callbackIdKey, event.listen("modem_message", callback))
        print("Remote callback started")
    else
        print("Remote callback already running")
    end
end

local function _stopRemoteAccess(callbackIdKey)
    if os.getenv(callbackIdKey) == nil then
        print("No remote callback found")
    else
        event.cancel(tonumber(os.getenv(callbackIdKey)))
        os.setenv(callbackIdKey, nil)
        print("Remote callback stopped")
    end
end

local function isStarted(callbackIdKey)
    return not (os.getenv(callbackIdKey) == nil)
end

local function _createRemote(remoteId, remoteAddress, commands, remoteCallback, sender, onStop)
    local callbackIdKey = remoteId .. "_remoteCallbackID"

    local remote = {
        remoteId = remoteId,
        remoteAddress = remoteAddress,
        commands = commands,
        start = function()
            if not isStarted(callbackIdKey) then
                _startRemoteAccess(callbackIdKey, remoteCallback)
            end
        end,
        isStarted = isStarted,
        getRemoteCallback = function() return os.getenv(callbackIdKey) end,
        send = function(...) sender(...) end,
        stop = function()
            if type(onStop) == "function" then
                onStop()
            end
            _stopRemoteAccess(callbackIdKey)
        end
    }

    for commandName, command in pairs(commands) do
        if type(command) == "function" then
            remote[commandName] = function(...) command(sender, ...) end
        else
            remote[commandName] = function(...) sender(command, ...) end
        end
    end

    return remote
end

local function _createTunnelSender(tunnel)
    return function(...)
        --print("sending to tunnel ...")
        --for a, b in pairs({ ... }) do print(b) end
        tunnel.send(...)
    end
end

local function _createModemBroadcaster(modem, port)
    return function(...)
        --print("broadcasting via modem ...")
        --for a, b in pairs({ ... }) do print(b) end
        modem.broadcast(port, ...)
    end
end

local function _createModemSender(modem, port, remoteAddress)
    return function(...)
        --print("sending to modem ...")
        --for a, b in pairs({ ... }) do print(b) end
        modem.send(remoteAddress, port, ...)
    end
end

local remoteAppApi = {
    createRemote = function(remoteId, remoteAddress, commands, listeners, sender, onStop)
        return _createRemote(remoteId, remoteAddress, commands, _createRemoteActionCallback(remoteAddress, listeners, sender), sender, onStop)
    end,
    createTunnelRemote = function(remoteId, remoteAddress, commands, listeners, tunnel)
        local sender = _createTunnelSender(tunnel)
        return _createRemote(remoteId, remoteAddress, commands, _createRemoteActionCallback(remoteAddress, listeners, sender), sender)
    end,
    createModemRemote = function(remoteId, remoteAddress, commands, listeners, modem, port, broadcastMode)
        local sender = broadcastMode == true and _createModemBroadcaster(modem, port) or _createModemSender(modem, port, remoteAddress)
        local function onStop()
            modem.close(port)
        end
        local remote = _createRemote(remoteId, remoteAddress, commands, _createRemoteActionCallback(remoteAddress, listeners, sender), sender, onStop)
        modem.open(port)
        return remote
    end,
    createGenericExecutor = function(remote)
        return function(...)
            local args = { ... }
            local command = args[1]
            print("[local]: executing command '" .. command .. "'")
            table.remove(args, 1)
            local handler = remote[command]
            if handler == nil then
                print("Invalid command")
            else
                handler(table.unpack(args))
            end
        end
    end,
    createModemProxy = function(remote, clientAddress, modem, port, broadcastMode)
        local sender = broadcastMode == true and _createModemBroadcaster(modem, port) or _createModemSender(modem, port, clientAddress)
        local proxyListener = function(event, localAddress, remoteAddress, _port, distance, commandName, ...)
            -- outgoing command forwarding (from client to remote)
            if remoteAddress == clientAddress and _port == port then
                local commandFunction = remote[commandName]
                if not (commandFunction == nil) then
                    print(string.format("forward command from client to remote: '%s'", commandName))
                    commandFunction(...)
                end
            end
            -- incoming command forwarding (from remote to client)
            if remoteAddress == remote.remoteAddress then
                print(string.format("forward command from remote to client: '%s'", commandName))
                sender(commandName, ...)
            end
        end

        local function _onStop()
            modem.close(port)
        end
        local remote = _createRemote(string.format("%s_proxy", remote.remoteId), clientAddress, {}, proxyListener, sender, _onStop)
        modem.open(port)
        return remote
    end,
    createSimpleTunnelToModemProxy = function(proxyId, tunnelAddress, tunnel, modemAddress, modem, port, broadcastMode)
        local toModemSender = broadcastMode == true and _createModemBroadcaster(modem, port) or _createModemSender(modem, port, modemAddress)
        local toTunnelSender = _createTunnelSender(tunnel)
        local callbackIdKey = proxyId .. "_remoteCallbackID"
        local remoteCallback = function(event, localAddress, remoteAddress, _port, distance, commandName, ...)
            print("command: " .. commandName .. ", remoteAddress: " .. remoteAddress)
            -- outgoing command forwarding (from modem to tunnel)
            if remoteAddress == modemAddress and _port == port then
                print(string.format("forward command from modem to tunnel: '%s'", commandName))
                toTunnelSender(commandName, ...)
            end
            -- incoming command forwarding (from tunnel to modem)
            if remoteAddress == tunnelAddress then
                print(string.format("forward command from tunnel to modem: '%s'", commandName))
                toModemSender(commandName, ...)
            end
        end
        return {
            start = function()
                if not isStarted(callbackIdKey) then
                    _startRemoteAccess(callbackIdKey, remoteCallback)
                end
            end,
            stop = function()
                _stopRemoteAccess(callbackIdKey)
            end
        }
    end
}

return remoteAppApi