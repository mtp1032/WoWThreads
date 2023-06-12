--------------------------------------------------------------------------------------
-- Dispatcher.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 23 May, 2023
local _, WoWThreads = ...
WoWThreads.Dispatcher = {}
dispatch = WoWThreads.Dispatcher

local L = locales.L
local sprintf = _G.string.format
local EMPTY_STR = core.EMPTY_STR
local SUCCESS   = core.SUCCESS

----------------------- THREAD HANDLE -------------------------------

dispatch.TH_EXECUTABLE_IMAGE    = 1   -- the coroutine created to execute the thread's function
dispatch.TH_SEQUENCE_ID         = 2   -- a number representing the order in which the thread was created
dispatch.TH_SIGNAL_QUEUE        = 3   -- a table of all currently pending signals
dispatch.TH_TICKS_PER_YIELD     = 4   -- the time in clock ticks a thread is supendend after a yield
dispatch.TH_REMAINING_TICKS     = 5   -- decremented on every clock tick. When 0 the thread is queued.
dispatch.TH_YIELD_COUNT         = 6   -- the number of times the coroutine has been resumed by the dispatcher.
dispatch.TH_LIFETIME            = 7
dispatch.TH_ACCUM_YIELD_TIME    = 8
dispatch.TH_JOIN_DATA           = 9
dispatch.TH_JOIN_QUEUE          = 10
dispatch.TH_CHILD_THREADS       = 11
dispatch.TH_PARENT_THREAD       = 12
dispatch.TH_EXECUTION_STATE     = 13   -- running, suspended, waiting, completed

dispatch.TH_NUM_ELEMENTS      = dispatch.TH_EXECUTION_STATE

-- Indices into the thread handle table
local TH_EXECUTABLE_IMAGE          = dispatch.TH_EXECUTABLE_IMAGE
local TH_SEQUENCE_ID        = dispatch.TH_SEQUENCE_ID
local TH_SIGNAL_QUEUE       = dispatch.TH_SIGNAL_QUEUE
local TH_TICKS_PER_YIELD    = dispatch.TH_TICKS_PER_YIELD
local TH_REMAINING_TICKS    = dispatch.TH_REMAINING_TICKS 
local TH_YIELD_COUNT        = dispatch.TH_YIELD_COUNT
local TH_LIFETIME           = dispatch.TH_LIFETIME
local TH_ACCUM_YIELD_TIME   = dispatch.TH_ACCUM_YIELD_TIME
local TH_JOIN_DATA          = dispatch.TH_JOIN_DATA
local TH_JOIN_QUEUE         = dispatch.TH_JOIN_QUEUE
local TH_CHILD_THREADS      = dispatch.TH_CHILD_THREADS
local TH_PARENT_THREAD      = dispatch.TH_PARENT_THREAD
local TH_EXECUTION_STATE    = dispatch.TH_EXECUTION_STATE

local TH_NUM_ELEMENTS       = dispatch.TH_EXECUTION_STATE

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
dispatch.SIG_ALERT           = 1
dispatch.SIG_JOIN_DATA_READY = 2
dispatch.SIG_TERMINATE       = 3
dispatch.SIG_METRICS         = 4
dispatch.SIG_NONE_PENDING    = 5

-- NOTE:
-- SIG_ALERT - requires recipient to return from yield() and exit while loop.
-- SIG_TERMINATE - requires thread to cleanup state and complete.
local SIG_ALERT             = dispatch.SIG_ALERT          -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_JOIN_DATA_READY   = dispatch.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = dispatch.SIG_TERMINATE
local SIG_METRICS           = dispatch.SIG_METRICS
local SIG_NONE_PENDING      = dispatch.SIG_NONE_PENDING    -- default value. Means the handle's signal queue is empty

---------------------- DEFAULT LOCAL AND GLOBAL VARS ------------------------

local DEFAULT_YIELD_TICKS  = 2 

local threadSequenceNumber  = 5    -- thread 6 is the first thread. the first 5 thread Ids are reserved for later use

-- when threads complete they are inserted into the graveyard table.
local graveyard             = {} -- table of completed threads
local threadControlBlock    = {} -- table of active threads
local signalNameTable       = { "SIG_ALERT", "SIG_JOIN_DATA_READY", "SIG_TERMINATE", "SIG_METRICS", "SIG_NONE_PENDING"}

