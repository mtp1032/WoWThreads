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

local SUCCESS = true
local FAILURE = false

local DEFAULT_YIELD_TICKS = 5

local THREAD_SEQUENCE_ID = 4
local ACCUMULATED_TICKS = 0
local threadControlBlock = {}
local morgue = {}
local CLOCK_INTERVAL = 1 / GetFramerate() * 1000
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
local TH_STATUS             = 11 -- running, suspended, waiting, completed, failed

-- Metrics
local NUM_HANDLE_ENTRIES = TH_STATUS

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
thread.SIG_ALERT = 1
thread.SIG_JOIN_DATA_READY = 2
thread.SIG_HIBERNATE = 3
thread.SIG_TERMINATE = 4
thread.SIG_METRICS = 5
thread.SIG_STOP = 6
thread.SIG_NONE_PENDING = 7

local SIG_ALERT = thread.SIG_ALERT
local SIG_JOIN_DATA_READY = thread.SIG_JOIN_DATA_READY
local SIG_HIBERNATE = thread.SIG_HIBERNATE
local SIG_TERMINATE = thread.SIG_TERMINATE
local SIG_METRICS = thread.SIG_METRICS
local SIG_STOP = thread.SIG_STOP
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING

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
-- @returns running thread, threadId. nil, -1 if thread not found.
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
    return nil, nil
end
local function createHandle(ticks, threadFunction )

    if ticks < DEFAULT_YIELD_TICKS then
        ticks = DEFAULT_YIELD_TICKS
    end
    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1

    local H = {}    -- create an empty handle table, H

    H[TH_COROUTINE] = coroutine.create(threadFunction)
    H[TH_STATUS]    = coroutine.status(H[TH_COROUTINE])
    H[TH_UNIQUE_ID]         = THREAD_SEQUENCE_ID
    H[TH_SIGNAL_QUEUE]      = FifoQueue.new()
    H[TH_DURATION_TICKS]    = ticks
    H[TH_REMAINING_TICKS]   = ticks
    H[TH_ACCUM_YIELD_TICKS] = 0
    H[TH_LIFETIME_TICKS]    = 0
    H[TH_YIELD_COUNT]       = 0

    H[TH_CHILDREN]  = {}
    H[TH_PARENT]    = nil

    -- Metrics

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
        errorMsg = sprintf(L["INVALID_TYPE"], utils:dbgPrefix(), "table", type(H))
        isValid = false
    end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        errorMsg = sprintf("%s %s, Expected 'table', got %s\n", L["HANDLE_ILL_FORMED"], utils:dbgPrefix(), type[H[TH_SIGNAL_QUEUE]])
        isValid = false
    end
    if type(H[TH_COROUTINE]) ~= "thread" then
        errorMsg = sprintf("%s", L["HANDLE_NOT_A_THREAD"], utils:dbgPrefix())
        isValid = false
    end

    local state = coroutine.status(H[TH_COROUTINE])
    if state == "dead" then
        local threadId = H[TH_UNIQUE_ID]
        errorMsg = sprintf(L["INVALID_EXE_STATE"], utils:dbgPrefix(), threadId, state)
        isValid = false
    end
    return isValid, errorMsg
end
local function signalInRange(signal)
    local isValid = true

    if signal < SIG_ALERT then
        isValid = false
        errorMsg = sprintf("%s\n", L["SIGNAL_OUT_OF_RANGE"], utils:dbgPrefix())
    end
    if signal > SIG_NONE_PENDING then
        isValid = false
        errorMsg = sprintf("%s\n", L["SIGNAL_OUT_OF_RANGE"], utils:dbgPrefix())
    end

    return isValid, errorMsg
end
local function signalIsValid(signal)
    local isValid = true

    local errorMsg = nil
    if signal == nil then
        isValid = false
        errorMsg = sprintf(L["INPUT_PARM_NIL"], utils:dbgPrefix())
    end
    if type(signal) ~= "number" then
        isValid = false
        errorMsg = sprintf(L["INVALID_TYPE"], utils:dbgPrefix(), type(signal), "number")
    end
    isValid, errorMsg = signalInRange( signal )
    if not isValid then
        errorMsg = sprintf(L["SIGNAL_OUT_OF_RANGE"], utils:dbgPrefix(),signal)
    end
    return isValid, errorMsg
