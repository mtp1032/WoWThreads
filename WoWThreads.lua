----------------------------------------------------------------------------------------
-- FILE NAME:		WoWThreads.Lua
-- ORIGINAL DATE:   14 March, 2023
----------------------------------------------------------------------------------------
local ADDON_NAME, WoWThreads = ...

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

L = EnUSlib.L

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

local THREAD_SEQUENCE_ID = 4
local ACCUMULATED_TICKS = 0
local threadControlBlock = {}
local morgue = {}
local CLOCK_INTERVAL = 1/GetFramerate()
local WoWThreadsStarted = false

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

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
thread.SIG_ALERT            = 1
thread.SIG_JOIN_DATA_READY  = 2
thread.SIG_HIBERNATE        = 3
thread.SIG_TERMINATE        = 4
thread.SIG_METRICS          = 5
thread.SIG_STOP             = 6
thread.SIG_NONE_PENDING     = 7

local SIG_ALERT             = thread.SIG_ALERT
local SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
local SIG_HIBERNATE         = thread.SIG_HIBERNATE
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_METRICS           = thread.SIG_METRICS
local SIG_STOP              = thread.SIG_STOP
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local signalNameTable = {
    "SIG_ALERT",
    "SIG_JOIN_DATA_READY",
    "SIG_HIBERNATE",
    "SIG_TERMINATE",
    "SIG_METRICS",
    "SIG_STOP",
    "SIG_NONE_PENDING"
}

-- =======================================================================
-- *                    LOCAL FUNCTIONS                                  =
-- =======================================================================

-- Table to hold registered callback functions.
local errorCallbackTable = {}

-- Function to invoke callbacks on error
local function reportErrorToClient(addonName, errorMessage)
    local H = getCallerHandle()
    if H ~= nil then
        local prefix = sprintf("Thread[%d]", H[TH_UNIQUE_ID] )
        local str1 = sprintf("%s - %s\n", prefix, errorMessage )
        errorMessage = str1
    end

    if errorCallbackTable[addonName] and 
    type(errorCallbackTable[addonName]) == "function" then
        errorCallbackTable[addonName](errorMessage)
    else
        print("Error: No valid error callback registered for addon: " .. addonName)
    end
end

local function getCallerHandle()
    -- only one thread can be "running"
    for _, H in ipairs(threadControlBlock) do
        local state = coroutine.status(H[TH_COROUTINE])
        if state == "running" then
            return H, H[TH_UNIQUE_ID]
        end
    end
    -- if we're here, it's because the WoW Client has issued
    -- this call. That's why there is not A "running" thread
    -- in the TCB.
    return nil, L["NO_THREAD_CONTEXT"]

end
local function createHandle(durationTicks, threadFunction )

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

    local parent_h, parentId = getCallerHandle()
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
-- Throws an error if the checks fail
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
        local threadId = H[TH_UNIQUE_ID]
        local s = sprintf("%s", L["INVALID_EXE_STATE"], threadId, state )
        errorMsg = sprintf("%s %s in %s ", utils:dbgPrefix(), s , fname )
        isValid = false
    end
    return isValid, errorMsg
end
local function signalInRange(signal)
    local isValid = true

    if signal < SIG_ALERT then
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

    if type(signal) ~= "number" then 
        isValid = false
        errorMsg = L["INVALID_TYPE"]
        return isValid, errorMsg
    end  

    isValid, errorMsg = signalInRange( signal )
    return isValid, errorMsg
end
local function moveToMorgue( H )
    local i = 1
    while i <= #threadControlBlock do
        local H = threadControlBlock[i]
        if status == "dead" then
            H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]
            table.remove(threadControlBlock, i)
            table.insert(morgue, H)
        end
    end
