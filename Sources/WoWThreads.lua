--=================================================================================
-- Filename: WoWThreads.lua
-- Date: 9 March, 2021
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
--=================================================================================
local ADDON_NAME, _ = ...

--                      ADMIN, HOUSEKEEPING STUFF
WoWThreads = WoWThreads or {}
WoWThreads.WoWThreads = WoWThreads.WoWThreads or {}
_G.WoWThreads = WoWThreads

-- Import the utility, signal, and localization libraries.
local UtilsLib = LibStub("UtilsLib")
if not UtilsLib then return end
local utils = UtilsLib

local SignalQueue = LibStub("SignalQueue")
if not SignalQueue then return end
local sq = SignalQueue

local EnUSlib = LibStub("EnUSlib")
if not EnUSlib then return end

local L = EnUSlib.L

-- These two operations ensure that the library name comes from
-- one source - the addon and version names from .TOC file.
local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
local libraryName = string.format("%s-%s", ADDON_NAME, version)

-- Export the WoWThreads public services
local LibStub = LibStub -- Assumes LibStub is globally available
local MAJOR, MINOR = libraryName, 1 -- Major and minor version numbers
local thread, _ = LibStub:NewLibrary(MAJOR, MINOR)
if not thread then return end -- No need to update if the loaded version is newer or the same

--                                  LOCAL DATA

local DEFAULT_YIELD_TICKS   = 2
local THREAD_SEQUENCE_ID    = 4 -- a number representing the order in which the thread was created
local ACCUMULATED_TICKS     = 0 -- The system-wide, total number of clock ticks

local threadControlBlock    = {} -- Table to hold all active threads
local threadSleepTable      = {} -- Table to hold sleeping threads
local morgue                = {} -- Table to hold the dead threads
local errorCallbackTable    = {} -- Table to hold the errorHandlers

local CLOCK_INTERVAL        = 1/GetFramerate()
local WoWThreadsStarted     = false
-- =====================================================================
--                      CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_UNIQUE_ID          = 2 -- a number representing the order in which the thread was created
local TH_SIGNAL_QUEUE       = 3 -- a table of all currently pending signals
local TH_YIELD_TICKS        = 4 -- the number of clock ticks for which a thread must suspend after a yield.
local TH_REMAINING_TICKS    = 5 -- decremented on every clock tick. When 0 the thread is queued.
local TH_ACCUM_YIELD_TICKS  = 6 -- The total number of yield ticks the thread is suspended.
local TH_LIFETIME_TICKS     = 7
local TH_YIELD_COUNT        = 8 -- the number of times a thread yields
local TH_CHILDREN           = 9
local TH_PARENT_HANDLE      = 10
local TH_CLIENT_ADDON       = 11
local TH_COROUTINE_ARGS     = 12

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
-- 
-- sigEntry = {signalValue, sender_h, ... }
thread.SIG_ALERT        = 1 -- schedule for immediate execution
thread.SIG_GET_DATA     = 2 -- no semantics. Used to execute an immediate normal return.
thread.SIG_SEND_DATA  = 3 -- no semantics. Used to execute an immediate normal return.
thread.SIG_BEGIN        = 4 -- no semantics.
thread.SIG_HALT         = 5 -- no semantics.
thread.SIG_TERMINATE    = 6 -- deletes the thread. Does not return from yield.
thread.SIG_IS_COMPLETE  = 7 -- info: thread is complete
thread.SIG_SUCCESS      = 8 -- info: thread completed successfully
thread.SIG_FAILURE      = 9 -- info: thread completed with failure
thread.SIG_READY        = 10
thread.SIG_WAKEUP       = 11 -- unused. Intended for thread pools.
thread.SIG_CALLBACK     = 12 -- info: Signal entry contains a callback function in Sig[3]
thread.SIG_THREAD_DEAD  = 13 -- info: thread has completed or failed.
thread.SIG_NONE_PENDING = 14 -- signal queue is empty.

