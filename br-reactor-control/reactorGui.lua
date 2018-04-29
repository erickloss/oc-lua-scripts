local computer = require("computer")
local gpu = require("component").gpu
local guiApi = require("gui")
require "try-catch"

-- reactor control GUI module
local reactorGuiApi = {}

function reactorGuiApi.create(autoOnModel, autoOffModel, logger)
    local publicApi = {}
    -- fallback
    publicApi.update = function(_) os.exit() end
    --[[
        try {
            function()
                _createGui(publicApi)
            end,
            catch {
                function(error)
                    print('error creating reactor GUI:' .. error)
                end
            }
        }
        ]]
    _createGui(publicApi, autoOnModel, autoOffModel, logger)
    return publicApi
end

function _createGui(publicApi, autoOnModel, autoOffModel, logger)
    local startTime = computer.uptime()
    logger.log(string.format("Starting reactor GUI... (%i seconds since machine boot)", startTime))
    local w, h = gpu.getResolution()
    local gui = guiApi.newGui(1, 1, w - 1, h - 1, true)

    local titleLabel = guiApi.newLabel(gui, 2, 3, "Reactor Control")
    local statusLabel = guiApi.newLabel(gui, 3, 5, "Status: Starting ...")
    local uptimeLabel = guiApi.newLabel(gui, 3, 6, "Uptime: Starting ...")

    local hline1 = guiApi.newHLine(gui, 1, 7, w - 1)

    local logList = guiApi.newList(gui, math.floor(w / 2), 8, math.floor(w / 2) - 2, h - 5, logger.entries(), nil, "Log Messages")

    -- auto on checkbox
    local autoOnCheckbox
    local autoOnCheckboxCallback = function()
        local checked = guiApi.getCheckboxStatus(gui, autoOnCheckbox)
        logger.log(string.format("Auto On: %s", checked and "Enabled" or "Disabled"))
        autoOnModel.set(checked)
    end
    autoOnCheckbox = _newLabeledCheckbox(gui, 3, 8, "Auto On (< 10%)", autoOnModel.get(), autoOnCheckboxCallback)
    -- auto off checkbox
    local autoOffCheckbox
    local autoOffCheckboxCallback = function()
        local checked = guiApi.getCheckboxStatus(gui, autoOffCheckbox)
        logger.log(string.format("Auto Off: %s", checked and "Enabled" or "Disabled"))
        autoOffModel.set(checked)
    end
    autoOffCheckbox = _newLabeledCheckbox(gui, 3, 9, "Auto Off (> 90%)", autoOffModel.get(), autoOffCheckboxCallback)

    -- shutdown button
    local shutdownButtonCallback = function()
        computer.shutdown()
    end
    local shutdownButton = guiApi.newButton(gui, w - 12, h - 1, "Shutdown", shutdownButtonCallback)

    -- gui update function
    publicApi.update = function(reactor)
        --print "update"
        guiApi.runGui(gui)
        guiApi.setText(gui, statusLabel, string.format("Status: %s", reactor.getActive() and "Active" or "Not Active"), false)
        guiApi.setText(gui, uptimeLabel, string.format("Uptime: %i", computer.uptime() - startTime), false)
        if logger.isDirty() then
            guiApi.clearList(gui, logList)
            for _, message in pairs(logger.entries()) do guiApi.insertList(gui, logList, message) end
        end
        guiApi.displayGui(gui)
    end
    logger.log(string.format("Started reactor GUI after %i seconds", computer.uptime() - startTime))
    guiApi.clearScreen()
end

function _newLabeledCheckbox(gui, x, y, label, state, func)
    guiApi.newLabel(gui, x + 3, y, label)
    return guiApi.newCheckbox(gui, x, y, state, func)
end

return reactorGuiApi