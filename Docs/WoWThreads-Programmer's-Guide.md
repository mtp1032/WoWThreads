# The WoWThreads Library


> If your only tool is a hammer, all problems look like nails
-- Abraham Maslow

>I’ve never met a young engineer who didn’t think threads were great. I’ve never met an older engineer who didn’t shun them like the plague.
-- Anonymous_
## Caveat
I am a developer of the second kind. I’m old, I’m a [former] software engineer/architect and I have a love-hate relationship with threading. I’ve written thousands of lines of multithreaded user-mode applications and protected-mode operating system internals. For Linux, I wrote the first POSIX thread package, *PCThreads*. Over the years, I’ve learned that while experience with multithreading can be impressive on a resume, using multiple threads seldom live up to their hype. And so it is with threads when applied to WoW Addon programming. They can be quite useful, but lead to madness if not applied appropriately.

WoWThreads was motivated by some WoW addon work I did for personal use. Over the course of playing World of Warcraft, I noted that many of the WoW addons I used were quite impressive. The code was clean and functional. None seemed overly complex, especially for complexity’s sake, as is so often the case with code written by less experienced engineers. Writing addons looked to be fun (and useful), so I jumped in. Initially, I wrote a couple of simple addons, one to display information when my character experienced a skillup and [yet another] bank management addon . But, as I gained more familiarity with Blizzard’s addon programming and especially its event-driven execution model, I couldn’t help but wonder if threading, rightly applied, might be useful. So, I wrote a simple combat logger and immediately ran into difficulty.

Since WoW, like many games of its type, is an event-driven application, I thought I’d write a small prototype threads facility that would enable me to dedicate threads to the tasks of receiving, processing, and displaying individual combat events. More specifically, I needed a more flexible way to control the spacing between lines of text as they scrolled across the screen. Using threads to handle events would allow the WoW client to return and wait for the next event. As it happened, the prototype thread package worked. My application didn’t run faster, but that wasn’t the goal. Instead, I needed to slow down the rate at which text frames scrolled up the screen. Talon, my code name for [what became] the WoWThreads facility, offered a set of primitives that allowed me to easily assign tasks to specific threads and coordinate their execution using a signals-based communication scheme.

So, is multithreading the way to go when developing WoW addons? *Probably not!*, Based on my experience, I’m not convinced threading brings much to a WoW addon developer’s toolkit. Threading is sexy, and it’s way cool to see one’s threaded code in action. But does threading make for better addons? In my opinion, most improvements will be marginal, but in some cases, they may be significant, to be sure. But for general purposes, no.

## Preface

A thread (more formally known as a "thread of execution") is the smallest unit of processing that can be scheduled independently of other executable objects. Generally, threads are components of a process, meaning that they exist within process's address space and share the same resources, such as memory and file handles However, in terms of execution, the are scheduled independently.

The WoWThreads library provides asynchronous, non-preemptive threads that, when incorporated into WoW addons, enable the addon to execute asynchronously and independently relative to the WoW Client process (WoW.exe) and other parts of the addon. For example, when a multithreaded addon receives an event, the event's data can be passed to one or more threads, and control is immediately returns to the WoW client. In other words, the WoW client does not wait for the addon to complete its event handling.

The WoWThreads library also enables developers to exchange information between addons by using its signal facility (more on this aspect below). In this way, WoWThreads supports communication and control between multiple addons. While this capability exists, specific services to support communication semantics between addons have yet to be implemented.

## Threads - Introduction and Background
The concepts described in this section are geared toward experienced developers who may not have had experience with thread programming before. If this is not you, please skip to the section, WoWThreads API.

With that out of the way, here we go. A thread created by the WoWThreads library consists of two components:

1. A thread handle (by convention, 'thread_h' in this document).
2. A coroutine that executes the thread's function.
   