local SIG_ALERT         = thread.SIG_ALERT
local SIG_GET_DATA      = thread.SIG_GET_DATA
local SIG_SEND_DATA   = thread.SIG_SEND_DATA
local SIG_BEGIN         = thread.SIG_BEGIN
local SIG_HALT          = thread.SIG_HALT
local SIG_TERMINATE     = thread.SIG_TERMINATE
local SIG_IS_COMPLETE   = thread.SIG_IS_COMPLETE
local SIG_SUCCESS       = thread.SIG_SUCCESS
local SIG_FAILURE       = thread.SIG_FAILURE  
local SIG_READY         = thread.SIG_READY 
local SIG_WAKEUP        = thread.SIG_WAKEUP 
local SIG_CALLBACK      = thread.SIG_CALLBACK
local SIG_THREAD_DEAD   = thread.SIG_THREAD_DEAD
local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING

local signalNameTable = {
    "SIG_ALERT",
    "SIG_GET_DATA",
    "SIG_SEND_DATA",
    "SIG_BEGIN",
    "SIG_HALT",
    "SIG_TERMINATE",
    "SIG_IS_COMPLETE",
    "SIG_SUCCESS",
    "SIG_FAILURE",
    "SIG_READY",
    "SIG_WAKEUP",
    "SIG_CALLBACK",
    "SIG_THREAD_DEAD",
    "SIG_NONE_PENDING"
}

--                          LOCAL FUNCTIONS 
local function setResult( fname, errorMsg, stackTrace )
    errorMsg = string.format("%s in %s. ", errorMsg, fname )
    return {errorMsg, stackTrace }
end
local function callerIsWoWClient( H )
    local isWowClient = false
    if H[TH_PARENT_HANDLE] == nil then
        return true
    end
    return false
end
local function isInMorgue( H )
    local inMorgue = false
    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            inMorgue = true
            return inMorgue, nil
        end
    end
    return inMorgue, L["THREAD_IS_DEAD"]
end

local function getCallerHandle()
    local running_h = nil
    local status = nil

    for i = 1, #threadControlBlock do
        local running_h = threadControlBlock[i]
        local co = running_h[TH_COROUTINE] 
        status = coroutine.status( co )       
        if status == "running" then
            return running_h, nil
        end
    end
    return nil, L["THREAD_INVALID_CONTEXT"]
end
local function getAddonName( thread_h )
    return thread_h[TH_CLIENT_ADDON], nil
end
-- this function is WoWThread's registered callback
local function threadCallback( addonName, errorMsg )
    local handler = nil

    if errorCallbackTable[addonName] then
        handler = errorCallbackTable[addonName]
        handler( errorMsg )
    else  
        local msg = string.format("Error handler not found for thread from %s.", addonName)
        DEFAULT_CHAT_FRAME:AddMessage(msg, 1.0, 0.0, 0.0)
        if utils:debuggingIsEnabled() then
            utils:dbgLog( errorMsg, debugstack(2) )
        end
    end
end
local function createHandle( addonName, yieldTicks, threadFunction,... )

    if yieldTicks  < DEFAULT_YIELD_TICKS then
        yieldTicks = DEFAULT_YIELD_TICKS
    end
    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1

    local H = {}    -- create an empty handle table, H

    H[TH_COROUTINE]         = coroutine.create( threadFunction ) 
    H[TH_UNIQUE_ID]         = THREAD_SEQUENCE_ID
    H[TH_SIGNAL_QUEUE]      = sq.new()
    H[TH_YIELD_TICKS]       = yieldTicks
    H[TH_REMAINING_TICKS]   = 1
    H[TH_ACCUM_YIELD_TICKS] = 0
    H[TH_LIFETIME_TICKS]    = 0
    H[TH_YIELD_COUNT]       = 0
    H[TH_CLIENT_ADDON]      = addonName

    H[TH_CHILDREN]  = {}
    H[TH_PARENT_HANDLE]    = nil
    H[TH_COROUTINE_ARGS] = {...}

    local parent_h = getCallerHandle()
    if parent_h ~= nil then
        -- This handle will be he child of the running thread.
        table.insert(parent_h[TH_CHILDREN], H)
        H[TH_PARENT_HANDLE] = parent_h
    end

    return H