end
local function scheduleThreads()
    ACCUMULATED_TICKS = ACCUMULATED_TICKS + 1

    local i = 1
    while i <= #threadControlBlock do
        local H = threadControlBlock[i]
        local status = coroutine.status(H[TH_COROUTINE])
        if status == "dead" then
            H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]
            table.remove(threadControlBlock, i)
            table.insert(morgue, H)
        
        elseif status == "suspended" then
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1

            if H[TH_REMAINING_TICKS] == 0 then
                H[TH_REMAINING_TICKS] = H[TH_DURATION_TICKS]
                status, result = coroutine.resume( H[TH_COROUTINE])
                if not status then
                    H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]
                    table.remove(threadControlBlock, i)
                    table.insert(morgue, H)        
                    reportErrorToClient( H[TH_ADDON_NAME], result )
                end
            end
        end
        i = i + 1
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
local function insertHandleIntoTCB(H)
    table.insert(threadControlBlock, H)
    return #threadControlBlock
end
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
Signature: status, errorMsg = thread:create( yieldTicks, threadFun,... )
Description: Creates a reference to an executable thread called a 
thread handle. The thread handle is implemented as a table of thread 
attributes, including the reference to the actual executable thread 
(coroutine).
Parameters:
- yieldTicks (number). The time, in clock ticks, the thread is to 
suspend itself when it calls thread:yield(). A clock tick is the 
reciprocal of your computer's framerate multiplied by 1000. On my 
system a clock tick is about 16.7 milliseconds where 60 ticks is 
about 1 second.
- threadFunc (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs), Additional arguments to be passed to the thread function.
Returns:
- If successful, Returns a thread handle.
- If failure, Returns nil and an error message
Usage:
    local thread_h, result = thread:create( 60, helloWorld, "Hello World" )
    if thread_h ~= nil then print( result) return end
@End]]
function thread:create( yieldTicks, threadFunction, ... )
    local errorMsg = nil
    local fname = "thread:create()"

    if utils:debuggingIsEnabled() then
        if type(yieldTicks) ~= "number" then
            local stack = debugstack(2)
            local simpleStack = utils:simplifyStacktrace( stack )
            errorMsg = sprintf("%s %s expected number in %s, got %s", utils:dbgPrefix(), L["INVALID_TYPE"], fname, type(ticks))
            return nil, errorMsg
        end
        if threadFunction == nil then
            return nil, L["INPUT_PARM_NIL"]
        end
        if type(threadFunction) ~= "function" then
            local stack = utils:simplifyStacktrace( debugstack(2))
            errorMsg = sprintf("%s %s expected function in %s, got %s", utils:dbgPrefix(), L["INVALID_TYPE"], func, tostring( type(threadFunction )))
            return nil, L["INVALID_TYPE"]
        end
    end
    -- Create a handle with a suspended coroutine
    local H = createHandle(yieldTicks, threadFunction)

    insertHandleIntoTCB(H)
    local status, result = coroutine.resume(H[TH_COROUTINE], ...)
    if not status then
        reportErrorToClient( ADDON_NAME, result )
        return nil, result
    end
    return H, nil
end

--[[@Begin
Title: Suspend a Thread's Execution
Signature: thread:yield()
Description: Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the thread's create function used to create the thread. 
Thread context required, 
Parameters:
- None
Returns:
- None
Usage:
    -- This is the function executed by the thread created below and prints the
    -- the greeting 3 times.
    local function helloWorld( greeting )
        local DONE = false
        local count = 1
        while not DONE do
            thread:yield()
            print( greeting )
            if count == 3 then
                DONE = false
            else
                print( greeting)
            end
        end
    end
    -- Create a thread to execute the helloWorld action routine.
    local thread_h, result = thread:create( 60, helloWorld, "Hello World!" )
    if thread_h == nil then print( result) return end
@End]]
function thread:yield()
    local beforeYieldTicks = ACCUMULATED_TICKS


    coroutine.yield()

    local H = getCallerHandle()
    H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    local numYieldTicks = ACCUMULATED_TICKS - beforeYieldTicks
    H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + numYieldTicks
    beforeYieldTicks = 0
end

--[[@Begin
Title: Suspend a thread's execution for a specified number of ticks
Signature: thread:delay( delayTicks )
Description: Delays a thread by the specified number of ticks. Thread 
context required.
Parameters:
- delayTicks (number): the number of ticks to delay before continuing
Returns:
- None
Usage:
@End]]
function thread:delay(delayTicks)
    local H = getCallerHandle()
    H[TH_REMAINING_TICKS] = delayTicks + H[TH_REMAINING_TICKS]
    coroutine.yield()