end
-- RETURNS void
--[[ 
local function scheduleThreads()
    ACCUMULATED_TICKS = ACCUMULATED_TICKS + 1

    for i, H in ipairs(threadControlBlock) do
        assert(H ~= nil, "H was nil")
        assert( type(H) == "table", "H was not a table" )

        -- remove any/all dead threads from the TCB and move
        -- them into the morgue
        H[TH_STATUS] = coroutine.status(H[TH_COROUTINE])

        if H[TH_STATUS] == "dead" then
            H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]
            table.remove(threadControlBlock, i)
            table.insert(morgue, H)
            utils:dbgPrint( sprintf("Thread[%s] exited normally.", H[TH_UNIQUE_ID]) )
        end

        if H[TH_STATUS] == "suspended" then
            -- decrement the remaining tick count and replenish the
            -- remaining ticks
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] == 0 then
                H[TH_REMAINING_TICKS] = H[TH_DURATION_TICKS]
            end
            -- resume the thread
            if H[TH_LIFETIME_TICKS] == 0 then
                H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS
            end
            local status, errorMsg = coroutine.resume(H[TH_COROUTINE])
            if not status then
                table.insert( morgue, H )
                local str = sprintf(L["RESUME_FAILED"], utils:dbgPrefix(), H[TH_UNIQUE_ID])
                errorMsg = sprintf("%s\n%s\n\n", str, errorMsg)
                utils:postMsg( errorMsg )
            end
        end
    end
end
 ]]
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
            utils:dbgPrint(sprintf("Thread[%s] exited normally.", H[TH_UNIQUE_ID]))
        else
            if status == "suspended" then
                H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
                if H[TH_REMAINING_TICKS] == 0 then
                    H[TH_REMAINING_TICKS] = H[TH_DURATION_TICKS]
                    local success, errorMsg = coroutine.resume(H[TH_COROUTINE])
                    if not success then
                        table.insert(morgue, H)
                        utils:postMsg(sprintf("Resume failed: %s - %s", H[TH_UNIQUE_ID], errorMsg))
                    end
                end
            end
            i = i + 1
        end
    end
end

 -- @returns void
 local function startTimer(CLOCK_INTERVAL)
    scheduleThreads()

    C_Timer.After(
        CLOCK_INTERVAL,
        function()
            startTimer(CLOCK_INTERVAL)
        end
    )
end
-- @returns TCB thread count.
local function insertHandleIntoTCB(H)
    table.insert(threadControlBlock, H)
    return #threadControlBlock
end
-- @returns Handle's coroutine
local function getCoroutine(H)
    return H[TH_COROUTINE]
end
local function WoWThreadLibInit()
    if not WoWThreadsStarted then
        local CLOCK_INTERVAL = (1 / GetFramerate())
        startTimer(CLOCK_INTERVAL)
    end
    WoWThreadsStarted = true
end
-- ============================================================================
--              PUBLIC (EXPORTED) METHODS
-- ============================================================================
-- @ Signature: status, result = thread:create( yieldTicks, threadFunction, ... )
-- @Description: This function creates a table of thread attributes called a thread handle.
-- @parameters 
-- yieldTicks (number):
-- threadFunction (function):.
-- ... Additional arguments to be passed to the thread function.
-- @returns: 
-- If successful: returns the newly created thread handle, thread_h
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:create( yieldTicks, threadFunction, ... )
    local errorMsg = nil

    if utils:debuggingIsEnabled() then
        if type(yieldTicks) ~= "number" then
            local stack = utils:simplifyStacktrace( debugstack(2))
            errorMsg = sprintf("%s %s expected number in %s, got %s"), utils:dbgPrefix(), L["INVALID_TYPE"], func, tostring(type(ticks))
            error( errorMsg)
        end
        if type(threadFunction) ~= "function" then
            local stack = utils:simplifyStacktrace( debugstack(2))
            errorMsg = sprintf("%s %s expected function in %s, got %s", utils:dbgPrefix(), L["INVALID_TYPE"], func, tostring( type(threadFunction )))
                error( errorMsg)
            end
    end
    -- Create a handle with a suspended coroutine
    local H = createHandle(yieldTicks, threadFunction)

    insertHandleIntoTCB(H)
    local co = H[TH_COROUTINE]
    local status, result = coroutine.resume(co, ...)
    if not status then
        error(result)
    end
    return H, H[TH_UNIQUE_ID]
end

-- @ Signature: thread:yield()
-- @Description: yields the processor to the next thread. Thread context required.
-- @param
-- None
-- @returns
-- None
-- @Example:
function thread:yield()
    local beforeYieldTicks = ACCUMULATED_TICKS

    coroutine.yield()

    local H = getCallerHandle()
    H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    local numYieldTicks = ACCUMULATED_TICKS - beforeYieldTicks
    H[TH_ACCUM_YIELD_TICKS] = H[TH_ACCUM_YIELD_TICKS] + numYieldTicks
    beforeTicks = 0
end

