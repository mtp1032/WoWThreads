--------------------------------------------------------------------------------------
-- Signals.lua 
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 11 December, 2021 

-- REFERENCES:
-- https://www.tutorialspoint.com/lua/lua_SignalsThread.htm
-- https://wow.gamepedia.com/Lua_functions

local _, WoWThreads = ...
WoWThreads.Signals = {}
sig = WoWThreads.Signals

local fileName = "Signals.lua"
local L = WoWThreads.L
local E = errors
local DEBUG = errors.DEBUG

local SUCCESS   = errors.STATUS_SUCCESS
local FAILURE   = errors.STATUS_FAILURE

local sprintf   = _G.string.format

-- Indices into the thread handle table
local TH_EXECUTABLE             = timer.TH_EXECUTABLE
local TH_IDENTIFIER             = timer.TH_IDENTIFIER
local TH_ADDRESS                = timer.TH_ADDRESS
local TH_STATUS                 = timer.TH_STATUS
local TH_FUNC_ARGS              = timer.TH_FUNC_ARGS
local TH_JOIN_RESULTS           = timer.TH_JOIN_RESULTS
local TH_DELAY_TICKS_REMAINING  = timer.TH_DELAY_TICKS_REMAINING
local TH_SIGNAL                 = timer.TH_SIGNAL
local TH_INITIAL_TICKS          = timer.TH_INITIAL_TICKS
local TH_YIELD_TIME             = timer.TH_YIELD_TIME
local TH_YIELD_COUNT            = timer.TH_YIELD_COUNT
local TH_DURATION_TICKS         = timer.TH_DURATION_TICKS
local TH_REMAINING_TICKS        = timer.TH_REMAINING_TICKS

local TH_NUM_ELEMENTS           = timer.TH_NUM_ELEMENTS


-- In all cases receipt of one of these signals queues the receiving thread
-- for immediate resumption (on the next tick)
local SIG_NONE      = timer.SIG_NONE    -- default value. Means no signal is pending
local SIG_RETURN    = timer.SIG_RETURN  -- cleanup state and return from the action routine
local SIG_WAKEUP    = timer.SIG_WAKEUP  -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_LAST      = timer.SIG_WAKEUP
local SIG_FIRST     = timer.SIG_FIRST

local sigNames = {
            "SIG_NONE",
            "SIG_RETURN",
            "SIG_WAKEUP"
        }

function sig:isValid( signal )
    local isValid = true
    local result = {SUCCESS, nil, nil }

    if signal < SIG_NONE then
        isValid = false
    end
    if signal > SIG_LAST then
        isValid = false
    end
    if isValid == false then
        return isValid, E:setResult( L["SIGNAL_INVALID"], debugstack() )
    end

    return isValid, result
end
-- *************** GET SIGNAL NAME ***************
function sig:getSigName( signal )
    if not sig:isValid( signal ) then
        local result = E:setResult( L["SIGNAL_INVALID"], debugstack())
        return nil, result
    end
    return sigNames[signal]
end
-- ************* SEND SIGNAL ***************
function sig:sendSignal( thread_h, signal )
    local result = {SUCCESS, nil, nil }
    local delivered = true

    if not sig:isValid( signal ) then
        result = E:setResult( L["SIGNAL_INVALID"], debugstack() )
        return false, result
    end
    -- Only threads receiving SIG_WAKEUP get their
    -- TH_REMAINING_TICKS adjusted to 1 for immediate
    -- execution

    thread_h[TH_SIGNAL] = signal
    if signal == SIG_WAKEUP then
        timer:queueThread( thread_h, signal)
    end
    return delivered, result
end
-- ************ GET/RETRIEVE SIGNAL **********
function sig:getSignal( thread_h )
    return thread_h[TH_SIGNAL]
end


if E:isDebug() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
