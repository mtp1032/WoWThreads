--------------------------------------------------------------------------------------
-- RegressionTests.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
local _, WoWThreads = ...
WoWThreads.RegressionTests = {}

local fileName = "RegressionTests.lua"
local L = WoWThreads.L
local E = errors
local U = utils
local DEBUG     = E:isDebug()
local SUCCESS   = errors.STATUS_SUCCESS
local FAILURE   = errors.STATUS_FAILURE

local sprintf = _G.string.format

local SIG_NONE      = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN    = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP    = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_LAST      = timer.SIG_WAKEUP
local SIG_FIRST     = timer.SIG_FIRST

local clockInterval = mgmt:getClockInterval()
print( "Dispatch Interval " .. tonumber( clockInterval ) .. " seconds.")

local function generator()
    local greeting = "Hello World!"
    local count = 1
    local done = false
    while not done do
        thread:yield()
        count = count + 1
        if count == 4 then done = true end
    end
    thread:exit( greeting )
end
local function sigReturn()
	local signal = SIG_NONE
    local threadId = thread:getId()

	while signal ~= SIG_RETURN do
		thread:yield()
        local thread_h = thread:self()
		signal, isValid, result = thread:getSignal( thread_h )
        if not isValid then 
            mf:postResult( result ) 
            return 
        end
	end
    threadId = thread:getId()
	mf:postMsg(sprintf("Success! Thread %d received %s. Exiting.\n", threadId, thread:getSignalName( SIG_RETURN )))
end
local function sigWakeup()
	local signal = SIG_NONE

	while signal ~= SIG_WAKEUP do
		thread:yield()
		signal, result = thread:getSignal()
	end

    local thread_h = thread:self()
    local threadId = thread:getId()
    local stats, result = mgmt:getMetrics( thread_h )
    if stats ~= nil then
        local s = sprintf("Thread %d recieved signal %s. Metrics follow:\n", threadId, thread:getSignalName( signal ) )
        s = s .. sprintf("    Thread state: %s\n", stats[1])
        s = s .. sprintf("    Average YieldTime: %0.2f seconds.n", stats[2] )
        s = s .. sprintf("    Ticks per Yield: %d ticks\n", stats[3])
        s = s .. sprintf("    Total Life Time: %d seconds\n", stats[4] )
        s = s .. sprintf("    Relative Time Yielded: %0.2f%%\n", stats[5] * 100 )
        s = s .. sprintf("    Relative Time Active: %0.2f%%\n", stats[6] * 100 )

        mf:postMsg( sprintf("%s\n", s ))
    end
end
local function helloWorld( greeting )
    mf:postMsg( sprintf("Single Parameter: %s\n\n", greeting ))
end
local function whoAmI( thread_h )
    local id = thread:getId( thread_h )
    mf:postMsg( sprintf("Thread Handle Parameter: I am thread %d\n", tostring( id )))
end
local function sum( v )
    local a, b, c = unpack(v)
    mf:postMsg( sprintf("Multiple Parameters: sum = %d\n", a + b + c))