-- ***********************************************************************
-- *                               LOCAL FUNCTIONS                       *
-- ***********************************************************************
local function removeFromTCB( thread_h )
    local threadId = thread_h[TH_SEQUENCE_ID]
    for i, H in ipairs( threadControlBlock ) do 
        if H[TH_SEQUENCE_ID] == threadId then 
            assert( H[TH_EXECUTION_STATE] == "completed", "ASSERT FAILED: Thread (%d) has not completed.", H[TH_SEQUENCE_ID])
            return (table.remove( threadControlBlock, i ))
        end
    end
    return nil
end
    -- RETURNS: Handle metrics entry = { threadId, ticksPerYield, yieldCount, timeSuspended, lifetime }
local function convertHandleToEntry( H )

    local threadId         = H[TH_SEQUENCE_ID]
    local ticksPerYield    = H[TH_TICKS_PER_YIELD]
    local yieldCount       = H[TH_YIELD_COUNT]
    local timeSuspended    = H[TH_ACCUM_YIELD_TIME]
    local lifetime         = H[TH_LIFETIME]
	local congestion = (1 - (timeSuspended / lifetime))

    local entry = { threadId, ticksPerYield, yieldCount, timeSuspended, lifetime, congestion }
    return entry
end
-- RETURNS void
local function scheduleThreads()
    for i, H in ipairs( threadControlBlock ) do  
        
        -- remove any/all dead threads from the TCB and move
        -- them into the graveyard
        H[TH_EXECUTION_STATE] = dispatch:getThreadState(H)

        if H[TH_EXECUTION_STATE] == "completed" then
            table.remove( threadControlBlock, i )
            table.insert( graveyard, H )
            if core:dataCollectionIsEnabled() then
                local lifetime = debugprofilestop() - H[TH_LIFETIME]
                H[TH_LIFETIME] = lifetime
            end
        elseif H[TH_EXECUTION_STATE] == "suspended" then

            -- decrement the remaining tick count. If equal
            -- to 0 then the coroutine will be resumed.
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] == 0 then

                -- replenish the remaining ticks counter and resume this thread.
                H[TH_REMAINING_TICKS] = H[TH_TICKS_PER_YIELD]

                -- NOTE: under some circumstataces a thread will
                -- complete and be signaled before we can set the thread's state. So, if
                -- we find a thread at this point in the loop through the TCB, we
                -- move the thread from the TCB to the graveyard.
                local wasResumed, retValue = coroutine.resume( H[TH_EXECUTABLE_IMAGE] )
                if not wasResumed then
                    local errMsg = sprintf("Thread[%d] faulted in the thread's function: Stack trace follows:\n%s\n", H[TH_SEQUENCE_ID], retValue )
                    print( errMsg )
                    local state = coroutine.status( H[TH_EXECUTABLE_IMAGE])
                    if state == "dead" then
                        -- remove from TCB
                        for i, h in ipairs( threadControlBlock ) do
                            if H[TH_SEQUENCE_ID] == h[TH_SEQUENCE_ID] then
                                table.remove( threadControlBlock, i )
                                table.insert( graveyard, H )
                                if core:dataCollectionIsEnabled() then
                                    local lifetime = debugprofilestop() - H[TH_LIFETIME]
                                    H[TH_LIFETIME] = lifetime
                                end
                            end
                        end
                    end
                end
            end 
        end
    end
end
-- ***********************************************************************
-- *                               PUBLIC FUNCTIONS                      *
-- ***********************************************************************

-- RETURNS: state - "completed", "running", "queued", "suspended"
function dispatch:getThreadState( H )
    local state = coroutine.status( H[TH_EXECUTABLE_IMAGE])

    if state == "dead" then 
        state = "completed" 
    end
    if state == "normal" then state = "queued" end
    return state
end
-- RETURNS: a thread metric entry and the number of remaing threads in the graveyard.
function dispatch:getThreadMetrics( H )
    local entry = nil
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if #graveyard == 0 then 
        return nil, #graveyard, result 
    end

    local numInGrave = #graveyard
    for i = 1, numInGrave do
        local h = graveyard[i]
        if H[TH_SEQUENCE_ID] == h[TH_SEQUENCE_ID] then
            entry = convertHandleToEntry( H )
            wipe( H )
            return entry, #graveyard, result
        end
    end
    return entry, numInGrave, result
end
-- RETURNS: the parent thread of H. if H is a top level thread, then nil is returned
function dispatch:getThreadParent( H )
    local parent_h = nil

    if H[TH_PARENT_THREAD] ~= EMPTY_STR then
        parent_h = H[TH_PARENT_THREAD]
    end
    return parent_h
