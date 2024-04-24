#WoWThreads

#CURRENT VERSION: 1.0
 
#SUMMARY: Enables a WoW AddOn to handle events delivered by the WoW Client's OnEvent service
asynchronously.

#DESCRIPTION: WoWThreads (code name Talon) is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. Talon provides the major features you would expect such as thread creation, signaling, delay, yield, and so forth.

Talon is designed to enable an addon to execute independently of the WoW Client event provider. More specifically, developers use threads to handle events delivered by the OnEvent service. In this way, once the WoW client delivers an event to the AddOn, it immediately returns. In the absence of WoWThreads, the WoW Client must wait for the AddOn to complete its handling before returning to the main game loop.

For more information and examples, see the WoWThreads Programmer's Guide in the Doc directory.
