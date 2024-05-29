----------------------------------------------------------------------------------------
-- FILE NAME:		WoWThreads.Lua
-- ORIGINAL DATE:   14 March, 2023
----------------------------------------------------------------------------------------
local ADDON_NAME, WoWThreads = ...
-- Example: varargs processing!
-- local args = {}
-- local numArgs = select("#", ...) -- varargs processing
-- for i = 1, numArgs do 
--     args[i] = select(i, ...)
-- end

-- =====================================================================
--                      ADMIN, HOUSEKEEPING STUFF
-- =====================================================================-
-- Access the Utilities Library
local sprintf = _G.string.format
local fileName = "WoWThreads.lua"

-- These are the two libraries supporting WoWThreads
local UtilsLib = LibStub("UtilsLib")
local utils = UtilsLib

local FifoQueue = LibStub("FifoQueue")
if not FifoQueue then return end

local EnUSlib = LibStub("EnUSlib")
if not EnUSlib then return end

local L = EnUSlib.L

local expansionName = utils:getExpansionName()
local version = utils:getVersion()

-- Initialize the library
local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
local libraryName = sprintf("%s-%s", ADDON_NAME, version)

-- Export the Threads code
local LibStub = LibStub -- Assuming LibStub is globally available
local MAJOR, MINOR = libraryName, 1 -- Major and minor version numbers
local thread, _ = LibStub:NewLibrary(MAJOR, MINOR)
if not thread then
    return
end -- No need to update if the loaded version is newer or the same


local DEFAULT_YIELD_TICKS = 5

local THREAD_SEQUENCE_ID    = 4
local ACCUMULATED_TICKS     = 0
local threadControlBlock    = {}
local threadSleepQueue      = {}
local morgue                = {}
local CLOCK_INTERVAL        = 1/GetFramerate()
local WoWThreadsStarted     = false
-- =====================================================================
--                      CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_UNIQUE_ID          = 2 -- a number representing the order in which the thread was created
local TH_SIGNAL_QUEUE       = 3 -- a table of all currently pending signals
local TH_DURATION_TICKS     = 4 -- the number of clock ticks for which a thread must suspend after a yield.
local TH_REMAINING_TICKS    = 5 -- decremented on every clock tick. When 0 the thread is queued.
local TH_ACCUM_YIELD_TICKS  = 6 -- The total number of yield ticks the thread is suspended.
local TH_LIFETIME_TICKS     = 7
local TH_YIELD_COUNT        = 8 -- the number of times a thread yields
local TH_CHILDREN           = 9
local TH_PARENT             = 10
local TH_ADDON_NAME         = 11
local TH_COROUTINE_ARGS     = 12

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
-- 
-- sigEntry = {signalValue, sender_h, ... }
thread.SIG_ALERT        = 1 -- schedule for immediate execution
thread.SIG_GET_DATA     = 2 -- no semantics. Used to execute an immediate normal return.
thread.SIG_RETURN_DATA  = 3 -- no semantics. Used to execute an immediate normal return.
thread.SIG_BEGIN        = 4 -- no semantics.
thread.SIG_HALT         = 5 -- no semantics.
thread.SIG_TERMINATE    = 6 -- deletes the thread. Does not return from yield.
thread.SIG_IS_COMPLETE  = 7 -- info: thread is complete
thread.SIG_SUCCESS      = 8 -- info: thread completed successfully
thread.SIG_FAILURE      = 9 -- info: thread completed with failure
thread.SIG_READY        = 10
thread.SIG_WAKEUP       = 11 -- unused. Intended for thread pools.
thread.SIG_CALLBACK     = 12
thread.SIG_THREAD_DEAD  = 13
thread.SIG_NONE_PENDING = 14 -- signal queue is empty.

local SIG_ALERT         = thread.SIG_ALERT
local SIG_GET_DATA      = thread.SIG_GET_DATA
local SIG_RETURN_DATA   = thread.SIG_RETURN_DATA
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
    "SIG_RETURN_DATA",
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

