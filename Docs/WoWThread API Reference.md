# The WoWThreads API Reference Manual
This manual constitutes the quasi-formal reference manual for the application 
programming interface (API) for the WoWThreads library. 

#### Signature:
thread_h, result = thread:create( yieldTicks, func [,...] )

#### Description:
Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.

#### Parameters:
- yieldTicks (number). The duration of time the calling thread is to
be suspended. The time is specified in clock ticks.In WoW, a clock tick 
is the reciprocal of your system's frame rate. On my system, a clock tick 
is about 16.7 milliseconds (1/60). Therefore, 60 ticks is about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs, optional), Additional arguments to be passed to the thread function.

#### Returns:
- Success: a valid thread handle is returned and the result is set to nil.
- Failure: nil is returned and the result parameter specifies an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local function greetings( greetingString )
            print( greetingString )
        end
        local thread_h, result = thread:create( 60, greetings, "Hello World" )
        if not thread_h then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
addonName, result = thread:getAddonName( [thread_h] )

#### Description:
Obtains the name of the addon within which the specified
thread was created. If thread_h is nil, the addon name of the calling
thread is returned. Because WoWThreads is a library of services shared
among multiple addons, the thread's addon name serves to distinguish
threads by the addon within which they were created. This may prove
useful when implementing shared callbacks.

#### Parameters:
- thread_h (thread handle, optional). A handle to the thread whose addon name is to be 
obtained. If not specified, the addon name of the calling thread will be returned.

#### Returns:
- Success: Returns the name of the specified thread's addon and the result is set to nil.
- Failure: the addonName is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- This function is typically used to get the name of the addon for use when
        -- invoking a callback error handler.
        local addonName, result = thread:getAddonName( target_h )
        if addonName == nil then
            print( result[1], result[2])
        end
```

#### Signature:
thread:yield()

#### Description:
Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the calling thread's create function. Note that thread:yield()
is always fatal if the caller is NOT a thread.

#### Parameters:
- None.

#### Returns:
- None

#### Usage:
```lua
    -- A simple function that waits (yields) for a specified period of 
        -- time. When it returns it checks for a signal.
        local function waitForSignal( signal )
            local DONE = false
            while not DONE do
                thread:yield()
                local sigEntry, result = thread:getSignal()
                if not sigEntry then
                    print( result[1], result[2])
                    return
                end
                if sigEntry[1] == SIG_TERMINATE then
                    DONE = true
                end
                if sigEntry[1] == signal then
                ... do something
                end
            end
        end
        -- Create a thread to execute the waitForSignal function.
        local thread_h, result = thread:create( 60, waitForSignal, signal )
        if thread_h == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local overhead, errorMsg = thread:getMetrics( thread_h )

#### Description:
Gets some some basic execution metrics; the runtime (ms) and
congestion (how long the thread had to wait to begin execution after having
been resumed).

#### Parameters:
- thread_h (thread_handle): the thread handle whose metrics are to be returned.

#### Returns:
- Success: then the runtime and the congestion metrics are returned and he result is set to nil.
- Failure: the runtime and congestion metrics are nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local runtime, congestion, result = thread:getMetrics( thread_h )
        if runtime == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local ticksDelayed, errorMsg = thread:delay( ticks )

#### Description:
Suspends the calling thread for the specified number of ticks.

#### Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been

#### Returns:
- Success: the actual number of ticks the thread was delayed. The result is set to nil.
- Failure: the handle is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- delay a thread 1 minute
        local actualDelay, result = thread:delay( 3600 )
        if actualDelay == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
thread:sleep()

#### Description:
Suspends the calling thread for an indeterminate amount of time.
Note, unlike thread:yield(), this call doesn't  return until awakened by receipt 
of a SIG_WAKEUP signal. Note, thread:sleep() is always fatal if the caller is not
a thread.

#### Parameters:
- None

#### Returns:
- Success: the thread's handle is returned when it regains the processor (i.e., after 
it is resumed), and the result parameter is set to nil.
- Failure: the handle is false and the result parameter contains an error message. This situation arises
when the target thread is not in the thread sleep queue.

#### Usage:
```lua
    local thread_h, result = thread:sleep()
        if thread_h == false then                 -- the thread was never put to sleep. 
            print( result[1], result[2])
        end
```

#### Signature:
thread_h, result = thread:getSelf()

#### Description:
Gets the handle of the calling thread.

#### Parameters:
- None

