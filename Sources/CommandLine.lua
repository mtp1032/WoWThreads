--------------------------------------------------------------------------------------
-- FILE NAME:       CommandLine.lua 
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   9 March, 2021
local _, WoWThreads = ...
WoWThreads.CommandLine = {}
cmd = WoWThreads.CommandLine
local sprintf = _G.string.format
local fileName = "CommandLine.lua"

local L = WoWThreads.L
local T = timer
local E = errors


local DEBUG = errors.DEBUG
local DEBUG = true

local SIG_NONE          = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN        = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP        = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_NUMBER_OF      = timer.SIG_WAKEUP

local SUCCESS   = errors.STATUS_SUCCESS
local FAILURE   = errors.STATUS_FAILURE

SLASH_TALON_MGMT_COMMANDS1 = "/talon"
SLASH_TALON_MGMT_COMMANDS2 = "/mgr"
SlashCmdList["TALON_MGMT_COMMANDS"] = function( msg )
    local result = {SUCCESS, nil, nil }
    local thread_h = nil

    if msg == nil then
        local prefix = E:prefix()
        local errorMsg = sprintf("%s Invalid command", prefix )
        result = {FAILURE, errorMsg }
        mf:postResult( result )
        return
    end
    if msg == "" then
        local prefix = E:prefix()
        local errorMsg = sprintf("%s Invalid command", prefix )
        result = {FAILURE, errorMsg }
        mf:postResult( result )
        return
    end

    local msg = strupper( msg )

    if msg == "DEBUGOFF" or msg == "OFF" then
        E:cancelDebug()
        mf:postMsg("\nDEBUG turned off!\n")
        return
    end
    if msg == "DEBUGON" or msg == "ON" then
        E:setDebug()
        mf:postMsg("\nDEBUG turned on!\n")
        return
    end

    if msg == "TOTALS" then
        local current, max = timer:mgmt_getThreadCount()
        local suspended, running = timer:mgmt_getCountByThreadState()
        local s = sprintf("\n[MGMT] Thread Counts: Current %d, Max %d, Suspended %d.\n",
                                current, max, suspended )
        mf:postMsg( s )
    end

    if msg == "STATS" then
        mf:postMsg( "Not Yet Implemented.\n" )
    end

    return
end

if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
