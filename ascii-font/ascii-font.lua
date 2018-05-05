local llm = require("llm")

local FONT_ANSI_SHADOW = "ansi-shadow"
local FONT_CALVIN_S = "calvin-s"

local AsciiFont = {}
local AsciiFont_MT = { __index = AsciiFont }

function AsciiFont:new(defaultFont)
    local new = {
        initialized = false,
        defaultFont = defaultFont,
        fonts = {}
    }
    return setmetatable(new, AsciiFont_MT)
end

function AsciiFont:initialize(customFonts)
    -- default fonts
    self.fonts[FONT_CALVIN_S] = llm:requireLocal("fonts/calvin-s")
    self.fonts[FONT_ANSI_SHADOW] = llm:requireLocal("fonts/ansi-shadow")
    -- custom fonts
    if customFonts ~= nil then
        for fontName, font in pairs(customFonts) do
            self.fonts[fontName] = font
        end
    end
    self.initialized = true
end

function AsciiFont:print(text, fontName)
    if not self.initialized then
        return "ERROR: font API not initialized", 30, 1
    end
    local font = fontName ~= nil and self.fonts[fontName] or self.fonts[self.defaultFont]
    if font == nil then
        return "ERROR: font " .. (fontName and fontName or "default") .. " not found", 50, 1
    end
    local height = font.height
    local width = 0

    local resultLines = {}
    for character in text:gmatch(".") do
        local fontChar = font.characters[character]
        if fontChar ~= nil then
            width = width + fontChar.width
            for lineIndex = 1, font.height do
                if resultLines[lineIndex] == nil then
                    resultLines[lineIndex] = ""
                end
                resultLines[lineIndex] = resultLines[lineIndex] .. fontChar.lines[lineIndex]
            end
        end
    end

    local result = ""
    for _, line in pairs(resultLines) do
        result = result .. line .. "\n"
    end

    return result, width, height
end

--- default fonts: calvin-s,

local function fontParser(width, height, characters, fontLinesInput)
    local widthCalculator = function(character)
        if type(width) == "number" then
            return width
        elseif type(width) == "function" then
            return width(character)
        end
    end
    local result = {
        height = height,
        characters = {}
    }
    local currentXPos = 0
    for character in characters:gmatch(".") do
        local fontChar = {
            width = widthCalculator(character),
            lines = {}
        }
        for i = 1, height do
            fontChar.lines[i] = fontLinesInput[i]:sub(currentXPos, currentXPos + fontChar.width)
        end
        result.characters[character] = fontChar
        currentXPos = currentXPos + fontChar.width
    end
    return result
end

return AsciiFont:new(FONT_CALVIN_S)
