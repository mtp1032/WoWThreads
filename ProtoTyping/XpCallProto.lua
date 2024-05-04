local UtilsLib = LibStub("UtilsLib")
local utils = UtilsLib

--================================================
--                  TESTS
-- =================================================

-- Error handler to format error messages and provide a stack trace
local function xcopyErrorHandler(errorMessage)
    return string.format("%s Invalid Type: expected 'table', got 'number'\nStack Trace:\n%s", utils:dbgPrefix(), errorMessage, debugstack(2))
end

-- Function to test xpcall which deliberately throws an error
local function testXpCall(param1, param3)
    if type(param1) ~= 'table' then
        error(string.format("Expected 'param1' to be a table, got %s", type(param1)))
    end
    local x = param1[1]
    return x  -- Consider what you might want to do with 'x'
end

-- Parameters for test function
local param1 = 3
local param2 = nil  -- Adjusted to be a table for correct indexing

-- Use xpcall to handle errors gracefully
local status, result = xpcall(
    function() return testXpCall(param1, param2) end,
    xcopyErrorHandler
)

if not status then
    utils:postMsg( result ) -- Changed to a standard print function for debugging
end