end
local function moveToMorgue( H )
    H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]

    for i, handle in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == handle[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( morgue, H)
            break
        end
    end
    if utils:debuggingIsEnabled() then
        local msg = string.format("thread[%d] moved from TCB to morgue", H[TH_UNIQUE_ID])
        utils:dbgLog( msg, debugstack(2) )
    end
end
-- returns the handle if successful. Otherwise, nil, errorMsg
local function putToSleep( H )
    local inTCB = false
    local isSleeping = false
    local errorMsg = nil
    local st = nil

    -- if it's already sleeping then return nil, errorMsg
    for i, entry in ipairs(threadSleepTable) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            isSleeping = true
            st = utils:simplifyStackTrace( debugstack(2))
            return nil,  L["THREAD_ALREADY_SLEEPING"]
        end
    end
    -- if the thread is in the TCB then remove it
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            if utils:debuggingIsEnabled() then
                local msg = string.format("thread[%d] removed from TCB", H[TH_UNIQUE_ID])
                utils:dbgLog( msg )
            end
            inTCB = true
            break
        end
    end

    -- if the thread wasn't in the TCB then return nil, errorMsg
    if not inTCB then
        local st = utils:simplifyStackTrace( debugstack(2))
        local errorMsg = string.format("Thread[%d] not found in thread control block", H[TH_UNIQUE_ID])
        if utils:debuggingIsEnabled() then
            utils:dbgLog( errorMsg )
        end
        return nil, errorMsg
    end

    -- thread is ready to be entered into the thread sleep table.
    table.insert(threadSleepTable, H)
    if utils:debuggingIsEnabled() then
        local st = utils:simplifyStackTrace( debugstack(2))
        local msg = string.format("Thread[%d] entered into the thread sleep table. ", H[TH_UNIQUE_ID])
        utils:dbgLog( msg, st )
    end    
    return H, errorMsg
end
local function wakeup(H )
    local isSleeping = false
    local errorMsg = nil

    for i, entry in ipairs(threadSleepTable) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadSleepTable, i)
            if utils:debuggingIsEnabled() then
                local msg = string.format("Thread[%d] removed from sleep table.\n", H[TH_UNIQUE_ID])
                utils:dbgLog( msg, debugstack(2) )
            end
    
            isSleeping = true
            break
        end
    end
    if not isSleeping then
        errorMsg = string.format("thread[%d] not in thread sleep table.\n", H[TH_UNIQUE_ID])
        if utils:debuggingIsEnabled() then
            utils:dbgLog( errorMsg, debugstack(2) )
        end
        return nil, errorMsg
    end
    if isSleeping then
        table.insert(threadControlBlock, H)
        if utils:debuggingIsEnabled() then
            local msg = string.format("Thread[%d] moved from sleep table to TCB.\n", H[TH_UNIQUE_ID])
            utils:dbgLog( msg, debugstack(2) )
        end
    end
    return H, errorMsg
end
local function handleIsValid(H)
    local isValid = true
    local errorMsg = nil

    if type(H) ~= "table" then
        errorMsg = L["INVALID_TYPE"]
        isValid = false
        return isValid, errorMsg
    end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        errorMsg = L["HANDLE_ILL_FORMED"]
        isValid = false
        return isValid, errorMsg
    end
    local isDead, errorMsg = isInMorgue(H) 
    if isDead then
        errorMsg = L["THREAD_IS_DEAD"]
        isValid = false
        return isValid, errorMsg
    end
    if type(H[TH_COROUTINE]) ~= "thread" then
        errorMsg = L["NOT_A_THREAD"]
        isValid = false
        return isValid, errorMsg
    end
    return isValid, errorMsg
