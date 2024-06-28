-- Filename: EnUs_WoWThreads.lua
local ADDON_NAME, _ = ...

-- get the uitls library
local UtilsLib = LibStub("UtilsLib")
if not UtilsLib then 
    return 
end
local utils = UtilsLib

-- Create a new library instance, or get the existing one
local LibStub = LibStub
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "EnUSlib", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local EnUSlib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not EnUSlib then 
    return 
end

local tickInterval = 1000 / GetFramerate() -- Milliseconds
-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

EnUSlib.L = L
local LOCALE = GetLocale()
if LOCALE == "enUS" then
    -- localizations
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"] 			        = utils:getVersion()
    L["EXPANSION_NAME"]             = utils:getExpansionName()
    L["TICK_INTERVAL"]              = string.format("Clock Interval: %0.3f ms", tickInterval )
    L["WOWTHREADS_OPTIONS"]         = string.format("%s Options", L["WOWTHREADS_NAME"] )     -- "WoWThreads Options"
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s Menu", L["WOWTHREADS_OPTIONS"])

    L["LINE1"] = "    WoWThreads is a library of services that enable developers"
    L["LINE2"] = "to incorporate asynchronous, non-preemptive multithreading into"
    L["LINE3"] = "their addons. You can read more about thread programming generally"
    L["LINE4"] = "and WoWThreads specifically in the Docs directory, specifically"
    L["LINE5"] = "WoWThreads-complete.md."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"] = "Check to collect system overhead data."
    L["TOOTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."
    L["TOOLTIP_DEBUGGING"]      = "If checked, writes addition error information to the Chat Window."

	-- WoWThreads Localizations
    L["WOWTHREADS_AND_VERSION"]    = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"]  )
	L["ADDON_MESSAGE"]		        = string.format("%s loaded. ", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s Error Messages.", L["WOWTHREADS_AND_VERSION"]  )

    -- Generic Error MessageS
	L["INVALID_TYPE"]		= "ERROR: Input parameter datatype invalid "
    L["INPUT_PARM_NIL"]     = "ERROR: Input parameter nil "

	-- Thread specific messages
	L["THREAD_HANDLE_NIL"] 		= "ERROR: Thread handle nil "
    L["THREAD_HANDLE_INVALID"]  = "ERROR: Invalid handle "
	L["THREAD_INVALID_TYPE"]           = "ERROR: Specified Thread handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"] = "ERROR: Caller is likely the WoW client (WoW.exe) "
    L["HANDLE_NOT_SPECIFIED"]   = "ERROR: Handle not specified "
    L["THREAD_CREATE_FAILED"]   = "ERROR: Failed to create thread "
    L["HANDLE_NON_EXISTANT"]    = "ERROR: Failed: Handle does not exist. "
	L["HANDLE_ILL_FORMED"]	    = "ERROR: Thread handle ill-formed "

	L["THREAD_IS_DEAD"]	        = "ERROR: Invalid handle. Thread has completed or faulted. "
    L["THREAD_NOT_FOUND"]       = "ERROR: Thread not found. "
    L["THREAD_SLEEP_FAILED"]    = "ERROR: Attempt to put thread to sleep failed. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "ERROR: Signal is out of range "
    L["SIGNAL_INVALID"]			    = "ERROR: Signal is unknown or nil "
    L["SIGNAL_INVALID_OPERATION"]   = "ERROR: SIG_NONE_PENDING can not be sent "
end
if LOCALE == "frFR" then
end
if LOCALE == "deDE" then
end
if LOCALE == "zhCN" then
end
if LOCALE == "koKR" then
end
if LOCALE == "svSE" then
end
if LOCALE == "heIL" then
end
if LOCALE == "esES" then
end

local fileName = "EnUS_WoWThreads.lua" 
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end