#### Returns:
- Success: returns a thread handle and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    
```

#### Signature:
threadId, result = thread:getId( [thread_h] )

#### Description:
Obtains the unique, numerical Id of the specified thread. Note,
if the thread parameter (thread_h) is nil, then the Id of the calling thread
is returned.

#### Parameters:
- thread_h (handle, optional): returns the numeric Id (unique) of the specified
thread. If not specified, the Id of the calling thread is returned.

#### Returns:
- Success: returns the numerical Id of the thread and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local threadId, result = thread:getId()
        if threadId == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local equal, result = thread:areEqual( h1, h2 )

#### Description:
Determines whether two thread handles are identical.

#### Parameters:
- h1 (handle): a thread handle
- h2 (handle); another thread handle

#### Returns:
- Success: returns either 'true' or 'false' and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local equal, result = thread:areEqual( H1, H2 )
        if equal == nil then 
            print( result) 
            return 
        end
```

#### Signature:
parent_h, result = thread:getParent( [thread_h] )

#### Description:
Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent

#### Usage:
```lua
    local parent_h, result = thread:getParent( thread_h )
        if parent_h == nil then 
            print( result[1], result[2])
        end
```

#### Signature:
childTable, result = thread:getChildThreads( [thread_h] )

#### Description:
Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle, optional). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- Success: returns a table of thread handles and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local childThreads, result = thread:getChildThreads( thread_h )
        if not childThreads then 
            print( result[1], result[2] ) 
        end
```

#### Signature:
state, result = thread:getState( [thread_h] )

#### Description:
Gets the execution state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.
- Note: a dormant (sleeping) thread is always in the 'suspended' state.

#### Parameters:
- thread_h (handle, optional): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.

#### Returns:
- Success: returns the state of the specified thread ("suspended", "running", 
or "dead"). The returned result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local state, result = thread:getState( thread_h )
        if not state then
            print( result[1], result[2] )
        end
```

#### Signature:
value, result = thread:signalIsValid( signal )

#### Description:
Checks whether the specified signal is valid

#### Parameters:
- signalValue (number): signal to be sent.

#### Returns:
- Success: value = true is returned and the result is set to nil.
- Failure: value = false is returned and the signal is invalid.

#### Usage:
```lua
    local isValid, result = thread:signalIsValid( signal )
        if not isValid then 
            print( result[1], result[2] )
            return 
        end
```

#### Signature:
value, result = thread:sendSignal( target_h, signaValue [,...] )

#### Description:
Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.

#### Parameters:
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.

#### Returns:
1. If successful: value = true or false. A 'true' value means that...
- The signal was inserted into the target thread's signal queue, or
- The target thread was dormant and the signal was SIG_WAKEUP.
A value = false can mean one of two alternatives:
- The target thread was dead (completed or faulted).
- The target thread was dormant (sleeping) the signal was NOT SIG_WAKEUP.
2. If failed: nil is returned indicating the signal was not delivered. Usually
this means that the target's thread handle was was not found in the sleep queue. The 
result parameter contains an error message (result[1]) and a stack trace (result[2]).

#### Usage:
```lua
    local wasSent, result = thread:sendSignal( target_h, signalValue, data )
        if wasSent == nil then 
            print( result[1], result[2] )
            return 
        elseif wasSent == false then
            print( "target thread has completed or is dormant.")
        end
```

#### Signature:
local sigEntry, result = thread:getSignal()

#### Description:
The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Note, thread:getSignal()
is always fatal if the caller is not a thread.

#### Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
```
result = {
    sigEntry[1] -- (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
    sigEntry[2] -- (handle): the handle of the thread that sent the signal.
    sigEntry[3] -- (varargs): data
}
```

#### Returns:
- Success: returns a signal entry and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local sigInt, result = thread:getSignal()
        if not sigInt then 
            print( result[1, result[2] )
        end
    
        local signal = sigEntry[1]
        local sender_h = sigEntry[2]
        local data = signal[3]
        ... do something
```

#### Signature:
signalName, result = thread:getSignalName( signal )

#### Description:
Gets the string name of the specified signal value. for
example, when submitting the numerical constant, SIG_ALERT (11) the
service returns the string, "SIG_ALERT"
end
end

#### Parameters:
- signal (number): the numerical signal whose name is to be returned.

#### Returns:
- Success: returns the name associated with the signal value and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local signalName, result = thread:getSignalName( signal )
        if signalName == nil then print( errorMsg ) return end
```

#### Signature:
signalCount, result = thread:getNumPendingSignals()

#### Description:
Gets the number of pending signals for the calling thread.
Note, thread:getNumPendingSignals() is always fatal if the caller is not
a thread.

#### Parameters:
- None

#### Returns:
- Success: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The result parameter will be nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local sigCount, result = thread:getNumPendingSignals( thread_h )
        if signalCount == nil then 
            print( result[1], result[2]) return end
```