end
local function signalInRange(signal)
    local isValid = true
    local errorMsg = nil

    if signal < SIG_ALERT then
        isValid = false
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
        errorMsg = L["SIGNAL_INVALID"]
        return isValid, errorMsg
    end

    if type(signal) ~= "number" then 
        isValid = false
        errorMsg = L["INVALID_TYPE"]
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
        H[TH_LIFETIME_TICKS] = H[TH_LIFETIME_TICKS] + 1
        local status = coroutine.status( H[TH_COROUTINE] )
        if status == "dead" then -- move it into the morgue
            moveToMorgue(H)
            return
        end
        
        if status == "suspended" then
            local args = H[TH_COROUTINE_ARGS]
            local errorMsg = nil
            local coroutineResumed = false
            local pcallSucceeded = false

            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            
            if H[TH_REMAINING_TICKS] == 0 then -- switch to H[TH_COROUTINE]
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS] -- replenish the remaining ticks
                local co = H[TH_COROUTINE]
                pcallSucceeded, coroutineResumed, errorMsg = pcall(coroutine.resume, co, unpack(args) )
                if not pcallSucceeded then
                    -- utils:dbgPrint( "pcallSucceeded", errorMsg )
                    moveToMorgue(H)
                    local st = utils:simplifyStackTrace( debugstack(2))
                    result = setResult( fname, errorMsg, st)
                    -- errorHandler( H[TH_CLIENT_ADDON], errorMsg )
                end
                if not coroutineResumed then
                    -- utils:dbgPrint( "coroutineResumed", errorMsg )
                    moveToMorgue(H)
                    local st = utils:simplifyStackTrace( debugstack(2))
                    result = setResult( fname, errorMsg, st)
                    -- errorHandler( H[TH_CLIENT_ADDON], errorStr )
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
local function extractAddonName(stacktrace) -- used in thread:create()
    local addonName = string.match(stacktrace, "AddOns/([^/]+)/")
    
    -- Return the captured addon name or nil if not found
    return addonName
end

--                      PUBLIC (EXPORTED) SERVICES

