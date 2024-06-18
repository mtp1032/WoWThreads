
# The WoWThreads Library
A thread (more formerly known as a "thread of execution") is the smallest unit of processing that can be scheduled indpendently of other executable objects. Generally, threads are components of a process, meaning that they exist within processes and share the same resources, such as memory and file handles, but operate independently in terms of execution flow.

The WoWThreads library provides asynchronous, non-preemptive threads that, when incorporated into WoW addons, enable the addon to execute asynchronously and independently relative to the WoW Client process (WoW.exe). For example, when a multithreaded addon receives an event the event's data is passed to one or more threads and control is immediately passed back to the WoW client. In other words, the WoW client does not wait for the addon to complete its event handling.

The WoWThreads library is also a means by which developers can exchange information between addons using its signal facility (more on this aspect below). In this way, the WoWThreads is able to support communications and control between multiple addons.

## Threads - Introduction
A thread created by the WoWThreads library, consists of two components:

1. A thread handle (thread_h in this document)
2. A coroutine that executes the thread's function
   
The thread's handle is table of attributes that the WoWThreads' internal machinery uses to schedule and manage the execution of the the thread's coroutine. A thread's handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements is own scheduler and assumes complete control over the thread's coroutine. The process is straight-forward: when created, the thread's handle is inserted into the library's "Thread Dispatch Table" (TCB). A timer-based scheduler (based on Blizzard's C_After.time service) examines the TCB on every clock tick for threads whose yield-timer has expired (more on the yield timer below). The coroutine of any thread whose yield-timer has expired are resumed.

### Execution Context
WoWThreads defines an execution context by the nature of the calling code. In multithreaded applications, developers speak of two contexts - the client context and the thread context:

#### Client Context - blocking

 A normal, non-threaded addon is executed within WoW's game client.Technically, this means that when the game client issues a call to an addon's procedure, the procedure's code and data are pushed onto the game client's stack and executed. When the addon's procedure completes and returns, the procedure is popped off the stack and the game client continues on.

Now, at the risk of oversimplification, imagine that the addon's function consists of processing an event requiring two million instructions and a 0.01 millisecond delay waiting for an I/O request to complete. In this example, the WoW game client will block until those two million instructions and the I/O request completes.

However, suppose that the addon's function notified a waiting thread to perform the operation. In this case, the WoW client wouldn't have to wait for the two million instructions and the I/O request to complete. That task is being handled by the thread to which the task has been passed. Instead, the client would return immediately after dispatching to the event handling to a thread.

#### Thread Context - non-blocking

Technically, in a threaded addon, however, a thread executes code from its own stack, separate from the WoW client's stack. Thus, code that is executed by the function passed to a thread's coroutine is said to be within a thread context. Let's examine this process in more detail. We begin with thread creation:
```
local thread_h, result = thread:create( yieldTicks, someFunction, ... )
```
The function in the thread creation call, "someFunction," is subsequently passed to a coroutine deep within the bowels of the WoWThreads library.

```
thread_h[TH_COROUTINE] = coroutine.create( someFunction )
```
The coroutine creation process is pretty simple: when coroutine.create() is called, the system creates a new stack in which someFunction() is its first (or top) frame. The coroutine's function is now ready to be executed. To execute the someFunction procedure, however, requires the computer to switch from the WoW client's stack, to the coroutine's stack. This is accomplished by the coroutine.resume() service.
```
local co = thread_h[TH_COROUTINE]
pcallStatus, wasResumed, errorStr = pcall(coroutine.resume, co, unpack(args) )
```
The coroutine resume operation switches to the coroutine's someFunction stack and its instruction pointer is set to point to first instruction of someFunction() and it's off to the races.

So far, the nature of the two contexts are mechanistically distinct but semantically identical. In both cases, the game client blocks until the non-threaded procedure returns or, in the threaded case, until the computer's instruction pointer is switched back to the game client. This brings us to the thread:yield() service.

