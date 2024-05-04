 -- FifoQueue.lua
local fileName = "FifoQueue.lua"
local sprintf = _G.string.format

-- Get the UtilLIb library
local UtilsLib = LibStub("UtilsLib")
local utils = UtilsLib
-- Create a new library instance, or get the existing one
local FifoQueue = {}
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "FifoQueue", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local FifoQueue, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not FifoQueue then return end -- No need to update if the version loaded is newer
local fifo = FifoQueue

-- Define the FifoQueue type with its methods
function FifoQueue.new()
    local self = setmetatable({}, FifoQueue)
    self.front = 1
    self.rear = 0
    self.items = {}
    return self
end
-- @brief: Adds an item to the rear of the queue
-- @param: value
-- @returns: None
function FifoQueue:enqueue(value)
    self.rear = self.rear + 1
    self.items[self.rear] = value
end
-- @bried: removes an item from the front of the queue
-- @param: None
-- @returns: see above
function FifoQueue:dequeue()
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
function FifoQueue:peek()
    if self:isEmpty() then
        error("FifoQueue is empty")
    else
        return self.items[self.front]
    end
end
function FifoQueue:isEmpty()
    return self.front > self.rear
end
function FifoQueue:size()
    return self.rear - self.front + 1
end

--[[ 
    EXAMPLE USAGE
local myFifoQueue = FifoQueue.new()
myFifoQueue:enqueue(10)
myFifoQueue:enqueue(20)
print("Peek: ", myFifoQueue:peek())  -- Should output 10 without removing it
print("Dequeued: ", myFifoQueue:dequeue())
print("Peek: ", myFifoQueue:peek())  -- Should now output 20
print("Is empty: ", myFifoQueue:isEmpty())
print("FifoQueue size: ", myFifoQueue:size())
 ]]

if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage(fileName, 0.0, 1.0, 1.0)
end
