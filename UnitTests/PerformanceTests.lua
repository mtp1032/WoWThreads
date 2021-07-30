--------------------------------------------------------------------------------------
-- PerformanceTests.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
local _, WoWThreads = ...
WoWThreads.PerformanceTests = {}
pt = WoWThreads.PerformanceTests

local fileName = "PerformanceTests.lua"
local L = WoWThreads.L
local E = errors
local U = utils
local DEBUG = E:isDebug()

local sprintf = _G.string.format

local SIG_NONE          = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN        = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP        = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_NUMBER_OF     = timer.SIG_WAKEUP

local threadStats = {}
local threadTable = {}
local NUM_THREADS = 2
local clockInterval = mgmt:getClockInterval()

function calculateDatasetStats( dataSet )

	local sum = 0
	local mean = 0
	local variance = 0
	local stdDev = 0
	local n = #dataSet

	if dataSet == nil then
		return mean, stdDev
	end
	if n == 0 then
		return mean, stdDev
	end

	-- calculate the mean
    for i = 1, n do
		sum = sum + dataSet[i]	-- ERROR HERE. See Lua Error stack trace below
	end
	mean = sum/n

	-- calculate the variance
	local sumSquares = 0
	for i = 1, n do
        local diffSquared = ((dataSet[i]) - mean )^2
		sumSquares = sumSquares + diffSquared
	end

    variance = sumSquares/(n-1)
    stdDev = math.sqrt( variance )

	return mean, stdDev
end

local function calculateOverallStats()

	local yieldTime = {}
	local lifeTime = {}
	local yieldRatio = {}
	local runRatio = {}

	for i = 1, #threadStats do
		local threadMetrics = threadStats[i]
		table.insert( yieldTime, threadMetrics[1] )
		table.insert( lifeTime, threadMetrics[2] )
		table.insert( yieldRatio, threadMetrics[3])
		table.insert( runRatio, threadMetrics[4])
	end

	local meanYieldInterval, stdDevYieldInterval 	= calculateDatasetStats( yieldTime )
	local meanLifeTime, stdDevLifetime 				= calculateDatasetStats( lifeTime )
	local meanYieldRatio, stdDevYieldRatio 			= calculateDatasetStats( yieldRatio )
	local meanRunRatio, stdDevRunRatio 				= calculateDatasetStats( yieldRatio )

	local s = sprintf("Mean yield interval: %0.1f (stdDev %0.1f\n", meanYieldInterval,stdDevYieldInterval)
	mf:postMsg( s )

	s = sprintf("Mean life time: %0.2f (stdDev %0.2f)\n", meanLifeTime, stdDevLifetime )
	mf:postMsg( s )
	s = sprintf("Mean yield ratio: %0.2f (stdDev %0.2f)\n", meanYieldRatio, stdDevYieldRatio )
	mf:postMsg( s )

	s = sprintf("Mean run ratio: %0.2f (stdDev %0.2f)\n", meanRunRatio, stdDevRunRatio )
	mf:postMsg( s )

end

local function printStats( threadMetrics )
	local s = sprintf("avg yield interval %0.2f seconds, lifetime %0.2f seconds, yieldRatio %0.2f%%, runRatio %0.2f%%\n",
													threadMetrics[2], threadMetrics[4], threadMetrics[5] * 100, threadMetrics[6] * 100)
	return s

end
local function threadFunc()
	local signal = SIG_NONE
	local result = {SUCCESS, nil, nil}

	while signal ~= SIG_RETURN do
		thread:yield()
		signal = thread:getSignal()
	end

	if isValid == false then
		mf:postResult( result )
		return
	end
	
	local thread_h = thread:self()
	local threadMetrics, result = mgmt:getMetrics( thread_h )
	table.insert( threadStats, threadMetrics )
	local str = printStats( threadMetrics )
	mf:postMsg( str )
end

local function main()
	local result = {SUCCESS, nil, nil }

	print( tostring( clockInterval ))
	for i = 1, NUM_THREADS do
		local yieldInterval = clockInterval * 40		-- 0.334 seconds
		threadTable[i], result = thread:create( yieldInterval, threadFunc )
	end

	E:dbgPrint( "main_h delaying for 5 seconds")
	thread:delay( 5 )
	E:dbgPrint( "... delay complete. Signaling threads to terminate.")

	for i = 1, NUM_THREADS do
		thread:sendSignal( threadTable[i], SIG_RETURN)
	end
	E:dbgPrint("SIG_RETURN sent to all threads.")
	local signal = SIG_NONE
	while signal ~= SIG_RETURN do
		thread:yield()
		signal = thread:getSignal()
	end
	calculateOverallStats()
end

SLASH_TESTS1 = "/perf"
SlashCmdList["TESTS"] = function( msg )
    local result = {SUCCESS, nil, nil }

    msg = strupper( msg )
    local main_h = nil
    if msg == "RUN" then
		local yieldInterval = clockInterval*300    -- approx. 5 seconds
		if main_h == nil then
			main_h, result = thread:create( yieldInterval, main  ) 
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
