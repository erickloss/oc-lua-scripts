local computer = require("computer")
local component = require("component")
local event = require("event")
local modem = component.modem

function _processNetworkMessage(event, a, b, c, d, command)
    print(event .. " " .. a .. " " .. b .. " " .. c .. " " .. d .. " " .. command)
end

function runClient()
    print("Running client ...")
    modem.open(23)
    event.listen("modem_message", _processNetworkMessage)
    while true do
        os.sleep(1)
        modem.broadcast(22, "hello", "foo")
        --print("tick")0
    end
end

runClient()