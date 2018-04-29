local RepositoryFactory = require("repositories")
local util = require("util")

local TYPE_LIB = "lib"
local TYPE_FILE = "file"

------- lib.json -------
-- library descriptor pattern: [type]@[repository]#[resourceIdentifier]
-- supported types: file, lib
-- for type lib, the resource identifier must point to the
-- root directory of the library containing the lib.json (resourceIdentifier must end with a slash then)

--------------------- utilities ---------------------
local function _installLib(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
    return function()
        local libJson = llm.dependencyLibJsonCache[dependencyDescriptor]
        print("installing library: " .. libJson.name .. " alias " .. alias .. " (from: " .. dependencyDescriptor .. ")")
        local baseResourceIdentifier
        for _, localFilePath in pairs(libJson.files) do
            print("  - installing file: " .. localFilePath)
            repository.getOrDownloadFile(resourceIdentifier, localFilePath)
        end
    end
end

local function _installFile(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
    return function()
        print("installing file: " .. dependencyDescriptor .. " alias " .. alias)
        repository.getOrDownloadFile(resourceIdentifier)
    end
end

local function _doCalculateAllDependencies(llm, dependencies)
    if llm.libJson.dependencies == nil then
        return
    end
    for alias, dependencyDescriptor in pairs(llm.libJson.dependencies) do
        if dependencies[dependencyDescriptor] ~= nil then
            local dependencyType, repositoryName, resourceIdentifier = dependencyDescriptor:match("^(.+)@(.+)#(.+)$")
            local repository = RepositoryFactory.createRepository(repositoryName)
            if repository ~= nil then
                if dependencyType == TYPE_FILE then
                    dependencies[dependencyDescriptor] = _installFile(llm, alias, dependencyDescriptor, repository, resourceIdentifier)
                elseif dependencyType == TYPE_LIB then
                    -- if the dependency itself is a library, the sub-dependencies are calculated recursive
                    local libJsonOfDependency = util.readJsonFileAsTable(repository.getOrDownloadFile(resourceIdentifier))
                    if libJsonOfDependency ~= nil then
                        llm.dependencyLibJsonCache[dependencyDescriptor] = libJsonOfDependency
                        _doCalculateAllDependencies(libJsonOfDependency, dependencies)
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
    _doCalculateAllDependencies(llm, result)
    return result
end

local function _installDependencies(dependencies)
    for _, installer in pairs(dependencies) do
        if typeof(installer) == "function" then
            installer()
        else
            print(installer)
        end
    end
end

--------------------- llm class ---------------------
local llm = {}
llm.libJson = nil
llm.dependencyLibJsonCache = {}

function llm:require(alias)
    -- find current package
    -- get resolver
    -- resolve local lib file path from alias
    -- return dofile(libPath)
end

function llm:install()
    self.libJson = util.readLibJson(".")
    print("calculating dependencies ...")
    local dependencies = _calculateAllDependencies(self)
    for depDescriptor, _ in pairs(dependencies) do
        print("Dependency: " .. depDescriptor)
    end
    print("installing dependencies ...")
    _installDependencies(dependencies)
    print("done")
end

-------------------------------------------------------
function llm:new(args)
    local new = {}

    if args then
        for key, val in pairs(args) do
            new[key] = val
        end
    end

    return setmetatable(new, llm)
end

return llm:new()