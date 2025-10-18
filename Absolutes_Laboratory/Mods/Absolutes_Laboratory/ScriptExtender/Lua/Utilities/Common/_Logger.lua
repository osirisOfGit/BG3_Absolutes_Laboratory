Ext.Require("Utilities/Advanced/_CustomEntitySerializer.lua")

-- Largely stolen from Auto_Sell_Loot - https://www.nexusmods.com/baldursgate3/mods/2435 Thx m8 (｡･∀･)ﾉﾞ

---@class Logger
Logger = {}

Logger.fileName = "log.txt"
Logger.logBuffer = {}

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

---@return Logger
function Logger:new(fileName)
    ---@type Logger
    local instance = {}

    setmetatable(instance, self)
    self.__index = self

    instance.fileName = fileName or self.fileName
    instance.logBuffer = {}

    return instance
end

local function GetTimestamp()
    local time = Ext.Timer.MonotonicTime()
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
    return not MCM and true or (MCM.Get("log_level") >= logLevel)
end

--- Function to print text with custom colors, message type, custom prefix, rainbowText, and prefix length
function Logger:BasicPrint(content, messageType, textColor, customPrefix, rainbowText, prefixLength)
    prefixLength = prefixLength or 15
    messageType = messageType or self.PrintTypes.INFO
    local textColorCode = textColor or TEXT_COLORS.cyan -- Default to cyan

    customPrefix = customPrefix or Ext.Mod.GetMod(ModuleUUID).Info.Name
    local padding = string.rep(" ", prefixLength - #customPrefix)
    local message = ConcatOutput(ConcatPrefix(customPrefix .. padding .. "  [" .. self.PrintTypes[messageType] .. "]" .. " (" .. (Ext.IsClient() and "C" or "S") .. ")", content))

    self:LogMessage(ConcatOutput("[" .. self.PrintTypes[messageType] .. "]" .. " (" .. (Ext.IsClient() and "C" or "S") .. ")", content))
    if messageType <= self.PrintTypes.INFO then
        local coloredMessage = rainbowText and GetRainbowText(message) or
            string.format("\x1b[%dm%s\x1b[0m", textColorCode, message)
        if messageType == self.PrintTypes.ERROR then
            Ext.Log.PrintError(coloredMessage)
        elseif messageType == self.PrintTypes.WARNING then
            Ext.Log.PrintWarning(coloredMessage)
        else
            Ext.Log.Print(coloredMessage)
        end
    end
end

local function stringifyTableArgs(...)
    local args = { ... }
    for i, val in ipairs(args) do
        if type(val) == "userdata" then
            if Ext.Types.GetObjectType(val) == "Entity" then
                val = val:GetAllComponents()
            else
                val = { val }
            end
            val = CustomEntitySerializer:recursiveSerialization(val, nil, {})
        end

        if type(val) == "table" then
            args[i] = Ext.Json.Stringify(val, {
                AvoidRecursion = true,
                IterateUserdata = true,
                StringifyInternalTypes = true
            })
        end
    end

    return table.unpack(args)
end

function Logger:BasicError(content, ...)
    if self:IsLogLevelEnabled(self.PrintTypes.ERROR) then
        self:BasicPrint(string.format(content, stringifyTableArgs(...)), self.PrintTypes.ERROR, TEXT_COLORS.red)
    end
end

function Logger:BasicWarning(content, ...)
    if self:IsLogLevelEnabled(self.PrintTypes.WARNING) then
        self:BasicPrint(string.format(content, stringifyTableArgs(...)), self.PrintTypes.WARNING, TEXT_COLORS.yellow)
    end
end

function Logger:BasicDebug(content, ...)
    if self:IsLogLevelEnabled(self.PrintTypes.DEBUG) then
        self:BasicPrint(string.format(content, stringifyTableArgs(...)), self.PrintTypes.DEBUG)
    end
end

function Logger:BasicTrace(content, ...)
    if self:IsLogLevelEnabled(self.PrintTypes.TRACE) then
        self:BasicPrint(string.format(content, stringifyTableArgs(...)), self.PrintTypes.TRACE)
    end
end

function Logger:BasicInfo(content, ...)
    if self:IsLogLevelEnabled(self.PrintTypes.INFO) then
        self:BasicPrint(string.format(content, stringifyTableArgs(...)), self.PrintTypes.INFO)
    end
end

local bufferLimit = 20 -- Adjust buffer size as needed

--- Flushes the buffer to the log file
function Logger:FlushLogBuffer()
    if #self.logBuffer == 0 then return end
    local fileContent = FileUtils:LoadFile(self.fileName) or ""
    local logMessages = table.concat(self.logBuffer, "\n")
    Ext.IO.SaveFile(FileUtils:BuildAbsoluteFileTargetPath(self.fileName), fileContent .. logMessages .. "\n")
    self.logBuffer = {}
end

Logger.timer = nil

--- Saves the log to the log.txt using a buffer
function Logger:LogMessage(message)
    local logMessage = GetTimestamp() .. " " .. message
    table.insert(self.logBuffer, logMessage)

    if self.timer then
        Ext.Timer.Cancel(self.timer)
        self.timer = nil
    end

    if #self.logBuffer >= bufferLimit then
        self:FlushLogBuffer()
    else
        self.timer = Ext.Timer.WaitFor(500, function()
            self:FlushLogBuffer()
            self.timer = nil
        end)
    end
end

--- Optionally, flush buffer on shutdown or at key moments
function Logger:Flush()
    self:FlushLogBuffer()
end

--- Wipes the log file
function Logger:ClearLogFile()
    if FileUtils:LoadFile(self.fileName) then
        Ext.IO.SaveFile(FileUtils:BuildAbsoluteFileTargetPath(self.fileName), "")
    end
end

Logger:ClearLogFile()
