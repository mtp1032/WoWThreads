----------------------------------------------------------------------------------------
-- enUS.lua
-- AUTHOR: mtpeterson1948 at gmail dot com
-- ORIGINAL DATE: 9 March, 2021
----------------------------------------------------------------------------------------
local _, WoWThreads = ...
WoWThreads.enUS = {}
local L = setmetatable({}, { __index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })
lang = WoWThreads.enUS

WoWThreads.L = L 
local sprintf = _G.string.format

-- English translations
local LOCALE = GetLocale()      -- BLIZZ
if LOCALE == "enUS" then
	L["ADDON_NAME"]					= "WoW Thread Library"
	L["VERSION"]					= "Alpha Release V 0.1 (ShadowLands)"
	L["ADDON_AND_VERSION"] 			= sprintf("%s - %s", L["ADDON_NAME"], L["VERSION"] )
	L["LOADED"]						= "loaded"
	L["ADDON_LOADED_MESSAGE"] 		= sprintf("%s %s - %s", L["ADDON_NAME"], L["LOADED"], L["VERSION"] )
	L["TIMER_STARTED"]				= "[INFO] Thread dispatcher and startup threads started."
	L["TIMER_TERMINATED"]			= "[INFO] Thread dispatcher terminated."
	L["STARTUP_MESSAGE"]			= "[INFO] Startup threads started."

	L["DESCR_SUBHEADER"] = "A Multithread Library for World of Warcraft Addon Development"
	-- Generic Error Message

	L["ARG_NIL"]				= "[ERROR] Parameter nil "
	L["ARG_MISSING"]			= "[ERROR] Parameter missing "
	L["ARG_INVALID_VALUE"]		= "[ERROR] Unexpected parameter or parameter value not in range "
	L["ARG_INVALID_TYPE"]		= "[ERROR] Parameter type invalid . "
	L["INVALID_THREAD_HANDLE"]	= "[ERROR] Thread handle not valid. "
	L["UNEQUAL_VALUES"]			= "[ERROR] Unequal Values "
	L["INCONSISTENT_STATE"]		= "[ERROR] State is inconsistent."
	L["ILL_FORMED"]				= "[ERROR] Ill-formed. "
	L["INVALID_OP"]				= "[ERROR] Invalid or Unsupported Operation. "
	L["INVALID_COMMAND"]		= "[ERROR] Invalid or Unsupported Command. "
	L["NON_EXISTENT"]			= "[ERROR] Object no longer exists. "

	L["THREAD_HANDLE_NIL"] 			= "[ERROR] Thread Handle nil. "
	L["FUNCTION_ARG_NIL"]			= "[ERROR] Function Parameter in thread:create() nil "

	L["THREAD_INVALID_HANDLE_TYPE"] = "[ERROR] Thread Handle not a table. "
	L["THREAD_INVALID_HANDLE_SIZE"] = "[ERROR] Thread Handle size invalid. "
	L["THREAD_INVALID_EXE"]			= "[ERROR] Thread executable invalid. "
	L["THREAD_NOT_RUNNING"]			= "[ERROR] Caller is not a running thread. "

	L["SIGNAL_INVALID"]				= "[ERROR] Signal is invalid or unknown. "
	
end
