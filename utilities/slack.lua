local component = require("component")
local json = require("json")
local internet = component.internet

local slack = {}

local slackUrl = "https://hooks.slack.com/services/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"

local function printTable(t)
    local result
    for k,v in pairs(t) do
        if result == nil then
            result = ""
        else
            result = result .. ", "
        end
        result = result .. k .. ":" .. v
    end
    return result
end

local function _readResponse(request)
    local responseBody = ""
    repeat
        local chunk = request.read()
        if not (chunk == nil) then
            responseBody = responseBody .. chunk
        end
    until chunk == nil
    return responseBody
end

local function _postJsonBlocking(url, body)
    print("sending POST request to " .. url)
    local headers = {}
    headers["content-type"] = "application/json"
    local request = internet.request(url, json:encode(body), headers)
    -- wait for status
    repeat until not (request.response() == nil)
    return request
end

function slack.postToSlack(message)
    local body = {}
    if type(message) == "string" then
        body.text = message
    elseif type(message) == "table" then
        body.text = printTable(message)
    end
    local request = _postJsonBlocking(slackUrl, body)
    local status = request.response()
    if status == 200 then
        print("message sent to slack")
    else
        print("error sending message to slack: " .. status)
    end
    print(_readResponse(request))
end

return slack