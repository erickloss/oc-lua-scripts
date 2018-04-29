local computer = require("computer")
local component = require("component")
local event = require("event")
local modem = component.modem
require("is-equal")
local serialization = require("serialization")

-- state for the reactor controller application
local applicationState = {
    autoOnEnabled = true,
    autoOffEnabled = true
}
local currentReactorState = nil

modem.open(22)
function _processNetworkMessage(event, a, b, c, d, command, payload)
    if (command == "get_reactor_state") then

    end
    print(event .. " " .. a .. " " .. b .. " " .. c .. " " .. d .. " " .. command .. " payload: " .. payload)
    modem.broadcast(23, "re: " .. command)


end

local function getCurrentReactorState()
    return {
        active = false
    }
end

function broadcastReactorState()
    modem.broadcast(23, serialization.serialize(currentReactorState))
end

function reactorStateChangeDetection()
    local lastReadReactorState = currentReactorState
    currentReactorState = getCurrentReactorState()
    if lastReadReactorState == nil or not isEqual(lastReadReactorState, currentReactorState) then
        broadcastReactorState()
    end
end

local function runServer()
    print("Running server ...")
    event.listen("modem_message", _processNetworkMessage)
    while true do
        os.sleep(1)
        reactorStateChangeDetection()
    end
end

runServer()
