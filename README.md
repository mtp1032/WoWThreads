#### WoWThreads V 1.0
 
##### SUMMARY: 
Enables a WoW AddOn to handle events delivered by the WoW Client's OnEvent service asynchronously.

##### DESCRIPTION:
WoWThreads is a library whose services provide asynchronous, non-preemptive multithreading for WoW Addon developers. WoWThreads provides the major features you would expect in a threads package such as thread creation, signaling (including inter-thread communications), delay, yield, and so forth.

The library is designed to enable an addon to execute asynchronously relative tothe WoW game client's (WoW.exe) event provider. More specifically, developers can use WoWThreads to handle events delivered by the OnEvent service. In this way, once the WoW client delivers an event to an addon's thread, the WoW client can immediately return. In the absence of WoWThreads, the WoW Client must wait for the addon to complete its handling before returning to the main game loop.

For more information and examples, a guide has been provided, the WoWThreads-complete.md in the Docs directory.

For your information, the following is the directory structure of the WoWThreads addon:

├── README.md
├── WoWThreads_Mainline.toc
├── WoWThreads_Cata.toc
├── WoWThreads_Vanilla.toc
├── WoWThreads_Wrath.toc
├── WoWThreads_WarWithin.toc
├── Docs/
│ └── WoWThreads-complete.md
├── Libs/
│ └── ACE/
│ ├── LibStub/
│ │ └── LibStub.lua
│ ├── CallbackHandler-1.0/
│ │ └── CallbackHandler-1.0.xml
│ ├── LibDataBroker-1.1/
│ │ └── LibDataBroker-1.1.lua
│ ├── LibDBIcon-1.0/
│ │ └── LibDBIcon-1.0.lua
│ ├── AceAddon-3.0/
│ │ └── AceAddon-3.0.xml
│ ├── AceConsole-3.0/
│ │ └── AceConsole-3.0.xml
│ └── AceDB-3.0/
│ └── AceDB-3.0.xml
├── LibStub/
├── Locales/
│ └── EnUS_WoWThreads.lua
└── Sources/
├── Icon.lua
├── OptionsLib.lua
├── SignalQueue.lua
├── UtilsLib.lua
└── WoWThreads.lua


## Description of Important Files

- **LICENSE:** The license file for the project.
- **README.md:** The main documentation file for the project.
- **WoWThreads_Mainline.toc:** Table of Contents file for the mainline version of the addon.
- **WoWThreads_Cata.toc:** Table of Contents file for the Cataclysm version of the addon.
- **WoWThreads_Vanilla.toc:** Table of Contents file for the Vanilla version of the addon.
- **WoWThreads_Wrath.toc:** Table of Contents file for the Wrath of the Lich King version of the addon.
- **WoWThreads_WarWithin.toc:** Table of Contents file for the War Within version of the addon.
- **Docs/WoWThreads-complete.md:** Complete documentation for the addon.
- **Libs/ACE/**: Directory containing ACE library files.
  - **LibStub/LibStub.lua:** LibStub library file.
  - **CallbackHandler-1.0/CallbackHandler-1.0.xml:** CallbackHandler library file.
  - **LibDataBroker-1.1/LibDataBroker-1.1.lua:** LibDataBroker library file.
  - **LibDBIcon-1.0/LibDBIcon-1.0.lua:** LibDBIcon library file.
  - **AceAddon-3.0/AceAddon-3.0.xml:** AceAddon library file.
  - **AceConsole-3.0/AceConsole-3.0.xml:** AceConsole library file.
  - **AceDB-3.0/AceDB-3.0.xml:** AceDB library file.
- **LibStub/:** Directory containing LibStub library.
- **Locales/EnUS_WoWThreads.lua:** Localization file for English (US).
- **Sources/:** Directory containing source files for the addon.
  - **Icon.lua:** Icon source file.
  - **OptionsLib.lua:** Options library source file.
  - **SignalQueue.lua:** Signal queue source file.
  - **UtilsLib.lua:** Utility library source file.
  - **WoWThreads.lua:** Main source file for the addon.
