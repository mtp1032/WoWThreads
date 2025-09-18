-- Core.lua

WoWThreads = WoWThreads or {}
WoWThreads.Core = WoWThreads.Core or {}
local core = WoWThreads.Core

local addonName = "WoWThreads"

local function getExpansionName( )
    local expansionLevel = GetExpansionLevel()
    local expansionNames = { -- Use a table to map expansion levels to names
        [LE_EXPANSION_DRAGONFLIGHT]             = "Dragon Flight",
        [LE_EXPANSION_SHADOWLANDS]              = "Shadowlands",
        [LE_EXPANSION_CATACLYSM]                = "Classic (Cataclysm)",
        [LE_EXPANSION_WRATH_OF_THE_LICH_KING]   = "Classic (WotLK)",
        [LE_EXPANSION_CLASSIC]                  = "Classic (Vanilla)",

        [LE_EXPANSION_MISTS_OF_PANDARIA]        = "Classic (Mists of Pandaria",
        [LE_EXPANSION_LEGION]                   = "Classic (Legion)",
        [LE_EXPANSION_BATTLE_FOR_AZEROTH]       = "Classic (Battle for Azeroth)",
        [LE_EXPANSION_WAR_WITHIN]               = "Retail (The War Within)"  
                              }
    return expansionNames[expansionLevel] -- Directly return the mapped name
end
local function getVersions()
    local tocVersion = C_AddOns.GetAddOnMetadata( addonName, "Version" )
    local x, y, z = strsplit(".", tocVersion or "0.0.0", 3)
    local MAJOR = tonumber(x) or 0
    local MINOR = tonumber(y) or 0
    local PATCH = tonumber(z) or 0

    local gitVersion = MAJOR * 10000 + MINOR * 100 + PATCH
    return tocVersion, gitVersion
end

-- Public: returns addonName, tocVersion, addonExpansion, gitVersion
function core:getAddonInfo()
    local addonExpansion = getExpansionName()
    local tocVersion, gitVersion = getVersions()
    return addonName, tocVersion, addonExpansion, gitVersion
end

WoWThreads.Core.loaded = true