--[[@Begin 
Signature: thread_h, result = thread:create( addonName, yieldTicks, addonName, func,... )
Description: Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.
Parameters:
- addonName (string). The name of the addon that created the thread.
- yieldTicks (number). The time, in clock ticks, the thread is to 
suspend itself when it calls thread:yield(). A clock tick is the 
reciprocal of your computer's framerate multiplied by 1000. On my 
system a clock tick is about 16.7 milliseconds where 60 ticks is 
about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs), Additional arguments to be passed to the thread function.
Returns:
- If successful: a valid thread handle is returned and the result is nil.
- If failure: nil is returned and the result parameter specifies an error message (result[1])
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
    local isValid = true
    local errorMsg = nil
    local addonName = nil

    local parent_h = getCallerHandle()
    if parent_h == nil then
        -- the caller is the WoW game client
        addonName = extractAddonName( debugstack(2) )
    else
        -- the caller is another thread (to be the parent
        -- of this thread)
        addonName = parent_h[TH_CLIENT_ADDON]
    end

    local H = createHandle( addonName, yieldTicks, threadFunction, ... )

    -- if not callerIsWoWClient(H) then
    --     isValid, errorMsg = handleIsValid(H)
    --     if not isValid then
    --         local st = utils:simplifyStackTrace( debugstack(2))
    --         local result = setResult( fname, errorMsg, st)
    --         return nil, result
    --     end
    -- end

    table.insert( threadControlBlock, H )
    return H, nil
end

--[[@Begin 
Signature: addonName, result = thread:getAddonName( thread_h )
Description: Obtains the name of the addon within which the specified
thread was created.
Parameters:
- thread_h (thread handle). A handle to the thread whose addon name is to be 
obtained.
Returns:
- If successful: Returns the name of the specified thread's addon and the result is nil.
- If failure: the addonName is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    -- This function is typically used to get the name of the addon for use when
    -- invoking the error handler.
    local wasSent, result = thread:sendSignal( target_h, SIG_ALERT )
    if not wasSent then
        print( result[1], result[2])
    end
@End]]
function thread:getAddonName( thread_h )
    local fname = "thread:getAddonName()"
    local errorMsg = nil

    if thread_h == nil then
        thread_h = getCallerHandle()
        if thread_h == nil then
            local st = utils:simplifyStackTrace( debugstack(2))
            local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
            return nil, result
        end
    end
    local addonName = getAddonName( thread_h )
    return addonName, nil
end

--[[@Begin
Signature: local ticks, errorMsg = thread:yield()
Description: Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the thread's create function used to create the thread. 
Thread context required, 
Parameters:
- None.
Returns:
- ticks (number): the actual number of ticks the thread was suspended
- If failure: the ticks value is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    -- A simple function that waits (yields) until a signal arrives.
    local function waitForSignal( signal )
        local DONE = false
        while not DONE do
            thread:yield()
            local sigEntry, result = thread:getSignal()
            if not sigEntry then
                print( result[1], result[2])
                return
            end
            ... do something
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

    local H, errorMsg = getCallerHandle()
    if H == nil then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
    local actualTicks = ACCUMULATED_TICKS

    coroutine.yield()
    local H, errorMsg = getCallerHandle()
    if H == nil then 
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st )
        return nil, result
    end

    H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    local numYieldTicks = ACCUMULATED_TICKS - actualTicks
    H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + numYieldTicks
    actualTicks = 0

    return numYieldTicks, errorMsg
end

--[[@Begin
Signature: local ticksDelayed, errorMsg = thread:delay( ticks )
Description: Suspends the calling thread for the specified number of ticks. 
Note: when signaled, delayed threads respond as normal.
Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been
Returns:
- If successful: the handle of the calling thread is returned and the result is nil.
- If failure: the handle is nil, and the result parameter contains an error message (result[1])
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
    local st = nil
    local errorMsg = nil

    if delayTicks == nil then
        st = utils:simplifyStackTrace( debugstack(2))
        errorMsg = string.format("%s in %s. ", L["INPUT_PARM_NIL"], fname )
        result = setResult( fname, errorMsg, st )
        return nil, result
    end

    if type( delayTicks ) ~= "number" then
        st = debugstack(2)
        local errorStr = string.format("%s in %s", L["INVALID_TYPE"], fname )
        result = { errorStr, st }
        return nil, result
    end

    local H, errorMsg = getCallerHandle()
    if not H then
        st = simplifyStackTrace( debugstack(2))
        errorMsg = string.format("%s in %s",  L["HANDLE_NON_EXISTANT"], fname )
        result = {errorMsg, st }
        return nil, result
    end

    H[TH_REMAINING_TICKS] = delayTicks
    local tickCount = ACCUMULATED_TICKS
    coroutine.yield()
    tickCount = ACCUMULATED_TICKS - tickCount

    return tickCount, errorMsg
end

--[[@Begin
Signature: thread:sleep()
Description: Suspends the calling thread for an indeterminate amount of time.
Note, unlike thread:yield(), this call doesn't  return until awakened by receipt 
of a SIG_WAKEUP signal.
Parameters:
- None
Returns:
- If successful: the handle of the calling thread is returned and the result is nil.
- If failure: the handle is nil, and the result parameter contains an error
message (result[1]) and a stack trace (result[2])
Usage:
    thread:sleep()
@End]]
function thread:sleep()
    local fname = "thread:sleep()"
    local errorMsg = nil
    local st = nil
    local result = nil

    local H, errorMsg = getCallerHandle()
    if H == nil then 
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
    H, errorMsg = putToSleep(H)
    if errorMsg == nil then
        st = utils:simplifyStackTrace( debugstack(2))
        result = setResult( fname, "Thread Handle Not Sleeping.", st) --@@
        return nil, result
    end
    return H, errorMsg
end

--[[@Begin
Signature: thread_h, result = thread:getSelf()
Description: Gets the handle of the calling thread.
Parameters:
- None
Returns:
- If successful: returns a thread handle and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
@End]]
function thread:getSelf()
    local fname = "thread:getSelf()"
    local isValid = true
    local errorMsg = nil
    
    local H, errorMsg = getCallerHandle()
    if H == nil then 
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
        return H, nil
end

--[[@Begin
Signature: threadId, result = thread:getId( thread_h )
Description: Obtains the unique, numerical Id of the specified thread.
Parameters:
- thread_h (handle):
Returns:
- If successful: returns the numerical Id of the thread and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
    local threadId = nil

    if thread_h == nil then
        local H, errorMsg = getCallerHandle()
        if H == nil then 
            local st = utils:simplifyStackTrace( debugstack(2))
            local result = setResult( fname, errorMsg, st)
            return nil, result
        end
    end

    -- thread_h is not nil. But, is it valid
    isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        return nil, setResult( fname, errorMsg , debugstack(2) )
    end

    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
Signature: local equal, result = thread:areEqual( h1, h2 )
Description: Determines whether two thread handles are identical.
Parameters: 
- h1 (handle): a thread handle
- h2 (handle); a thread handle
Returns: 
- If successful: returns 'true' and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
    if H2 == nil then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end

    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end
    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end

    -- handles are not nil and they are both valid
    if H1[TH_UNIQUE_ID] ~= H2[TH_UNIQUE_ID] then
        return areEqual, nil
    else
        areEqual = true
    end
    return areEqual, nil
end

--[[@Begin
Signature: parent_h, result = thread:getParent( thread_h )
Description: Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent.
Parameters
- thread_h (handle): if nil, then the calling thread's parent is returned.
Returns
- If successful: returns the handle of the parent thread and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
        H, errorMsg = getCallerHandle()
        if not H then
            local st = utils:simplifyStackTrace( debugstack(2))
            local result = setResult( fname, errorMsg, st )
            return result
        end
    end

    isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        return nil, setResult( fname, errorMsg, debugstack(2) )
    end
    return thread_h[TH_PARENT_HANDLE]

end

--[[@Begin
Signature: childTable, result = thread:getChildThreads( thread_h )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- If successful: returns a table of thread handles and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local childThreads, result = thread:getChildThreads( thread_h )
    if not childThreads then 
        print( result[1], result[2] ) 
    end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        local isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local st = utils:simplifyStackTrace( debugstack(2))
            local result = setResult( fname, errorMsg, st)
            return nil, result
        else -- we're looking for the caller's thread Id.
            thread_h, errorMsg = getCallerHandle()
            if thread_h == nil then 
                local st = utils:simplifyStackTrace( debugstack(2))
                local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
                return nil, result
                end
        end
    end
    return thread_h[TH_CHILDREN], nil
end

--[[@Begin
Signature: state, result = thread:getState( thread_h )
Description: Gets the state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.
Parameters:
- thread_h (handle): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.
Returns: 
- If successful: returns the state of the specified thread ("suspended", "running", 
or "dead") of the specified thread. The result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local state, result = thread:getState( thread_h )
    if not state then
        print( result[1], result[2] )
    end
@End]]
function thread:getState(thread_h)
    local fname = "thread:getState()"
    local errorMsg = nil
    if thread_h == nil then 
        thread_h, errorMsg = getCallerHandle()
        if thread_h == nil then
            local st = utils:simplifyStackTrace( debugstack(2))
            local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
            return nil, result
        end
        return "running", nil 
    end

    local status = coroutine.status( thread_h[TH_COROUTINE])
    return status, nil
end

--[[@Begin
Signature: value, result = thread:sendSignal( target_h, signaValue,[,data] )
Description: Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): signal to be sent.
- data (any) Data (including functions) to be passed to the receiving thread.
Returns:
- If successful: value = true is returned and the result is nil.
- If failure: value = false is returned and the signal could NOT delivered. Usually
this means that the target thread was 'dead,' non-existent, or the WoW client (WoW.exe).
The result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local wasSent, result = thread:sendSignal( target_h, signalValue, data )
    if not wasSent then 
        print( result[1], result[2] )
        return 
    end
@End]]
function thread:sendSignal( target_h, signal, ... )
    local fname = "thread:sendSignal()"
    local wasSent = true
    local errorMsg = nil
    local isValid = false

    -- check that the target handle is valid
    if target_h == nil then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
    isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end

    -- check that the signal is valid
    if signal == SIG_NONE_PENDING then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname,  L["SIGNAL_INVALID_OPERATION"], st)
        return nil, result
    end

    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then 
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end

    local isDead, errorMsg = isInMorgue( target_h )
    if isDead then
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end

    -- Initialize and insert an entry into the recipient thread's signalTable
    -- utils:dbgPrint()
    local sender_h, errorMsg = getCallerHandle()
    local varargs = {...}
    local sigEntry = {signal, sender_h, varargs[1] }

    -- local sigEntry = {signal, sender_h, sigData }
    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)

    if signal == SIG_ALERT then
        target_h[TH_REMAINING_TICKS] = 1
    end
    if signal == SIG_WAKEUP then
        wakeup( target_h )
    end
    return wasSent, nil
end

--[[@Begin
Signature: local sigEntry, result = thread:getSignal()
Description: The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Thread
context is required.
Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
sigEntry[1] (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
sigEntry[2] (handle): the handle of the thread that sent the signal.
sigEntry[3] (varargs): data
Returns:
- If successful: returns a signal entry and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
    local errorMsg = nil

    local H, errorMsg = getCallerHandle()
    if H == nil then 
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, L["THREAD_HANDLE_NIL"], st)
        return nil, result
    end
    
    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        return {SIG_NONE_PENDING, nil, nil }, nil
    end

    local entry = H[TH_SIGNAL_QUEUE]:dequeue()
    local signalName = signalNameTable[entry[1]]

    return entry, nil
end

--[[@Begin
Signature: signalName, result = thread:getSignalName( signal )
Description: Gets the string name of the specified signal value.
Parameters:
- signal (number): the numerical signal whose name is to be returned.
Returns:
- If successful: returns the name associated with the signal value and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
        local st = utils:simplifyStackTrace( debugstack(2))
        local result = setResult( fname, errorMsg, st)
        return nil, result
    end

    return signalNameTable[signal], errorMsg
end

--[[@Begin
Signature: signalCount, result = thread:getNumPendingSignals()
Description: Gets the number of pending signals for the calling thread.
Parameters:
- None
Returns:
- If successful: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The result parameter will be nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).
Usage:
    local sigCount, result = thread:getNumPendingSignals( thread_h )
    if signalCount == nil then 
        print( result[1], result[2]) return end
@End]]
function thread:getNumPendingSignals()
    local fname = "thread:getNumPendingSignals()"
    local errorMsg = nil
    local H = nil

    local thread_h, errorMsg = getCallerHandle()
    if thread_h == nil then 
        return nil, setResult( fname, errorMsg, debugstack(2) )
    end
    return thread_h[TH_SIGNAL_QUEUE]:size(), nil
end


-- Will not be available upon release. These are for
-- WoWThreads development only.
function thread:debuggingIsEnabled()
    print( "In  debuggingIsEnabled")
end
function thread:enableDebugging()
    print(  "In enableDebugging()")
end
function thread:disableDebugging()
    print(  "In disableDebugging()")
end
function thread:dataCollectionIsEnabled()
    print( "In dataCollectionIsEnabled()")
end
function thread:enableDataCollection()
    print( "In enableDataCollection()")
end
function thread:disableDataCollection()
    print( "In disableDataCollection()")
end


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent(self, event, ...)
    local numArgs = select("#", ...)    -- unused
    local addonName = select(1, ...)


    if event == "ADDON_LOADED" and ADDON_NAME == addonName then

        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_MESSAGE"], 0.0, 1.0, 1.0 )
        DEFAULT_CHAT_FRAME:AddMessage( L["CLOCK_INTERVAL"], 0.0, 1.0, 1.0 )
        eventFrame:UnregisterEvent("ADDON_LOADED")

        WoWThreadLibInit()
    end
    return
end
eventFrame:SetScript("OnEvent", OnEvent)

local fileName = "WoWThreads.lua"
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end

------- PROTOTYPING -------------------------