When thread:yield() is called the thread's coroutine is suspended. Internally, this switches the context back to the caller. If the caller was the WoW client, it immediately picks up where it left off. Here's an example of the use of thread:yield().
```
local function threadFunc()
    local DONE = false
    local signal = SIG_NON_PENDING

    while not DONE do
        local sigEntry = thread:getSignal()
        if sigEntry[1] == SIG_ALERT then
            -- do something important
        elseif sigEntry[1] == SIG_TERMINATE then
            DONE = true
            break
        end
    end
end
```
Now, suppose this is a function of a thread created with a yieldTick count of 60. In this function, the threadFunc executes a while loop checking for a signal after every yield interval (i.e., 60 ticks or about 1 second). It does this continously until it receives a SIG_ALERT signal. When it does, it takes the appropriate action. If it receives a SIG_TERMINATE signal, the thread breaks from the while loop and exits.

Note: the thread loops forever until a SIG_TERMINATE is received. This is a good example of how a thread that needs to respond to events that occur regularly might organize its loop.

In other words, this thread spends almost 100% of its time waiting for signals. Moreover, everytime it calls thread:yield() another thread or the WoW client resumes its execution.

### Thread Timing Control

In WoWThreads, time is measured in clock ticks. On my system, the clock ticks every 16.667 milliseconds (the reciprocal of my system's framerate). Under heavy loads the tick interval may be longer. I've seen tick intervals as large 23 milliseconds. 

Note: Conversion to seconds is easy. Sixty (60) ticks is about one second. If a thread is created with a yieldTime of 60 ticks, then every time the thread calls thread:yield(), it will be suspended for about one second. This is a very, very long time in computer time.

With this in mind, let's revisit the thread creation step above:
```
local thread_h, result = thread:create( yieldTicks, someFunction, ... )
```
The yieldTicks parameter is the time (in clock ticks) during which the thread is to be suspended after calling thread:yield(). To manage thread suspension and execution, WoWThreads uses two counters: the yieldTicks parameter stored in thread_h[TH_YIELD_TICKS] and the ticks remaining parameter stored in thread_h[TH_REMAINING_TICKS] to determine when to resume the thread..

Initially, the yield count and the remaining count are set equal and submitted to the TCB. The scheduler then decrements the remaining counter by 1 on every tick. When the remaining counter reaches zero (0), the remaining counter is replenished by setting it to the yield count and the coroutine is resumed. 
```
thread_h[TH_REMAINING_TICKS] = thread_h[TH_REMAINING_TICKS] - 1
if thread_h[TH_REMAINING_TICKS] == 0 then
    thread_h[TH_REMAINING_TICKS] = thread_h[TH_YIELD_TICKS]
    local co = thread_h[TH_COROUTINE]
    status, resumed, result = pcall(coroutine.resume, co, unpack(args) )
end
```
There is no guarantee that a thread will resume execution after its yieldTicks expire. This is because when the thread's time eventually expires, the WoWThreads' scheduler submits the coroutine to the operating system for resumption.

## Signals
In WoWThreads, threads communicate via signals. When a thread sends a signal to a target thread, that signal is inserted into the target thread’s signal queue. The signal queue exhibits FIFO semantics. In other words, the thread that has been in the queue the longest is retreive.

WoWThreads supports a number of signal services, the two most important of which are thread:sendSignal() and thread:getSignal(). Of these two, thread:sendSignal() can be sent by the client (WoW.exe). However, the getSignal() service requires a thread context.

In Unix and other operating systems the signal object is a positive, integer numeral. In WoWThreads, a signal is actually a three-element table.
```
local signal = {
        sigNumber,  -- an integer constant
        sender_h,   -- the thread handle of the sending thread
        ...         -- varargs for data passing
}
```
The elements of the signal table are discussed next.

#### SigNumber
There are currently 14 different signals, but note: Even though their names are suggestive, they are just that. In other words, WoWThreads does not enforce or otherwise dictate semantics.

The behavior of some of signal numbers are controlled by the system. For example, when a thread receives a SIG_ALERT, it is immediately moved to the run queue. SIG_THREAD_DEAD is returned to the sending thread if the receiving thread has completed or terminated because of an error. While SIG_WAKEUP can be sent to any thread, it can only be acted on by a sleeping thread, i.e., previously put itself to sleep by calling thread:sleep().

thread.SIG_ALERT        = 1
thread.SIG_GET_DATA     = 2 
thread.SIG_SEND_DATA    = 3
thread.SIG_BEGIN        = 4 
thread.SIG_HALT         = 5
thread.SIG_TERMINATE    = 6
thread.SIG_IS_COMPLETE  = 7 
thread.SIG_SUCCESS      = 8 
thread.SIG_FAILURE      = 9 
thread.SIG_READY        = 10
thread.SIG_WAKEUP       = 11 
thread.SIG_CALLBACK     = 12 
thread.SIG_THREAD_DEAD  = 13 
thread.SIG_NONE_PENDING = 14 

#### Sender Thread (sender_h)
The second element of the signal table is the handle of the thread that sent the signal. Note, however, that thread:sendSignal() can be sent by the WoW client. So, for example, when an event is delivered to an addon, the OnEvent service can send an appropriate signal to the thread handling that event.
#### Varargs (...)
This element is used to send data to other threads. The element is untyped so there are no limitations on the type of data that can be sent. This element was added with thread pools in mind in which worker threads are sent tasks to be executed.

Note: In my addons, when the OnEvent service delivers a thread to the addon, the addon alerts a handler thread (cleu_h) and, along with the alert, sends
 the event event info (= subEvent). Here is a snippet from my combat logger.
```
if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local subEvent = {CombatLogGetCurrentEventInfo()}	
    local status, errorMsg = thread:sendSignal( cleu_h, SIG_ALERT, subEvent )
    if not status then thread:invokeHandler( ADDON_NAME, errorMsg ) end
    return
end
```
In the example above, cleu_h is the thread responsible for the initial processing of the event info.

## Function Return Values:
All WoWThread public functions return two parameters the second of which is the result parameter. If the first parameter is nil, then the function has failed. In this case, the information about the cause of its failure is contained  in the second return parameter, conventionally called the "result.""

#### Usage
The result return parameter is a two member table:
```
    result = 
        { errorMsg, -- (string) describes the cause of the failure
          stackTrace -- (string) a stack trace indicating where the error occurred.
        }

    -- example
    local thread_h, result = thread:create( ticks, func )
    if not thread_h then
        print( result[1], result[2] )
    end
```

# WoWThreads API Services

In this section, a formal description of each of the library's public services are described.

#### Signature:
thread_h, result = thread:create( addonName, yieldTicks, addonName, func,... )

#### Description:
Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.

#### Parameters:
- addonName (string). The name of the addon that created the thread.
- yieldTicks (number). The time, in clock ticks, the thread is to 
suspend itself when it calls thread:yield(). A clock tick is the 
reciprocal of your computer's framerate multiplied by 1000. On my 
system a clock tick is about 16.7 milliseconds where 60 ticks is 
about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs), Additional arguments to be passed to the thread function.

