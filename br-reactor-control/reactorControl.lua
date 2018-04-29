local logger = require("logger")
local component = require("component")
local reactorGuiApi = require("reactorGui")
local reactor = component.br_reactor

-- state for the reactor controller application
local state = {
    autoOnEnabled = true,
    autoOffEnabled = true
}

local autoOnModel = {
    get = function() return state.autoOnEnabled end,
    set = function(value) state.autoOnEnabled = value end
}

local autoOffModel = {
    get = function() return state.autoOffEnabled end,
    set = function(value) state.autoOffEnabled = value end
}

function autoOff()
    if (reactor.getActive() and reactor.getEnergyStored() > 2000000) then
        reactor.setActive(false)
        logger.log("Internal energy buffer max. threshold reached; reactor deactivated")
    end
end

function autoOn()
    if (not reactor.getActive() and reactor.getEnergyStored() < 50000) then
        reactor.setActive(true)
        logger.log("Internal energy buffer min. threshold reached; reactor activated")
    end
end

function runReactorControl()
    component.gpu.setResolution(64, 22)
    local gui = reactorGuiApi.create(autoOnModel, autoOffModel, logger)
    while true do
        if state.autoOffEnabled then autoOff() end
        if state.autoOnEnabled then autoOn() end
        gui.update(reactor)
    end
end

--print("foo")
runReactorControl()