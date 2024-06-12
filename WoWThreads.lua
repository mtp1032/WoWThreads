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
local TH_PARENT             = 10
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
local function isCallerClient( H )
    local isWowClient = false
    if H[TH_PARENT] == nil then
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

    for i = 1, #threadControlBlock do
        local running_h = threadControlBlock[i]
        local co = running_h[TH_COROUTINE]
        local status = coroutine.status( co )
        if status == "running" then
            return running_h, nil
        end
    end
    return nil, L["NO_THREAD_CONTEXT"]
end
local function getAddonName( thread_h )
    if thread_h == nil then
        thread_h = getCallerHandle()
    end
    return thread_h[TH_CLIENT_ADDON]
end
local function formatErrorMsg( errorMsg, functionName, stackTrace )
    local st = utils:simplifyStackTrace( stackTrace )
    errorMsg = string.format("%s in %s. %s\n ", errorMsg, functionName, st )
    return errorMsg
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
    H[TH_REMAINING_TICKS]   = H[TH_YIELD_TICKS]
    H[TH_ACCUM_YIELD_TICKS] = 0
    H[TH_LIFETIME_TICKS]    = 0
    H[TH_YIELD_COUNT]       = 0
    H[TH_CLIENT_ADDON]      = addonName

    H[TH_CHILDREN]  = {}
    H[TH_PARENT]    = nil
    H[TH_COROUTINE_ARGS] = {...}

    local parent_h = getCallerHandle()
    if parent_h ~= nil then
        -- This handle will be he child of the running thread.
        table.insert(parent_h[TH_CHILDREN], H)
        H[TH_PARENT] = parent_h
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

    -- if it's already sleeping then return nil, errorMsg
    for i, entry in ipairs(threadSleepTable) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            isSleeping = true
            local errorMsg = string.format("Thread is already sleeping" )
            return nil, errorMsg
        end
    end
    -- if the thread is in the TCB then remove it
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            if utils:debuggingIsEnabled() then
                local msg = string.format("thread[%d] removed from TCB", H[TH_UNIQUE_ID])
                utils:dbgLog( msg, debugstack(2) )
            end
            inTCB = true
            break
        end
    end

    -- if the thread wasn't in the TCB then return nil, errorMsg
    if not inTCB then
        local errorMsg = string.format("Thread[%d] not found in thread control block", H[TH_UNIQUE_ID])
        if utils:debuggingIsEnabled() then
            utils:dbgLog( errorMsg, debugstack(2) )
        end
        return nil, errorMsg
    end

    -- thread is ready to be entered into the thread sleep table.
    table.insert(threadSleepTable, H)
    if utils:debuggingIsEnabled() then
        local msg = string.format("Thread[%d] entered into the thread sleep table. ", H[TH_UNIQUE_ID])
        utils:dbgLog( msg, debugstack(2) )
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
local function reformatErrorStr(originalStr)
    -- Use pattern matching to find the position of the colon followed by a number
    local firstColon = originalStr:find(":%d")
    if not firstColon then
        return originalStr -- If there is no colon followed by a number, return the original string
    end
    
    -- Find the position of the second colon
    local secondColon = originalStr:find(": ", firstColon + 1)
    if not secondColon then
        return originalStr -- If there is no second colon, return the original string
    end
    
    -- Extract the substrings based on the positions found
    local secondString = originalStr:sub(1, secondColon - 1)
    local firstString = originalStr:sub(secondColon + 2)

    -- Format the new string with the first and second parts swapped and separated by a newline
    return string.format("[ERROR] %s\nSee - %s\n", firstString, secondString)
end
local function scheduleThreads()
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
                    errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
                    utils:dbgPrint( "pcallSucceeded", errorMsg )
                    moveToMorgue(H)
                    -- errorHandler( H[TH_CLIENT_ADDON], errorMsg )
                end
                if not coroutineResumed then
                    errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
                    utils:dbgPrint( "coroutineResumed", errorMsg )
                    moveToMorgue(H)
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
Signature: thread_h, errorMsg = thread:create( addonName, yieldTicks, addonName, func,... )
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
- If successful, Returns a thread handle and the thread's Id.
- If failure, Returns nil. The error message describes the error
and its location.
Usage:
    local function greetings( greetingString )
        print( greetingString )
    end
    local thread_h, errorMsg = thread:create( 60, greetings, "Hello World" )
    if thread_h ~= nil then print( result) return end
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

    if not isCallerClient(H) then
        isValid, errorMsg = handleIsValid(H)
        if not isValid then
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, errorMsg
        end
    end

    table.insert( threadControlBlock, H )
    return H, nil
end