end

--[[@Begin
Title: Get the handle of the calling thread
Signature: thread_h, result = thread:getSelf()
Description: Gets the handle of the calling thread.
Parameters:
- None
Returns:
- If successful: returns a thread handle
- If failure: 'nil' is returned along with an error message (string)
Usage:
@End]]

function thread:getSelf()
    local errorMessage = L["NO_THREAD_CONTEXT"]
    local H =getCallerHandle()
    if H == nil then return nil, errorMessage end
    return H, nil
end

--[[@Begin
Title: Obtain the numerical Id of the specified thread
Signature: threadId, result = thread:getId( thread_h )
Description: Obtains the numerical Id of the calling thread. Thread context
required.
Parameters:
- thread_h (handle):
Returns:
- If successful: returns the numerical Id of the thread.
- If failure: 'nil' is returned along with an error message (string)
Usage:
    local threadId, result = thread:getId()
    if threadId == nil then print( result) return end
@End]]
function thread:getId(thread_h)
    local threadId = nil
    local isValid = true
    local errorMsg = nil
    local fname = "thread:getId()"

    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = sprintf("%s %s in %s.",utils:dbgPrefix(), errorMsg, fname)
            return nil, errorMsg
        end
    else -- input handle (thread_h) was nil.
        thread_h = getCallerHandle()
        if thread_h == nil then 
            errorMessage = sprintf("%s %s in %s.", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
            return nil, errorMsg
        end
    end
    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
Title: Check if two threads are equal
Signature: local equal, result = thread:areEqual( H1, H2 )
Description: Determines whether two thread handles are identical. Thread context
required.
Parameters: 
- H1 (handle): a thread handle
- H2 (handle); a thread handle
Returns: 
- If successful: returns 'true'
- If failure: returns 'false' and an error message (string)
Usage:
    local equal, result = thread:areEqual( H1, H2 )
    if equal == nil then print( result) return end
@End]]
function thread:areEqual(H1, H2)
    local errorMsg = nil
    local fname = "thread:areEqual()"

    -- check that neither handle is nil
    if H1 == nil or H2 == nil then
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), L["HANDLE_NIL"], fname )
        return nil, errorMsg
    end

    -- check that neither handle is invalid
    isValid, errorMsg = handleIsValid(H1)
    if not isValid then
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    isValid, errorMsg = handleIsValid(H2)
    if not isValid then
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, fname )
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
    local parent_h, result = thread:getParent( thread_h )
    if parent_h == 'nil' then print( result) return end
@End]]
function thread:getParent(thread_h)
    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "getParentThread( thread_h)"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end
    return thread_h[TH_PARENT]
end

--[[@Begin
Title: Obtain a table of handles of the specified thread's children.
Signature: children, result thread:getChildThreads( thread_h )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- If successful: returns a table of thread handles.
- If failure: 'nil' is returned and an error message (string)
Usage:
    local threadTable, result = thread:getChildThreads( thread_h )
    if threadTable == 'nil' then print( result ) return end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil
    local isValid = false

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, fname )
            error( errorMsg )
        end
    else
        thread_h, errorMsg = getCallerHandle()
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, fname )
    end
    return thread_h[TH_CHILDREN]
end

--[[@Begin
Title: Get a Thread's State
Descripture: Obtain the specified thread's execution state.
Signature: state, result = thread:getState( thread_h )
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
    local state, result = thread:getState( thread_h )
    if state == 'nil' then print( result ) return end
@End]]
function thread:getState(thread_h)
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "getState( thread_h)"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end

    local status = coroutine.status(H[TH_COROUTINE])
    return status
end