-- @Signature: thread:delay( delayTicks )
-- @Description: Delays a thread by the specified number of ticks. Thread context required.
-- @param 
-- delayTicks (number): the number of ticks to delay before continuing
-- @returns
-- None
--@Example:
function thread:delay(delayTicks)
    local H = getCallerHandle()
    H[TH_REMAINING_TICKS] = delayTicks + H[TH_REMAINING_TICKS]
    coroutine.yield()
end

-- @Signature: thread_h = thread:getSelf()
-- @Description returns the callingthread's handle. Thread context required
-- @param
-- None
-- @returns
-- If successful: returns the calling thread's handle.
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:getSelf()
    return getCallerHandle()
end

-- @Signature: thread:getId( thread_h )
-- @Description: Obtains the numerical Id of the calling thread. Thread context required.
-- @param 
--thread_h (handle)
-- @returns
-- If successful: returns the numerical Id of the thread.
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:getId(thread_h)
    local threadId = nil
    local isValid = true
    local errorMsg = nil

    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "thread:getId()"
            errorMsg = sprintf("%s in thread:getId().", errorMsg )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end

    return thread_h[TH_UNIQUE_ID]
end

-- @Signature: thread:areEqual( H1, H2 )
-- @Desxription: determines whether two thread handles are identical. Thread context required.
-- @param 
--H1 (handle)
--H2 (handle)
-- @returns 
-- If successful: returns true
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:areEqual(H1, H2)
    local errorMsg = nil
    if H1 == nil or H2 == nil then
        local func = "thread:areEqual( H1, H2)"
        errorMsg = sprintf("%s %s in %s", utils:dbgPrefix(), L["HANDLE_NIL"], func )
        error(errorMsg)
    end

    isValid, errorMsg = handleIsValid(H1)
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "thread:areEqual( H1, H2 )"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end

    isValid, errorMsg = handleIsValid(H2)
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "thread:areEqual( H1, H2 )"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end
    return H1[TH_UNIQUE_ID] == H2[TH_UNIQUE_ID]
end

-- @Signature: thread:getParent( thread_h )
-- @Description: gets the specified thread's parent. Thread context required.
-- @param
-- thread_h (handle)
-- @returns
-- If successful: returns the handle of the parent thread
-- If failure: returns 'false' and an error message as a string
--@Example:
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

-- @Signature: thread:getChildThreads( thread_h )
-- @ Obtains the handle of the specified thread's children
-- @param 
--thread_h (handle). If nil, then the calleing thread's children are returned
-- @returns
-- If successful: returns a table of thread handles.
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:getChildThreads(thread_h)
    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "getChildThreads( thread_h)"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end
        return thread_h[TH_CHILDREN]
end

-- @Signature: thread:getExecutionState( thread_h )
-- @Description: gets the state of the specified thread. Thread context required.
-- @param
-- thread_h (handle)
-- @returns 
-- If successful: returns the state ("suspended", "running", or "dead") of the specified thread
-- If failure: returns 'false' and an error message as a string
--@Example:
function thread:getExecutionState(thread_h)
    if thread_h ~= nil then
        isValid, errorMsg = handleIsValid(thread_h)
        if not isValid then
            local func = "getExecutionState( thread_h)"
            errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
            error( errorMsg )
        end
    else
        thread_h = getCallerHandle()
    end

    local status = coroutine.status(H[TH_COROUTINE])
    return status
end

-- @Signature: thread:sendSignal( target_h, signal, ... )
-- @Description sends a signal to the specified thread. Thread context NOT required.
-- @param 
-- thread_h (handle): the thread to which the signal is to be sent. 
-- @param 
-- signal (number) signal to be sent.
-- @param ... (varargs). data to be passed to the receiving thread
-- @returns
-- If successful: returns true
-- If failure: returns 'false' and an error message as a string
-- @Example:
function thread:sendSignal( target_h, signal, ...)
    local isValid = true
    local errorMsg = nil
    local args = {...}

    if target_h == nil then
        errorMsg = sprintf("%s %s in thread:sendSignal().\n", utils:dbgPrefix(), L["HANDLE_NIL"] )
        -- utils:postMsg( errorMsg )
        error( errorMsg )
    end

    isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        local func = "thread:sendSignal( target_h, signal, ...)"
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
        error( errorMsg )
    end
    local isValid, errorMsg = signalIsValid( signal )
    if not isValid then
        local func = "thread:sendSignal( target_h, signal, ...)"
        errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
        utils:postMsg( errorMsg )
        error( errorMsg )
    end
    -- get the identity of the calling thread
    local sender_h = getCallerHandle()
 
    -- Initialize and insert an entry into the recipient thread's signalTable
    local entry = {signal, sender_h, args }
    
    -- inserts the entry at the head of the queue.
    target_h[TH_SIGNAL_QUEUE]:push(entry)
