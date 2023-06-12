----------------------------------------------------------------------------------------
-- FILE NAME:		EnUS_WoWThreads.Lua
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   25 May, 2023
----------------------------------------------------------------------------------------
local _, WoWThreads = ...
WoWThreads.Locales = {}
locales = WoWThreads.Locales

local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

locales.L = L 
local sprintf = _G.string.format
locales.ADDON_NAME = "WoWThreads"
local function getExpansionName()
	local expansionName = nil
	local expansionLevel = GetServerExpansionLevel()

	if expansionLevel == LE_EXPANSION_CLASSIC then
		expansionName = "Classic (Vanilla)"
	end
	if expansionLevel == LE_EXPANSION_WRATH_OF_THE_LICH_KING then
		expansionName = "Classic (WotLK)"
	end
	if expansionLevel == LE_EXPANSION_DRAGONFLIGHT then
		expansionName = "Dragon Flight"
	end

	if isValid == false then
		local errMsg = sprintf("Invalid Expansion Code, %d", expansionLevel )
		DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s", errMsg), 1.0, 1.0, 0.0 )
	end
	return expansionName
end

local addonName 	= locales.ADDON_NAME
local addonVersion	= GetAddOnMetadata( addonName, "Version")
local expansionName = getExpansionName()
local clockInterval	= 1/GetFramerate() * 1000
local msPerTick 	= sprintf("Clock interval: %0.01f milliseconds per tick.\n", clockInterval )

local LOCALE = GetLocale()
if LOCALE == "enUS" then

	-- WoWThreads Localizations
	L["ADDON_NAME"]				= addonName
	L["VERSION"] 				= addonVersion
	L["EXPANSION"] 				= expansionName

	L["ADDON_NAME_AND_VERSION"] = sprintf("%s %s (%s)", L["ADDON_NAME"], L["VERSION"],L["EXPANSION"])
	L["ADDON_LOADED_MESSAGE"] 	= sprintf("%s loaded", L["ADDON_NAME_AND_VERSION"] )
	L["MS_PER_TICK"] 			= sprintf("Clock interval: %0.01f milliseconds per tick\n", clockInterval )

	L["LEFTCLICK_FOR_OPTIONS_MENU"]	= "Left click for options menu."
	L["RIGHTCLICK_SHOW_COMBATLOG"]	= "Right click for fun"
	L["SHIFT_LEFTCLICK_DISMISS_COMBATLOG"] = "Some other function."
	L["SHIFT_RIGHTCLICK_ERASE_TEXT"]	= "Yet another function"

 	-- Generic Error MessageS
	L["INPUT_PARM_NIL"]		= "[ERROR] Input parameter nil "
	L["INVALID_TYPE"]		= "[ERROR] Input datatype invalid . "
	L["PARAM_ILL_FORMED"]	= "[ERROR] Input paramter improperly formed. "
	L["ENTRY_NOT_FOUND"]	= "[ERROR] Entry in thread performance table not found. "

	-- Thread specific messages
	L["THREAD_HANDLE_NIL"] 				= "[ERROR] Thread handle nil. "
	L["HANDLE_ELEMENT_IS_NIL"]			= "[ERROR] Thread handle element is nil. "
	L["HANDLE_NOT_TABLE"] 				= "[ERROR] Thread handle not a table. "
	L["HANDLE_NOT_FOUND"]				= "[ERROR] handle not found in thread control block."
	L["HANDLE_INVALID_TABLE_SIZE"] 		= "[ERROR] Thread handle size invalid. "
	L["HANDLE_COROUTINE_NIL"]			= "[ERROR] Thread coroutine in handle is nil. "
	L["INVALID_COROUTINE_TYPE"]			= "[ERROR] Thread coroutine is not a thread. "
	L["INVALID_COROUTINE_STATE"]		= "[ERROR] Unknown or invalid coroutine state. "
	L["THREAD_RESUME_FAILED"]			= "[ERROR] Thread was dead. Resumption failed. "
	L["THREAD_STATE_INVALID"]			= "[ERROR] Operation failed. Thread state does not support the operation. "

	L["SIGNAL_OUT_OF_RANGE"]			= "[ERROR] Signal is invalid (out of range) "
	L["SIGNAL_ILLEGAL_OPERATION"]		= "[WARNING] Cannot signal a completed thread. "
	L["RUNNING_THREAD_NOT_FOUND"]		= "[ERROR] Failed to retrieve running thread. "
	L["THREAD_INVALID_CONTEXT"] 		= "[ERROR] Operation requires thread context. "
	L["DEBUGGING_NOT_ENABLED"]			= "[ERROR] Debugging has not been enabled. "
	L["DATA_COLLECTION_NOT_ENABLED"]	= "[ERROR] Data collection has not been enabled. "

	L["ASSERT"]	= "ASSERT FAILED: "
end

-- local fileName = "EnUS_locales.Lua"
-- DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