-- =======================================================================
-- *                    LOCAL FUNCTIONS                                  =
-- =======================================================================

-- Table to hold registered callbackFunc functions.
local errorCallbackTable = {}
local function libErrorHandler( errorMessage )
    local errorMsg = sprintf("[CB] %s\n", errorMessage )
    utils:postMsg( errorMsg )
end
function  thread:reportError( addonName, errorMsg )
    local func = errorCallbackTable[addonName]

    if func then
        local str = ">> " .. errorMsg
        func( str )
    else
    end
end
local function getCallerHandle()
    local running_h = nil

    for i = 1, #threadControlBlock do
        local running_h = threadControlBlock[i]
        local co = running_h[TH_COROUTINE]
        local status = coroutine.status( co )
        if status == "running" then
            return running_h
        end
    end

    return nil
end

local function createHandle(durationTicks, threadFunction, ... )

    if durationTicks  < DEFAULT_YIELD_TICKS then
        durationTicks = DEFAULT_YIELD_TICKS
    end
    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1

    local H = {}    -- create an empty handle table, H

    H[TH_COROUTINE] = coroutine.create(threadFunction)
    H[TH_UNIQUE_ID]         = THREAD_SEQUENCE_ID
    H[TH_SIGNAL_QUEUE]      = FifoQueue.new()
    H[TH_DURATION_TICKS]    = durationTicks
    H[TH_REMAINING_TICKS]   = H[TH_DURATION_TICKS]
    H[TH_ACCUM_YIELD_TICKS] = 0
    H[TH_LIFETIME_TICKS]    = 0
    H[TH_YIELD_COUNT]       = 0

    H[TH_CHILDREN]  = {}
    H[TH_PARENT]    = nil

    H[TH_ADDON_NAME] = ADDON_NAME
    H[TH_COROUTINE_ARGS] = {...}

    local parent_h = getCallerHandle()
    if parent_h ~= nil then
        -- this call is being executed by a WoW Thread. Therefore,
        -- the running thread is the parent and this handle will be
        -- the child of the running thread.
        table.insert(parent_h[TH_CHILDREN], H)
        H[TH_PARENT] = parent_h
    end
    return H
end
--------------- BEGIN VALIDATE FUNCTIONS -------------------
local function moveToMorgue( H )
    H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]

    for i, entry in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( morgue, H)
            break
        end
    end
    utils:dbgPrint( sprintf("thread[%d] moved into morgue", H[TH_UNIQUE_ID]) )
end
local function putToSleep( H )
    for i = 1, #threadControlBlock do
        if H[TH_UNIQUE_ID] == threadControlBlock[i][TH_UNIQUE_ID] then 
            table.remove(threadControlBlock, i)
            break
        end
    end
    table.insert(threadSleepQueue, H)
end
-- Raises an error if the checks fail
local function handleIsValid(H)
    local isValid = true
    local errorMsg = nil

    if type(H) ~= "table" then
        errorMsg = L["INVALID_TYPE"]
        isValid = false
    end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        errorMsg = L["HANDLE_ILL_FORMED"]
        isValid = false
    end
    if type(H[TH_COROUTINE]) ~= "thread" then
        errorMsg = L["HANDLE_NOT_A_THREAD"]
        isValid = false
    end

    local state = coroutine.status(H[TH_COROUTINE])
    if state == "dead" then
        errorMsg = L["THREAD_STATE_DEAD"]
        isValid = false
    end
    return isValid, errorMsg
end

