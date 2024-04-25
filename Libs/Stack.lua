-- Stack.lua
local Filename = "Stack.lua"

local sprintf = _G.string.format
local StackLib = {}

_G.StackLib = StackLib  -- Add into the Global table

-- Implements a LIFO table. Inserts and removes from the end of the table.
function StackLib.Create()
    local stack = {items = {}, size = 0}

    function stack:push(value)
        self.size = self.size + 1
        self.items[self.size] = value
    end
    function stack:pop()
        if self:isEmpty() then
            error("Stack is empty")
        else
            local value = self.items[self.size]
            self.items[self.size] = nil  -- Optional: clear the reference
            self.size = self.size - 1
            return value
        end
    end
    function stack:isEmpty()
        return self.size == 0
    end
    return stack
end

if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage(fileName, 0.0, 1.0, 1.0)
end
