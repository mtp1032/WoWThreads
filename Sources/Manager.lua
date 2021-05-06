--------------------------------------------------------------------------------------
-- Manager.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 11 December, 2021 

-- REFERENCES:
-- https://www.tutorialspoint.com/lua/lua_TimerThread.htm
-- https://wow.gamepedia.com/Lua_functions

local _, WoWThreads = ...
WoWThreads.Manager = {}
mgmt = WoWThreads.Manager

local fileName = "Manager.lua"
local L = WoWThreads.L
local E = errors
local DEBUG = errors.DEBUG

local sprintf   = _G.string.format

----------------------- THREAD HANDLE -------------------------------
-- Indices into the thread handle table
local TH_EXECUTABLE             = timer.TH_EXECUTABLE
local TH_IDENTIFIER             = timer.TH_IDENTIFIER
local TH_ADDRESS                = timer.TH_ADDRESS
local TH_STATUS                 = timer.TH_STATUS
local TH_FUNC_ARGS              = timer.TH_FUNC_ARGS
local TH_JOIN_RESULTS           = timer.TH_JOIN_RESULTS
local TH_DELAY_TICKS_REMAINING  = timer.TH_DELAY_TICKS_REMAINING
local TH_SIGNAL                 = timer.TH_SIGNAL
local TH_INITIAL_TICKS          = timer.TH_INITIAL_TICKS
local TH_YIELD_TIME             = timer.TH_YIELD_TIME
local TH_YIELD_COUNT            = timer.TH_YIELD_COUNT
local TH_DURATION_TICKS         = timer.TH_DURATION_TICKS
local TH_REMAINING_TICKS        = timer.TH_REMAINING_TICKS

local TH_NUM_ELEMENTS           = timer.TH_NUM_ELEMENTS


-- In all cases receipt of one of these signals queues the receiving thread
-- for immediate resumption (on the next tick)

local SIG_NONE      = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN    = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP    = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_LAST      = timer.SIG_WAKEUP
local SIG_FIRST     = timer.SIG_FIRST

-- ***********************************************************************
--                  PUBLIC MANAGEMENT SERVICES
-- ***********************************************************************
function mgmt:initWoWThreads()
    timer:initDispatcher()
end
function mgmt:getYieldInterval( thread_h )
    local result = {SUCCESS, nil, nil }
    local isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return nil, result
    end

    local ticks = thread_h[TH_DURATION_TICKS]
    tdinterval = timer:getClockInterval()
    return tdinterval * ticks, result
end
function mgmt:setYieldInterval( thread_h, timeInterval )
    local isValid = true
    local result = {SUCCESS, nil, nil }

    local isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return isValid, result
    end

    local timerDispatchInterval = timer:getClockInterval()
    thread_h[TH_DURATION_TICKS] = timeInterval / timerDispatchInterval
    thread_h[TH_REMAINING_TICKS] = thread_h[TH_DURATION_TICKS]
    return isValid, result
end
function mgmt:getClockInterval()
    return timer:getClockInterval()
end
function mgmt:getThreadCountByState()

    local tcb = timer:getTCB()

    local suspendedCount = 0
    local activeCount = 0
    local deadCount = 0
    local normalCount = 0
    local totalCount = 0

    for _, th in ipairs( tcb ) do
        local state = coroutine.status( th[TH_EXECUTABLE])
        if state == "suspended" then
            suspendedCount = suspendedCount + 1
            totalCount = totalCount + 1
        end
        if state == "running" then
            activeCount = activeCount + 1
            totalCount = totalCount + 1
        end
        if state == "dead" then 
            deadCount = deadCount + 1
            totalCount = totalCount + 1
        end
        if state == "normal" then
            normalCount = normalCount + 1
            totalCount = totalCount + 1
        end
    end
    return totalThreads, suspendedCount, activeCount, deadCount, normalCount
end
function mgmt:getMetrics( thread_h )
    local result = {SUCCESS, nil, nil }
    local isValid = true

    isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return nil, result
    end
    local metrics = {timer:getMetrics( thread_h)}
    return metrics, result
end

--------------------- SLASH COMMANDS ----------------------
if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
