#WoWThreads

#CURRENT VERSION: 1.0

#DESCRIPTION: WoWThreads (code name Talon) is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. Talon provides the major features you would expect such as thread creation, signaling, delay, yield, and so forth. Here is a summary of some of the services that are available in this release.

Talon is designed to enable an addon to execute independently of the WoW Client event provider. More specifically, developers use Talon threads to handle events delivered by the OnEvent service. In this way, the WoW Client simple delivers the event and immediately returns to the main game loop. 

For more information and examples, see the WoWThreads Programmer's Guide in the Doc directory.
