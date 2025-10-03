### README.md (WoWThreads version 2.0.0)

**Latest Release**: [Download the latest release](https://github.com/mtp1032/WoWThreads/releases/latest)  
**View this README on GitHub**: [README.md](https://github.com/mtp1032/WoWThreads/blob/main/README.md)

#### RELEASE NOTES

SIG_WAKEUP is now inoperative. In WoWThreads a sleeping thread is awakened with the function thread:wakeup( thread_h ), where thread_h is the handle to the sleeping thread.

thread:sleep( thread_h ) expresses the following semantics:
- Causes the calling thread to suspend for an indefinite time and may only be awakened by a call to the new function, thread:wakeup( thread_h ). 
- When a sleeping thread is awakened (by thread:wakeup( thread_h )), the thread is queued for immediate execution.
- A sleeping thread cannot respond to a signal unless first awakened. NOTE: a sleeping thread can receive signals but cannot respond until they are awakened.

#### DESCRIPTION
WoWThreads is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. WoWThreads provides the major features you would expect in a threads package such as thread creation, signaling (including inter-thread communications), delay, yield, sleep, and so forth.

The library is designed to enable an addon to execute threads asynchronously relative to the WoW game client's (WoW.exe) event provider. More specifically, developers can use WoWThreads to handle events delivered by the OnEvent service. For example, consider an addon that logs and displays combat log information (e.g., from the Combat Log Event [Unfiltered]). When the event fires, the WoW client sends a signal to one of the addon's threads waiting to handle the event and its payload. Once the handler thread is signaled, the WoW Client returns to the game loop to wait for more events to fire. In other words, the WoW client hands control to as addon's thread and returns to the game. In the absence of WoWThreads, the WoW Client must wait for the addon to complete its handling before returning to the main game loop.

#### PERFORMANCE
The test reported here attempts to look at the overhead from both system and library (WoWThreads library) software. The test compared the thread execution times generated from debugprofilestop() compared to execution times calculated from the number of clock ticks (1/Framerate()). 

I note that the Elapsed Time metric is always greater than the time calculated from the Elapsed Ticks metric. I assume this is because the time from debugprofilestop() included system and addon overhead and the time calculated by multiplying the number of ticks (16.667 ms per tick) did not.

NOTES:
- Platform: WoWThreads beta (v1.6.8) - The current release candidate.
- Elapsed Time was given by debugprofilestop()
- Elapsed Ticks was given by number of ticks * 16.667 ms/tick (i.e., 1/Framerate()
- For these measurements, the Options Menu Data Collection overhead checkbox was checked.

[PASS] TEST: Thread Metrics - single thread
Id: 6, Elapsed Time: 6046 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10

[PASS] TEST: Thread Metrics - 2 threads
Id: 7, Elapsed Time: 5895 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 6, Elapsed Time: 5896 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10

[PASS] TEST: Thread Metrics - 3 threads
Id: 8, Elapsed Time: 5976 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 7, Elapsed Time: 5976 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 6, Elapsed Time: 5976 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10

[PASS] TEST: Thread Metrics - 10 threads
Id: 15, Elapsed Time: 5873 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 14, Elapsed Time: 5874 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 13, Elapsed Time: 5874 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 12, Elapsed Time: 5874 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 11, Elapsed Time: 5875 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 10, Elapsed Time: 5875 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 9, Elapsed Time: 5875 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 8, Elapsed Time: 5875 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 7, Elapsed Time: 5876 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10
Id: 6, Elapsed Time: 5876 (ms), Elapsed Ticks: 301 (5017 ms), Ticks per yield: 30, Resumptions: 10

##### Elapsed Time vs. Elapsed Ticks

Elapsed Time (from debugprofilestop()) is always larger than Elapsed Ticks (frame-based). That difference is exactly what we would expect since debugprofilestop() measures wall-clock execution time inside WoW, including system overhead, addon code, Lua scheduling, and any frame update delays. On the other hand, Elapsed Ticks is a synthetic estimate: ticks × 16.667 ms (assuming 60 fps) only accounts for “idealized frame time,” not the real scheduling/overhead cost.

So the discrepancy tells us how much time WoW and WoWThreads overhead contributes beyond the theoretical tick budget.

##### Consistency Across Thread Counts

With 1, 2, 3, and even 10 threads, the measured Elapsed Time is remarkably stable (~5.87–6.04 seconds). Elapsed Ticks stays flat (301 ticks × 16.667 ms ≈ 5017 ms) regardless of thread count. This shows that the WoWThreads library scales linearly under increasing load and does not add overhead as more threads are created. The extra ~800–1000 ms gap (Elapsed Time – Elapsed Ticks) is the fixed cost of WoW’s event loop, coroutine scheduling, and the library's data collection wrappers.

##### Ticks per Yield & Resumptions

Each thread yielded every ~30 ticks and resumed ~10 times. These numbers match across all thread counts, confirming the  scheduling logic is deterministic and that WoWThreads doesn’t “starve” or “favor” threads when concurrency increases.

##### Interpretation

The ~15–20% overhead (6000 ms vs. 5017 ms) is effectively the price of running inside WoW’s frame/update system. It is noteworthy that the overhead doesn’t balloon when the number of threads increases (from 1 → 10 threads in this case. This strongly indicates that the library overhead is constant and does not increase with addional threads.

NOTE: a relationship exists between the execution time of the thread's function and the length of the yield. When the yield interval is larger than the excution time, efficiency declines. When the yield interval is less that the execution time, thread congestion occurs, i.e., threads are queued for execution but cannot run because competition for the CPU is increased.

Conclusion:
Comparing elapsed times from debugprofilestop() and thread tick counts exposes the real cost of thread execution (system + addon), while the tick-based estimate reflects only the idealized workload. The consistent gap and stability across thread counts shows that WoWThreads' measured overhead is essentially WoW’s frame/update scheduling tax.

#### INSTALLATION

- Download and install WoWThreads-v1.6.8-master.zip
- Unzip WoWThreads-v1.6.8-master.zip (produces WoWThreads-master)
- Rename WoWThreads-master to WoWThreads.
- To add WoWthreads to your addon, add WoWThreads as a dependence.
```
  ##Dependencies: WoWThreads
```

- Access to the WoWThreads library is through LibStub. So, at the top of each of your Addon's .lua file that need to access WoWThreads' services, insert the following:

```
-- Access WoWThreads using LibStub
local thread = LibStub("WoWThreads")
if not thread then
    print("Error: WoWThreads library not found!")
    return 
end

local SIG_GET_PAYLOAD  = thread.SIG_GET_PAYLOAD
local SIG_SEND_PAYLOAD = thread.SIG_SEND_PAYLOAD
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE
local SIG_SUCCESS      = thread.SIG_SUCCESS.
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY     = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING
```
#### NOTE
For efficiency you might consider only importing the signals to be used in the file  you're editing. For example, in one of my files I use for testing I only import SIG_GET_PAYLOAD, SIG_SEND_PAYLOAD, SIG_ALERT, SIG_TERMINATE, and SIG_NONE_PENDING.

#### USAGE
The WoWThreads package has passed its regression tests on all playable expansions (TWW, MOP Classic, Vanilla Classic, aniversary realms) and on TWW v11.2.5, PTR (Mop Classic) v 5.5 1, and Mists of Pandaria Classic v5.5.0. WoWThreads has not been tested on other test releases due to the absence of realms.

When you begin incorporating WoWThreads into your addon, I recommend (emphatically) that you enable error logging. To do this, click on the addon's threads minimap icon to bring up the options menu which offers two options:

- Check to enable debug logs.
- Check to collect system overhead data.

##### KNOWN BUGS
While the WoWThreads minimap icon is fully functional, the thread image does not show.

##### TODO
- Continue to update the documentation - both the README.md (this doc) and the Programmer's guide (WoWThreads-Complete.md 
in the Docs directory).
- The SIG_WAKEUP signal has been deprecated and in the next minor release will not be supported.

##### LOCALIZATION
User-visible code has been localized in German, French, Russian, Norwegian, Japanese, Mandarin Chinese, Spanish, and Klingon


##### SUPPORT
For more information and examples, two documents can be found in the your local WoWThreads' Docs directory or in the addon's github docs directory:

- A Programming Guide: This document details some of the more important concept to keep in mind when designing code that uses threads. You can click the URL below.

https://github.com/mtp1032/WoWThreads/blob/main/Docs/WoWThreads-Programming-Guide.md. 

- An API Reference Manual: This document is a quasi-formal description of the public services
supported by WoWThreads. Click the URL below to access the manual.

https://github.com/mtp1032/WoWThreads/blob/main/Docs/WoWThreads-API-Reference-Manual.md.

