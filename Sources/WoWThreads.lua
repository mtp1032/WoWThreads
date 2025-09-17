--=================================================================================
-- Filename: WoWThreads.lua
-- Date: 9 March, 2021
-- ORIGINAL DATE: 9 March, 2021
--=================================================================================
--                      ADMIN, HOUSEKEEPING STUFF
WoWThreads = WoWThreads or {}

if not WoWThreads.SignalQueue.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("SignalQueue.lua not loaded", 1, 0, 0)
    return
end
local core  = WoWThreads.Core
local utils = WoWThreads.UtilsLib
local L     = WoWThreads.Locales.L
local sig	= WoWThreads.SignalQueue

--=============== Create As A Libstub Library ===========
-- Configure WoWThreads as a LibStub managed library
local libStubAddonName, _, _, gitVersion = core:getAddonInfo()
local thread, oldVersion = LibStub:NewLibrary(libStubAddonName, gitVersion)
if not thread then return end  -- no upgrade needed
--=======================================================

--                                  LOCAL DATA
local DEBUGGING_ENABLED     = true
local DATA_COLLECTION       = false
local CURRENT_RUNNING_THREAD = nil
local DEFAULT_YIELD_TICKS    = 1
local THREAD_SEQUENCE_ID     = 4 -- a number representing the order in which the thread was created
local ACCUMULATED_TICKS      = 0 -- The system-wide, total number of clock ticks

local threadControlBlock    = {} -- Table to hold all running and suspended threads
local threadSleepTable      = {} -- Table to hold sleeping threads
local threadDelayTable      = {}
local morgue                = {} -- Table to hold the dead threads

local CLOCK_INTERVAL         = 1/GetFramerate() -- approx 16.7 ms on a 60Hz system
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
local TH_ADDON_NAME       	= 11
local TH_COROUTINE_ARGS     = 12
local TH_ELAPSED_TIME       = 13 -- the time the thread was created, in seconds since epoch
local TH_NUM_HANDLE_ELEMENTS = TH_ELAPSED_TIME

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data. 
-- Example: sigTable = {signalValue, sender_h, ... }
--
-- These constants are the signal values found in sigTable[1]
thread.SIG_HAS_PAYLOAD     = 1 -- TBD
thread.SIG_SEND_PAYLOAD = 2 -- TBD
thread.SIG_BEGIN        = 3 -- TBD
thread.SIG_HALT         = 4 -- TBD
thread.SIG_IS_COMPLETE  = 5 -- info: thread is complete
thread.SIG_SUCCESS      = 6 -- info: thread completed successfully
thread.SIG_FAILURE      = 7 -- info: thread completed with failure
thread.SIG_IS_READY        = 8
thread.SIG_CALLBACK     = 9  -- info: Signal entry contains a callback function in Sig[3]
thread.SIG_THREAD_DEAD  = 10 -- info: thread has completed or failed.
thread.SIG_ALERT        = 11 -- schedule for immediate execution
thread.SIG_WAKEUP       = 12 -- unused. Intended for thread pools.
thread.SIG_TERMINATE    = 13 -- thread terminates upon receipt.
thread.SIG_NONE_PENDING = 14 -- signal queue is empty.

thread.signalTable = {
    SIG_HAS_PAYLOAD     = thread.SIG_HAS_PAYLOAD,
    SIG_SEND_PAYLOAD    = thread.SIG_SEND_PAYLOAD,
    SIG_BEGIN        = thread.SIG_BEGIN,
    SIG_HALT         = thread.SIG_HALT,
    SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE,
    SIG_SUCCESS      = thread.SIG_SUCCESS,
    SIG_FAILURE      = thread.SIG_FAILURE,
    SIG_IS_READY     = thread.SIG_IS_READY,
    SIG_CALLBACK     = thread.SIG_CALLBACK,
    SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD,
    SIG_ALERT        = thread.SIG_ALERT,
    SIG_WAKEUP       = thread.SIG_WAKEUP,
    SIG_TERMINATE    = thread.SIG_TERMINATE,
    SIG_NONE_PENDING = thread.SIG_NONE_PENDING,
}

