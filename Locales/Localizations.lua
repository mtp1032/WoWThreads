-- Filename: Locales.lua
WoWThreads = WoWThreads or {}
WoWThreads.Locales = WoWThreads.Locales or {}

if not WoWThreads.Core.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "Core.lua not loaded", 1, 0, 0 )
    return
end

local core = WoWThreads.Core
local addonName, addonVersion, addonExpansion = core:getAddonInfo()
-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

WoWThreads.Locales.L = L
local LOCALE = GetLocale()
local addonName, addonVersion, addonExpansion = core:getAddonInfo()

if LOCALE == "enUS" then

    L["ADDON_LOADED_MESSAGE"] = string.format("%s v%s, %s loaded.", addonName, addonVersion, addonExpansion )

    --                      Minimap Options Menu Localizations
    -- L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    -- L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    -- L["ENABLE_DATA_COLLECTION"] = "Check to collect system overhead data."
    -- L["TOOTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."

    -- L["ENABLE_ERROR_LOGGING"]   = "Check to enable error logging."
    -- L["TOOLTIP_DEBUGGING"]      = "If checked, writes additional error information to the Chat Window."

    --                          Generic Error MessageS
	L["INVALID_TYPE"]		= "ERROR: Datatype unexpected "
    L["PARAMETER_NIL"]  	= "ERROR: Parameter nil "

	--                          Thread-specific messages
	L["THREAD_HANDLE_NIL"] 		    = "ERROR: Thread handle nil "
	L["THREAD_NO_COROUTINE"]        = "ERROR: Handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERROR: Caller is likely the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERROR: Thread handle ill-formed. Check table size. "
    L["THREAD_NOT_COMPLETED"]       = "ERROR: Thread has not yet completed. "

	L["THREAD_COROUTINE_DEAD"]      = "ERROR: Invalid handle. Thread has completed or faulted. "
    L["THREAD_NOT_FOUND"]           = "ERROR: Thread not found. "

    -- Signal failure
	L["SIGNAL_OUT_OF_RANGE"]	    = "ERROR: Signal is out of range "
    L["SIGNAL_IS_NIL"]	            = "ERROR: Signal is unknown or nil "
    L["SIGNAL_INVALID_TYPE"]        = "ERROR: Signal type is invalid. Should be 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ERROR: SIG_NONE_PENDING can not be sent "
end

WoWThreads.Locales.loaded = true