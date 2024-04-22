#WoWThreads

#CURRENT VERSION: 1.0

#DESCRIPTION: WoWThreads (code name Talon) is an API used to incorporate asynchronous, non-preemptive multithreading into WoW Addons. Talon provides the major features you would expect such as thread creation, signaling, delay, yield, and so forth. Here is a summary of some of the services that are available in this release.

Threads - creation, yield, join, exit, signal (set/get), state (active, suspended, completed) Signals - SIG_ALERT, SIG_TERMINATE, SIG_NONE_PENDING, and SIG_METRICS. Tuning (thread congestion metrics).

Talon is designed to increase an addon's ability to take advantage of the WoW client's inherent asynchronicity by offering threads to which tasks can be assigned and then run asnchronously relative to the WoW client's execution code path.

For more information and examples, see the WoWThreads Programmer's Guide in the Doc directory.
