--------------------------------------------------------------------------------------
-- Timer.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 11 December, 2021 

-- REFERENCES:
-- https://www.tutorialspoint.com/lua/lua_TimerThread.htm
-- https://wow.gamepedia.com/Lua_functions

local _, WoWThreads = ...
WoWThreads.Timer = {}
timer = WoWThreads.Timer

local fileName = "Timer.lua"
local L = WoWThreads.L
local E = errors
local DEBUG = errors.DEBUG

local sprintf   = _G.string.format

----------------------- THREAD HANDLE -------------------------------
timer.TH_EXECUTABLE             = 1
timer.TH_IDENTIFIER             = 2
timer.TH_ADDRESS                = 3
timer.TH_STATUS                 = 4
timer.TH_FUNC_ARGS              = 5
timer.TH_JOIN_RESULTS           = 6
timer.TH_DELAY_TICKS_REMAINING  = 7
timer.TH_SIGNAL                 = 8
timer.TH_INITIAL_TICKS          = 9
timer.TH_YIELD_TIME             = 10
timer.TH_YIELD_COUNT            = 11
timer.TH_DURATION_TICKS         = 12
timer.TH_REMAINING_TICKS        = 13

timer.TH_NUM_ELEMENTS           = timer.TH_REMAINING_TICKS

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
timer.SIG_NONE      = 1
timer.SIG_RETURN    = 2
timer.SIG_WAKEUP    = 4

timer.SIG_LAST      = timer.SIG_WAKEUP
timer.SIG_FIRST     = timer.SIG_NONE

local SIG_NONE      = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN    = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP    = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_LAST      = timer.SIG_WAKEUP
local SIG_FIRST     = timer.SIG_FIRST

---------------------- DEFAULT LOCAL AND GLOBAL VARS ------------------------
local TIMER_IS_STARTED = false

-- The timeInterval cannot be less that the frame rate. For example,
-- a frame rate of 60 FPS is 0.01666 seconds. The timing accuracy
-- is limited by the frame rate. Also, with a frame rate of 1ms
-- or less, the soonest the callback will be called is on the
-- next frame.

local _DEFAULT_TIMER_INTERVAL   = (1/GetFramerate())

-- DEFAULT_THREAD_TICKS are 20 times the _DEFAULT_TIMER_INTERVAL.
-- In other words, 20 ticks per thread is the default yield time.
local _DEFAULT_THREAD_TICKS     = 20 
local _TERMINATE_TICKER         = false

----------------------- @@@ .toc saved variables -----------------------------------
local timerDispatchInterval           = _DEFAULT_TIMER_INTERVAL
------------------------------------------------------------------------------------

local threadSequenceNumber  = 5    -- the first 5 thread Ids are reserved
local currentThreadCount    = 0
local maxThreadCount        = 0
local totalTickCount     = 0
local threadControlBlock = {}

function timer:checkIfValid( thread_h )
    local result = {SUCCESS, nil, nil }
    local isValid = false

    if thread_h == nil then
        result = E:setResult( L["THREAD_HANDLE_NIL"], debugstack() )
        E:dbgPrint( result[2])
        return isValid, result

    elseif type(thread_h) ~= "table" then
        result = E:setResult(L["THREAD_INVALID_HANDLE_TYPE"], debugstack() )
        E:dbgPrint( result[2])
        return isValid, result

    elseif #thread_h ~= TH_NUM_ELEMENTS then
        result = E:setResult( L["THREAD_INVALID_HANDLE_SIZE"], debugstack() )
        return isValid, result

    elseif thread_h[TH_EXECUTABLE] ~= nil then
        if type( thread_h[TH_EXECUTABLE] ) ~= "thread" then
            result = E:setResult( L["THREAD_INVALID_EXE"], debugstack() )
            return isValid, result
        end
        local state = coroutine.status( thread_h[TH_EXECUTABLE] )
        if state == "dead" then
            result = E:setResult( L["THREAD_INVALID_EXE"], debugstack() )
            return isValid, result
        end
    end
    return true, result
end
function timer:getTCB()
    return threadControlBlock
end
function timer:queueThread( thread_h, signal )
    thread_h[TH_REMAINING_TICKS] = 1
