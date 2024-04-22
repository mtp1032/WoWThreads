-- Stack.lua
local Filename = "Stack.lua"

local StackLib = {}

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

-- This is how you would expose StackLib to other parts of your addon.
-- In World of Warcraft addons, you usually directly assign to a globally accessible table.
-- For example:

-- USAGE
_G.StackLib = StackLib

