local llm = require("llm")

local args = { ... }

for _, commandToRun in pairs(args) do
    if commandToRun == "install" then
        llm:install()
    elseif commandToRun == "clean" then
        llm:clean()
    end
end