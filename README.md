### README.md (version 1.6.8)

**Latest Release**: [Download the latest release](https://github.com/mtp1032/WoWThreads/releases/latest)  
**View this README on GitHub**: [README.md](https://github.com/mtp1032/WoWThreads/blob/main/README.md)

##### DESCRIPTION
WoWThreads is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. WoWThreads provides the major features you would expect in a threads package such as thread creation, signaling (including inter-thread communications), delay, yield, sleep, and so forth.

The library is designed to enable an addon to execute threads asynchronously relative to the WoW game client's (WoW.exe) event provider. More specifically, developers can use WoWThreads to handle events delivered by the OnEvent service. For example, consider an addon that logs and displays combat log information (e.g., from the Combat Log Event [Unfiltered]). When the event fires, the WoW client sends a signal to one of the addon's threads waiting to handle the event and its payload. Once the handler thread is signaled, the WoW Client returns to the game loop to wait for more events to fire. In other words, the WoW client hands control to as addon's thread and returns to the game. In the absence of WoWThreads, the WoW Client must wait for the addon to complete its handling before returning to the main game loop.

##### INSTALLATION

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
### NOTE
For efficiency you might consider only importing the signals to be used in the file  you're editing. For example, in one of my files I use for testing I only import SIG_GET_PAYLOAD, SIG_SEND_PAYLOAD, SIG_ALERT, SIG_TERMINATE, and SIG_NONE_PENDING.

##### USAGE
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

