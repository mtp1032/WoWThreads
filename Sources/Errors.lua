--------------------------------------------------------------------------------------
-- Errors.lua
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 March, 2021
--------------------------------------------------------------------------------------
local _, WoWThreads = ...
WoWThreads.Errors = {}	
errors = WoWThreads.Errors	
local fileName = "Errors.lua"
local sprintf = _G.string.format

local L = WoWThreads.L
local E = errors
--[[ 
INFO: Error handling
https://www.tutorialspoint.com/lua/lua_error_handling.htm
 ]]

 --                      The Result Table
local DISPLAY_TIME = 20

errors.STATUS_SUCCESS = 1
errors.STATUS_FAILURE = 0

local SUCCESS   = errors.STATUS_SUCCESS
local FAILURE   = errors.STATUS_FAILURE

errors.RESULT = {SUCCESS, nil, nil }
local RESULT = errors.RESULT

local ARG_NIL 			= lang.ARG_NIL
local ARG_MISSING 		= lang.ARG_MISSING
local ARG_ILL_FORMED	= lang.ARG_ILL_FORMED
local ARG_INVALID_VALUE	= lang.ARG_INVALID_VALUE
local ARG_INVALID_TYPE 	= lang.ARG_INVALID_TYPE
local ARG_INVALID_OP	= lang.ARG_INVALID_OP

local INVALID_THREAD_HANDLE	= lang.INVALID_HANDLE
local UNEQUAL_VALUES		= lang.UNEQUAL_VALUES
local INCONSISTENT_STATE	= lang.INCONSISTENT_STATE

errors.DEBUG = false
local DEBUG = errors.DEBUG

function errors:setDebug()
	errors.DEBUG = true
	return errors.DEBUG
end
function errors:cancelDebug()
	errors.DEBUG = false
	return errors.DEBUG
end
function errors:isDebug()
	return errors.DEBUG
end
---------------------------------------------------------------------------------------------------
--                      LOCAL FUNCTIONS
----------------------------------------------------------------------------------------------------
local function simplifyStackTrace( stackTrace )
	local startPos, endPos = string.find( stackTrace, '\'' )
	stackTrace = string.sub( stackTrace, 1, startPos )
	stackTrace = string.gsub( stackTrace, "Interface\\AddOns\\", "")
	
	stackTrace = string.gsub( stackTrace, "`", "<")
	stackTrace = string.gsub( stackTrace, "'", ">")
		
	stackTrace = string.gsub( stackTrace, ": in function ", "")        
	local stackFrames = { strsplit( "/\n", stackTrace )}
			
	local numFrames = #(stackFrames)
	for i = 1, numFrames do
		stackFrames[i] = strtrim( stackFrames[i] )
	end
	
	for i = 1, numFrames do
		startPos = strfind( stackFrames[i], "<")
		stackFrames[i] = string.sub( stackFrames[i], 1, startPos-1)
	end
	
	local simplifiedStackTrace = stackFrames[1]
	for i = 2, numFrames do
		simplifiedStackTrace = strjoin( "\n", simplifiedStackTrace, stackFrames[i])
		simplifiedStackTrace = strtrim( simplifiedStackTrace )
	end
	return simplifiedStackTrace
end	
local function fileAndLineNo( stackTrace )
	local pieces = {strsplit( ":", stackTrace, 5 )}
	local segment = {strsplit( "\\", pieces[1], 5 )}
	local i = 1
	local fileName = segment[i]
	while segment[i] ~= nil do
		index = tostring(i)
		fileName = segment[i]
		i = i+1 
	end

	-- [EventHandler.lua"]	-- need to remove the " character - the 18th character in the string"
	local strLen = string.len( fileName )
	local fileName = string.sub( fileName, 1, strLen - 2 )
	local lineNumber = tonumber(pieces[2])
	local fileAndLine = sprintf("[%s:%d]", fileName, lineNumber )

	return fileAndLine, fileName, lineNumber
end
---------------------------------------------------------------------------------------------------
--                      PUBLIC/EXPORTED FUNCTIONS
----------------------------------------------------------------------------------------------------
-- return an error message of the form [File.lua:66] FAILED: Invalid parameter
-- function errors:setResult( errMsg, stackTrace )
-- 	local fn = fileAndLineNo( stackTrace )
-- 	errMsg = sprintf("%s FAILED: %s\nSTACK TRACE:\n%s\n", fn, errMsg, stackTrace )
-- 	local result = {STATUS_FAILURE, errMsg, stackTrace}
-- 	return result
-- end

function errors:setResult( errMsg, stackTrace )
	local result = { STATUS_FAILURE, nil, nil }

	local fn = fileAndLineNo( stackTrace )
	errMsg = sprintf("%s %s\n", fn, errMsg )
	result[2] = errMsg

	if stackTrace ~= nil then
		result[3] = stackTrace
	end
	return result
end
-- e.g., returns "[file.lua:65]"
function errors:prefix()
	local prefix = fileAndLineNo( debugstack(2) )
	return prefix
end
function errors:dbgPrint( msg )
	local fn = fileAndLineNo( debugstack(2) )
	local str = nil
	if msg then
		str = sprintf("%s %s", fn, msg )
	else
		str = fn
	end
	DEFAULT_CHAT_FRAME:AddMessage( str, 1.0, 1.0, 0.0 )
end

local function myfunction ()
	print(debug.traceback("Stack trace"))
	print(debug.getinfo(1))
	print("Stack trace end")
 
	return 10
 end
 function errors:printError( result )
    UIErrorsFrame:AddMessage( result[2], 1.0, 1.0, 0.0, nil, 10 ) 
end


SLASH_DEBUG_TESTS1 = "/dbgtest"
SlashCmdList["DEBUG_TESTS"] = function( msg )
	 
	 myfunction ()
	 print(debug.getinfo(1))
end

if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