--[[@Begin
Title: Signal another thread.
Signature: status, result = thread:sendSignal( target_h, signaValue, ... )
Description: Sends a signal to the specified thread. Thread context NOT required.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): signal to be sent.
- ... (varargs): Data to be passed to the receiving thread
Returns:
- If successful, Returns true
- If failure, 'nil' is returned and an error message as a string
Usage:
    local status, result = thread:sendSignal( thread_h, SIG_ALERT )
    if not status then print( result ) return end
@End]]
function thread:sendSignal( target_h, signal, ...)
    local isValid = true
    local errorMsg = nil
    local fname = "thread:sendSignal()"
    local args = {...}

    if target_h == nil then
        errorMsg = sprintf("%s %s in %s.\n", utils:dbgPrefix(), L["HANDLE_NOT_SPECIFIED"], fname )
        return false, errorMsg
    end

    if coroutine.status( target_h[TH_COROUTINE]) == "dead" then
        isValid = false
        errorMsg = sprintf("%s %s in %s.\n", utils:dbgPrefix(), L["SIGNAL_NOT_DELIVERED"], fname )
    end

    -- get the identity of the calling thread. This will be nil
    -- if the calling thread is the WoW Client.
    local sender_h = getCallerHandle()
 
    -- Initialize and insert an entry into the recipient thread's signalTable
    local signalEntry = {signal, sender_h, ... }
    
    -- inserts the entry at the head of the queue.
    target_h[TH_SIGNAL_QUEUE]:enqueue(signalEntry)
    return isValid, errorMsg
end

--[[@Begin
Title: Get a signal, if present.
Description: The queue of a thread's signals is FIFO. So, getting a signal means 
gets the first signal in the calling thread's signal queue. In other words, then
signal that has been in the queue the longest. Thread context is required.
Signature: status, result = thread:getSignal()
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
    local signal, result = thread:getSignal()
    if signal == nil then print( result ) return end
    signalValue, sender_h, data = signal[1], signal[2], signal[3]
@End]]
function thread:getSignal()
    local fname = "thread:getSignal()"
    local isValid = true
    local errorMsg = nil

    local H = getCallerHandle()
    if H == nil then -- we're the WoW client.
        errorMsg = sprintf("%s %s in %s.\n", utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end

    -- Check if there is an entry in the caller's signalQueue.
    if not H[TH_SIGNAL_QUEUE]:isEmpty() then
        local entry = H[TH_SIGNAL_QUEUE]:dequeue() -- Get the first signal entry in the signal queue
        return entry
    end
    return {SIG_NONE_PENDING, nil, nil }
end

--[[@Begin
Title: Get the name of a signal
Signature: signalName, result = thread:getSignalName( signal )
Description: Gets the string name of the specified signal value. Thread context
not required.
Parameters:
- signal (number): the signal
Returns:
- If successful: returns the name of the signal value
- If failure: returns 'nil' and an error message(string)
Usage:
    local signalName, result = thread:getSignalName( signal )
    if signalName == nil then print( result ) return end
@End ]]
function thread:getSignalName(signal)
    local fname = "thread:getSignalName()"
    local errorMsg = nil
    local isValid = true

    if signal == nil then
        isValid = false
        errorMsg = L["INPUT_SIGNAL_NIL"]
        return isValid, errorMsg
    end

    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then
        errorMsg = sprintf("%s %s in %s", utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    return signalNameTable[signal], nil
end
--[[@Begin
Title: Register a callback function with the WoWThreads Library.
Signature: thread:registerCallback( addonName, callbackFunc )
Description: Allows an addon client to register a callback function to be
invoked when an error occurs in WoWThreads. WoWThreads will then pass the 
error message back to then addon through the callback function.
Parameters:
- addonName (string): The name of the addon that is registering the callback.
- callbackFunc (function): The function that sends the error message back tonumber
the addon. 
Returns:
- If successful: returns true
Usage:
@End]]
function thread:registerCallback( addonName, callback )
    errorCallbackTable[addonName] = callback
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
    local addonName = ...

    if event == "ADDON_LOADED" and ADDON_NAME == addonName then

        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_MESSAGE"], 0.0, 1.0, 1.0 )
        DEFAULT_CHAT_FRAME:AddMessage( L["CLOCK_INTERVAL"], 0.0, 1.0, 1.0 )
        eventFrame:UnregisterEvent("ADDON_LOADED")

        WoWThreadLibInit()
    end
    return
end
eventFrame:SetScript("OnEvent", OnEvent)


if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage(fileName, 0.0, 1.0, 1.0)
end