end
function timer:removeThread( remove_h )

    for i, thread_h in ipairs( threadControlBlock ) do
        if thread_h[TH_IDENTIFIER] == remove_h[TH_IDENTIFIER] then
            table.remove( threadControlBlock, i )
            currentThreadCount = currentThreadCount - 1
        end
    end

end
function timer:initThreadHandle( yieldInterval, f, args )
    local durationTicks = 0
    if yieldInterval < _DEFAULT_TIMER_INTERVAL then
        durationTicks = _DEFAULT_THREAD_TICKS
    else
        durationTicks = floor( yieldInterval/timerDispatchInterval )
    end
    threadSequenceNumber = threadSequenceNumber + 1

    local thread_h = {}
    thread_h[TH_IDENTIFIER]             = threadSequenceNumber
    thread_h[TH_FUNC_ARGS]              = nil
    thread_h[TH_JOIN_RESULTS]           = nil
    thread_h[TH_SIGNAL]                = SIG_NONE
    thread_h[TH_DELAY_TICKS_REMAINING]  = durationTicks   
    thread_h[TH_INITIAL_TICKS]          = totalTickCount  
    thread_h[TH_YIELD_TIME]             = 0  
    thread_h[TH_YIELD_COUNT]            = 0
    thread_h[TH_DURATION_TICKS]         = durationTicks
    thread_h[TH_REMAINING_TICKS]        = 1        

    -- if there are parameters to be passed to the thread's function, check
    -- whether the "HANDLE" keyword is among them. If so, replace the
    -- the keyword with the newly initialized thread_h
    if args ~= nil then
        if type(args) == "table" then
            -- First, is "HANDLE" one of the parameters placed in an arg table?
            -- If so, replace "HANDLE" with this newly created handle
            local limit = #args
            for i = 1, limit do
                if args[i] == "HANDLE" then
                    args[i] = thread_h
                end
            end
        else -- it's not a table, but a single-valued function
            if type( args ) == "string" then
                if args == "HANDLE" then
                    args = thread_h
                end
            end
        end
        thread_h[TH_FUNC_ARGS] = args
    else
        thread_h[TH_FUNC_ARGS] = nil
    end

    local coRef = coroutine.create( f )
    local coRefAddrString = tostring(coRef)

    thread_h[TH_STATUS] = coroutine.status( coRef )
    thread_h[TH_EXECUTABLE] = coRef
    thread_h[TH_ADDRESS] = string.sub( tostring( coRef), 14 )
    table.insert( threadControlBlock, thread_h )

    currentThreadCount = currentThreadCount + 1
    if currentThreadCount > maxThreadCount then
        maxThreadCount = currentThreadCount
    end
    return thread_h
end
local function dispatchThreads()

    -- remove any/all dead threads before processing the
    -- threadControlBlock.
    for i, thread_h in ipairs( threadControlBlock ) do
        if thread_h[TH_STATUS] == "dead" then
            local dead_h = table.remove( threadControlBlock, i )
            currentThreadCount = currentThreadCount - 1

            -- prepare the handle for garbage collection
            -- mf:postMsg( sprintf("Reaping souls of the dearly departed - Thread %d removed.\n", dead_h[TH_IDENTIFIER]))
            -- dead_h[TH_EXECUTABLE] = nil
            -- dead_h = nil
        end
    end

    -- The dispatcher is ONLY interested in "suspended" threads.
    for _, H in ipairs( threadControlBlock ) do    
        local coExe             = H[TH_EXECUTABLE]
        H[TH_STATUS]            = coroutine.status( coExe )
        if H[TH_STATUS] == "suspended" then

            -- local threadId          = H[TH_IDENTIFIER] 
            -- local remainingTicks    = H[TH_REMAINING_TICKS]    
            -- local totalTicks        = H[TH_DURATION_TICKS]

            -- decrement the remainingTick count. If equal
            -- to 0 then the coroutine will be resumed.
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1

            if H[TH_REMAINING_TICKS] == 0 then
                -- replenish the remaining ticks counter and resume this thread.
                H[TH_REMAINING_TICKS] = H[TH_DURATION_TICKS]

                local resumed = false
                local s = nil
                local args = H[TH_FUNC_ARGS]
                if args ~= nil then
                    resumed, s = coroutine.resume( coExe, args )
                else
                    resumed, s = coroutine.resume( coExe )
                end                
                H[TH_STATUS] = coroutine.status( coExe ) 
            end
        end
    end
