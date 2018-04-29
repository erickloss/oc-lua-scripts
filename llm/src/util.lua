local json = require("lib/json")
local env = require("env")

local function _readFileContentAsString(file)
    local content = ""
    repeat
        local chunk = file.read()
        if chunk ~= nil then
            content = content .. chunk
        end
    until chunk == nil
    file.close()
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
    return _readJsonFileAsTable(string.format("%s/%s", directory, env.LIB_JSON_FILE_NAME))
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

return {
    readFileContentAsString = _readFileContentAsString,
    readFileAsString = _readFileAsString,
    readJsonFileAsTable = _readJsonFileAsTable,
    readLibJson = _readLibJson,
    getOrDownloadFile = _getOrDownloadFile
}
