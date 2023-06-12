--------------------------------------------------------------------------------------
-- FILE NAME:       WoWThreads.Lua 
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   25 May, 2023 

--------------------------------------------------------------------------------------
--      This is the public interface to WoWThreads.                                 --
--------------------------------------------------------------------------------------
local _, WoWThreads = ...

-- Initialize the library
local libName = "WoWThreads", 1
local version = 1

local thread = LibStub:NewLibrary( libName, version)
if not thread then return end

local L = locales.L
local sprintf = _G.string.format 

thread.SIG_ALERT            = dispatch.SIG_ALERT
thread.SIG_JOIN_DATA_READY  = dispatch.SIG_JOIN_DATA_READY
thread.SIG_TERMINATE        = dispatch.SIG_TERMINATE
thread.SIG_METRICS          = dispatch.SIG_METRICS
thread.SIG_NONE_PENDING     = dispatch.SIG_NONE_PENDING

thread.SUCCESS     = core.SUCCESS
thread.EMPTY_STR   = core.EMPTY_STR

local SUCCESS   = thread.SUCCESS
local EMPTY_STR = thread.EMPTY_STR

local function validateThreadHandle( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if thread_h == nil then
        local errMsg = sprintf("Input thread handle nil - %s\n", L["THREAD_HANDLE_NIL"])
        result = core:setResult(L["THREAD_HANDLE_NIL"], debugstack(1) )
        return result
    end  
    -- validate the thread handle's elements
    result = dispatch:checkIfHandleValid( thread_h )
    if not result[1] then return result end
    
    return result
end

-- DESCRIPTION:
-- RETURNS: result
local function validateThreadCreateParms( ticks, func )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 

    if ticks == nil then
        local errMsg = sprintf("%s - ticks not specified.\n", L["INPUT_PARM_NIL"])
        result = core:setResult( errMsg, debugstack(1))
    end
    if type( ticks ) ~= "number" then
        local errMsg = sprintf("%s - ticks not a number.\n", L["INVALID_TYPE"])
        result = core:setResult( errMsg, debugstack(1))
    end
    if func == nil then
        local errMsg = sprintf("%s - Thread function not specified.\n", L["INPUT_PARM_NIL"])
        result = core:setResult( errMsg, debugstack(1))
    end
    if type(func) ~= "function" then
        local errMsg = sprintf("%s - Parameter 2 not a function.\n", L["INVALID_TYPE"])
        result = core:setResult( errMsg, debugstack(1))
    end    
    return result
end
-- DESCRIPTION: Create a new thread.
-- RETURNS: (handle) thread_h, result
function thread:create( ticks, func, ... )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 
    result = validateThreadCreateParms( ticks, func )
    if not result[1] then 
        return nil, result 
    end

    -- Create a handle with a suspended coroutine
    local H, result = dispatch:createHandle( ticks, func )
    if not result[1] then 
        return nil, result 
    end

    local co = dispatch:getCoroutine( H )
    dispatch:insertHandleIntoTCB(H)
    local resumed, val = coroutine.resume( co, ... )
    if not resumed then
        local threadId = dispatch:getThreadId( H )
        local threadState = coroutine.status( co )
        local msg = sprintf("Thread[%d] %s: %s,\n%s\n", threadId, threadState, L["THREAD_RESUME_FAILED"], val)
        result = core:setResult( msg, debugstack(2) )
        return nil, result
    end
    assert( H ~= nil, "ASSERT FAILED")
    assert( result[1] == SUCCESS, sprintf( "%s: Expected 'true', got %s", "ASSERT_FAILED", tostring(result[1]) ))
    return H, result
end 

-- DESCRIPTION: Delays the calling thread for specified number of ticks
-- RETURNS: void
function thread:delay( ticks )
    assert( ticks ~= nil, "ticks: " ..L["INPUT_PARM_NIL"] .. "in thread:delay()." )
    assert( type(ticks) == "number", L["INVALID_TYPE"])

    -- Get the handle of the calling thread
    local thread_h = dispatch:getRunningHandle()

    dispatch:setDelay( thread_h, ticks )    
    dispatch:yield()
end

-- DESCRIPTION: yields execution of the number of ticks specified in thread:create()
-- RETURNS; void
function thread:yield()
    local self_h = dispatch:getRunningHandle()
    dispatch:yield(self_h)
end
-- DESCRIPTION: returns the thread numerical Id
-- RETURNS: (number) threadId, result
function thread:getId( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local threadId = nil

    if thread_h == nil then
        thread_h, threadId = dispatch:getRunningHandle()
        return threadId, result
    else -- thread_h was not nil
        result = dispatch:checkIfHandleValid( thread_h )
        if not result[1] then return nil, result end
    end
    if threadId == nil then
        threadId = dispatch:getThreadId( thread_h )
    end
    return threadId, result
end

-- DESCRIPTION: Returns the handle of the calling thread.
-- RETURNS: (handle) thread_h, (number) threadId
function thread:self()
    local self_h, selfId = dispatch:getRunningHandle()
    return self_h, selfId
end

-- DESCRIPTION: determines whether two threads are the same
-- RETURNS: (boolean) true if equal, result
function thread:areEqual( th1, th2 )
    local areEqual = false
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    assert( th1 ~= nil, sprintf("ASSERT FAILED: Param 1 - %s", L["THREAD_HANDLE_NIL"] ))
    assert( th2 ~= nil, sprintf("ASSERT FAILED: Param 2 - %s", L["THREAD_HANDLE_NIL"] ))

    result = validateThreadHandle( th1 )
    if not result[1] then return areEqual, result end
    result = validateThreadHandle( th2 )
    if not result[1] then return areEqual, result end

    local th1Id = dispatch:getThreadId( th1 )
    local th2Id = dispatch:getThreadId( th2)

    areEqual = th1Id == th2Id
    return areEqual, result
end

-- DESCRIPTION: gets the specified thread's parent
-- RETURNS: (handle) parent_h, result
function thread:getParent( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h == nil then
        thread_h = dispatch:getRunningHandle()
    else
        result = dispatch:checkIfHandleValid( thread_h ) 
    end
    if not result[1] then 
        return nil, result 
    end

    local parent_h = dispatch:getThreadParent( thread_h )
    return parent_h, result
end

-- DESCRIPTION: gets a table of the specified thread's children.
-- RETURNS: (table) childThreads, result
function thread:getChildThreads( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h == nil then
        thread_h = dispatch:getRunningHandle()
    else
        result = dispatch:checkIfHandleValid( thread_h )
        if not result[1] then 
            return nil, result 
        end
    end

    local children, tableCount = dispatch:getThreadChildren( thread_h )
    if tableCount == 0 then 
        children = nil 
    end
    return children, result
end 

-- DESCRIPTION: gets the specified thread's execution state
-- RETURNS: (string) state ( = "completed", "suspended", "queued", ), result.
function thread:getState( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if thread_h == nil then
        result = core:setResult( L["THREAD_HANDLE_NIL"], debugstack(1))
        return nil, result
    end
    result = validateThreadHandle( thread_h )
    if not result[1] then return nil, result end
            
    local state = dispatch:getThreadState( thread_h )
    return state, result
end
-----------------------------------------------------------
--                   SIGNAL FUNCTIONS                      -
-----------------------------------------------------------
-- DESCRIPTION: gets the string name of the specified signal
-- RETURNS: (string) signalName. result
function thread:getSignalName( signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = dispatch:validateSignal( signal )
    if not result[1] then return nil, result end

    local signalName = dispatch:getSignalName( signal )
    return signalName, result
end

-- DESCRIPTION: sends a signal to the specified thread. 
-- RETURNS: result. 
function thread:sendSignal( thread_h, signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if thread_h == nil then
        result = core:setResult( L["THREAD_HANDLE_NIL"], debugstack(2) )
        return result
    end
    result = validateThreadHandle( thread_h )
    if not result[1] then return result end
    
    result = dispatch:validateSignal( signal )
    if not result[1] then return result end

    local state = dispatch:getThreadState( thread_h )
    if state == "completed" then
        core:setResult(L["THREAD_ILLEGAL_OPERATION"], debugstack(1) )
        return result
    end
    
    -- everything is hunky dory
    dispatch:deliverSignal( thread_h, signal )
    return result
end

-- DESCRIPTION: retrieves a signal sent to the calling thread.
-- RETURNS: (number) signal, (handle) sender_h NOTE: sender_h 
-- will be "" (EMPTY_STR) if sent from Blizzard code.
--
-- EXAMPLE: More than one signal in the thread's queue.
-- signal, sender_h = thread:getSignal()
-- while signal ~= SIG_NONE_PENDING do
--     <process signal>
--     signal, sender_h = thread:getSignal()
-- end
function thread:getSignal()
    signal, sender_h = dispatch:getSignal()
    local thread_h, threadId = dispatch:getRunningHandle() 
    return signal, sender_h
end
-------------------------------------------------------------------
--                  UTILITIES
-------------------------------------------------------------------
function thread:prefix( stackTrace )
	if stackTrace == nil then stackTrace = debugstack(2) end
	
	local pieces = {strsplit( ":", stackTrace, 5 )}
	local segments = {strsplit( "\\", pieces[1], 5 )}

	local fileName = segments[#segments]
	
	local strLen = string.len( fileName )
	local fileName = string.sub( fileName, 1, strLen - 2 )
	local names = strsplittable( "\/", fileName )
	local lineNumber = tonumber(pieces[2])
	local location = sprintf("[%s:%d] ", names[#names], lineNumber)
	return location
end
function thread:print( msg )
	local fileAndLine = thread:prefix( debugstack(2) )
	local str = msg
	if str then
		str = sprintf("%s %s", fileAndLine, str )
	else
		str = fileAndLine
	end
	DEFAULT_CHAT_FRAME:AddMessage( str, 0.0, 1.0, 1.0 )
end	
function thread:printx( ... )
	local prefix = thread:prefix( debugstack(2) )
    print( prefix, ... )
end	
function thread:setResult( errMsg, stackTrace )
	local result = { FAILURE, EMPTY_STR, EMPTY_STR }

	local msg = sprintf("%s %s:\n", thread:prefix( stackTrace ), errMsg )
	result[2] = msg

	if stackTrace ~= nil then
		result[3] = stackTrace
	end
	return result
end
function thread:postResult( result )
	if errorMsgFrame == nil then
		errorMsgFrame = frames:createErrorMsgFrame("Error Message")
	end

	if result[1] ~= FAILURE then 
		return
	end

	local resultMsg = sprintf("%s:\n%s\n", result[2], result[3])
	errorMsgFrame.Text:Insert( resultMsg )
	errorMsgFrame:Show()
end

local fileName = "locales.Lua"
if core:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