local SIG_HAS_PAYLOAD     = thread.SIG_HAS_PAYLOAD
local SIG_SEND_PAYLOAD    = thread.SEND_DATA
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE
local SIG_SUCCESS      = thread.SIG_SUCCESS
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY        = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING

thread.signalNameTable = {
    "SIG_HAS_PAYLOAD",
    "SIG_SEND_PAYLOAD",
    "SIG_BEGIN",
    "SIG_HALT",
    "SIG_IS_COMPLETE",
    "SIG_SUCCESS",
    "SIG_FAILURE",
    "SIG_IS_READY",
    "SIG_CALLBACK",
    "SIG_THREAD_DEAD",
    "SIG_ALERT",
    "SIG_WAKEUP",
    "SIG_TERMINATE",
    "SIG_NONE_PENDING"
}
local signalNameTable = thread.signalNameTable
--                          LOCAL FUNCTIONS 

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
	if DEBUGGING_ENABLED then
		DEFAULT_CHAT_FRAME:AddMessage( newMsg, 1.0, 1.0, 0.0 )
	    utils:postMsg( newMsg )
    	DEFAULT_CHAT_FRAME:AddMessage( newMsg, 0.0, 1.0, 1.0 )
	end
end

local function setResult(errorMsg, fname, stackTrace)
    local resultStr     = nil
	local msg = nil
	local result = nil


	if stackTrace == nil then error( "stackTrace was nil.") end
	if fname == nil then error( "function name was nil.") end
	if errorMsg == nil then error( "Error message was nil.") end

	stackTrace = utils:simplifyStackTrace(stackTrace)
	msg = string.format("%s occurred in %s:\nStack: %s\n\n", errorMsg, fname, stackTrace )
	result = { msg, fname, stackTrace }
    
    if not DEBUGGING_ENABLED then
		DEBUGGING_ENABLED = true
        dbgLog( msg )
		DEBUGGING_ENABLED = false
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
local function isHandleInMorgue( H )
    if #morgue == 0 then return false end

    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            return true
        end
    end
return false
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
            if DEBUGGING_ENABLED then 
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
-- deprecated
local function getHandleOfCallingThread()
    return CURRENT_RUNNING_THREAD
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
        [TH_ADDON_NAME]         = addonName,
        [TH_COROUTINE_ARGS]     = {...},
        [TH_ELAPSED_TIME]       = debugprofilestop()
    }
    if parent_h ~= nil then
        table.insert( parent_h[TH_CHILDREN], H)
    end

    return H
end

