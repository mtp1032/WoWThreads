-- FILE NAME:		Test3.lua
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   25 May, 2023
local _, ThreadTest3 = ...

local Major ="WoWThreads"
local thread = LibStub:GetLibrary( Major )
if not thread then 
    return 
end

local sprintf = _G.string.format 

local SIG_ALERT             = thread.SIG_ALERT
local SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_METRICS           = thread.SIG_METRICS
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local SUCCESS   = thread.SUCCESS
local EMPTY_STR = thread.EMPTY_STR

local function func()
    local DONE = false
    local threadId = thread:getId()

    while not DONE do
        thread:yield()
        local signal, sender_h = thread:getSignal()
        if signal == SIG_TERMINATE then
            DONE = true
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage( sprintf("Thread %d terminated.", threadId), 0.0, 1.0, 1.0 )

end
local function main( maxThreads )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local DONE = false
    local threads = {}

    local threadId, result = thread:getId()
    thread:print( sprintf("Main thread (Id = %d) creating %d child threads.", threadId, maxThreads ) )

    local numCreated = 0
    for i = 1, maxThreads do
        threads[i], result = thread:create( 20, func )
        if not result[1] then thread:postResult( result ) end
    end

    thread:delay( 120 )
    for i = 1, maxThreads do
        result = thread:sendSignal( threads[i], SIG_TERMINATE )
        if not result[1] then thread:postResult( result ) end
    end

    DEFAULT_CHAT_FRAME:AddMessage( "WoWThreads: Main thread terminated successully.", 0.0, 1.0, 1.0 )
end
DEFAULT_CHAT_FRAME:AddMessage( "*** WoWThreads Test 3 ***.", 0.0, 1.0, 1.0 )

local maxThreads = 5
local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
main_h, result = thread:create( 60, main, maxThreads )
assert( result[1] == SUCCESS, sprintf("ASSERT FAILED: %s", result[2]))