local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING

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
local function wakeup(H)
    local isValid = false

    if #threadSleepQueue == 0 then
        return isValid, L["THREAD_NOT_FOUND"] 
    end
    
    for i = 1, #threadSleepQueue do
        local H = threadSleepQueue[i]
        if H[TH_UNIQUE_ID] == target_h[TH_UNIQUE_ID] then
            H[TH_REMAINING_TICKS] = 1
            table.remove( threadSleepQueue, i )
            table.insert( threadControlBlock, H )
            isValid = true
            break
        end
    end
    if not isValid then 
        -- thread:reportError( ADDON_NAME, L["THREAD_NOT_FOUND"] ) 
        return nil, L["THREAD_NOT_FOUND"] 
    end
    return isValid, nil
end
local function scheduleThreads()
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
            
            if H[TH_REMAINING_TICKS] == 0 then -- switch to next coroutine
                H[TH_REMAINING_TICKS] = H[TH_DURATION_TICKS] -- replenish the remaining ticks
                local co = H[TH_COROUTINE]
                local errorStr = nil
                pcallSucceeded, coroutineResumed, errorStr = pcall(coroutine.resume, co, unpack(args) )
                if not pcallSucceeded then
                    local st = utils:parseStackTrace( debugstack(2))
                    moveToMorgue(H)
                            -- utils:dbgPrint( "PCALL failed. Thread[%d] moved to morgue", H[TH_UNIQUE_ID])
                    errorStr = sprintf("\nStack Trace:\n%s\n%s\n", st, errorStr)
                    thread:reportError(ADDON_NAME, errorStr )
                    -- error( "stopped - pcall() failed" )
                end
                if not coroutineResumed then
                    local st = utils:parseStackTrace( debugstack(2))
                    -- utils:dbgPrint( "Thread[%d] failed to resume - moved to morgue", H[TH_UNIQUE_ID])
                    moveToMorgue(H)
                            errorStr = sprintf("Stack Trace:\n%s\n%s\n", st, errorStr)
                    thread:reportError(ADDON_NAME, errorStr)
                    -- error( "stopped: " .. errorStr )
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
-- Returns TCB thread count.
-- Returns Handle's coroutine
local function getCoroutine(H)
    return H[TH_COROUTINE]
end
local function WoWThreadLibInit()
    if not WoWThreadsStarted then
        startTimer( 1/GetFramerate() )
    end
    WoWThreadsStarted = true
end
-- ============================================================================
--              PUBLIC (EXPORTED) METHODS
-- ============================================================================
--[[@Begin 
Title: Create a Thread
Signature: thread_h, threadId, errorMsg = thread:create( yieldTicks, func,... )
Description: Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.
Parameters:
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
- If successful, Returns a thread handle and the thread's Id.
- If failure, Returns nil. The error message describes the error
and its location.
Usage:
    local thread_h, threadId, errorMsg = thread:create( 60, helloWorld, "Hello World" )
    if thread_h ~= nil then print( result) return end
@End]]
function thread:create( yieldTicks, threadFunction, ... )
    local fname = "thread:create()"
    local isValid = true
    local errorMsg = nil

    local H = createHandle( yieldTicks, threadFunction, ... )

    isValid, errorMsg = handleIsValid(H)
    if not isValid then
        errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, fname )         
        -- thread:reportError( ADDON_NAME, errorMsg )
        return nil, nil, errorMsg
    end

    table.insert( threadControlBlock, H )
    return H, H[TH_UNIQUE_ID], nil
end

--[[@Begin
Title: Suspend a Thread's Execution
Signature: success, errorMsg = thread:yield()
Description: Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the thread's create function used to create the thread. 
Thread context required, 
Parameters:
- None.
Returns:
- Success (boolean): True if the thread was successfully suspended, 
false otherwise.
- Error message (string): The error message if the thread could not be suspended.
Usage:
    -- This is the function executed by the thread created below and prints the
    -- the greeting 3 times.
    local function helloWorld( greeting )
        local DONE = false
        local count = 1
        while not DONE do
            thread:yield()
            count = count + 1
            if count == 3 then
                DONE = false
            else
                print( greeting)
            end
        end
    end
    -- Create a thread to execute the helloWorld action routine.
    local thread_h, errorMsg = thread:create( 60, helloWorld, "Hello World!" )
    if thread_h == nil then print( result) return end
@End]]
function thread:yield()
    local fname = "thread:yield()"
    local errorMsg = nil

    local beforeYieldTicks = ACCUMULATED_TICKS

    coroutine.yield()
    local H = getCallerHandle()
    if H == nil then 
        errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname)
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg 
    end

    H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    local numYieldTicks = ACCUMULATED_TICKS - beforeYieldTicks
    H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + numYieldTicks
    beforeYieldTicks = 0
