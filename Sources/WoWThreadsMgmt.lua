
--------------------------------------------------------------------------------------------
-- Filename: threadMgmt.lua
-- Date: 21 May, 2025
-- AUTHOR: Michael Peterson (scaffolded by ChatGPT)
--------------------------------------------------------------------------------------------

WoWThreads = WoWThreads or {}
WoWThreads.Mgmt = WoWThreads.Mgmt or {}

if not WoWThreads.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("WoWThreads.lua not loaded", 1, 0, 0)
    return
end

local mgmt      = WoWThreads.Mgmt
local utils     = WoWThreads.UtilsLib
local thread	= WoWThreads.ThreadLib

-- Registry of all managed threads
mgmt.threadRegistry = {}

-- Register a thread by name
function mgmt:register(name, handle)
    self.threadRegistry[name] = handle
    if utils:isDebuggingIsEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Thread '%s' registered.", name), 0.0, 1.0, 1.0)
    end
end

-- Get a registered thread by name
function mgmt:get(name)
    return self.threadRegistry[name]
end

-- Send a signal to a named thread
function mgmt:send(name, signal, ...) 
    local h = self:get(name)
    if h then
        return thread:sendSignal(h, signal, ...)
    else
        return nil, "Thread not found: " .. tostring(name)
    end
end

-- Shutdown all threads by sending SIG_TERMINATE
function mgmt:shutdownAll()
    for name, h in pairs(self.threadRegistry) do
        local wasSent, result = thread:sendSignal(h, thread.SIG_TERMINATE)
        if not wasSent then
            utils:postResult( result )
        end
    end
end

-- Handle a signal entry
function mgmt:handleSignal(sigEntry)
    local signal = sigEntry[1]
    if signal == thread.SIG_TERMINATE then
        self:shutdownAll()
    elseif signal == thread.SIG_ALERT then
        -- Optional: define alert behavior
    else
        -- Optional: handle other signal types
    end
end

-- List all active threads
function mgmt:list()
    for name, h in pairs(self.threadRegistry) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Thread '%s' is registered.", name), 0.0, 1.0, 0.0)
    end
end

WoWThreads.Mgmt.loaded = true