end
-- RETURNS: childTable, childCount. nil, 0 if no child threads
function dispatch:getThreadChildren( H )
    local childTable = nil
    local childCount = 0

    local childCount = #H[TH_CHILD_THREADS]
    if childCount ~= 0 then
        childTable = H[TH_CHILD_THREADS]
    end
    return childTable, childCount
end
-- RETURNS: void
function dispatch:startTimer( clockInterval )

    scheduleThreads()
   
    C_Timer.After( clockInterval, 
        function() 
            dispatch:startTimer( clockInterval )
        end)
    return
end
-- RETURNS: running thread, threadId. nil, 0 if thread not found.
function dispatch:getRunningHandle()
    local H = nil

    -- only one thread can be "running"
    for _, H in ipairs( threadControlBlock ) do
        local state = coroutine.status( H[TH_EXECUTABLE_IMAGE] )
        if state == "running" then
            return H, H[TH_SEQUENCE_ID]
        end
    end
    return H, 0
end
-- RETURNS: void
function dispatch:yield()

    local H, threadId = dispatch:getRunningHandle()
    local startTime = 0
    if core:dataCollectionIsEnabled() then
        startTime = debugprofilestop()
    end

    coroutine.yield()
        
    if core:dataCollectionIsEnabled() then
        local elapsedTime = debugprofilestop() - startTime
        H[TH_ACCUM_YIELD_TIME] = H[TH_ACCUM_YIELD_TIME] + elapsedTime
        H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    end
end        
-- RETURNS: void
function dispatch:setDelay( H, delayTicks )
    H[TH_REMAINING_TICKS] = delayTicks
end
-- RETURNS: signal name
function dispatch:getSignalName( signal )
    return signalNameTable[signal]
end
-- RETURNS: void
function dispatch:deliverSignal( H, signal )
    local sender_h = nil

    sender_h = dispatch:getRunningHandle()
    local sigEntry = {signal, sender_h, EMPTY_STR }

    if  signal == SIG_ALERT or 
        signal == SIG_TERMINATE or
        signal == SIG_JOIN_DATA_READY then
            H[TH_REMAINING_TICKS] = 1
    end

    table.insert( H[TH_SIGNAL_QUEUE], sigEntry )