end
function timer:getCurrentThreadHandle()
    local running_h = nil

    local threadStr = tostring( coroutine.running())
    assert( threadStr ~= nil, L["THREAD_NOT_RUNNING"])
    local addrString = string.sub( threadStr, 14 )
    for _, running_h in ipairs( threadControlBlock ) do
        if running_h[TH_ADDRESS] == addrString then
            return running_h
        end
    end
    return running_h
end
function timer:getThreadState( thread_h )
    thread_h[TH_STATUS] = coproutine.status( thread_h[TH_EXECUTABLE] )
    return thread_h[TH_STATUS]
end
function timer:resumeThread( thread_h )
    thread_h[TH_REMAINING_TICKS] = 1
end
function timer:getYieldInterval( thread_h )
    local ticks = thread_h[TH_DURATION_TICKS]
    return timerDispatchInterval * ticks
end
function timer:setYieldInterval( thread_h, timeInterval )
    if timeInterval < (1/GetFramerate()) then
        timeInterval = (1/GetFramerate())
    end
    thread_h[TH_DURATION_TICKS] = timeInterval / timerDispatchInterval
    thread_h[TH_REMAINING_TICKS] = thread_h[TH_DURATION_TICKS]
end
function timer:getClockInterval()
    return timerDispatchInterval
end
function timer:initDispatcher()
    if TIMER_IS_STARTED == false then
        TIMER_IS_STARTED = true
        DEFAULT_CHAT_FRAME:AddMessage( L["TIMER_STARTED"], 1.0, 1.0, 0.0 )
    end

    if _TERMINATE_TICKER then 
        DEFAULT_CHAT_FRAME:AddMessage( L["TIMER_TERMINATED"], 1.0, 1.0, 0.0 )
        return 
    end
    
    dispatchThreads()

    C_Timer.After( timerDispatchInterval, 
        function()
            timer:initDispatcher() 
        end)
    totalTickCount = totalTickCount + 1
end
function timer:terminateDispatcher()
    _TERMINATE_TICKER = true
end
function timer:getThreadCountByState()
    local suspendedCount = 0
    local activeCount = 0
    for _, th in ipairs( threadControlBlock ) do
        if th[TH_STATUS] == "suspended" then
            suspendedCount = suspendedCount + 1
        end
        if th[TH_STATUS] == "running" then
            activeCount = activeCount + 1
        end
    end
    return suspendedCount, activeCount
end
function timer:getThreadCount()
    return currentThreadCount, maxThreadCount -- @@@@@@@@@@ tmp Doesn't work in ptr
end
function timer:getThreadAccumYieldTime( thread_h )
    return thread_h[TH_YIELD_TIME]
end
function timer:getTotalTickCount()
    return totalTickCount
end
function timer:yield()
    local timestamp = debugprofilestop()
    coroutine.yield()
    local yieldTime = debugprofilestop() - timestamp
    
    local h = timer:getCurrentThreadHandle()

    h[TH_YIELD_TIME]  = h[TH_YIELD_TIME] + yieldTime
    h[TH_YIELD_COUNT] = h[TH_YIELD_COUNT] + 1
end

function timer:getMetrics( thread_h )
    local threadState = coroutine.status( thread_h[TH_EXECUTABLE])
    local totalLifetime = (totalTickCount - thread_h[TH_INITIAL_TICKS]) * timerDispatchInterval
    local totalYieldTime = thread_h[TH_YIELD_TIME]
    local avgYieldInterval = (thread_h[TH_YIELD_TIME]/1000/ thread_h[TH_YIELD_COUNT]) 
    
    local avgTicksPerYield = 0
    local yieldRatio = 0
    local runRatio = 0

    if totalLifetime > 0 then
        avgTicksPerYield = avgYieldInterval / timerDispatchInterval
        yieldRatio = (totalYieldTime/1000) / totalLifetime 
        runRatio = 1 - yieldRatio
    end

    return threadState, avgYieldInterval, avgTicksPerYield, totalLifetime, yieldRatio, runRatio
end

if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