The thread's handle is a table of attributes that WoWThreads' internal logic uses to schedule and manage the execution of the thread's coroutine. Each thread handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements its own scheduler and assumes complete control over a thread's coroutine. The process is straightforward: when created, the thread's handle (containing a reference to its coroutine) is inserted into the library's "Thread Control Block" (TCB). A timer-based scheduler (based on Blizzard's C_After service) examines the TCB on every clock tick for threads whose yield-timer has expired (more on the yield timer below). The coroutine of any threads whose yield-timer has expired are resumed.

### Execution Context
For WoWThreads, an execution context is defined by the nature of the calling code. If a service is called or invoked by a thread, that service is said to execute in a thread context. If a service, even a thread service, is called from a non-thread process, typically the WoW client, the service executes in a client context.

#### Client Context - blocking

A normal, non-threaded addon is executed by WoW's game client. Technically, this means that when the game client issues a call to an addon's procedure, the operating system pushes the WoW Client's context (code, data, symbols, etc.) onto the stack. Once done, the operating system switches to the addon procedure's first instruction, and the addon begins executing. When the addon's procedure completes, it executes a return, which in turn causes the operating system to pop the client's stack frame, switching back to the client.

> Note, however, that once the game's context is pushed onto the stack, the game client must wait for the addon's procedure to complete. In other words, while the addon is executing, the WoW client is blocked and will remain blocked until the addon completes are returns to the WoW client.

#### Thread Context - non-blocking

Technically, in a threaded addon, a thread executes code from its own stack, separate from the WoW client's stack. Thus, code that is executed by the function passed to a thread's coroutine is said to be within a thread context. Let's examine this process in more detail. We begin with thread creation:
```
local thread_h, result = thread:create( yieldTicks, someFunction, ... )
```
The function in the thread creation call, "someFunction," is subsequently passed to a coroutine deep within the bowels of the WoWThreads library. More specifically,
```
thread_h[TH_COROUTINE] = coroutine.create( someFunction )
```
The coroutine creation process is simple: when `coroutine.create()` is called, the system creates a new stack in which `someFunction()` is its first (or top) frame. The coroutine's function is now ready to be executed. To execute the `someFunction()` procedure, however, requires the computer to switch from the WoW client's stack to the coroutine's stack. This is accomplished by the `coroutine.resume()` service.
```
local co = thread_h[TH_COROUTINE]
pcallStatus, wasResumed, errorStr = pcall(coroutine.resume, co, unpack(args) )
```
The coroutine resume operation switches to the coroutine's someFunction stack, and its instruction pointer is set to point to the first instruction of `someFunction()`.

So far, the nature of the two contexts are mechanistically distinct but semantically identical. In both cases, the game client blocks until the non-threaded procedure returns or, in the threaded case, until the computer's instruction pointer is switched back to the game client. 

This brings us to the `thread:yield()` service.

When `thread:yield()` is called, the thread's coroutine is suspended. Internally, this switches the context back to the caller (or, a waiting thread). If the caller was the WoW client, the WoW Client immediately picks up where it left off. Here's an example of the use of `thread:yield()`.
```
local function threadFunc()
    local DONE = false

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
Now, suppose this is a function of a thread created with a yieldTick count of 60. In this case, `threadFunc()` executes a while loop checking for a signal after its tick interval exprires, i.e., 60 ticks or about 1 second. It does this continuously until it receives a SIG_ALERT or SIG_TERMINATE signal. When it does, it takes the appropriate action. If it receives a SIG_TERMINATE signal, the thread breaks from the while loop and exits.

In general, this is the general pattern of how a thread is programmed to respond to events passed to it from the game client.

In other words, this thread spends almost 100% of its time waiting for signals. Moreover, every time it calls `thread:yield()`, another thread or the WoW client resumes its execution. This, of course, is the heart of asynchronous processing.

>Note: this pattern not simultaneous or concurrent execution. Technically, this model is called multitasking, in which tasks execute asynchronously from each other.

### Thread Timing Control

In WoWThreads, time is measured in clock ticks. On my system, the clock ticks every 16.667 milliseconds (the reciprocal of my system's framerate). Under heavy loads, the tick interval may be longer. I've seen tick intervals as large as 23 milliseconds.

>Note: Conversion to seconds is easy. Sixty (60) ticks is about one second. If a thread is created with a yieldTime of 60 ticks, then every time the thread calls thread:yield(), it will be suspended for about one second. One second is a very, very long time in computer time.

With this in mind, let's revisit the thread creation step above:
```
local thread_h, result = thread:create( yieldTicks, someFunction, ... )
```
The yieldTicks parameter is the time (in clock ticks) during which the thread is to be suspended after calling `thread:yield()`. To manage thread suspension and execution, WoWThreads uses two counters: the yieldTicks parameter stored in thread_h[TH_YIELD_TICKS] and the ticks remaining parameter stored in thread_h[TH_REMAINING_TICKS] to determine when to resume the thread.

Initially, the yield count and the remaining count are set equal when submitted to the TCB. The scheduler then decrements the remaining counter by 1 on every tick. When the remaining counter reaches zero (0), its count is replenished by setting it to the yield count, and the coroutine is resumed, as for example, shown in the snippet below. 
```
thread_h[TH_REMAINING_TICKS] = thread_h[TH_REMAINING_TICKS] - 1
if thread_h[TH_REMAINING_TICKS] == 0 then
    thread_h[TH_REMAINING_TICKS] = thread_h[TH_YIELD_TICKS]
    local co = thread_h[TH_COROUTINE]
    status, resumed, result = pcall(coroutine.resume, co, unpack(args) )
end
```
There is no guarantee that a thread will resume execution immediately after its yieldTicks expire. This is because when the thread's time eventually expires, the WoWThreads scheduler submits the coroutine to the operating system for resumption.

## Signals
In WoWThreads, threads communicate via signals. When a thread sends a signal to a target thread, that signal is inserted into the target thread’s signal queue. The signal queue exhibits FIFO semantics. In other words, the thread that has been in the queue the longest is the first to be retrieved.

WoWThreads supports a number of signal services, the two most important of which are `thread:sendSignal()` and `thread:getSignal()`. Of these two, `thread:sendSignal()` can be sent from the client (WoW.exe) or another thread. However, the `thread:getSignal()` service requires thread context. Put more simply, only a thread can receive a signal, but both threads and non-threads can send signals.

In Unix and other operating systems, the signal object is a positive integer numeral. In WoWThreads, a signal is actually a three-element table.
```
local sigEntry = {
        sigNumber,  -- an integer constant (e.g., SIG_ALERT).
        sender_h,   -- the thread handle of the sending thread.
        ...         -- varargs for passing data.
}
```
The elements of the signal table are discussed next.

#### SigNumber
There are currently 14 different signals, but note: Even though their names are suggestive, they are just that. In other words, WoWThreads does not enforce or otherwise dictate semantics, with two exceptions: first, when a thread receives a SIG_ALERT, it is immediately resumed. Second, SIG_WAKEUP causes a sleeping thread to be immediately resumed. Note: SIG_WAKEUP only works for sleeping thread, i.e., a thread that previously called `thread:sleep()`.

Here are all 14 signals.

local SIG_GET_DATA      = 1
local SIG_SEND_DATA     = 2
local SIG_BEGIN         = 3
local SIG_HALT          = 4 
local SIG_IS_COMPLETE   = 5
local SIG_SUCCESS       = 6
local SIG_FAILURE       = 7
local SIG_READY         = 8
local SIG_CALLBACK      = 9
local SIG_THREAD_DEAD   = 10
local SIG_ALERT         = 11
local SIG_WAKEUP        = 12
local SIG_TERMINATE     = 13
local SIG_NONE_PENDING  = 14

#### Sender Thread (sender_h)
The second element of the signal table is the handle of the thread that sent the signal. Note that signals can be sent by the WoW client. So, for example, when an event is delivered to an addon, the OnEvent service can send an appropriate signal to the thread handling that event. In this case, the sender_h element of the signal table is nil because the WoW client is not a thread!
#### Varargs (...)
This element is used to send data to other threads. The element is untyped, so there are no limitations on the type of data that can be sent. This element was added with thread pools in mind in which pools of worker threads are sent tasks to be executed.

Note: In my combat logger addon, when the OnEvent services signals (SIG_ALERT) a handler thread and, along with the alert, sends the event's payload (= subEvent). Here is a snippet from the addon.
```
if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local eventData = {CombatLogGetCurrentEventInfo()}	
    local wasSent, result = thread:sendSignal( thread_h, SIG_ALERT, eventData )
    if wasSent == nil then 
        print( result[1], result[2])
    return
end
```
In the example above, thread_h is the thread responsible for the initial processing of the event info.

## Function Return Values:
All public WoWThreads functions return two parameters, the second of which is the result parameter. If the first parameter is nil, then the function has failed. In this case, the information about the cause of its failure is contained in the second return parameter, conventionally called the "result."

#### Usage
The result return parameter is a three member table:
```
    result = 
        { errorMsg, -- (string): describes the cause of the failure.
          functionName -- (string): the name of the function in which the error occurred.
          stackTrace -- (string): a stack trace indicating where the error occurred.
        }

    -- example
    local thread_h, result = thread:create( ticks, func )
    if not thread_h then
        print( result[1], result[2], result[3] )
    end
```