#### Returns:
- If successful: a valid thread handle is returned and the result is nil.
- If failure: nil is returned and the result parameter specifies an error message (result[1])
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
addonName, result = thread:getAddonName( thread_h )

#### Description:
Obtains the name of the addon within which the specified
thread was created.

#### Parameters:
- thread_h (thread handle). A handle to the thread whose addon name is to be 
obtained.

#### Returns:
- If successful: Returns the name of the specified thread's addon and the result is nil.
- If failure: the addonName is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- This function is typically used to get the name of the addon for use when
        -- invoking the error handler.
        local wasSent, result = thread:sendSignal( target_h, SIG_ALERT )
        if not wasSent then
            print( result[1], result[2])
        end
```

#### Signature:
local ticks, errorMsg = thread:yield()

#### Description:
Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the thread's create function used to create the thread. 
Thread context required,

#### Parameters:
- None.

#### Returns:
- ticks (number): the actual number of ticks the thread was suspended
- If failure: the ticks value is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- A simple function that waits (yields) until a signal arrives.
        local function waitForSignal( signal )
            local DONE = false
            while not DONE do
                thread:yield()
                local sigEntry, result = thread:getSignal()
                if not sigEntry then
                    print( result[1], result[2])
                    return
                end
                ... do something
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
local ticksDelayed, errorMsg = thread:delay( ticks )

#### Description:
Suspends the calling thread for the specified number of ticks.

#### Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been

#### Returns:
- If successful: the handle of the calling thread is returned and the result is nil.
- If failure: the handle is nil, and the result parameter contains an error message (result[1])
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
of a SIG_WAKEUP signal.

#### Parameters:
- None

#### Returns:
- If successful: the handle of the calling thread is returned and the result is nil.
- If failure: the handle is nil, and the result parameter contains an error
message (result[1]) and a stack trace (result[2])

#### Usage:
```lua
    thread:sleep()