end

--[[@Begin
Title: Suspends the calling thread until it receives a SIG_WAKEUP
signal.
Signature: thread:sleep()
Description: Suspends a thread for an indeterminate time.
Note, like thread:yield() or thread:delay(), this call doesn't 
return until awakened by receipt of a SIG_WAKEUP signal.
Thread context is required.
Parameters:
- None
Returns:
- None
Usage:
@End]]
function thread:sleep()
    local fname = "thread:sleep()"
    local errorMsg = nil

    local H, errorMsg = getCallerHandle()
    if H == nil then -- we're the WoW client.
        errorMsg = sprintf("%s - %s in %s.\n", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg
    end
    putToSleep(H)
end

--[[@Begin
Title: Get the handle of the calling thread
Signature: thread_h, errorMsg = thread:getSelf()
Description: Gets the handle of the calling thread.
Parameters:
- None
Returns:
- If successful: returns a thread handle
- If failure: 'nil' is returned along with an error message (string)
Usage:
@End]]
function thread:getSelf()
    local fname = "thread:getSelf()"
    local isValid = true
    local errorMsg = nil
    
    local H = getCallerHandle()
    if H == nil then 
        errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), errorMsg, fname)
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg 
    end
    return H, nil
end

--[[@Begin
Title: Obtain the numerical Id of the specified thread
Signature: threadId, errorMsg = thread:getId( thread_h )
Description: Obtains the numerical Id of the calling thread. Thread context
required.
Parameters:
- thread_h (handle):
Returns:
- If successful: returns the numerical Id of the thread.
- If failure: 'nil' is returned along with an error message (string)
Usage:
    local threadId, errorMsg = thread:getId()
    if threadId == nil then print( result) return end
@End]]
function thread:getId(thread_h)
    local fname = "thread:getId()"
    local isValid = true
    local errorMsg = nil

    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = sprintf("%s - %s in %s.",utils:dbgPrefix(), errorMsg, fname)
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, errorMsg
        end
    else -- input handle (thread_h) was nil.
        thread_h = getCallerHandle()
        if thread_h == nil then 
            errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, errorMsg
        end
    end
    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
Title: Check if two threads are equal
Signature: local equal, errorMsg = thread:areEqual( H1, H2 )
Description: Determines whether two thread handles are identical. Thread context
required.
Parameters: 
- H1 (handle): a thread handle
- H2 (handle); a thread handle
Returns: 
- If successful: returns 'true'
- If failure: returns 'false' and an error message (string)
Usage:
    local equal, errorMsg = thread:areEqual( H1, H2 )
    if equal == nil then print( result) return end
@End]]
function thread:areEqual(H1, H2)
    local fname = "thread:areEqual()"
    local isValid = true
    local errorMsg = nil
    
    -- check that neither handle is nil
    if H1 == nil or H2 == nil then
        errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), L["HANDLE_NIL"], fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg
    end

    -- check that neither handle is invalid
    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg
    end
    isValid, errorMsg = handleIsValid(H2)
    if not isValid then
        errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return nil, errorMsg
    end

    -- handles are not nil and they are both valid
    return H1[TH_UNIQUE_ID] == H2[TH_UNIQUE_ID]
end

