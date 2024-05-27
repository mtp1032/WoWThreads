-- In WoWThreads.lua
local callbackTable = {}
local thread = {}
local scheduler = {}
local coroutineQueue = {}

-- The registration function defined in WoWThreads.lua
function thread:registerCallback(addonName, callback)
    if type(addonName) ~= "string" then
        error("addonName not a string.")
    end
    
    if callback == nil then
        error("callback was nil.")
    end
    if type(callback) ~= "function" then
        error("callback not a function.")
    end
    
    -- Initialize the list for the addon if it doesn't exist
    if not callbackTable[addonName] then
        callbackTable[addonName] = {}
    end
    
    -- Add the callback to the list
    table.insert(callbackTable[addonName], callback)
end

-- A function to execute the callbacks when an error occurs
local function reportErrorToClient(addonName, errorMessage)
    local callbacks = callbackTable[addonName]
    
    if callbacks then
        for _, callback in ipairs(callbacks) do
            local success, err = pcall(callback, errorMessage)
            if not success then
                -- Log the error if the callback itself fails
                print("Error in callback for addon " .. addonName .. ": " .. err)
            end
        end
    else
        -- Log if no callbacks are registered
        print("No callbacks registered for addon " .. addonName)
    end
end

-- Function to create and schedule a new thread
function thread:create(func, addonName)
    local co = coroutine.create(func)
    table.insert(coroutineQueue, {co = co, addonName = addonName})
end

-- Scheduler function to resume coroutines
function scheduler:run()
    while #coroutineQueue > 0 do
        local coData = table.remove(coroutineQueue, 1)
        local co = coData.co
        local addonName = coData.addonName

        -- Wrap coroutine.resume in a pcall to catch errors
        local success, res = pcall(coroutine.resume, co)
        if not success then
            reportErrorToClient(addonName, res)
        elseif coroutine.status(co) ~= "dead" then
            -- Requeue the coroutine if it is not finished
            table.insert(coroutineQueue, coData)
        end
    end
end

-- Example usage of creating a thread
-- thread:create(function()
--     -- Coroutine function code
-- end, "ExampleAddon")

-- Example client addon code
local ADDON_NAME = "ExampleAddon"

-- Register a callback to handle errors
thread:registerCallback(ADDON_NAME, function(errorMessage)
    print("Received error: " .. errorMessage)
end)

-- Create a new thread
thread:create(function()
    error("This is a test error")
end, ADDON_NAME)

-- Run the scheduler
scheduler:run()
