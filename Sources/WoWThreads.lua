--=================================================================================
-- Filename: WoWThreads.lua
-- Date: 9 March, 2021
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
--=================================================================================
local ADDON_NAME, _ = ...

--                      ADMIN, HOUSEKEEPING STUFF
WoWThreads = WoWThreads or {}
_G.WoWThreads = WoWThreads


-- Import the utility, signal, and localization libraries.
local UtilsLib = LibStub("UtilsLib")
if not UtilsLib then return end
local utils = UtilsLib

local EnUSlib = LibStub("EnUSlib")
if not EnUSlib then return end
local L = EnUSlib.L

-- Configure WoWThreads as a LibStub managed library
local MAJOR = tonumber(C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MAJOR"))
local MINOR = tonumber(C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MINOR"))
local PATCH = tonumber(C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-PATCH"))

if not (MAJOR and MINOR and PATCH) then
    error("Failed to retrieve version information from the .toc file.")
end
-- Combine version components into a single github-style version number
local versionNumber = MAJOR * 10000 + MINOR * 100 + PATCH

-- Register the library with LibStub using the combined version number
local thread, oldVersion = LibStub:NewLibrary("WoWThreads", versionNumber)
if not thread then return end  -- no upgrade needed

local sig = WoWThreads.SignalQueue
--                                  LOCAL DATA
local DEBUGGING_ENABLED = false
local DATA_COLLECTION = false
local DEFAULT_YIELD_TICKS    = 1
local THREAD_SEQUENCE_ID     = 4 -- a number representing the order in which the thread was created
local ACCUMULATED_TICKS      = 0 -- The system-wide, total number of clock ticks

local threadControlBlock     = {} -- Table to hold all running and suspended threads
local threadSleepTable       = {} -- Table to hold sleeping threads
local morgue                 = {} -- Table to hold the dead threads

local CLOCK_INTERVAL         = 1/GetFramerate()
local WoWThreadsStarted      = false
-- =====================================================================
--                      NUMERIC CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_UNIQUE_ID          = 2 -- a number representing the order in which the thread was created
local TH_SIGNAL_QUEUE       = 3 -- a table of all currently pending signals
local TH_YIELD_TICKS        = 4 -- the number of clock ticks for which a thread must suspend after a yield.
local TH_REMAINING_TICKS    = 5 -- decremented on every clock tick. When 0 the thread is queued.
local TH_ACCUM_YIELD_TICKS  = 6 -- The total number of yield ticks for which the thread is suspended.
local TH_LIFETIME_TICKS     = 7
local TH_RESUMPTIONS        = 8 -- the number of times a thread yields
local TH_CHILDREN           = 9
local TH_PARENT_HANDLE      = 10
local TH_CLIENT_ADDON       = 11
local TH_COROUTINE_ARGS     = 12
local TH_NUM_HANDLE_ELEMENTS    = TH_COROUTINE_ARGS

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data. 
-- Example: sigTable = {signalValue, sender_h, ... }
--
-- These constants are the signal values found in sigTable[1]
thread.SIG_GET_DATA     = 1 -- no semantics. Used to execute an immediate normal return.
thread.SIG_SEND_DATA    = 2 -- no semantics. Used to execute an immediate normal return.
thread.SIG_BEGIN        = 3 -- no semantics.
thread.SIG_HALT         = 4 -- no semantics.
thread.SIG_IS_COMPLETE  = 5 -- info: thread is complete
thread.SIG_SUCCESS      = 6 -- info: thread completed successfully
thread.SIG_FAILURE      = 7 -- info: thread completed with failure
thread.SIG_READY        = 8
thread.SIG_CALLBACK     = 9 -- info: Signal entry contains a callback function in Sig[3]
thread.SIG_THREAD_DEAD  = 10 -- info: thread has completed or failed.
thread.SIG_ALERT        = 11 -- schedule for immediate execution
thread.SIG_WAKEUP       = 12 -- unused. Intended for thread pools.
thread.SIG_TERMINATE    = 13 -- deletes the thread. Does not return from yield.
thread.SIG_NONE_PENDING = 14 -- signal queue is empty.

local SIG_GET_DATA     = thread.SIG_GET_DATA -- no semantics.
local SIG_SEND_DATA    = thread.SIG_SEND_DATA -- no semantics.
local SIG_BEGIN        = thread.SIG_BEGIN -- no semantics.
local SIG_HALT         = thread.SIG_HALT -- no semantics.
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE -- no semantics
local SIG_SUCCESS      = thread.SIG_SUCCESS -- no semantics
local SIG_FAILURE      = thread.SIG_FAILURE -- no semantics
local SIG_READY        = thread.SIG_READY -- no semantics
local SIG_CALLBACK     = thread.SIG_CALLBACK -- info: Signal entry contains a callback function in Sig[3]
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD -- info: thread has completed or failed.
local SIG_ALERT        = thread.SIG_ALERT -- schedule for immediate execution
local SIG_WAKEUP       = thread.SIG_WAKEUP -- wakeup a sleeping thread for execution
local SIG_TERMINATE    = thread.SIG_TERMINATE -- info: use to ask a thread to terminate.
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING -- info: signal queue is empty.

local signalNameTable = {
    "SIG_GET_DATA",
    "SIG_SEND_DATA",
    "SIG_BEGIN",
    "SIG_HALT",
    "SIG_IS_COMPLETE",
    "SIG_SUCCESS",
    "SIG_FAILURE",
    "SIG_READY",
    "SIG_CALLBACK",
    "SIG_THREAD_DEAD",
    "SIG_ALERT",
    "SIG_WAKEUP",
    "SIG_TERMINATE",
    "SIG_NONE_PENDING"
}

--                          LOCAL FUNCTIONS 

function thread:debuggingIsEnabled()
    return DEBUGGING_ENABLED
end
function thread:enableDebugging()
    DEBUGGING_ENABLED = true
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Debugging %s", tostring(DEBUGGING_ENABLED)),0.0, 1.0, 1.0 )
end
function thread:disableDebugging()
    DEBUGGING_ENABLED = false
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Debugging %s", tostring(DEBUGGING_ENABLED)),0.0, 1.0, 1.0 )
end
function thread:dataCollectionIsEnabled()
    return DATA_COLLECTION
end
function thread:enableDataCollection()
    DATA_COLLECTION = true
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Data collection %s", tostring(DATA_COLLECTION)),0.0, 1.0, 1.0 )
end
function thread:disableDataCollection()
    DATA_COLLECTION = false
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Data collection %s", tostring(DATA_COLLECTION)),0.0, 1.0, 1.0 )
end


-- this function is used to extract a useful stack trace from an error encountered
-- during the coroutine's function (aka, the thread's function.)
local function transformErrorString(errorString)
    utils:postMsg( errorString )

    -- Pattern to match the error string and capture the filename, line number, and error message
    local pattern = "Interface/AddOns/[^/]+/(.+):(%d+): (.+)"
    
    -- Use string.match to capture the required parts
    local filePath, lineNumber, errorMessage = string.match(errorString, pattern)
    
    -- Extract the filename from the full file path
    local fileName = string.match(filePath, "([^/]+)$")
    
    -- Format the result
    local errorMsg = string.format("[%s:%s]: %s", fileName, lineNumber, errorMessage)
    
    return errorMsg
end 
local function dbgLog( msg ) -- use debugstack(2)
    local newMsg = string.format("[LOG] %s \n", msg )
    DEFAULT_CHAT_FRAME:AddMessage( newMsg, 0.0, 1.0, 1.0 )
end

local function setResult( errorMsg, fname, stackTrace )
    local result = nil

    local st = utils:simplifyStackTrace( stackTrace )
    errorMsg = string.format("%s occurred in %s. ", errorMsg, fname )
    result = {errorMsg, st }
    if thread:debuggingIsEnabled() then 
        local resultStr = string.format("%s %s\n%s\n", utils:dbgPrefix(), errorMsg, st )
        dbgLog( resultStr )
    end
    return result
end
local function coroutineIsDead(H)
    local dead = false

    local status = coroutine.status( H[TH_COROUTINE])
    if status == "dead" then
        dead = true
    end
    return dead
end
local function handleIsInMorgue( H )
    local inMorgue = false
    if #morgue == 0 then return false end

    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            inMorgue = true
            return inMorgue
        end
    end
    return inMorgue
end
local function wakeupThread(H)
    local isInTable = false

    if #threadSleepTable == 0 then 
        return isInTable
    end

    for i, entry in ipairs(threadSleepTable) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            table.remove( threadSleepTable, i )
            table.insert( threadControlBlock, H )
            if thread:debuggingIsEnabled() then 
                local resultStr = string.format("%s Moved thread[%d] from sleep to TCB.", utils:dbgPrefix(), H[TH_UNIQUE_ID])
                dbgLog( resultStr )
            end
        
            H[TH_REMAINING_TICKS] = 1
            isInTable = true
            return isInTable
        end
    end
    return isInTable
end
local function getHandleOfCallingThread()
    local state = nil
    local H = nil

    for i = 1, #threadControlBlock do
        H = threadControlBlock[i]
        local co = H[TH_COROUTINE] 
        local state = coroutine.status( co )       
        if state == "running" then
            return H, nil
        end
    end

    return nil, L["THREAD_INVALID_CONTEXT"]
end
local function createHandle( addonName, parent_h, yieldTicks, threadFunction, ...)

    if yieldTicks < DEFAULT_YIELD_TICKS then
        yieldTicks = DEFAULT_YIELD_TICKS
    end

    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1
    local H = {
        [TH_COROUTINE] = coroutine.create(threadFunction),
        [TH_UNIQUE_ID]          = THREAD_SEQUENCE_ID,
        [TH_SIGNAL_QUEUE]       = sig.new(),
        [TH_YIELD_TICKS]        = yieldTicks,
        [TH_REMAINING_TICKS]    = 1,
        [TH_ACCUM_YIELD_TICKS]  = 0,
        [TH_LIFETIME_TICKS]     = ACCUMULATED_TICKS,
        [TH_RESUMPTIONS]        = 0,
        [TH_CHILDREN]           = {},
        [TH_PARENT_HANDLE]      = parent_h,
        [TH_CLIENT_ADDON]       = addonName,
        [TH_COROUTINE_ARGS]     = {...}
    }
    if parent_h ~= nil then
        table.insert( parent_h[TH_CHILDREN], H)
    end

    return H
end

-- returns true if successful, false otherwise + errorMsg
local function moveToMorgue( H, normalCompletion )
    H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]

    for i, handle in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == handle[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( morgue, H)

            if thread:debuggingIsEnabled() then
                local msg = nil
                if normalCompletion == false then
                    msg = string.format("%s *** ABNORMAL *** termination. Moved thread[%d] from TCB to morgue", utils:dbgPrefix(), H[TH_UNIQUE_ID])
                else
                    msg = string.format("%s Normal termination. Moved thread[%d] from TCB to morgue",utils:dbgPrefix(),  H[TH_UNIQUE_ID])
                end
                dbgLog( msg )
            end
            break
        end
    end
end
-- returns true if successful, false otherwise + errorMsg
local function moveToSleepTable( H )
    local errorMsg = nil
    local successful = false

    -- Remove thread from TCB and insert it into the sleep table
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( threadSleepTable, H )
            successful = true
            if thread:debuggingIsEnabled() then
                local msg = string.format("%s Thread[%d] removed from TCB, inserted into sleep table.\n", utils:dbgPrefix(), H[TH_UNIQUE_ID])
                dbgLog( msg )
            end
            return successful, nil
        end
    end

    if not successful then
        errorMsg = L["THREAD_NOT_FOUND"]
        if thread:debuggingIsEnabled() then
            local msg = string.format("%s Thread[%d] not found in TCB.\n", utils:dbgPrefix(), H[TH_UNIQUE_ID])
            dbgLog( msg )
        end
    end
        
    return successful, errorMsg
end

local function handleIsValid(H)
    local isValid = true
    local errorMsg = nil

    if type(H) ~= "table" then
        errorMsg =L["THREAD_HANDLE_WRONG_TYPE"]
        isValid = false
        return isValid, errorMsg
    end
    if #H ~= TH_NUM_HANDLE_ELEMENTS then
        errorMsg = L["THREAD_TABLE_ILL_FORMED"]
        isValid = false
        return isValid, errorMsg
    end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        errorMsg = L["WRONG_TYPE"]
        isValid = false
        return isValid, errorMsg
    end
    if type(H[TH_COROUTINE]) ~= "thread" then
        errorMsg = L["THREAD_NO_COROUTINE"]
        isValid = false
        return isValid, errorMsg
    end

    return isValid, errorMsg
end
local function signalInRange(signal)
    local isValid = true
    local errorMsg = nil

    if signal < SIG_GET_DATA then
        isValid = false
        errorMsg = L["SIGNAL_OUT_OF_RANGE"]
    end
    if signal > SIG_NONE_PENDING then
        isValid = false
        errorMsg = L["SIGNAL_OUT_OF_RANGE"]
    end

    return isValid, errorMsg
end
local function signalIsValid(signal)
    local isValid = true
    local errorMsg = nil

    if signal == nil or signal == "" then
        isValid = false
        errorMsg = L["SIGNAL_IS_NIL"]
        return isValid, errorMsg
    end

    if type(signal) ~= "number" then 
        isValid = false
        errorMsg = L["SIGNAL_INVALID_TYPE"]
        return isValid, errorMsg
    end  

    isValid, errorMsg = signalInRange( signal )
    if not isValid then
        return isValid, errorMsg
    end
    return isValid, errorMsg
end
local function scheduleThreads()
    local result = nil

    local fname = "scheduleThreads()"
    ACCUMULATED_TICKS = ACCUMULATED_TICKS + 1
    if #threadControlBlock == 0 then
        return
    end

    for i, H in ipairs(threadControlBlock) do
        local status = coroutine.status( H[TH_COROUTINE] )
        if status == "dead" then -- move it into the morgue
            moveToMorgue(H, true )
            return
        end
        
        if status == "suspended" then
            local args = H[TH_COROUTINE_ARGS]
            local errorMsg = nil
            local coroutineResumed = false
            local pcallSucceeded = false

            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            
            if H[TH_REMAINING_TICKS] == 0 then -- resume this thread
                local result = nil
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS] -- replenish the remaining ticks
                local co = H[TH_COROUTINE]
                pcallSucceeded, coroutineResumed, errorMsg = pcall(coroutine.resume, co, unpack(args) )
                if not pcallSucceeded then
                    moveToMorgue(H, false )
                    if thread:debuggingIsEnabled() then
                        errorMsg = string.format("%s %s", utils:dbgPrefix(), transformErrorString( errorMsg ))
                        utils:postMsg( errorMsg )
                        dbgLog( errorMsg )
                    end
                end

                if not coroutineResumed then

                    if thread:debuggingIsEnabled() then
                        errorMsg = string.format("%s %s", utils:dbgPrefix(), transformErrorString( errorMsg ))
                        utils:postMsg( string.format("\n    %s\n", errorMsg))
                        dbgLog( errorMsg )
                    end
                    moveToMorgue(H, false )
                end
            end
        end
    end
end
 local function startTimer(CLOCK_INTERVAL)
        scheduleThreads()

    C_Timer.After(
        CLOCK_INTERVAL,
        function()
            startTimer(CLOCK_INTERVAL)
        end
    )
end
local function WoWThreadLibInit( addonName )
    if not WoWThreadsStarted then
        startTimer( 1/GetFramerate() )
    end
    WoWThreadsStarted = true
end
local function extractAddonName(stacktrace)
    local addonName = string.match(stacktrace, "AddOns/([^/]+)/")
    
    -- Return the captured addon name or nil if not found
    return addonName
end
--                      PUBLIC (EXPORTED) SERVICES

--[[@Begin 
Signature: thread_h, result = thread:create( yieldTicks, func [,...] )
Description: Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.
Parameters:
- yieldTicks (number). The duration of time the calling thread is to
be suspended. The time is specified in clock ticks.In WoW, a clock tick 
is the reciprocal of your system's frame rate. On my system, a clock tick 
is about 16.7 milliseconds (1/60). Therefore, 60 ticks is about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs, optional), Additional arguments to be passed to the thread function.
Returns:
- Success: a valid thread handle is returned and the result is set to nil.
- Failure: nil is returned and the result parameter specifies an error message (result[1])
and a stack trace (result[2]).
Usage:
    local function greetings( greetingString )
        print( greetingString )
    end
    local thread_h, result = thread:create( 60, greetings, "Hello World" )
    if not thread_h then 
        print( result[1], result[2]) 
        return 
    end
@End]]
function thread:create( yieldTicks, threadFunction,... )
    local fname = "thread:create()"
    local errorMsg = nil
    local parent_h = nil
    local result = nil
    local addonName = nil

    if type( yieldTicks) ~= "number" then
        errorMsg = L["WRONG_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    if threadFunction == nil then
        errorMsg = L["PARAMETER_NIL"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    if type(threadFunction) ~= "function" then
        errorMsg = L["WRONG_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    parent_h, errorMsg = getHandleOfCallingThread()
    if parent_h == nil then -- then the caller must be the WoW game client
        addonName = extractAddonName( debugstack(2) )
    else
        -- the caller is a thread, i.e., -- the parent.
        addonName = parent_h[TH_CLIENT_ADDON]
    end

    local H = createHandle( addonName, parent_h, yieldTicks, threadFunction, ... )

    table.insert( threadControlBlock, H )
    if thread:debuggingIsEnabled() then
        dbgLog( string.format("%s Thread[%d] inserted into TCB.", utils:dbgPrefix(),  H[TH_UNIQUE_ID]))
    end
    return H, nil
end

--[[@Begin 
Signature: addonName, result = thread:getAddonName( [thread_h] )
Description: Obtains the name of the addon within which the specified
thread was created. If thread_h is nil, the addon name of the calling
thread is returned. Because WoWThreads is a library of services shared
among multiple addons, the thread's addon name serves to distinguish
threads by the addon within which they were created. This may prove
useful when implementing shared callbacks.
Parameters:
- thread_h (thread handle, optional). A handle to the thread whose addon name is to be 
obtained. If not specified, the addon name of the calling thread will be returned.
Returns:
- Success: Returns the name of the specified thread's addon and the result is set to nil.
- Failure: the addonName is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    -- This function is typically used to get the name of the addon for use when
    -- invoking a callback error handler.
    local addonName, result = thread:getAddonName( target_h )
    if addonName == nil then
        print( result[1], result[2])
    end
@End]]
function thread:getAddonName( thread_h )
    local fname = "thread:getAddonName()"
    local result = nil
    local errorMsg = nil

    if thread_h == nil then
        thread_h, errorMsg = getHandleOfCallingThread()
        if thread_h == nil then
            result = setResult( errorMsg, fname, debugstack(2))
            return nil, result
        end
    end
    return thread_h[TH_CLIENT_ADDON], nil
end

--[[@Begin
Signature: thread:yield()
Description: Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the calling thread's create function. Note that thread:yield()
is always fatal if the caller is NOT a thread.
Parameters:
- None.
Returns:
- None
Usage:
    -- A simple function that waits (yields) for a specified period of 
    -- time. When it returns it checks for a signal.
    local function waitForSignal( signal )
        local DONE = false
        while not DONE do
            thread:yield()
            local sigEntry, result = thread:getSignal()
            if not sigEntry then
                print( result[1], result[2])
                return
            end
            if sigEntry[1] == SIG_TERMINATE then
                DONE = true
            end
            if sigEntry[1] == signal then
            ... do something
            end
        end
    end
    -- Create a thread to execute the waitForSignal function.
    local thread_h, result = thread:create( 60, waitForSignal, signal )
    if thread_h == nil then 
        print( result[1], result[2]) 
        return 
    end
@End]]
function thread:yield()
    local fname = "thread:yield()"
    local beforeTicks = ACCUMULATED_TICKS
    local H = nil
    local errorMsg = nil

    coroutine.yield()

    if thread:dataCollectionIsEnabled() then  
        H, errorMsg = getHandleOfCallingThread()
    
        H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1
        H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + (ACCUMULATED_TICKS - beforeTicks)
    end
end

--[[@Begin
Signature: local overhead, errorMsg = thread:getMetrics( thread_h )
Description: Gets some some basic execution metrics; the runtime (ms) and
congestion (how long the thread had to wait to begin execution after having
been resumed). Note: at this point, only completed threads can be queried.
Parameters:
- thread_h (thread_handle): the thread handle whose metrics are to be returned.
Returns:
- Success: then the thread's elapsed time and congestion metrics are returned and the result is set to nil.
- Failure: the runtime and congestion metrics are nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local elapsedTime, congestion, result = thread:getMetrics( thread_h )
    if runtime == nil then 
        print( result[1], result[2]) 
        return 
    end
@End]]
function thread:getMetrics( thread_h )
    local fname = "thread:getMetrics()"
    local errorMsg = nil
    local result = nil

    if thread_h == nil then
        errorMsg = L["THREAD_HANDLE_NIL"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, nil, result
    end

    local isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, nil, result
    end

    if not handleIsInMorgue( thread_h ) then
        local result = setResult( L["THREAD_NOT_COMPLETED"], fname, debugstack(2))
        return nil, nil, result
    end

    -- local id = thread_h[TH_UNIQUE_ID]

    -- utils:dbgPrint( "Thread", id, "LifetimeTicks", thread_h[TH_LIFETIME_TICKS]) -- 90
    -- utils:dbgPrint( "Thread", id, "Resumptions", thread_h[TH_RESUMPTIONS]) -- 0
    -- utils:dbgPrint( "Thread", id, "yieldTicks", thread_h[TH_YIELD_TICKS]) -- 2
    -- utils:dbgPrint( "Thread", id, "accumYieldTicks", thread_h[TH_ACCUM_YIELD_TICKS]) -- 0
    
    local ms_per_tick      = CLOCK_INTERVAL -- ms per tick
    local elapsedTicks     = thread_h[TH_LIFETIME_TICKS]

    local idealYieldTicks   = thread_h[TH_RESUMPTIONS] * thread_h[TH_YIELD_TICKS]
    local actualYieldTicks  = thread_h[TH_ACCUM_YIELD_TICKS]

    local congestion  = (actualYieldTicks -idealYieldTicks) / idealYieldTicks
    local elapsedTime = ms_per_tick * elapsedTicks

    return elapsedTime, congestion
end

--[[@Begin
Signature: local ticksDelayed, errorMsg = thread:delay( ticks )
Description: Suspends the calling thread for the specified number of ticks. 
Note: when signaled, delayed threads respond as normal. Note: thread:delay()
is always fatal if the caller is not a thread.
Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been
Returns:
- Success: the actual number of ticks the thread was delayed. The result is set to nil.
- Failure: the handle is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    -- delay a thread 1 minute
    local actualDelay, result = thread:delay( 3600 )
    if actualDelay == nil then 
        print( result[1], result[2]) 
        return 
    end
@End]]
function thread:delay( delayTicks )
    local fname = "thread:delay()"
    local result = nil
    local stackTrace = nil
    local errorMsg = nil
    local H = nil

    if delayTicks == nil then
        result = setResult( L["PARAMETER_NIL"], fname, debugstack(2) )
        return nil, result
    end

    if type( delayTicks ) ~= "number" then
        result = setResult( L["WRONG_TYPE"], fname, debugstack(2) )
        return nil, result
    end

    H, errorMsg = getHandleOfCallingThread()
    if H == nil then
        if H == nil then
            result = setResult( errorMsg, fname, debugstack(2) )
            return nil, result
        end
    end

    H[TH_REMAINING_TICKS] = delayTicks
    local tickCount = ACCUMULATED_TICKS
    coroutine.yield()
    tickCount = ACCUMULATED_TICKS - tickCount

    return tickCount, result
end

--[[@Begin
Signature: thread:sleep()
Description: Suspends the calling thread for an indeterminate amount of time.
Note, unlike thread:yield(), this call doesn't  return until awakened by receipt 
of a SIG_WAKEUP signal. Note, thread:sleep() is always fatal if the caller is not
a thread.
Parameters:
- None
Returns:
- Success: the thread's handle is returned when it regains the processor (i.e., after 
it is resumed), and the result parameter is set to nil.
- Failure: the handle is false and the result parameter contains an error message. This situation arises
when the target thread is not in the thread sleep queue.
Usage:
    local thread_h, result = thread:sleep()
    if thread_h == false then                 -- the thread was never put to sleep. 
        print( result[1], result[2])
    end
@End]]
function thread:sleep()
    local fname = "thread:sleep()"
    local errorMsg = nil
    local successful = false
    local result = nil

    local H, errorMsg = getHandleOfCallingThread()
    if H == nil then
        result = setResult( fname, errorMsg, debugstack(2) )
        return nil, result
    end

    successful, errorMsg = moveToSleepTable(H)
    if not successful then
        result = setResult( errorMsg, fname, debugstack(2) )
        return nil, result
    end

    local co = H[TH_COROUTINE]
    coroutine.yield( co )
    return H, result
end

--[[@Begin
Signature: thread_h, result = thread:getSelf()
Description: Gets the handle of the calling thread.
Parameters:
- None
Returns:
- Success: returns a thread handle and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
@End]]
function thread:getSelf()
    local fname = "thread:getSelf()"
    local errorMsg = nil
    local result = nil
    
    local H, errorMsg = getHandleOfCallingThread()
    if H == nil then
        result = setResult( errorMsg, fname, debugstack(2) )
        return nil, result
    end
    return H, nil
end

--[[@Begin
Signature: threadId, result = thread:getId( [thread_h] )
Description: Obtains the unique, numerical Id of the specified thread. Note,
if the thread parameter (thread_h) is nil, then the Id of the calling thread
is returned.
Parameters:
- thread_h (handle, optional): returns the numeric Id (unique) of the specified
thread. If not specified, the Id of the calling thread is returned.
Returns:
- Success: returns the numerical Id of the thread and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local threadId, result = thread:getId()
    if threadId == nil then 
        print( result[1], result[2]) 
        return 
    end
@End]]
function thread:getId(thread_h)
    local fname = "thread:getId()"
    local isValid = true
    local errorMsg = nil
    local result = nil

    if thread_h == nil then
        thread_h, errorMsg = getHandleOfCallingThread()
        if thread_h == nil then
            result = setResult( errorMsg, fname, debugstack(2))
            return nil, result
        end
    end

    -- thread_h is not nil. But, is it valid
    isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        result = setResult( errorMsg, fname, debugstack(2) )
    end
    
    if handleIsInMorgue(thread_h) then
        return thread_h[TH_UNIQUE_ID], nil
    end

    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
Signature: local equal, result = thread:areEqual( h1, h2 )
Description: Determines whether two thread handles are identical.
Parameters: 
- h1 (handle): a thread handle
- h2 (handle); another thread handle
Returns: 
- Success: returns either 'true' or 'false' and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local equal, result = thread:areEqual( H1, H2 )
    if equal == nil then 
        print( result) 
        return 
    end
@End]]
function thread:areEqual(H1, H2)
    local fname = "thread:areEqual()"
    local areEqual = false
    local errorMsg = nil
    local isValid = false
    
    -- check that neither handle is nil
    if H1 == nil then
        local result = setResult( L["THREAD_HANDLE_NIL"], fname, debugstack(2))
        return nil, result
    end
    if H2 == nil then
        local result = setResult( L["THREAD_HANDLE_NIL"],fname, debugstack(2))
        return nil, result
    end

    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    return H1[TH_UNIQUE_ID] == H2[TH_UNIQUE_ID], nil
end

--[[@Begin
Signature: parent_h, result = thread:getParent( [thread_h] )
Description: Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent
Note: In this document all threads created by thw WoW client (WoW.exe)
are termed primary threads.
Parameters
- thread_h (handle, optional): if nil, then the calling thread's parent is returned.
Returns
- Success: returns the handle of the parent thread and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local parent_h, result = thread:getParent( thread_h )
    if parent_h == nil then 
        print( result[1], result[2])
    end
@End]]
function thread:getParent(thread_h)
    local fname = "thread:getParent()"
    local isValid = true
    local errorMsg = nil
    local H = nil

    if thread_h == nil then
        thread_h, errorMsg = getHandleOfCallingThread()
        if not thread_h then
            local result = setResult( errorMsg, fname, debugstack(2))
            return nil, result
        end
    end

    isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    return thread_h[TH_PARENT_HANDLE],  nil
end

--[[@Begin
Signature: childTable, result = thread:getChildThreads( [thread_h] )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle, optional). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- Success: returns a table of thread handles and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Note: a nil, nil return means that the thread has no children.
Usage:
    local childThreads, result = thread:getChildThreads( thread_h )
    if not childThreads then 
        print( result[1], result[2] ) 
    end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil

    if thread_h == nil then
        thread_h, errorMsg = getHandleOfCallingThread()
        if not thread_h then
            local result = setResult( errorMsg, fname, debugstack(2))
            return nil, result
        end
    end

    local isValid, errorMsg = handleIsValid( thread_h )
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    return thread_h[TH_CHILDREN], nil
end

--[[@Begin
Signature: state, result = thread:getState( [thread_h] )
Description: Gets the execution state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.
- Note: a dormant (sleeping) thread is always in the 'suspended' state.
Parameters:
- thread_h (handle, optional): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.
Returns: 
- Success: returns the state of the specified thread ("suspended", "running", 
or "dead"). The returned result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local state, result = thread:getState( thread_h )
    if not state then
        print( result[1], result[2] )
    end
@End]]
function thread:getExeState(thread_h)
    local fname = "thread:getState()"
    local errorMsg = nil
    
    if thread_h == nil then 
        thread_h, errorMsg = getHandleOfCallingThread()
        if thread_h == nil then
            local result = setResult( errorMsg, fname, debugstack(2) )
            return nil, result
        end
    end

    local co = thread_h[TH_COROUTINE]
    local status = coroutine.status( co )
    return status
end

--[[@Begin
Signature: value, result = thread:signalIsValid( signal )
Description: Checks whether the specified signal is valid
Parameters: 
- signalValue (number): signal to be sent.
Returns:
- Success: value = true is returned and the result is set to nil.
- Failure: value = false is returned and the signal is invalid.
Usage:
    local isValid, result = thread:signalIsValid( signal )
    if not isValid then 
        print( result[1], result[2] )
        return 
    end
@End]]
function thread:signalIsValid( signal )
    local isValid, errorMsg = signalIsValid( signal )
    return isValid, errorMsg
end

--[[@Begin
Signature: value, result = thread:sendSignal( target_h, signaValue [,...] )
Description: Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.
Returns:
1. If successful: value = true or false. A 'true' value means that...
- The signal was inserted into the target thread's signal queue, or
- The target thread was dormant and the signal was SIG_WAKEUP.
A value = false can mean one of two alternatives:
- The target thread was dead (completed or faulted).
- The target thread was dormant (sleeping) the signal was NOT SIG_WAKEUP.
2. If failed: nil is returned indicating the signal was not delivered. Usually
this means that the target's thread handle was was not found in the sleep queue. The 
result parameter contains an error message (result[1]) and a stack trace (result[2]).
Usage:
    local wasSent, result = thread:sendSignal( target_h, signalValue, data )
    if wasSent == nil then 
        print( result[1], result[2] )
        return 
    elseif wasSent == false then
        print( "target thread has completed or is dormant.")
    end
@End]]
function thread:sendSignal( target_h, signal, ... )
    local fname = "thread:sendSignal()"
    local wasSent = true
    local errorMsg = nil
    local result = nil
    local isValid = false

    -- check that the target handle is valid
    if target_h == nil then
        result = setResult( L["THREAD_HANDLE_NIL"], fname, debugstack(2))
        return nil, result
    end
    if type( target_h) ~= "table" then
        errorMsg = L["THREAD_HANDLE_WRONG_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    
    -- is the target thread a real thread?
    isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    if type( signal ) ~= "number" then
        result = setResult( L["INVALID_TYPE"])
        return nil, result
    end
    -- check that the signal is valid
    if signal == SIG_NONE_PENDING then
        result = setResult( L["SIGNAL_INVALID_OPERATION"], fname, debugstack(2))
        return nil, result
    end

    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then 
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    if handleIsInMorgue( target_h ) then
        return false, nil 
    end

    if signal == SIG_WAKEUP then
        if wakeupThread( target_h ) then
            return true, nil
        else
            return false, nil
        end
    end

    -- Initialize and insert an entry into the recipient thread's signalTable
    local sender_h, errorMsg = getHandleOfCallingThread()
    local varargs = {...}
    local sigEntry = {signal, sender_h, varargs[1] }

    -- local sigEntry = {signal, sender_h, sigData }
    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)

    if signal == SIG_ALERT then
        target_h[TH_REMAINING_TICKS] = 1
    end

    return wasSent, result
end

--[[@Begin
Signature: local sigEntry, result = thread:getSignal()
Description: The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Note, thread:getSignal()
is always fatal if the caller is not a thread.
Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
```
result = {
    sigEntry[1] -- (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
    sigEntry[2] -- (handle): the handle of the thread that sent the signal.
    sigEntry[3] -- (varargs): data
}
```
Returns:
- Success: returns a signal entry and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local sigInt, result = thread:getSignal()
    if not sigInt then 
        print( result[1, result[2] )
    end

    local signal = sigEntry[1]
    local sender_h = sigEntry[2]
    local data = signal[3]
    ... do something

@End]]
function thread:getSignal()
    local fname = "thread:getSignal()"
    local sigEntry = nil
    local errorMsg = nil

    local H, errorMsg = getHandleOfCallingThread()
    if H == nil then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        sigEntry = { SIG_NONE_PENDING, nil, nil }
        return sigEntry, nil
    end
    local sigEntry = H[TH_SIGNAL_QUEUE]:dequeue()
    return sigEntry, nil
end

--[[@Begin
Signature: signalName, result = thread:getSignalName( signal )
Description: Gets the string name of the specified signal value. for
example, when submitting the numerical constant, SIG_ALERT (11) the
service returns the string, "SIG_ALERT"
end
end
Parameters:
- signal (number): the numerical signal whose name is to be returned.
Returns:
- Success: returns the name associated with the signal value and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local signalName, result = thread:getSignalName( signal )
    if signalName == nil then print( errorMsg ) return end
@End]]
function thread:getSignalName(signal)
    local fname = "thread:getSignalName()"
    local errorMsg = nil
    local isValid = true

    isValid, errorMsg = signalIsValid( signal )
    if not isValid then
        local result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    return signalNameTable[signal], errorMsg
end

--[[@Begin
Signature: signalCount, result = thread:getNumPendingSignals()
Description: Gets the number of pending signals for the calling thread.
Note, thread:getNumPendingSignals() is always fatal if the caller is not
a thread.
Parameters:
- None
Returns:
- Success: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The result parameter will be nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local sigCount, result = thread:getNumPendingSignals( thread_h )
    if signalCount == nil then 
        print( result[1], result[2]) return end
@End]]
function thread:getNumPendingSignals()
    local fname = "thread:getNumPendingSignals()"
    local result = nil
    local errorMsg = nil

    local H, errorMsg = getHandleOfCallingThread()
    if H == nil then
        local result = setResult( errorMsg, fname, debugstack(2))
        return H, result
    end
    return H[TH_SIGNAL_QUEUE]:size(), result
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

local function OnEvent(self, event, ...)
    local addonName = select(1, ...)

    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
        DEFAULT_CHAT_FRAME:AddMessage(L["ADDON_MESSAGE"], 0.0, 1.0, 1.0)
        DEFAULT_CHAT_FRAME:AddMessage(L["TICK_INTERVAL"], 0.0, 1.0, 1.0)
        eventFrame:UnregisterEvent("ADDON_LOADED")

        WoWThreadLibInit()

        DEBUGGING_ENABLED = _G["WoWThreads_DEBUGGING_ENABLED"] or false
        DATA_COLLECTION   = _G["WoWThreads_DATA_COLLECTION"] or false        
    
    elseif event == "PLAYER_LOGOUT" then
        _G["WoWThreads_DEBUGGING_ENABLED"] = DEBUGGING_ENABLED
        _G["WoWThreads_DATA_COLLECTION"]   = DATA_COLLECTION
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