--[[@Begin
Title: Obtains the handle of the specified thread's parent
Signature: parent_h, errorMsg = thread:getParent( thread_h )
Description: Gets the specified thread's parent. Thread context required.
Parameters
- thread_h (handle): if nil, then the calling thread's parent is returned.
Returns
- If successful: returns the handle of the parent thread
- If failure: 'nil' is returned and an error message (string)
Usage:
    local parent_h, errorMsg = thread:getParent( thread_h )
    if parent_h == 'nil' then print( result) return end
@End]]
function thread:getParent(thread_h)
    local fname = "thread:getParent()"
    local isValid = true
    local errorMsg = nil

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, fname )
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, errorMsg
        end
    else
        thread_h = getCallerHandle()
        if thread_h == nil then -- we're the WoW client.
            errorMsg = sprintf("%s - %s in %s.\n", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, errorMsg
        end
    
    end
    return thread_h[TH_PARENT]
end

--[[@Begin
Title: Obtain a table of handles of the specified thread's children.
Signature: children, errorMsg thread:getChildThreads( thread_h )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- If successful: returns a table of thread handles and a count of the number of children
- If failure: 'nil' and 'nil' are returned and an error message (string) i.e.,
- Error returns: nil, nil, errorMsg.
Usage:
    local threadTable, childCounterrorMsg = thread:getChildThreads( thread_h )
    if threadTable == 'nil' then print( errorMsg ) return end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        local isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, fname )
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            return nil, nil, errorMsg
        end
    else -- the argument is non-nil
        local H = getCallerHandle()
        if H == nil then 
            errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), errorMsg, fname)
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, nil, errorMsg 
        end
    end

    return thread_h[TH_CHILDREN], #thread_h[TH_CHILDREN], errorMsg
end

--[[@Begin
Title: Get a Thread's State
Descripture: Obtain the specified thread's execution state.
Signature: state, errorMsg = thread:getState( thread_h )
Description: Gets the state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.
Parameters:
- thread_h (handle): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.
Returns: 
- If successful: returns the state ("suspended", "running", or "dead") of the 
specified thread.
- If failure: returns 'false' and an error message (string)
Usage:
    local state, errorMsg = thread:getState( thread_h )
    if state == 'nil' then print( errorMsg ) return end
@End]]
function thread:getState(thread_h)
    local fname = "thread:getState()"
    local wasSent = true
    local errorMsg = nil

    if thread_h ~= nil then
        local wasSent, errorMsg = handleIsValid(thread_h)
        if not wasSent then
            local func = "getState( thread_h)"
            errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), errorMsg, func )
            -- thread:reportError( ADDON_NAME,  errorMsg )
            -- error( errorMsg )
            return nil, errorMsg
        end
        if thread_h == nil then 
            errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), errorMsg, fname)
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            -- error( errorMsg )
            return nil, errorMsg 
        end
    end

    local status = coroutine.status(H[TH_COROUTINE])
    return status, nil
end

