---------------------------------------------------------------
-- Filename: UtilsLib.lua
-- Author: Michael Peterson
-- Date: October, 2026
---------------------------------------------------------------

local UtilsLib = {}

--======================================================================
--                          DEBUG UTILITIES
--======================================================================

function UtilsLib.simplifyStackTrace(stackTrace)
    local addonName = string.match(stackTrace, "AddOns/([^/]+)")
    local subDirs = string.match(stackTrace, "AddOns/[^/]+/(.-)/[^/]+%.lua")
    local fileName = string.match(stackTrace, "/([^/]+%.lua)")
    local lineNumber = string.match(stackTrace, ":(%d+):")

    if not addonName or not fileName or not lineNumber then
        return stackTrace
    end

    if subDirs then
        return string.format("%s/%s/%s:%s", addonName, subDirs, fileName, lineNumber)
    else
        return string.format("%s/%s:%s", addonName, fileName, lineNumber)
    end
end

local DEBUG_ENABLED = true

function UtilsLib.isDebuggingEnabled()
    return DEBUG_ENABLED
end

function UtilsLib.enableDebugging()
    DEBUG_ENABLED = true
end

function UtilsLib.disableDebugging()
    DEBUG_ENABLED = false
end

function UtilsLib.dbgPrefix(stackTrace)
    stackTrace = stackTrace or debugstack(2)

    local fileName, lineNumber = stackTrace:match("[\\/]([^\\/:]+):(%d+)")
    if not fileName or not lineNumber then
        return "[Unknown:0] "
    end

    return string.format("[%s:%d] ", fileName, tonumber(lineNumber))
end

function UtilsLib.dbgPrint(...)
    local prefix = UtilsLib.dbgPrefix(debugstack(2))

    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end

    prefix = string.format("|cffff9900%s|r", prefix)
    local output = prefix .. table.concat(args, " ")

    print(output)
end

return UtilsLib
