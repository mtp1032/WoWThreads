 -- SignalQueue.lua
 local ADDON_NAME, _ = ... 

-- Import the Utils library
local UtilsLib = LibStub("UtilsLib")
local utils = UtilsLib
-- Create a new library instance, or get the existing one
local SignalQueue = {}
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "SignalQueue", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local SignalQueue, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not SignalQueue then return end -- No need to update if the version loaded is newer

function SignalQueue.new()
    local self = setmetatable({}, {__index = SignalQueue})
    self.front = 1
    self.rear = 0
    self.items = {}
    return self
end
-- @brief: Adds an item to the rear of the queue
-- @param: value
-- @returns: None
function SignalQueue:enqueue(value)
    self.rear = self.rear + 1
    self.items[self.rear] = value
end
-- @bried: removes an item from the front of the queue
-- @param: None
-- @returns: see above
function SignalQueue:dequeue()
    if self:isEmpty() then
        return true
    else
        local value = self.items[self.front]
        self.items[self.front] = nil  -- Optional: clear the slot
        self.front = self.front + 1
        if self.front > self.rear then  -- Reset if the queue is empty
            self.front = 1
            self.rear = 0
        end
        return value
    end
end
-- @brief: Returns the first item in the queue without removing it
-- @param: None
-- @returns: see above
function SignalQueue:peek()
    if self:isEmpty() then
        error("SignalQueue is empty")
    else
        return self.items[self.front]
    end
end
function SignalQueue:isEmpty()
    return self.front > self.rear
end
function SignalQueue:size()
    return self.rear - self.front + 1
end

local fileName = "SignalQueue.lua"
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage(fileName, 0.0, 1.0, 1.0)
end
