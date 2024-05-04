-- Prototype

local SUCCESS = true
local FAILURE = false
local result = {errorMsg, stackTrace }
-- errorMsge: [ERROR] Parament nil in function someFunction at [FILE:LINE]
-- stacKTrace: Abreviated stack trace: ADDON_NAME/File/File2/...[FILE:LINE]

--[[ 
    In Lua, the xpcall function is used to call another function in a protected mode 
    and handle any errors with an error handler. However, xpcall itself only takes a 
    single argument function by default, which can be challenging when you need to 
    pass multiple or variable arguments to the function being called.

    To handle this situation where you have a function like someFunction(param1, param2, ...), 
    you can utilize a closure or an anonymous function to capture the variable arguments 
    passed to the function and pass them along.

    In the example below, You'll need to wrap someFunction in an anonymous function that 
    captures all arguments, including the variable arguments. Here's how you can do it:
]]
local function parseErrorMsg( inputString )
    local lastColon = nil  -- Variable to store the position of the last colon
    local pos = 0          -- Starting position for the search
    
    -- Loop to find the last colon
    while true do
        local start, ends = string.find(inputString, ":", pos + 1) -- Find ':' starting from pos+1
        if not start then break end  -- If no more colons, exit the loop
        lastColon = start  -- Update lastColon with the new found position
        pos = start        -- Update pos to move the search start point forward
    end

    -- If a colon was found, extract the substring after it
    if lastColon then
        return string.sub(inputString, lastColon + 1)
    else
        return nil  -- No colon was found, return nil or handle as needed
    end
end
    
-- -- Test the function with the provided example
-- 
-- local inputString = "Interface/AddOns/WoWThreads/Libs/UtilsLib.lua:409: attempt to index local 'param1' (a number value)"
-- local extractedMessage = parseErrorMsg(inputString)
-- print(extractedMessage)


local function myErrorHandler(errorMessage)
    errorMessage = parseErrorMsg( errorMessage )
    errorMessage = string.format("%s %s", utils:dbgPrefix(), errorMessage)
    return errorMessage
end

local function triggerError(param1, param2, ...)
    -- This will trigger an error because 'param1' can't be indexed
    local x = param1[1]
    return "SUCCESS"
end

-- Example call to triggerError()` using `xpcall` and an anonymous function.
-- Example call to triggerError()` using `xpcall` and an anonymous function.
    local param1 = 3
    local param2 = "value2"
    local bar = "bar"
    local foo = "foo"
    local status, result = xpcall(
                        function() return           -- the anonymous function
                        triggerError(
                            param1, param2, foo, bar ) 
                        end,
                        myErrorHandler )
if not status then
    utils:postMsg( result )
end