end

-- @Signature: status, result = thread:getSignal()
-- @Description: gets the first signal in the calling thread's signal queue. Thread context required.
-- @param
-- signal (number): the signal to be retrieved (oldest signal in the queue)
-- @returns
-- If successful: returns the signal
-- If failure: returns 'false' and an error message as a string
-- @Example:
function thread:getSignal()
    local entry = nil
    local H = getCallerHandle()

    -- Check if there is an entry in the signalQueue.
    if H[TH_SIGNAL_QUEUE]:isEmpty() == false then
        entry = H[TH_SIGNAL_QUEUE]:pop()  -- Assuming pop operation
        local signal, sender_h, args = entry.signal, entry.sender, entry.args
        return entry[1], entry[2], entry[3]
    end
    return SIG_NONE_PENDING, nil, nil
end

-- @Signature: thread:getSignalName( signal )
-- @Description: gets the string name of the specified signal. Thread context NOT required.
-- @param
-- signal (number): the signal
-- @returns
-- If successful: returns the name of the signal
-- If failure: returns 'false' and an error message as a string
-- @Example:
function thread:getSignalName(signal)
    -- local isValid, errorMsg = signalIsValid( signal )
    -- if not isValid then
    --     error(errorMsg)
    -- end
    return signalNameTable[signal]
end

--- @brief gets the thread's execution state.
-- @param (handle) thread_h
-- @returns the specified thread's state as either "dead", "running", "suspended"
function thread:getState(thread_h)
    if debuggingIsEnabled() then
        if thread_h ~= nil then
            isValid, errorMsg = handleIsValid(thread_h)
            local func = "thread:getState()"
            if not isValid then
                local func = "thread:getState( target_h )"
                errorMsg = sprintf("%s %s in %s.", utils:dbgPrefix(), errorMsg, func )
                error( errorMsg )
            end
        else
            thread_h = getCallerHandle()
        end
    end
    return coroutine.status(thread_h[TH_COROUTINE])
end
------------------------- MANAGEMENT INTERFACE --------------------
local function thread:getCongestion(thread_h)
    local threadId          = thread_h[TH_UNIQUE_ID]
    local suspendedTicks    = thread_h[TH_ACCUM_YIELD_TICKS]
    local lifetimeTicks     = thread_h[TH_LIFETIME_TICKS]
    local yieldCount        = thread_h[TH_YIELD_COUNT]

    local runtimeTicks  = lifetimeTicks - suspendedTicks
    local yieldInterval     = thread_h[TH_DURATION_TICKS]
    idealTotalYieldTicks    = yieldCount * yieldInterval
    realTotalYieldTicks     = yieldCount * suspendedTicks

    efficiency = idealTotalYieldTicks - (1 - (idealTotalYieldTicks) / realTotalYieldTicks)

    local entry = {}

    return entry
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent(self, event, ...)
    local addonName = ...

    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
        WoWThreadLibInit()

        DEFAULT_CHAT_FRAME:AddMessage(L["ADDON_MESSAGE"], 0.0, 1.0, 1.0)
        DEFAULT_CHAT_FRAME:AddMessage(L["CLOCK_INTERVAL"], CLOCK_INTERVAL, 0.0, 1.0, 1.0)

        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
    return
end
eventFrame:SetScript("OnEvent", OnEvent)



--[[ 
    PROTOTYPE: thread:create( yieldTicks, threadFunction, ... )
function thread:create( yieldTicks, threadFunction, ... )
    local errorMsg = nil

    if utils:debuggingIsEnabled() then
        if type(yieldTicks) ~= "number" then
            local stack = debugstack(2)
            local simpleStack = simplifyStack( stack, "thread:create" )
            errorMsg = sprintf("%s %s expected number in %s, got %s"), utils:dbgPrefix(), L["INVALID_TYPE"], func, tostring(type(ticks))
            local failInfo = {errorMsg, simpleStack }
            return FAILURE, result
        end
        if type(threadFunction) ~= "function" then
            local stack = debugstack(2)
            local simpleStack = simplifyStack( stack, "thread:create" )
            errorMsg = sprintf("%s %s expected function in %s, got %s", utils:dbgPrefix(), L["INVALID_TYPE"], func, tostring( type(threadFunction )))
            local failInfo = {errorMsg, simpleStack }
            return FAILURE, result
            end
    end
    -- Create a handle with a suspended coroutine
    local H = createHandle(yieldTicks, threadFunction)

    insertHandleIntoTCB(H)
    local co = H[TH_COROUTINE]
    local status, result = coroutine.resume(co, ...)
    if not status then
        error(result)
    end
    return H, H[TH_UNIQUE_ID]
end


 ]]