--[[@Begin 
Signature: addonName, errorMsg = thread:getAddonName( thread_h )
Description: Obtains the name of the addon within which the specified
thread was created.
Parameters:
- thread_h (thread handle). A handle to the thread whose addon name is to be 
obtained. If nil, the addon name of the calling thread is retreived.
Returns:
- If successful, Returns the name of the specified thread's addon.
- If failure, Returns nil. The error message describes the error
and its location.
Usage:
    -- This function is typically used to get the name of the addon for use In
    -- invoking the error handler.
    local wasSent, errorMsg = thread:sendSignal( target_h, SIG_ALERT )
    if not wasSent then
        thread:invokeErrorHandler( thread:getAddonName(), errorMsg )
        return nil, errorMsg
    end
@End]]
function thread:getAddonName( thread_h )
    return getAddonName( thread_h )
end

--[[@Begin
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
    -- A simple function that waits for a signal signal.
    local function waitForSignal( signal )
        local DONE = false
        while not DONE do
            thread:yield()
            local sigEntry, errorMsg = thread:getSignal()
            if not sigEntry then
                thread:invokeErrorHandler( thread:getAddonName(), errorMsg )
                return nil, errorMsg
            end
            if sigEntry[1] == SIG_ALERT then
                < do something >
                DONE = true
            end 
        end
    end
    -- Create a thread to execute the waitForSignal function.
    local thread_h, errorMsg = thread:create( 60, waitForSignal, signal )
    if thread_h == nil then print( result) return end
@End]]
function thread:yield()
    local fname = "thread:yield()"

    local H, errorMsg = getCallerHandle()
    if H == nil then
        return nil, errorMsg
    end
    local beforeYieldTicks = ACCUMULATED_TICKS

    coroutine.yield()
    local H, errorMsg = getCallerHandle()
    if H == nil then 
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        if utils.stack then
            error(string.format("FATAL: Addon terminated: %s\n", errorMsg ))
        end
    end

    H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    local numYieldTicks = ACCUMULATED_TICKS - beforeYieldTicks
    H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + numYieldTicks
    beforeYieldTicks = 0
end

