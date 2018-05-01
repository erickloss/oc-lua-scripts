local json = require("json")
local fs = require("filesystem")

local LIB_JSON_FILE_NAME = "lib.json"
local TYPE_LIB = "lib"
local TYPE_FILE = "file"
local REPOSITORY_GITHUB = "github"

------------------- env
local function getOrInitDefaultEnv(key, default)
    if os.getenv(key) == nil then
        os.setenv(key, default)
    end
    return os.getenv(key)
end

local env = {
    DEVELOPMENT_MODE = getOrInitDefaultEnv("LLM.DEVELOPMENT_MODE", true),
    LIB_ROOT_DIR = getOrInitDefaultEnv("LLM.LIB_ROOT_DIR", "/home/.llm/lib") -- TODO change to /tmp/.llm/lib
}

------------------ util ------------------
local function _readFileContentAsString(file)
    local content = ""
    repeat
        local chunk = file:read(1024)
        if chunk ~= nil then
            content = content .. chunk
        end
    until chunk == nil
    file:close()
    return content
end

local function _readFileAsString(filePath)
    if fs.exists(filePath) then
        local file = fs.open(filePath)
        if file then
            return _readFileContentAsString(file)
        else
            print("Could not open file: " .. filePath)
        end
    else
        print("No such file: " .. filePath)
    end
end

local function _readJsonFileAsTable(filePath)
    return json:decode(_readFileAsString(filePath))
end

local function _readLibJson(directory)
    return _readJsonFileAsTable(string.format("%s/%s", directory, LIB_JSON_FILE_NAME))
end

local function _getOrDownloadFile(sourceUrl, targetDirectory, targetFileName)
    local fullFilePath = string.format("%s/%s", env.LIB_ROOT_DIR, targetDirectory)
    if not fs.isDirectory(fullFilePath) then
        fs.makeDirectory(fullFilePath)
    end
    local pathAndName = string.format("%s/%s", fullFilePath, targetFileName)
    if env.DEVELOPMENT_MODE or not fs.exists(pathAndName) then
        print("downloading file '" .. sourceUrl .. "' to '" .. pathAndName .. "'")
        os.execute(string.format("wget -f %s %s", sourceUrl, pathAndName))
        -- TODO error handling
    else
        print("use cached local file '" .. pathAndName .. "'")
    end
    return pathAndName
end


------- lib.json -------
-- library descriptor pattern: [type]@[repository]#[resourceIdentifier]
-- supported types: file, lib
-- for type lib, the resource identifier must point to the
-- root directory of the library containing the lib.json (resourceIdentifier must end with a slash then)

--------------------- repository base class ---------------------
local Repository = {}
local Repository_MT = {}

function Repository:getOrDownloadFile(resourceIdentifier, file)
    -- intent to be overridden
    return nil
end

function Repository:getLocalFilePath(resourceIdentifier, file)
    -- intent to be overridden
    return nil
end

-- constructor
function Repository:new(repositoryName)
    local new = {}
    new.repositoryName = repositoryName

    return setmetatable(new, Repository_MT)
end

--------------------- github repository class ---------------------
-- pattern: [user]:[repository]:[branch]:[filePath]
-- the filePath may be a file or a directory (direcotries should end with a slash)
-- example: IgorTimofeev:OpenComputers:master:lib/json.lua
-- github URL pattern
-- https://github.com/[user]/[repository]/raw/[branch]/[filename]
local GithubRepository = {} -- extends Repository
local GithubRepository_MT = {__index = GithubRepository}

local function _parseGithubResourceIdentifier(resourceIdentifier, file)
    local user, repository, branch, filePath = resourceIdentifier:match("(.+):(.+):(.+):(.+)")
    if file ~= nil then
        filePath = filePath .. file
    end
    local githubPath, githubFileName = filePath:match("^(.+)/(.+)$")
    local localFilePath = string.format("github/%s/%s/%s/%s", user, repository, branch, githubPath)
    return user, repository, branch, filePath, githubFileName, localFilePath
end

function GithubRepository:getOrDownloadFile(resourceIdentifier, file)
    local user, repository, branch, filePath, githubFileName, localFilePath = _parseGithubResourceIdentifier(resourceIdentifier, file)
    local githubUrl = string.format("https://github.com/%s/%s/raw/%s/%s", user, repository, branch, filePath)
    return _getOrDownloadFile(githubUrl, localFilePath, githubFileName)
end

function GithubRepository:getLocalFilePath(resourceIdentifier, file)
    local _, _, _, _, githubFileName, localFilePath = _parseGithubResourceIdentifier(resourceIdentifier, file)
    return string.format("%s/%s/%s", env.LIB_ROOT_DIR, localFilePath, githubFileName)
end

-- constructor
function GithubRepository:new(repositoryName)
    local new = Repository:new(repositoryName)

    return setmetatable(new, GithubRepository_MT)
end

--------------------- factory ---------------------