--[[@Begin
Title: Signal another thread.
Signature: status, errorMsg = thread:sendSignal( target_h, signaValue,[,data] )
Description: Sends a signal to the specified thread. Thread context NOT required.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): signal to be sent.
- data (any) Data (including functions) to be passed to the receiving thread
Returns:
    If successful, SIG_SUCCESS, nil is returned.
    If not successful, SIG_FAILURE, error message is returned. If 
    the call failed because the target thread is dead, then SIG_THREAD_DEAD, nil
    is returned. In other words, signaling a dead thread is not fatal. What happens
    when a dead thread is signaled is up to the developer.
Usage:
    -- Sending a signal to a dead thread is not fatal.
    local status, errorMsg = thread:sendSignal( target_h, signalValue, data )
    if status == SIG_FAILURE then 
        error( errorMsg )
        return 
    end
    if status == SIG_THREAD_DEAD then
        print( "thread was dead" )
    end


@End]]
function thread:sendSignal( target_h, signal, data )
    local fname = "thread:sendSignal()"
    local wasSent = true
    local errorMsg = nil
    local sigName = nil
    local isDead = false

    if target_h == nil then
        local sigName, errorMsg = signalNameTable[signal]
        errorMsg = sprintf("%s - %s in %s. Attempt to send %s\n", utils:dbgPrefix(), L["HANDLE_NIL"], fname, sigName )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        return SIG_FAILURE, errorMsg
    end

    if signal == SIG_NONE_PENDING then
        errorMsg = sprintf("%s - %s in %s.\n", utils:dbgPrefix(), L["SIGNAL_INVALID_OPERATION"], fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        return SIG_FAILURE, errorMsg
    end
    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then 
        errorMsg = sprintf("%s - %s in %s\n", utils:dbgPrefix(), errorMsg, fname )
        -- thread:reportError( ADDON_NAME, errorMsg ) 
        -- error( errorMsg )
        return SIG_FAILURE, errorMsg
    end
    local state = coroutine.status( target_h[TH_COROUTINE])
    if state == "dead" then
        local st = utils:parseStackTrace( debugstack(2))
        local threadId = sprintf("Thread[%d]", target_h[TH_UNIQUE_ID])
        errorMsg = sprintf("%s - %s in %s.", utils:dbgPrefix(), L["THREAD_STATE_DEAD"], fname )
        -- thread:reportError( ADDON_NAME,  errorMsg ) 
        return SIG_THREAD_DEAD, errorMsg
    end

    -- get the identity of the calling thread. This will be nil
    -- if the calling thread is the WoW Client.
    local sender_h = getCallerHandle()

    -- Initialize and insert an entry into the recipient thread's signalTable
    local sigEntry = {signal, sender_h, data }

    -- inserts the entry at the head of the queue.
    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)
    local numSigs = target_h[TH_SIGNAL_QUEUE]:size()

    if signal == SIG_ALERT then
        target_h[TH_REMAINING_TICKS] = 1
    end
    return SIG_SUCCESS, nil
end

--[[@Begin
Title: Get a signal, if present.
Description: The queue of a thread's signals is FIFO. So, getting a signal means 
gets the first signal in the calling thread's signal queue. In other words, then
signal that has been in the queue the longest. Thread context is required.
Signature: status, errorMsg = thread:getSignal()
Description: Sends a signal to the specified thread.
Parameters:
- target_h (handle): the thread to which the signal is to be sent.
- signal (number) signal to be sent.
Returns
- If successful: returns a signal entry, i.e., entry = {signal, sender_h, data}.
In other words, a table entry. The entry consists of a signal value, the handle of the sending thread, and
data. The sending thread's handle will be nil if sent from the WoW client.
- If failure: 'nil' is returned along with an error message (string)
Usage:
    local signal, errorMsg = thread:getSignal()
    if signal == nil then print( errorMsg ) return end
    signalValue, sender_h, data = signal[1], signal[2], signal[3]
@End]]

function thread:getSignal()
    local fname = "thread:getSignal()"
    local errorMsg = nil

    -- utils:dbgPrint()
    local H = getCallerHandle()
    if H == nil then 
        errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), L["THREAD_CONTEXT_REQUIRED"], fname)
        thread:reportError( ADDON_NAME,  errorMsg ) 
        -- error( errorMsg )
        -- utils:dbgPrint()
        return nil, errorMsg 
    end
    -- utils:dbgPrint( H[TH_UNIQUE_ID])

    -- Check if there is an entry in the caller's signalQueue.
    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        -- utils:dbgPrint("No signals in queue.")
        return {SIG_NONE_PENDING, nil, nil }
    end

    -- utils:dbgPrint(H[TH_SIGNAL_QUEUE]:size(), " signals in queue.")
    local entry = H[TH_SIGNAL_QUEUE]:dequeue()
    -- utils:dbgPrint(H[TH_SIGNAL_QUEUE]:size(), " signals in queue.")
    local signalName = signalNameTable[entry[1]]

    -- utils:dbgPrint( entry[3])
    return entry, nil
