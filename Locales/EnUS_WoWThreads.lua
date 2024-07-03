-- Filename: EnUs_WoWThreads.lua
local ADDON_NAME, _ = ...

-- Create a new library instance, or get the existing one
local LibStub = LibStub
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "EnUSlib", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local EnUSlib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not EnUSlib then 
    return 
end

local tickInterval = 1000 / GetFramerate() -- Milliseconds
local function getExpansionName( )
    local expansionLevel = GetExpansionLevel()
    local expansionNames = { -- Use a table to map expansion levels to names
        [LE_EXPANSION_DRAGONFLIGHT] = "Dragon Flight",
        [LE_EXPANSION_SHADOWLANDS] = "Shadowlands",
        [LE_EXPANSION_CATACLYSM] = "Classic (Cataclysm)",
        [LE_EXPANSION_WRATH_OF_THE_LICH_KING] = "Classic (WotLK)",
        [LE_EXPANSION_CLASSIC] = "Classic (Vanilla)",

        [LE_EXPANSION_MISTS_OF_PANDARIA] = "Classic (Mists of Pandaria",
        [LE_EXPANSION_LEGION] = "Classic (Legion)",
        [LE_EXPANSION_BATTLE_FOR_AZEROTH] = "Classic (Battle for Azeroth)",
        [10]   = "The War Within"
    }
    return expansionNames[expansionLevel] -- Directly return the mapped name
end
local version       = C_AddOns.GetAddOnMetadata( ADDON_NAME, "Version")

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

    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"] 			        = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Clock Interval: %0.3f ms", tickInterval )
    L["WOWTHREADS_OPTIONS"]         = string.format("%s Options", L["WOWTHREADS_NAME"] )     -- "WoWThreads Options"
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s Menu", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]    = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"]  )
	L["ADDON_MESSAGE"]		       = string.format("%s loaded. ", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]     = string.format("%s Error Messages.", L["WOWTHREADS_AND_VERSION"]  )

    --                      Minimap Options Menu Localizations
    L["NOTIFICATION_FRAME_TITLE"]   = string.format( "Notifications - %s ",  L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads is a library of services that enable developers"
    L["LINE2"] = "to incorporate asynchronous, non-preemptive multithreading into"
    L["LINE3"] = "their addons. You can read more about thread programming generally,"
    L["LINE4"] = "and WoWThreads specifically. See, WoWThreads-complete.md in the"
    L["LINE5"] = "Docs subdirectory."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"] = "Check to collect system overhead data."
    L["TOOTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."

    L["ENABLE_ERROR_LOGGING"]   = "Check to enable error logging."
    L["TOOLTIP_DEBUGGING"]      = "If checked, writes additional error information to the Chat Window."


    --                          Generic Error MessageS
	L["WRONG_TYPE"]		= "ERROR: Datatype unexpected "
    L["PARAMETER_NIL"]  = "ERROR: Parameter nil "

	--                          Thread-specific messages
	L["THREAD_HANDLE_NIL"] 		    = "ERROR: Thread handle nil "
    L["THREAD_HANDLE_WRONG_TYPE"]   = "ERROR: Invalid handle. Wrong type. Should be type 'table' "
	L["THREAD_NO_COROUTINE"]        = "ERROR: Handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERROR: Caller is likely the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERROR: Thread handle ill-formed. Check table size. "

	L["THREAD_COROUTINE_DEAD"]      = "ERROR: Invalid handle. Thread has completed or faulted. "
    L["THREAD_OPERATION_FAILED"]  = "ERROR: Thread not found. "

    -- Signal failure
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
