--------------------------------------------------------------------------------------
-- FILE NAME:       Manager.lua 
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   25 May, 2023
local _, WoWThreads = ...
WoWThreads.Manager = {}
mgr = WoWThreads.Manager

local L = locales.L

local sprintf = _G.string.format
local EMPTY_STR = core.EMPTY_STR
local SUCCESS   = core.SUCCESS
local FAILURE   = core.FAILURE

local SIG_ALERT             = dispatch.SIG_ALERT          -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_JOIN_DATA_READY   = dispatch.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = dispatch.SIG_TERMINATE
local SIG_METRICS           = dispatch.SIG_METRICS
local SIG_NONE_PENDING      = dispatch.SIG_NONE_PENDING    -- default value. Means the handle's signal queue is empty

-- DESCRIPTION: Returns congestion metrics for the specified thread
-- RETURNS: a metrics entry, remainingEntries, result
-- NOTE 1: if the metrics entry is nil and the results table show SUCCESS
--         then the graveyard (of completed threads) was empty.
-- NOTE 2: if debugging is not enabled, an error value is returned.
-- NOTE 3: entry = { threadId, ticksPerYield, yieldCount, timeSuspended, lifetime }
function mgr:getCongestionEntry( H )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local count = 0
    local entry = nil
    if H == nil then
        result = core:setResult(L["THREAD_HANDLE_NIL"], debugstack(2) )
        return nil, count, result
    end  
    if not core:dataCollectionIsEnabled() then
        result = core:setResult( L["DATA_COLLECTION_NOT_ENABLED"], debugstack(1) )
        return nil, count, result
    end
    result = dispatch:checkIfHandleValid( H )
    if not result[1] then return result end

    local entry, count, result = dispatch:getThreadMetrics(H)
    if not result[1] then return nil, remainingEntries, result end
    return entry, count, result
end
local WoWThreadsStarted = false
function mgr:WoWThreadLibInit()
    if not WoWThreadsStarted then 
        local clockInterval = (1/GetFramerate())
        dispatch:startTimer( clockInterval )
        WoWThreadsStarted = true
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent( self, event, ... )
    local addonName = ...

    if event == "ADDON_LOADED" and addonName == locales.ADDON_NAME then
        
		mgr:WoWThreadLibInit()

        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_LOADED_MESSAGE"], 0.0, 1.0, 1.0 )
        DEFAULT_CHAT_FRAME:AddMessage( L["MS_PER_TICK"], 0.0, 1.0, 1.0 )
        eventFrame:UnregisterEvent("ADDON_LOADED")  
    end
    return
end
eventFrame:SetScript( "OnEvent", OnEvent )

local fileName = "Manager.lua"
if core:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
