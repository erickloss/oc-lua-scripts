local util = require("util")

local REPOSITORY_GITHUB = "github"

--------------------- repository base class ---------------------
local Repository = {}

function Repository:getOrDownloadFile(resourceIdentifier, file)
    -- intent to be overridden
    return nil
end

-- constructor
function Repository:new(repositoryName)
    local new = {}
    new.repositoryName = repositoryName

    return setmetatable(new, Repository)
end

--------------------- github repository class ---------------------
-- pattern: [user]:[repository]:[branch]:[filePath]
-- the filePath may be a file or a directory (direcotries should end with a slash)
-- example: IgorTimofeev:OpenComputers:master:lib/json.lua
-- github URL pattern
-- https://github.com/[user]/[repository]/raw/[branch]/[filename]
local GithubRepository = {} -- extends Repository

function GithubRepository:getOrDownloadFile(resourceIdentifier, file)
    local user, repository, branch, filePath = resourceIdentifier:match("(.+):(.+):(.+):(.+)")
    if file ~= nil then
        filePath = filePath .. file
    end
    local githubUrl = string.format("https://github.com/%s/%s/raw/%s/%s", user, repository, branch, filePath)
    local githubPath, githubFileName = filePath:match("^(.+/)(.+)$")
    local localFilePath = string.format("/github/%s/%s/%s/%s", user, repository, branch, githubPath)

    return util.getOrDownloadFile(githubUrl, localFilePath, githubFileName)
end

-- constructor
function GithubRepository:new(repositoryName)
    local new = Repository:new(repositoryName)

    return setmetatable(new, GithubRepository)
end

--------------------- factory ---------------------
return function(repositoryName)
    if repositoryName == REPOSITORY_GITHUB then
        return GithubRepository:new(repositoryName)
    else
        print("unsupported repository: " .. repositoryName)
    end
end

