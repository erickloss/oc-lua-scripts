local llm = require("llm")

local args = { ... }
if args[1] == "install" then
    llm:install()
end