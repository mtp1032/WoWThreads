--- @brief Creates a thread handle. Thread context not required.
-- @param yieldTicks (number) the number of clock ticks for which the thread.
-- @param threadFunction (function) the function to be executed by the thread.
-- @param varargs (any) any arguments to be passed to the thread's function.
-- @return The thread handle (table) or nil if the handle could not be created.
function thread:create( yieldTicks, threadFunction, ...)
    -- do stuff
end