end

--[[@Begin
Title: Get the name of a signal
Signature: signalName, errorMsg = thread:getSignalName( signal )
Description: Gets the string name of the specified signal value. Thread context
not required.
Parameters:
- signal (number): the signal
Returns:
- If successful: returns the name of the signal value
- If failure: returns 'nil' and an error message(string)
Usage:
    local signalName, errorMsg = thread:getSignalName( signal )
    if signalName == nil then print( errorMsg ) return end
@End ]]
function thread:getSignalName(signal)
    local fname = "thread:getSignalName()"
    local errorMsg = nil
    local isValid = true

    isValid, errorMsg = signalIsValid( signal )
    if not isValid then
        errorMsg = sprintf("%s - %s in %s\n", utils:dbgPrefix(), errorMsg, fname )
        -- thread:reportError( ADDON_NAME, errorMsg )
        -- error( errorMsg )
        return nil, errorMsg
    end

    return signalNameTable[signal]
end

--[[@Begin
Title: Get a count of the number of signals pending in a thread's 
signal queue.
Signature: signalCount, errorMsg = thread:getSigCount( thread_h )
Description: Gets the number of signals in the calling thread's signal queue.
Parameters:
- thread_h (number): The number of pending signals in the specified
thread's signal queue
Returns:
- If successful: returns the number of pending signals
- If failure: returns 'nil' and an error message(string)
Usage:
    local sigCount, errorMsg = thread:getSigCount( thread_h )
    if signalCount == nil then print( errorMsg ) return end
@End ]]
function thread:getSigCount( thread_h )
    local errorMsg = nil
    local fname = "thread:getSigCount()"
    local H = nil

    if thread_h == nil then
        thread_h = getCallerHandle()
        if thread_h == nil then 
            errorMsg = sprintf("%s - %s in %s", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname)
            -- thread:reportError( ADDON_NAME,  errorMsg ) 
            error( errorMsg )
            return nil, errorMsg
        end
    end
    return thread_h[TH_SIGNAL_QUEUE]:size(), nil
end
--[[@Begin
Title: Register a callbackFunc function with the WoWThreads Library.
Signature: thread:registerCallback( addonName, callbackFuncFunc )
Description: Allows an addon client to register a callbackFunc function to be
invoked when an error occurs in WoWThreads. WoWThreads will then pass the 
error message back to then addon through the callbackFunc function.
Parameters:
- addonName (string): the name of the addon
- callbackFunc (function): the callbackFunc function
Returns:
- None
Usage:
@End]]
function thread:registerCallback( addonName, callbackFunc )

    if type(addonName) ~= "string" then
        error("Invalid addon name")
    end
    if type(callbackFunc) ~= "function" then
        error("Invalid callback function")
    end   
    errorCallbackTable[addonName] = callbackFunc
end
-- ------------------------- MANAGEMENT INTERFACE --------------------
-- local function thread:getCongestion(thread_h)
--     local threadId          = thread_h[TH_UNIQUE_ID]
--     local suspendedTicks    = thread_h[TH_ACCUM_YIELD_TICKS]
--     local lifetimeTicks     = thread_h[TH_LIFETIME_TICKS]
--     local yieldCount        = thread_h[TH_YIELD_COUNT]

--     local runtimeTicks  = lifetimeTicks - suspendedTicks
--     local yieldInterval     = thread_h[TH_DURATION_TICKS]
--     idealTotalYieldTicks    = yieldCount * yieldInterval
--     realTotalYieldTicks     = yieldCount * suspendedTicks

--     efficiency = idealTotalYieldTicks - (1 - (idealTotalYieldTicks) / realTotalYieldTicks)

--     local entry = {}

--     return entry
-- end
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
