--------------------------------------------------------------------------------------
-- Threads.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
local _, WoWThreads = ...
WoWThreads.Threads = {}
thread = WoWThreads.Threads

local fileName = "Threads.lua"

local E = errors
local L = WoWThreads.L

local DEBUG = errors.DEBUG
local sprintf = _G.string.format

local SUCCESS   = errors.STATUS_SUCCESS
local FAILURE   = errors.STATUS_FAILURE

-- Indices into the thread handle table
local TH_EXECUTABLE             = timer.TH_EXECUTABLE
local TH_SEQUENCE_NUMBER             = timer.TH_SEQUENCE_NUMBER
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

local SIG_NONE      = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN    = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP    = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_LAST      = timer.SIG_WAKEUP
local SIG_FIRST     = timer.SIG_FIRST

-- -- used to error check EVERY thread handle passed as a parameter.
-- local function checkIfValid( thread_h )
--     return timer:checkIfValid( thread_h )
-- end
----------------------------------------------------------
--              CREATE THREAD
-- create a thread with a yield interval of t, and start
-- routine f.
----------------------------------------------------------
function thread:create( t, f, ... ) 
    local result = {SUCCESS, nil,nil }
    local isValid = true
    local arg = ...
    -- Check the arguments -- THESE HAVE TO BE CORRECT.
    assert( t ~= nil, L["Input duration is nil."])
    assert( type(t) == "number", L["ARG_INVALID_TYPE"])
    assert( f ~= nil, L["ARG_NIL"])
    assert( type(f) == "function", L["INVALID ARG"] )

    local thread_h = timer:initThreadHandle( t, f, arg )
    isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return nil, result 
    end

    return thread_h, result
end
----------------------------------------------------------
--              THREAD YIELD
-- suspend / yield the calling thread
----------------------------------------------------------
function thread:yield() 
    timer:yield() 
end
----------------------------------------------------------
--              THREAD SELF
-- get the calling thread's handle
----------------------------------------------------------
function thread:self()
    local thread_h = timer:getCurrentThreadHandle()
    if thread_h == nil then 
        E:setResult( L["THREAD_NOT_RUNNING"], debugstack() )
        -- assert( thread_h ~= nil, L["THREAD_NOT_RUNNING"])
        return
    end
    return thread_h
end
----------------------------------------------------------
--              THREAD JOIN
--  Used to wait for the termination of another thread.
----------------------------------------------------------
function thread:join( thread_h )
    local isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return result
    end

    local self_h = thread:self()

    local joinResults = thread_h[TH_JOIN_RESULTS]
    while( joinResults == nil ) do
        thread:yield()
        joinResults = thread_h[TH_JOIN_RESULTS]
    end
    self_h[TH_JOIN_RESULTS] = joinResults
    return joinResults
end
----------------------------------------------------------
--              THREAD EXIT
-- replaces start routine's return statement. Used in
-- conjunction with thread:join()
----------------------------------------------------------
function thread:exit( returnData )
    local thread_h = timer:getCurrentThreadHandle()
    thread_h[TH_JOIN_RESULTS] = returnData
end
----------------------------------------------------------
--              THREAD SIGNALS
----------------------------------------------------------
-- send a signal to a target thread
function thread:sendSignal( thread_h, signal )
    local isValid = true
    local result = {SUCCESS, nil, nil }

    if not sig:isValid( signal ) then
        E:setResult( L["SIGNAL_INVALD"], debugstack() )
        -- assert( sig:isValid( signal ))
    end

    isValid, result = timer:checkIfValid( thread_h )
    if IsValid == false then
        return isValid, result        
    end

    isValid, result = sig:sendSignal( thread_h, signal)
    return isValid, result
end
-- get the thead's pending signal, if any
function thread:getSignal( thread_h )
    local result = {SUCCESS, nil, nil }
    local isValid = true

    if thread_h == nil then 
        thread_h = thread:self() 
    end
    local isValid, result = timer:checkIfValid( thread_h )
    if not isValid then
        return nil, result
    end
    local signal = SIG_NONE

    local threadId = thread:getId()

    signal = thread_h[TH_SIGNAL]
    thread_h[TH_SIGNAL] = SIG_NONE
    if signal ~= 1 then
    end
    return signal, result
end
---------------------------------------------------------
--            SOME USEFUL UTILITIES
---------------------------------------------------------
-- get the name of the signal, e.g., SIG_WAKEUP
function thread:getSignalName( signal )
    return sig:getSigName( signal )
end
-- delay the calling thread
function thread:delay( seconds )
    local self_h = thread:self()
    local originalDuration = self_h[TH_DURATION_TICKS]
    local timerDispatchInterval = mgmt:getClockInterval()
    local sleepTicks = floor( seconds/timerDispatchInterval )
    self_h[TH_DURATION_TICKS] = sleepTicks
    self_h[TH_REMAINING_TICKS] = sleepTicks
    thread:yield()
    self_h[TH_DURATION_TICKS] = originalDuration
    self_h[TH_REMAINING_TICKS] = 1
end
-- get the thread's unique identifier
function thread:getId( thread_h ) 

    if thread_h == nil then
        thread_h = timer:getCurrentThreadHandle()
    end
    return thread_h[TH_SEQUENCE_NUMBER]
end
function thread:getYieldInterval( thread_h )
    local isValid = true
    local result = {SUCCESS, nil, nil }
    if thread_h == nil then
        thread_h = timer:getCurrentThreadHandle()
    end

    isValid, result = timer:checkIfValid(thread_h )
    if not isValid then
        return result
    end

    return thread_h[TH_DURATION_TICKS]
end
function thread:exists( thread_h )
    local isValid = false
    if thread_h == nil then
        thread_h = timer:getCurrentThreadHandle()
    end
    local isValid, result = timer:checkIfValid( thread_h )
    return isValid
end

if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