-- returns true if successful, false otherwise + errorMsg
local function moveToMorgue( H, normalCompletion )
    H[TH_LIFETIME_TICKS] = ACCUMULATED_TICKS - H[TH_LIFETIME_TICKS]
    H[TH_ELAPSED_TIME] = debugprofilestop() - H[TH_ELAPSED_TIME]
    for i, handle in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == handle[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( morgue, H)

            if DEBUGGING_ENABLED then
                local msg = nil
                if normalCompletion == false then
                    msg = string.format("*** ABNORMAL *** termination. Moved thread[%d] from TCB to morgue", H[TH_UNIQUE_ID])
                else
                    msg = string.format("%s Normal termination. Moved thread[%d] from TCB to morgue", H[TH_UNIQUE_ID])
                end
                -- dbgLog( msg )
                -- utils:postMsg( msg )
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
            if DEBUGGING_ENABLED then
                local msg = string.format("%s Thread[%d] removed from TCB, inserted into sleep table.\n", utils:dbgPrefix(), H[TH_UNIQUE_ID])
                dbgLog( msg )
            end
            return successful, nil
        end
    end

    if not successful then
        errorMsg = L["THREAD_NOT_FOUND"]
        if DEBUGGING_ENABLED then
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
        errorMsg =L["INVALID_TYPE"]
        isValid = false
		print("312")
        return isValid, errorMsg
    end
    -- if #H ~= TH_NUM_HANDLE_ELEMENTS then
    --     errorMsg = L["THREAD_HANDLE_ILL_FORMED"]
    --     isValid = false
	-- 	print("318", #H )
    --     return isValid, errorMsg
    -- end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        errorMsg = L["INVALID_TYPE"]
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
local function signalIsValid(signal)
    if signal == nil then
        return false, L["SIGNAL_IS_NIL"]
    end

    if type(signal) ~= "number" then
        return false, L["SIGNAL_INVALID_TYPE"]
    end

    if signal < thread.SIG_HAS_PAYLOAD or signal > thread.SIG_NONE_PENDING then
        return false, L["SIGNAL_OUT_OF_RANGE"]
    end

    return true, nil
end
local function resumeOnError()

end
local function resumeThread(H)
    local co = H[TH_COROUTINE]
    local args = H[TH_COROUTINE_ARGS] or {} -- Ensure args is a table

    if DEBUGGING_ENABLED then
        dbgLog(string.format("%s Resuming Thread[%d]", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
    end

    -- Define error handler for xpcall using debugstack
    local function errorHandler(err)
        return tostring(err) .. "\nStack trace:\n" .. debugstack(2)
    end

    -- Use xpcall instead of pcall
	CURRENT_RUNNING_THREAD = H
    local xpcallResults = { xpcall(coroutine.resume, errorHandler, co, unpack(args)) }
    CURRENT_RUNNING_THREAD = nil

    local xpcallSucceeded = xpcallResults[1]
    if not xpcallSucceeded then
        if DEBUGGING_ENABLED then
            dbgLog(string.format("%s Thread[%d] xpcall failed: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], tostring(xpcallResults[2])))
        end
        moveToMorgue(H, true)
        return false, xpcallResults[2]
    end

    local coroutineSucceeded = xpcallResults[2]
    if not coroutineSucceeded then
        if DEBUGGING_ENABLED then
			dbgLog(string.format("%s Thread[%d] xpcall failed: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], tostring(xpcallResults[2]):gsub("\n", "\n  ")))        end
        moveToMorgue(H, true)
        return false, xpcallResults[3]
    end

    if coroutine.status(co) == "dead" then
        if DEBUGGING_ENABLED then
            dbgLog(string.format("%s Thread[%d] completed", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
        end
        moveToMorgue(H, true)
        return true, nil
    end

    return true, select(2, unpack(xpcallResults))
end
local function scheduleThreads()
    ACCUMULATED_TICKS = ACCUMULATED_TICKS + 1

    if #threadDelayTable > 0 then
        for i = #threadDelayTable, 1, -1 do
            local H = threadDelayTable[i]
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] <= 0 then
                table.remove(threadDelayTable, i)
                table.insert(threadControlBlock, H)
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS]
                if DEBUGGING_ENABLED then
                    dbgLog(string.format("%s Thread[%d] delay expired, moved to TCB.", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
                end
            end
        end
    end

    if #threadControlBlock == 0 then
        return
    end

    for i = #threadControlBlock, 1, -1 do
        local H = threadControlBlock[i]
        local co = H[TH_COROUTINE]
        if coroutine.status(co) == "suspended" then
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] <= 0 then
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS]
				---------------------------------------
                local success, result = resumeThread(H)
                ---------------------------------------
                if not success then
                    if DEBUGGING_ENABLED then
                        dbgLog(string.format("%s Thread[%d] error: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], tostring(result)))
                    end
                elseif result then
                    if DEBUGGING_ENABLED then
                        dbgLog(string.format("%s Thread[%d] yielded: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], tostring(result)))
                    end
                    -- Handle yielded value as a delay (mimics thread:delay(ticks))
                    if type(result) == "number" then
                        H[TH_REMAINING_TICKS] = result
                        table.remove(threadControlBlock, i)
                        table.insert(threadDelayTable, H)
                        if DEBUGGING_ENABLED then
                            dbgLog(string.format("%s Thread[%d] delayed for %d ticks", utils:dbgPrefix(), H[TH_UNIQUE_ID], result))
                        end
                    end
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
local function WoWThreadsLibInit( addonName )
    if not WoWThreadsStarted then
        startTimer( 1/GetFramerate() )
    end
    WoWThreadsStarted = true
end
local function extractAddonName(stacktrace)
    local addonName = string.match(stacktrace, "AddOns/([^/]+)/")
    return addonName
end

--================================================================
--==================== PUBLIC (EXPORTED) SERVICES ================
--================================================================

function thread:isDebuggingEnabled()
    return DEBUGGING_ENABLED
end
function thread:enableDebugging()
    DEBUGGING_ENABLED = true
end
function thread:disableDebugging()
    DEBUGGING_ENABLED = false
end
function thread:dataCollectionIsEnabled()
    return DATA_COLLECTION
end
function thread:enableDataCollection()
    DATA_COLLECTION = true
end
function thread:disableDataCollection()
    DATA_COLLECTION = false
end

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
        errorMsg = L["INVALID_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    if threadFunction == nil then
        errorMsg = L["PARAMETER_NIL"] .. "threadFunction() for thread:create()"
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    if type(threadFunction) ~= "function" then
        errorMsg = L["INVALID_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end

    parent_h = getHandleOfCallingThread()

	-- If parent_h is nil, the caller must be the WoW game client whose 
	-- addon name can be extracted from the stack trace.
    if parent_h == nil then 
        addonName = extractAddonName( debugstack(2) )
    else
        -- the caller  is a thread. Therefore, it has a parent thread from which the addon name is obtained.
        addonName = parent_h[TH_ADDON_NAME]
    end

    local H = createHandle( addonName, parent_h, yieldTicks, threadFunction, ... )

    table.insert( threadControlBlock, H )
    if DEBUGGING_ENABLED then
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
        thread_h = getHandleOfCallingThread()
        if thread_h == nil then
            return nil, result
        end
    end
    return thread_h[TH_ADDON_NAME], nil
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
    local DONE = false
	while not DONE do
		-- do some work
		thread:yield()  -- suspend the thread for its specified yieldTicks interval
		local signal = thread:getSignal()
		if signal[1] == SIG_TERMINATE then
			DONE = true
		end	
	end
@End]]
function thread:yield()
    local fname = "thread:yield()"
    local beforeTicks = ACCUMULATED_TICKS
    local H = nil
    local errorMsg = nil
	local result = nil

    coroutine.yield()

	H = getHandleOfCallingThread()
    if DATA_COLLECTION then  
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

    local isValid = handleIsValid(thread_h)
    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2))
        return nil, nil, result
    end

    if not isHandleInMorgue( thread_h ) then
        result = setResult( L["THREAD_NOT_COMPLETED"], fname, debugstack(2))
        return nil, nil, result
    end

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
function thread:delay(delayTicks)
    local fname = "thread:delay()"
	local result = nil
    if not delayTicks or type(delayTicks) ~= "number" then
        result = setResult(L["INVALID_TYPE"], fname, debugstack(2))
		return nil, result
    end

    local H = getHandleOfCallingThread()
    -- Set delay and remove from TCB
    H[TH_REMAINING_TICKS] = delayTicks
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert(threadDelayTable, H)
            break
        end
    end

    coroutine.yield()
    return delayTicks, nil
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

    H = getHandleOfCallingThread()
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
	return getHandleOfCallingThread()
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
		thread_h = getHandleOfCallingThread()
    end

    -- thread_h is not nil. But, is it valid
    isValid = handleIsValid(thread_h)
    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2) )
    end
    
    if isHandleInMorgue(thread_h) then
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
    local result = nil
    
    -- check that neither handle is nil
    if H1 == nil then
        result = setResult( L["THREAD_HANDLE_NIL"], fname, debugstack(2))
        return nil, result
    end
    if H2 == nil then
        result = setResult( L["THREAD_HANDLE_NIL"],fname, debugstack(2))
        return nil, result
    end

    isValid  = handleIsValid(H1)
    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2))
        return nil, result
    end
    isValid  = handleIsValid(H2)
    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2))
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
function thread:getParent( thread_h )
    local fname = "thread:getParent()"
	local errorMsg = nil
    local result = nil
    if thread_h == nil then    
		thread_h = getHandleOfCallingThread()
    end

	return thread_h
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
    local result = nil

    if thread_h == nil then
        thread_h  = getHandleOfCallingThread()
    end

    local isValid = handleIsValid( thread_h )
    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2))
        return nil, result
    end

    return thread_h[TH_CHILDREN], nil
end
--[[@Begin
Signature: value, result = thread:isSignalValid( signal )
Description: Checks whether the specified signal is valid
Parameters: 
- signalValue (number): signal to be sent.
Returns:
- Success: value = true is returned and the result is set to nil.
- Failure: value = false is returned and the signal is invalid.
Usage:
    local isValid, result = thread:isSignalValid( signal )
    if not isValid then 
        print( result[1], result[2] )
        return 
    end
@End]]
function thread:isSignalValid( signal )
	local fname = "thread:isSignalValid()"
	local result = nil	
    local isValid, errorMsg = signalIsValid( signal )
	if not isValid then
		result = setResult( errorMsg, fname, debugstack(2))
	end
	return isValid, result
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
    local wasSent, result = thread:sendSignal( target_h, thread.signal, data )
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
        errorMsg = L["INVALID_TYPE"]
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    
	-- is the target thread a real thread?
    isValid = handleIsValid( target_h )

    if not isValid then
        result = setResult(  L["THREAD_INVALID_CONTEXT"], fname, debugstack(2))
        return nil, result
    end
    isValid, errorMsg = signalIsValid(signal)
	if not isValid then
        result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
    -- User code cannot send SIG_NONE_PENDING signals.
	if signal == thread.SIG_NONE_PENDING then
        result = setResult( L["SIGNAL_INVALID_OPERATION"], fname, debugstack(2))
        return nil, result
    end
	if isHandleInMorgue( target_h ) then
        return false, nil 
    end

	if signal == thread.SIG_WAKEUP then
        if wakeupThread( target_h ) then
            return true, nil
        else
            return false, nil
        end
    end

	-- Initialize and insert an entry into the recipient thread's signalTable
    local sender_h = getHandleOfCallingThread()
	local sigEntry = {signal, sender_h, ... }

    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)

	if signal == thread.SIG_ALERT then
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
    local fname 	= "thread:getSignal()"
    local sigEntry 	= nil
    local result 	= nil

    local H  = getHandleOfCallingThread()
	if H == nil then
		result = utils:setResult( L["THREAD_HANDLE_NIL"], fname, debugstack(3) )
		return nil, result
	end

    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        sigEntry = { SIG_NONE_PENDING, nil, nil }
        return sigEntry, nil
    end

    sigEntry = H[TH_SIGNAL_QUEUE]:dequeue()
	if sigEntry[1] == SIG_HAS_PAYLOAD then
		utils:dbgPrint( type[sigEntry[1]])
		utils:dbgPrint( type[sigEntry[2]])
		utils:dbgPrint( type[sigEntry[3]])
	end
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
    local result = nil
	local signalName = nil

    local isValid, errorMsg = signalIsValid(signal)
    if not isValid then
		result = setResult( errorMsg, fname, debugstack(2))
        return nil, result
    end
	local signalName = signalNameTable[signal]
	return signalName, result
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
	local errorMsg = nil
	local result = nil

    local H = getHandleOfCallingThread()

    return H[TH_SIGNAL_QUEUE]:size(), nil
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

local function OnEvent(self, event, ...)
    local ADDON_NAME = select(1, ...)
    local addonName = core:getAddonInfo()
    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
        DEFAULT_CHAT_FRAME:AddMessage(L["ADDON_LOADED_MESSAGE"], 0.0, 1.0, 0)
        eventFrame:UnregisterEvent("ADDON_LOADED")
        WoWThreadsLibInit()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

WoWThreads.loaded = true
