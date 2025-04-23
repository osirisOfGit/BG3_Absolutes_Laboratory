Logger = {}
-- Largely stolen from Auto_Sell_Loot - https://www.nexusmods.com/baldursgate3/mods/2435 Thx m8 (｡･∀･)ﾉﾞ

Logger.PrintTypes = {
    TRACE = 5,
    DEBUG = 4,
    INFO = 3,
    WARNING = 2,
    ERROR = 1,
    OFF = 0,
    [5] = "TRACE",
    [4] = "DEBUG",
    [3] = "INFO",
    [2] = "WARNING",
    [1] = "ERROR",
    [0] = "OFF",
}

local TEXT_COLORS = {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    cyan = 34,
    magenta = 35,
    blue = 36,
    white = 37,
}

local function GetTimestamp()
    local time = Ext.Utils.MonotonicTime()
    local milliseconds = time % 1000
    local seconds = math.floor(time / 1000) % 60
    local minutes = math.floor((time / 1000) / 60) % 60
    local hours = math.floor(((time / 1000) / 60) / 60) % 24
    return string.format("[%02d:%02d:%02d.%03d]",
        hours, minutes, seconds, milliseconds)
end


local function ConcatPrefix(prefix, message)
    local paddedPrefix = prefix .. string.rep(" ", 25 - #prefix) .. " : "

    if type(message) == "table" then
        local serializedMessage = Ext.Json.Stringify(message)
        return paddedPrefix .. serializedMessage
    else
        return paddedPrefix .. tostring(message)
    end
end

local function ConcatOutput(...)
    local varArgs = { ... }
    local outStr = ""
    local firstDone = false
    for _, v in pairs(varArgs) do
        if not firstDone then
            firstDone = true
            outStr = tostring(v)
        else
            outStr = outStr .. " " .. tostring(v)
        end
    end
    return outStr
end
local function GetRainbowText(text)
    local colors = { "31", "33", "32", "36", "35", "34" } -- Red, Yellow, Green, Cyan, Magenta, Blue
    local coloredText = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        local color = colors[i % #colors + 1]
        coloredText = coloredText .. string.format("\x1b[%sm%s\x1b[0m", color, char)
    end
    return coloredText
end

function Logger:IsLogLevelEnabled(logLevel)
    return MCM.Get("log_level") >= logLevel
end

--- Function to print text with custom colors, message type, custom prefix, rainbowText, and prefix length
function Logger:BasicPrint(content, messageType, textColor, customPrefix, rainbowText, prefixLength)
    prefixLength = prefixLength or 15
    messageType = messageType or Logger.PrintTypes.INFO
    local textColorCode = textColor or TEXT_COLORS.cyan     -- Default to cyan

    customPrefix = customPrefix or ModUtils:GetModInfo().Name
    local padding = string.rep(" ", prefixLength - #customPrefix)
    local message = ConcatOutput(ConcatPrefix(customPrefix .. padding .. "  [" .. Logger.PrintTypes[messageType] .. "]", content))

    Logger:LogMessage(ConcatOutput(ConcatPrefix(customPrefix .. "  [" .. Logger.PrintTypes[messageType] .. "]", content)))
    if messageType <= Logger.PrintTypes.INFO then
        local coloredMessage = rainbowText and GetRainbowText(message) or
            string.format("\x1b[%dm%s\x1b[0m", textColorCode, message)
        if messageType == Logger.PrintTypes.ERROR then
            Ext.Utils.PrintError(coloredMessage)
        elseif messageType == Logger.PrintTypes.WARNING then
            Ext.Utils.PrintWarning(coloredMessage)
        else
            Ext.Utils.Print(coloredMessage)
        end
    end
end

function Logger:BasicError(content, ...)
    if Logger:IsLogLevelEnabled(Logger.PrintTypes.ERROR) then
        Logger:BasicPrint(string.format(content, ...), Logger.PrintTypes.ERROR, TEXT_COLORS.red)
    end
end

function Logger:BasicWarning(content, ...)
    if Logger:IsLogLevelEnabled(Logger.PrintTypes.WARNING) then
        Logger:BasicPrint(string.format(content, ...), Logger.PrintTypes.WARNING, TEXT_COLORS.yellow)
    end
end

function Logger:BasicDebug(content, ...)
    if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
        Logger:BasicPrint(string.format(content, ...), Logger.PrintTypes.DEBUG)
    end
end

function Logger:BasicTrace(content, ...)
    if Logger:IsLogLevelEnabled(Logger.PrintTypes.TRACE) then
        Logger:BasicPrint(string.format(content, ...), Logger.PrintTypes.TRACE)
    end
end

function Logger:BasicInfo(content, ...)
    if Logger:IsLogLevelEnabled(Logger.PrintTypes.INFO) then
        Logger:BasicPrint(string.format(content, ...), Logger.PrintTypes.INFO)
    end
end

local logPath = 'log.txt'
--- Saves the log to the log.txt
function Logger:LogMessage(message)
    local fileContent = FileUtils:LoadFile(logPath) or ""
    local logMessage = GetTimestamp() .. " " .. message
    Ext.IO.SaveFile(FileUtils:BuildAbsoluteFileTargetPath(logPath), fileContent .. logMessage .. "\n")
end

--- Wipes the log file
function Logger:ClearLogFile()
    if FileUtils:LoadFile(logPath) then
        Ext.IO.SaveFile(FileUtils:BuildAbsoluteFileTargetPath(logPath), "")
    end
end
