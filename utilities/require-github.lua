local fs = require("filesystem")
local libDir = "/lib/.require-github"

-- https://github.com/user/repository/raw/branch/filename
local require_github = function(user, repository, filename, branch)
    if branch == nil then branch = "master" end
    local githubUrl = "https://github.com/" .. user .. "/" .. repository .. "/raw/" .. branch .. "/" .. filename
    local fullFilePath = libDir .. "/" .. user .. "/" .. repository .. "/" .. branch .. "/" .. filename
    os.execute("wget -f -P " .. fullFilePath .. " " .. githubUrl)
    print(fs.exist(fullFilePath))
end


