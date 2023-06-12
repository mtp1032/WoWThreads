-- FILE NAME:		ThreadTest1.lua
-- AUTHOR:          Michael Peterson
-- ORIGINAL DATE:   25 May, 2023
local _, ThreadTest1 = ...

local sprintf = _G.string.format 
local dbg = thread

local Major ="WoWThreads"
local thread = LibStub:GetLibrary( Major )
if not thread then 
    return 
end

local SIG_ALERT             = thread.SIG_ALERT
local SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_METRICS           = thread.SIG_METRICS
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local SUCCESS = true
local main_h = nil

local function childFunc()
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR }
    local signal = SIG_NONE_PENDING
    local DONE = false

    while not DONE do
        thread:yield()
        signal, sender_h = thread:getSignal()
        if signal ~= SIG_TERMINATE then
            if sender_h ~= nil then
            local senderId, result = thread:getThreadId( sender_h)

            end 
        else
            result = thread:sendSignal( sender_h, SIG_TERMINATE )
            assert( result[1] == SUCCESS, sprintf("ASSERT FAILED: %s", result[2]))
            DONE = true
        end
    end
end

local function main()
    local signal = SIG_NONE_PENDING
    local DONE = false
    

    local child_h, result = thread:create( 60, childFunc )
    assert( result[1] == SUCCESS, sprintf("ASSERT FAILED: %s", result[2]))
    
    thread:delay( 60 )

    result = thread:sendSignal( child_h, SIG_TERMINATE )
    assert( result[1] == SUCCESS, sprintf("ASSERT FAILED: %s", result[2]))

    while not DONE do
        thread:yield()
        signal, sender_h = thread:getSignal()        
        if signal == SIG_TERMINATE then
            DONE = true
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage( "WoWThreads: Main thread terminated successully.", 0.0, 1.0, 1.0 )
end
DEFAULT_CHAT_FRAME:AddMessage( "*** WoWThreads Test 1 ***.", 0.0, 1.0, 1.0 )

local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
local main_h = nil
local ticks = 20
result, main_h = thread:create( ticks, main, "main_h")
if not result[1] then thread:postResult( result ) end

 --=================================== TEST OF DBG PRINTING SERVICES ==================
-- local function bottom()
--     thread:print( "In bottom()")
--     print(thread:prefix(), "In bottom()" )
--     local result = thread:setResult( "Action Failed ", debugstack(2))
--     return result
-- end
-- local function middle()
--     local result = bottom()
--     return result
-- end
-- local function top()
--     print( thread:prefix() )
--     local result = middle()
--     return result
-- end
-- print( thread:prefix() )
-- local result = top()
-- print( thread:prefix(), "Hello World.")
-- thread:postResult( result )
-- thread:print( "Done!")

--  