```

#### Signature:
thread_h, result = thread:getSelf()

#### Description:
Gets the handle of the calling thread.

#### Parameters:
- None

#### Returns:
- If successful: returns a thread handle and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    
```

#### Signature:
threadId, result = thread:getId( thread_h )

#### Description:
Obtains the unique, numerical Id of the specified thread.

#### Parameters:
- thread_h (handle):

#### Returns:
- If successful: returns the numerical Id of the thread and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
- h2 (handle); a thread handle

#### Returns:
- If successful: returns 'true' and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
parent_h, result = thread:getParent( thread_h )

#### Description:
Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent.
Parameters
- thread_h (handle): if nil, then the calling thread's parent is returned.
Returns
- If successful: returns the handle of the parent thread and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local parent_h, result = thread:getParent( thread_h )
        if parent_h == nil then 
            print( result[1], result[2])
        end
```

#### Signature:
childTable, result = thread:getChildThreads( thread_h )

#### Description:
Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- If successful: returns a table of thread handles and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local childThreads, result = thread:getChildThreads( thread_h )
        if not childThreads then 
            print( result[1], result[2] ) 
        end
```

#### Signature:
state, result = thread:getState( thread_h )

#### Description:
Gets the state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.

#### Parameters:
- thread_h (handle): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.

#### Returns:
- If successful: returns the state of the specified thread ("suspended", "running", 
or "dead") of the specified thread. The result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local state, result = thread:getState( thread_h )
        if not state then
            print( result[1], result[2] )
        end
```

#### Signature:
value, result = thread:sendSignal( target_h, signaValue,[,data] )

#### Description:
Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.

#### Parameters:
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): signal to be sent.
- data (any) Data (including functions) to be passed to the receiving thread.

#### Returns:
- If successful: value = true is returned and the result is nil.
- If failure: value = false is returned and the signal could NOT delivered. Usually
this means that the target thread was 'dead,' non-existent, or the WoW client (WoW.exe).
The result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local wasSent, result = thread:sendSignal( target_h, signalValue, data )
        if not wasSent then 
            print( result[1], result[2] )
            return 
        end
```

#### Signature:
local sigEntry, result = thread:getSignal()

#### Description:
The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Thread
context is required.

#### Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
sigEntry[1] (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
sigEntry[2] (handle): the handle of the thread that sent the signal.
sigEntry[3] (varargs): data

#### Returns:
- If successful: returns a signal entry and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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
Gets the string name of the specified signal value.

#### Parameters:
- signal (number): the numerical signal whose name is to be returned.

#### Returns:
- If successful: returns the name associated with the signal value and the result is nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
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

#### Parameters:
- None

#### Returns:
- If successful: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The result parameter will be nil.
- If failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local sigCount, result = thread:getNumPendingSignals( thread_h )
        if signalCount == nil then 
            print( result[1], result[2]) return end
```