###  README.md
##### WoWThreads Asynchronous, Non-preemptive Multithreading

### CHANGELOG
##### V1.0.0
- Initial release
 
##### DESCRIPTION:
WoWThreads is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. WoWThreads provides the major features you would expect in a threads package such as thread creation, signaling (including inter-thread communications), delay, yield, sleep, and so forth.

The library is designed to enable an addon to execute asynchronously relative to the WoW game client's (WoW.exe) event provider. More specifically, developers can use WoWThreads to handle events delivered by the OnEvent service. In this way, once the WoW client delivers an event to an addon's thread, the WoW client can immediately return. In the absence of WoWThreads, the WoW Client must wait for the addon to complete its handling before returning to the main game loop.

##### USAGE
Click on the addon's threads minimap icon to bring up the options menu which offers two options:

- Check to enable error logging
- Check to collect system overhead data.
  
During development, you'll want to have both of these options checked.

##### KNOWN BUGS
None Yet!

##### LOCALIZATION
Localization entries have been generated for 12 languages recommended by Blizzard. However, the translations were done using an AI Chatbot (ChatGPT Code Pilot), so I'm sure they could be improved. I would welcome people to review and correct the translations.

##### INSTALLATION:

- Download and install WoWThreads from CurseForge
- In your Addon's TOC, add WoWThreads as a dependency for example:
```
  ##Dependencies: WoWThreads
```

- Access to the WoWThreads library is through LibStub. So, at the top of each of your Addon's .lua file that will use the WoWThreads' services, insert the following:

```
-- Access WoWThreads using LibStub
local thread = LibStub("WoWThreads")
if not thread then
    print("Error: WoWThreads library not found!")
    return
end
```
Below the LibStub entry, add the following constants (signals):
```
local SIG_GET_DATA     = thread.SIG_GET_DATA
local SIG_SEND_DATA    = thread.SIG_SEND_DATA
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE
local SIG_SUCCESS      = thread.SIG_SUCCESS.
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_READY        = thread.SIG_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING
```

##### SUPPORT
For more information and examples, a guide can be found in the WoWThreads' Docs directory (WoWThreads-complete.md). 

The same document can also be accessed from github:
https://github.com/mtp1032/WoWThreads/blob/main/Docs/WoWThreads-complete.md. 

Finally, you may want to join the WoWThreads' discord server, https://discord.gg/K4QhU458SQ
