--------------------------------------------------------------------------------------
-- Utils.lua
-- AUTHOR: Michael Peterson 
-- ORIGINAL DATE: 9 March, 2021
----------------------------------------------------------------------------------------
local _,  WoWThreads = ...
WoWThreads.Utils = {}
utils = WoWThreads.Utils
local fileName = "Utils.lua"
local E = errors
local L = WoWThreads.L

local sprintf = _G.string.format
utils.wt = coroutine
wt = utils.wt

-- ************************ GLOBAL VARIABLES ********************************************
utils._EMPTY = ""
local _EMPTY = utils._EMPTY
--*************************** THE INFO TABLE ********************************************
--                      The infoTable
--***************************************************************************************
--                      Indices into the infoTable table
local INTERFACE_VERSION = 1	-- string
local BUILD_NUMBER 		= 2	-- string
local BUILD_DATE 		= 3	-- string
local TOC_VERSION		= 4	-- number
local ADDON_NAME 		= 5	-- string

local infoTable = {}

--******************** ADDON AND ADMIN SERVICES *****************************************
--                      Game/Build/AddOn Info (from Blizzard's GetBuildInfo())
--***************************************************************************************
local infoTable = { GetBuildInfo() }

function utils:getAddonName()
	return infoTable[ADDON_NAME]
end
function utils:getReleaseVersion()
    return infoTable[INTERFACE_VERSION]
end
function utils:getBuildNumber()
    return infoTable[BUILD_NUMBER]
end
function utils:getBuildDate()
    return infoTable[BUILD_DATE]
end
function utils:getTocVersion()
    return infoTable[TOC_VERSION]	-- e.g., 90002
end
function utils:printChatMsg( msg )
	DEFAULT_CHAT_FRAME:AddMessage( msg, 1.0, 1.0, 0.0 )
end

--********************* MATH UTILITIES **************************************************
-- Rounds up to integer
function utils:roundUp( num)
    return math.ceil( num )
end
-- Rounds down to integer
function utils:roundDown( num )
    return math.floor( num )
end
-- Rounds up or down to the nearest integer
function utils:nearestInt( num )
    local lowerInt = math.floor( num )
    local diff = num - lowerInt
    if diff > 0.5 then
        return math.ceil( num )
    end
    return lowerInt
end
-- Calculating Means and StdDevs
-- https://youtu.be/VpQVQv5DSe8
-- https://youtu.be/MlkZXiuxodw

function utils:stats( dataSet )

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

--*********************** TIMER UTILITIES **********************************************
function utils.getFrameInterval()
    return GetTickTime()
end
function utils:getFrameRate()
    return GetFrameRate()
end
-- ********************* MISC UTILITIS **************************************************
function utils:sortHighToLow( entry1, entry2 )
    return entry1[2] > entry2[2]
end
-- takes a string representation of a coroutine address of the form "thread: 000002193BB63890" and
-- converts it to a decimal number.
function utils:hexStrToDecNum( hexAddress )
	local stringNumber = string.sub(hexAddress, 9)
	return( tonumber( stringNumber, 16 ))
end


if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
