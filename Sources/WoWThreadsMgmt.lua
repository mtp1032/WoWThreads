
--------------------------------------------------------------------------------------------
-- Filename: threadMgmt.lua
-- Date: 21 May, 2025
-- AUTHOR: Michael Peterson (scaffolded by ChatGPT)
--------------------------------------------------------------------------------------------

WoWThreads = WoWThreads or {}
WoWThreads.Mgmt = WoWThreads.Mgmt or {}

if not WoWThreads.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("WoWThreads.lua not loaded", 1, 0, 0)
    return
end

local mgmt      = WoWThreads.Mgmt
local utils     = WoWThreads.UtilsLib

local thread = LibStub("WoWThreads")
if not thread then
    print("Error: WoWThreads library not found!")
    return 
end

local SIG_GET_PAYLOAD  = thread.SIG_GET_PAYLOAD
local SIG_SEND_PAYLOAD = thread.SIG_SEND_PAYLOAD
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE
local SIG_SUCCESS      = thread.SIG_SUCCESS
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY       = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING

local morgue = WoWThreads.morgue


WoWThreads.Mgmt.loaded = true