end
-- RETURNS: signal, sender_h (SIG_NONE_PENDING if thread's signal queue is empty.)
-- NOTE: signals are returned in the order they are received (FIFO)
function dispatch:getSignal()
    local signal = SIG_NONE_PENDING
    local sender_h = nil

    local H, threadId = dispatch:getRunningHandle()
    local signalQueue = H[TH_SIGNAL_QUEUE]
    if #signalQueue == 0 then
        return signal, sender_h
    end

    if #signalQueue > 0 then
        local sigEntry = table.remove(H[TH_SIGNAL_QUEUE], 1 )
        signal = sigEntry[1]
        sender_h = sigEntry[2]
    end

    return signal, sender_h
end
-- RETURNS: Thread Id
function dispatch:getThreadId( H )
    return H[TH_SEQUENCE_ID]
end
-- RETURNS: TCB thread count.
function dispatch:insertHandleIntoTCB( H )
    table.insert( threadControlBlock, H)
    return #threadControlBlock
end 
-- RETURNS: Handle's coroutine 
function dispatch:getCoroutine( H )
    if core:debuggingIsEnabled() then
        assert( H ~= nil, sprintf("ASSERT FAILED: %s\n", L["THREAD_HANDLE_NIL"]), debugstack(1))
        assert( H[TH_EXECUTABLE_IMAGE] ~= nil, L["HANDLE_COROUTINE_NIL"], debugstack(1) )
        assert( type(H[TH_EXECUTABLE_IMAGE]) == "thread", L["INVALID_COROUTINE_TYPE"], debugstack(1))
    end
    return H[TH_EXECUTABLE_IMAGE]
end
-- RETURNS: result
function dispatch:validateSignal( signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if core:debuggingIsEnabled() then
        if signal == nil then
            result = core:setResult(L["INPUT_PARM_NIL"],debugstack(1))
            return result    
        end
        assert( signal ~= nil, sprintf("%s\n    %s\n", L["INPUT_PARM_NIL"], debugstack(1) ))
        assert( type(signal) == "number",L["INVALID_TYPE"])
        assert( signal >= SIG_ALERT, L["SIGNAL_OUT_OF_RANGE"])
        assert( signal <= SIG_NONE_PENDING, L["SIGNAL_OUT_OF_RANGE"])
        return result
    end

    -- validate the signal
    if signal == nil then
        result = core:setResult(L["INPUT_PARM_NIL"],debugstack(1))
        return result
    end
    if type( signal ) ~= "number" then
        result = core:setResult(L["INVALID_TYPE"], debugstack(1) )
        return result
    end

    -- return signal <= SIG_ALERT  and signal >= SIG_NONE_PENDING
    if signal < SIG_ALERT and signal > SIG_NONE_PENDING then 
        result = core:setResult( L["SIGNAL_OUT_OF_RANGE"] )
        return isValid, result
    end
    return result
end
-- RETURNS: result
function dispatch:checkIfHandleValid( H )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    -- if core:debuggingIsEnabled() then
        assert(#H == TH_NUM_ELEMENTS, L["HANDLE_INVALID_TABLE_SIZE"])
        assert( type(H) == "table", L["HANDLE_NOT_TABLE"])
        assert( H[TH_EXECUTABLE_IMAGE] ~= nil, L["HANDLE_COROUTINE_NIL"] )
        assert( type(H[TH_EXECUTABLE_IMAGE]) == "thread", L["INVALID_COROUTINE_TYPE"] )
    --     return result
    -- end

    if type(H[TH_EXECUTABLE_IMAGE]) ~= "thread" then
        result = core:setResult(L["INVALID_TYPE"] .. " Expected type == 'thread'", debugstack(1))
        return result
    end
    if type(H) ~= "table" then
        result = core:setResult(L["HANDLE_NOT_TABLE"], debugstack(1) )
        return result
    end        
    if #H ~= TH_NUM_ELEMENTS then
        result = core:setResult(L["HANDLE_INVALID_TABLE_SIZE"], debugstack(1) )
        return result
    end
    for i = 1, TH_NUM_ELEMENTS do
        if H[i] == nil then
            local s = sprintf("H[%d] is nil.", i)
            result = core:setResult( s, debugstack(1) )
            return result
        end
    end
    
    return result        
end
-- RETURNS: partial handle, result
function dispatch:createHandle( durationTicks, func )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR }
    local H = {}
    if durationTicks < DEFAULT_YIELD_TICKS then
        durationTicks = DEFAULT_YIELD_TICKS
    end
    threadSequenceNumber = threadSequenceNumber + 1

    H[TH_EXECUTABLE_IMAGE]  = coroutine.create( func )
    H[TH_SEQUENCE_ID]       = threadSequenceNumber
    H[TH_SIGNAL_QUEUE]      = {}
    H[TH_TICKS_PER_YIELD]   = durationTicks
    H[TH_REMAINING_TICKS]   = 1
    H[TH_YIELD_COUNT]       = 0
    H[TH_LIFETIME]          = debugprofilestop()
    H[TH_ACCUM_YIELD_TIME]  = 0
    H[TH_JOIN_DATA]         = EMPTY_STR
    H[TH_JOIN_QUEUE]        = {}
    H[TH_CHILD_THREADS]     = {}
    H[TH_PARENT_THREAD]     = EMPTY_STR
    H[TH_EXECUTION_STATE]   = EMPTY_STR

    local running_h, runningId = dispatch:getRunningHandle() 
    if running_h ~= nil then

        -- this call is being executed by a WoW Thread. Therefore,
        -- the running thread is the parent and this handle will be 
        -- the child of the running thread.
        table.insert( running_h[TH_CHILD_THREADS], H )
        H[TH_PARENT_THREAD] = running_h
    end

    return H, result
end
-- RETURNS: void
function dispatch:insertJoinQueue( producer_h, caller_h )
    local caller_h, callerId = dispatch:getRunningHandle()
    table.insert( producer_h[TH_JOIN_QUEUE], caller_h )
end
-- RETURNS: void
function dispatch:insertJoinData( joinData )
    local self_h = dispatch:getRunningHandle()
    self_h[TH_JOIN_DATA] = joinData
end
-- RETURNS; joinData
function dispatch:getJoinData( H )
    return H[TH_JOIN_DATA]
end
-- RETURNS: void
function dispatch:signalJoiners()
    local self_h, selfId = dispatch:getRunningHandle()
    local joinerThreads = self_h[TH_JOIN_QUEUE]

    for _, joiner_h in ipairs( self_h[TH_JOIN_QUEUE] ) do
        local wasSent = dispatch:deliverSignal( joiner_h, SIG_JOIN_DATA_READY )
        if core:debuggingIsEnabled() then
            if not wasSent then
                local threadId = joiner_h[TH_SEQUENCE_ID]
            end
        end
    end
    wipe( self_h[TH_JOIN_QUEUE] )
end
function dispatch:printGreeting()
    print("Hello world.")
end

local fileName = "Dispatcher.lua"
if core:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
