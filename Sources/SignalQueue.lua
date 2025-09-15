-- Filename: SignalQueue.lua

WoWThreads = WoWThreads or {}
WoWThreads.SignalQueue = WoWThreads.SignalQueue or {}

if not WoWThreads.UtilsLib.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("UtilsLib.lua not loaded.", 1, 0, 0 )
end
local signal = WoWThreads.SignalQueue

-- SignalQueue class definition
local SignalQueue = {}
SignalQueue.__index = SignalQueue

-- Constructor
function signal.new()
    local self = setmetatable({}, SignalQueue)
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

-- @brief: removes an item from the front of the queue
-- @param: None
-- @returns: the removed value or nil if the queue is empty
function SignalQueue:dequeue()
    if self:isEmpty() then
        return nil
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
-- @returns: the first item in the queue or nil if the queue is empty
function SignalQueue:peek()
    if self:isEmpty() then
        return nil
    else
        return self.items[self.front]
    end
end

-- @brief: Checks if the queue is empty
-- @param: None
-- @returns: true if the queue is empty, false otherwise
function SignalQueue:isEmpty()
    return self.front > self.rear
end

-- @brief: Returns the number of items in the queue
-- @param: None
-- @returns: the size of the queue
function SignalQueue:size()
    return self.rear - self.front + 1
end
WoWThreads.SignalQueue.loaded = true
