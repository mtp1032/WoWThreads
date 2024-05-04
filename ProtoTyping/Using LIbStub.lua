--[[ 
Step 1: Include LibStub
Ensure that LibStub is included in your environment. This is usually done by having LibStub.lua available in your addon directory and including it in your .toc file.

Step 2: Create or Get a Library Instance
You will use LibStub to either create a new instance of your library or get the existing one if it's already been loaded by another addon. This is done to make sure that multiple addons using the same library don't end up loading multiple versions of it.

UtilsLib.lua
Here's how you might set up your UtilsLib.lua file

 ]]
-- Create a new library instance, or get the existing one
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "Library Name", 1
local LibStub = LibStub
local UtilsLib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not UtilsLib then return end -- No need to update if the version loaded is newer


-- In other addons that need to use this library, you would retrieve the library instance from LibStub:
local lib = LibStub( "Library Name" )