--[[@Begin
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
    if H == nil then 
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        if utils:debuggingIsEnabled() then
            utils:dbgLog( errorMsg, debugstack(2) )
        end
        return nil, errorMsg 
    end
    return putToSleep(H)
end

--[[@Begin
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
    
    local H, errorMsg = getCallerHandle()
    if H == nil then 
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg 
    end
    return H, nil
end

--[[@Begin
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
    local threadId = nil

    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(H)
        if not isValid then
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, nil, errorMsg
        end
    else -- input handle (thread_h) was nil.
        thread_h, errorMsg = getCallerHandle()
        if thread_h == nil then 
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, errorMsg 
        end
    end
    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
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
    local areEqual = false
    local errorMsg = nil
    
    -- check that neither handle is nil
    if H1 == nil then
        errorMsg = string.format("%s",L["THREAD_HANDLE_NIL"])
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end
    if H2 == nil then
        errorMsg = string.format("%s",L["THREAD_HANDLE_NIL"])
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return areEqual, errorMsg
    end
    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return areEqual, errorMsg
    end
    isValid, errorMsg = handleIsValid(H2)
    if not isValid then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return areEqual, errorMsg
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
Signature: parent_h, errorMsg = thread:getParent( thread_h )
Description: Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent.
Parameters
- thread_h (handle): if nil, then the calling thread's parent is returned.
Returns
- If successful: returns the handle of the parent thread. However, if the
thread has no parent (i.e., was created by the WoW client, the the errorMsg
will be nil as well (e.g., to return nil, nil means no parent).
- If failure: 'nil' is returned and an error message (string)
Usage:
    local parent_h, errorMsg = thread:getParent( thread_h )
    if parent_h == 'nil' then 
        if errorMsg == nil then
            print( "specfied thread has no parent" ) 
        else
            print( errorMsg )
        end
        return
    end

@End]]
function thread:getParent(thread_h)
    local fname = "thread:getParent()"
    local isValid = true
    local errorMsg = nil

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, errorMsg
        else
            return nil, nil
        end
        return thread_h[TH_PARENT], errorMsg
    else
        local thread_h, errorMsg = getCallerHandle()
        if thread_h == nil then 
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, errorMsg 
        else
            return thread_h[TH_PARENT], errorMsg
        end
    end
    return thread_h[TH_PARENT], errorMsg
end

--[[@Begin
Signature: childTable, errorMsg thread:getChildThreads( thread_h )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- If successful: returns a table of thread handles.
- If failure: 'nil' is returned along with an error message (string) i.e.,
Usage:
    local childTable, errorMsg = thread:getChildThreads( thread_h )
    if childTable == 'nil' then print( errorMsg ) return end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        local isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, nil, errorMsg
        else -- the argument is non-nil
            thread_h, errorMsg = getCallerHandle()
            if thread_h == nil then 
                errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
                return nil, errorMsg 
            end
        end
    end
    return thread_h[TH_CHILDREN], errorMsg
end

--[[@Begin
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
    if thread_h == nil then 
        return "running", nil 
    end

    local status = coroutine.status( thread_h[TH_COROUTINE])
    return status, nil
end

--[[@Begin
Signature: status, errorMsg = thread:sendSignal( target_h, signaValue,[,data] )
Description: Sends a signal to the specified thread. Thread context NOT required.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): signal to be sent.
- data (any) Data (including functions) to be passed to the receiving thread.areEqual
- NOTE: WoWThreads assumes that the structure of the ... parameter is known to the
receiveing thread.
Returns:
- If successful, true is returned. This only means that the signal was delivered.
Programmers should make no assumptions about whether the signal was received.
- If not successful either the target thread was 'dead' or the signal was invalid.
If the target thread was 'dead', then the false is returned along with an error 
message to that effectIf the call failed for any other reason 
(e.g., an invalide signal), the nil is returned along with an appropriate error 
message.
Usage:
    -- Sending a signal to a dead thread is not fatal.
    local wasSent, errorMsg = thread:sendSignal( target_h, signalValue, data )
    if not wasSent then 
        print( errorMsg )
        return 
    end
@End]]
function thread:sendSignal( target_h, signal, ... )
    local fname = "thread:sendSignal()"
    local wasSent = true
    local errorMsg = nil
    local isValid = false
    local isWowClient = true

    -- check that the signal is valid
    if signal == SIG_NONE_PENDING then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end

    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then 
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end

    -- check that the target handle is valid
    if target_h == nil then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end

    isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end

    local isDead, errorMsg = isInMorgue( target_h )
    if isDead then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end
    -- Validity checks are complete.

    -- Initialize and insert an entry into the recipient thread's signalTable
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
Description: The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Thread
context is required.
Parameters:
- target_h (handle): the thread to which the signal is to be sent.
- signal (number) signal to be sent.
Returns:
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

    local H, errorMsg = getCallerHandle()
    if H == nil then 
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg 
    end
    
    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        return {SIG_NONE_PENDING, nil, nil }
    end

    local entry = H[TH_SIGNAL_QUEUE]:dequeue()
    local signalName = signalNameTable[entry[1]]

    return entry, nil
end

--[[@Begin
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
@End]]
function thread:getSignalName(signal)
    local fname = "thread:getSignalName()"
    local errorMsg = nil
    local isValid = true

    isValid, errorMsg = signalIsValid( signal )
    if not isValid then
        errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
        return nil, errorMsg
    end

    return signalNameTable[signal]
end

--[[@Begin
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
@End]]
function thread:getSigCount( thread_h )
    local fname = "thread:getSigCount()"
    local errorMsg = nil
    local H = nil

    if thread_h == nil then
        local thread_h, errorMsg = getCallerHandle()
        if thread_h == nil then 
            errorMsg = formatErrorMsg( errorMsg, fname, debugstack(2))
            return nil, errorMsg 
        end
    end
    return thread_h[TH_SIGNAL_QUEUE]:size(), nil
end

--[[@Begin
Signature: thread:invokeErrorHandler( addonName, errorMsg )
Description: Invokes a previously registered error callback function. This service
is useful for reporting applicable errors to code executing outside of not under
a thread context.
- addonName (string): The name of the addon in which the thread was created.
- errorMsg (string): An error message describing the error.
Returns:
- None
Usage:
    local sigEntry, errorMsg = thread:getSignal()
    if sigEntry == nil then 
        thread:invokeErrorHandler( addonName, errorMsg )
        return nil, errorMsg
    end
@End]]
function thread:invokeErrorHandler(addonName, errorMsg )
    threadCallback( addonName, errorMsg )
end

--[[@Begin
Signature: thread:registerErrorHandler( addonName, callbackHandler )
Description: Client addons can register an error callback function to be
called when an error occurs. The error callback function will be called with
the error message.
- addonName (string): The name of the addon in which the thread was created.
- callbackHandler (function): The error callback function.
Returns:
- None
Usage:
    local function callbackErrorHandler( addonName, errorMsg )
        print( errorMsg )
    end
    ...
    thread:registerErrorHandler( addonName, errorHandler )
@End]]
function thread:registerErrorHandler( addonName, callbackHandler )
    if not errorCallbackTable[addonName] then
        errorCallbackTable[addonName] = callbackHandler
        DEFAULT_CHAT_FRAME:AddMessage( string.format("Error handler registered for %s", addonName), 0.0, 1.0, 1.0)
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage( string.format("Error handler for %s could not be registered.", addonName), 0.0, 1.0, 1.0)
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