local function _createRepository(repositoryName)
    if repositoryName == REPOSITORY_GITHUB then
        return GithubRepository:new(repositoryName)
    else
        print("unsupported repository: " .. repositoryName)
    end
end

--------------------- llm ---------------------

local function _installLib(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
    return function()
        local libJson = llm.dependencyLibJsonCache[dependencyDescriptor]
        print("installing library: " .. libJson.name .. " alias " .. alias .. " (from: " .. dependencyDescriptor .. ")")
        local baseResourceIdentifier
        for _, localFilePath in pairs(libJson.files) do
            print("  - installing file: " .. localFilePath)
            repository:getOrDownloadFile(resourceIdentifier, localFilePath)
        end
    end
end

local function _installFile(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
    return function()
        print("installing file: " .. dependencyDescriptor .. " alias " .. alias)
        repository:getOrDownloadFile(resourceIdentifier)
    end
end

local function _doCalculateAllDependencies(llm, libJson, dependencies)
    if libJson.dependencies == nil then
        return
    end
    for alias, dependencyDescriptor in pairs(libJson.dependencies) do
        if dependencies[dependencyDescriptor] == nil then
            local dependencyType, repositoryName, resourceIdentifier = dependencyDescriptor:match("^(.+)@(.+)#(.+)$")
            print("Found dependency: type=" .. dependencyType .. ", repository=" .. repositoryName .. ", resourceIdentifier=" .. resourceIdentifier)
            local repository = _createRepository(repositoryName)
            if repository ~= nil then
                if dependencyType == TYPE_FILE then
                    dependencies[dependencyDescriptor] = _installFile(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
                elseif dependencyType == TYPE_LIB then
                    -- if the dependency itself is a library, the sub-dependencies are calculated recursively
                    local libJsonOfDependency = _readJsonFileAsTable(repository:getOrDownloadFile(resourceIdentifier, LIB_JSON_FILE_NAME))
                    if libJsonOfDependency ~= nil then
                        llm.dependencyLibJsonCache[dependencyDescriptor] = libJsonOfDependency
                        _doCalculateAllDependencies(llm, libJsonOfDependency, dependencies)
                        dependencies[dependencyDescriptor] = _installLib(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
                    else
                        dependencies[dependencyDescriptor] = "error: no lib.json found"
                        print("no lib.json found for dependency: " .. dependencyDescriptor)
                    end
                else
                    print("unsupported dependency type: " .. dependencyType)
                end
            end
        end
    end
end

local function _calculateAllDependencies(llm)
    local result = {}
    _doCalculateAllDependencies(llm, llm.libJson, result)
    return result
end

local function _installDependencies(dependencies)
    for _, installer in pairs(dependencies) do
        if type(installer) == "function" then
            installer()
        else
            print(installer)
        end
    end
end

local function _appendDotLuaIfNotPresent(script)
    if string.sub(script,-4) == ".lua" then
        return script
    else
        return script .. ".lua"
    end
end

--------------------- llm class ---------------------
local llm = {}
local LLM_MT = {__index = llm}
llm.libJson = nil
llm.dependencyLibJsonCache = {}

function llm:require(alias)
    self.libJson = _readLibJson(os.getenv("PWD"))
    local dependencyDescriptor = self.libJson.dependencies[alias]
    if dependencyDescriptor == nil then
        print("Could not find require alias: " .. alias)
    else
        local dependencyType, repositoryName, resourceIdentifier = dependencyDescriptor:match("^(.+)@(.+)#(.+)$")
        local repository = _createRepository(repositoryName)
        local localRequiredFilePath
        if dependencyType == TYPE_FILE then
            localRequiredFilePath = repository:getLocalFilePath(resourceIdentifier)
        elseif dependencyType == TYPE_LIB then
            -- get entry point lua script
            local libJsonOfDependency = _readJsonFileAsTable(repository:getLocalFilePath(resourceIdentifier, LIB_JSON_FILE_NAME))
            local entryPoint = libJsonOfDependency.entryPoint
            localRequiredFilePath = repository:getLocalFilePath(resourceIdentifier, entryPoint)
        else
            print("unsupported dependency type: " .. dependencyType)
            return nil
        end
        localRequiredFilePath = _appendDotLuaIfNotPresent(localRequiredFilePath)
        print("require: " .. localRequiredFilePath)
        return dofile(localRequiredFilePath)
    end
end

function llm:install()
    self.libJson = _readLibJson(os.getenv("PWD"))
    print("calculating dependencies ...")
    local dependencies = _calculateAllDependencies(self)
    for depDescriptor, _ in pairs(dependencies) do
        print("Dependency: " .. depDescriptor)
    end
    print("installing dependencies ...")
    _installDependencies(dependencies)
    print("done")
end

function llm:clean()
    print("cleaning up llm lib dir ...")
    os.execute("rm -rf " .. env.LIB_ROOT_DIR)
end

-----------------------   factory -----------------------
function llm:new()
    local new = {}
    local instance = setmetatable(new, LLM_MT)
    return instance
end

return llm:new()