end
local function main()
	local result = {SUCCESS, nil, nil }
    local numThreads = 5
    
    mf:postMsg(sprintf("*************************************\n"))
    mf:postMsg(sprintf("** TEST: THREAD DELAY 2.0 seconds ***\n"))
    mf:postMsg(sprintf("*************************************\n\n"))

    thread:delay( 2.0 )
    mf:postMsg( sprintf("thread:delay() successful.\n\n"))

    mf:postMsg(sprintf("*************************************\n"))
    mf:postMsg(sprintf("****** TEST: PARAMETER PASSING ********\n"))
    mf:postMsg(sprintf("*************************************\n\n"))    

    local yieldInterval =  clockInterval*25    -- yield time 25 ticks or approx. 0.4 seconds

    local result = {SUCCESS, nil, nil }
    local v = {1, 2, 3}
    local th1, result = thread:create( yieldInterval, sum, v )
    if th1 == nil then
        mf:postResult( result )
        return
    end

    local th2, result = thread:create( yieldInterval, whoAmI, "HANDLE" )
    if th2 == nil then
        mf:postResult( result )
        return
    end

    local greeting = "Hello World!"
    local th3, result = thread:create( yieldInterval, helloWorld, greeting )
    if th3 == nil then
        mf:postResult( result )
        return
    end

    thread:delay( 2.0 )
    mf:postMsg( sprintf("Parameter passing successful.\n\n"))

        
    mf:postMsg(sprintf("*************************************\n"))
    mf:postMsg(sprintf("***********TEST: JOIN/EXIT *************\n"))
    mf:postMsg(sprintf("*************************************\n\n"))

    local generator_h, result = thread:create( yieldInterval, generator )
    if generator_h == nil then
        mf:postResult( result )
        return
    end

    local data = thread:join( generator_h )
    mf:postMsg( sprintf("Join Test Successful. Parameter - %s\n\n", data ))
 
    mf:postMsg(sprintf("*************************************\n"))
    mf:postMsg(sprintf("************ TEST: SIG_RETURN *********\n"))
    mf:postMsg(sprintf("*************************************\n\n"))

	local threads = {}
    mf:postMsg( sprintf("SIG_RETURN: Creating %d threads.\n", numThreads ))
	local yieldInterval = clockInterval*random(20,30)
	for i = 1, numThreads do
		threads[i], result = thread:create( yieldInterval, sigReturn )        
        if threads[i] == nil then
            mf:postResult( result ) 
            return 
        end
	end

	-- -- this is to make sure that the test threads are up and running.
	thread:delay( 2.0 )

    mf:postMsg(sprintf("Sending SIG_RETURN to the previously created %d threads.\n\n", numThreads))
	for i = 1, numThreads do
        local thread_h = threads[i]
        local successful, result = thread:sendSignal( thread_h, SIG_RETURN )
        if not successful then
            postResult( result )
        end

        local threadId = thread:getId(  threads[i] )

        mf:postMsg(sprintf("SIG_RETURN successfully sent to thread %d\n", threadId ))
	end
 
    mf:postMsg(sprintf("\n*************************************\n"))
    mf:postMsg(sprintf("************ TEST: SIG_WAKEUP *********\n"))
    mf:postMsg(sprintf("*************************************\n\n"))

    threads = {}

    mf:postMsg( sprintf("Testing SIG_WAKEUP: Creating %d threads.\n", numThreads ))
	for i = 1, numThreads do
        local ticks = random( 50, 300 )
        local yieldInterval = clockInterval * ticks -- approx. 3.33 seconds
    
		threads[i], result = thread:create( yieldInterval, sigWakeup )
        if threads[i] == nil then
            mf:postResult( result )
            return
        end
        local threadId = thread:getId( threads[i])
	end

    mf:postMsg(sprintf("\nSending SIG_WAKEUP to the previously created %d threads.\n\n", numThreads))
	for i = 1, numThreads do
		local successful, result = thread:sendSignal( threads[i], SIG_WAKEUP )
        if not successful then
            mf:postResult( result ) 
            return 
        end

        local threadId = thread:getId(  threads[i] )
        mf:postMsg(sprintf("SIG_WAKEUP successfully sent to thread %d\n", threadId ))
	end
    mf:postMsg(sprintf("\n\n********* REGRESSION TESTS COMPLETE ***********\n\n"))

    local signal = SIG_NONE
	while signal ~= SIG_RETURN do
		thread:yield()
		signal, isValid, result = thread:getSignal()
        if not isValid then 
            mf:postResult( result ) 
            return 
        end
	end
    mf:postMsg( sprintf("Regression Tests Terminated.\n"))
end

local main_h = nil  

SLASH_REGRESSION_TESTS1 = "/regression"
SLASH_REGRESSION_TESTS2 = "/rtest"
SlashCmdList["REGRESSION_TESTS"] = function( msg )
    local result = {SUCCESS, nil, nil }

    msg = strupper( msg )
    
    if msg == "START" then
        local yieldInterval = clockInterval*300    -- approx. 5 seconds
	    if main_h == nil then
		    main_h, result = thread:create( yieldInterval, main  ) 
            print( thread:getId( main_h ))  
            if main_h == nil then
                mf:postResult( result ) 
                return       
	        end
        end
    end
    if msg == "STOP" then
		local delivered, result = thread:sendSignal( main_h, SIG_RETURN )
        if not delivered then 
            mf:postResult( result )
            return 
        end
	end

    if msg == "STATS" then
        local remainingThreads = mgmt:getThreadCountByState()
        mf:postMsg( sprintf("Total threads remaining %d\n", remainingThreads ))
    end

end

 if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
