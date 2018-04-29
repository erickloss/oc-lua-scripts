local loggerApi = {}
local _isDirty = false

loggerApi.log = function(message)
    print(message)
    _isDirty = true
    table.insert(logEntries, message)
end

loggerApi.entries = function()
    _isDirty = false
    return logEntries
end

loggerApi.isDirty = function() return _isDirty end

logger = loggerApi
return logger