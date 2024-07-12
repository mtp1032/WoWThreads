--=================================================================================
-- Filename: Icon.lua
-- Date: 13 March, 2021 (Updated: 13 June, 2024)
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 13 March, 2021
--=================================================================================
local ADDON_NAME, _ = ...
WoWThreads = WoWThreads or {}
-- WoWThreads.WoWThreads = WoWThreads.WoWThreads or {}
_G.WoWThreads = WoWThreads

WoWThreads.minimap = WoWThreads.minimap or {}
local minimap = WoWThreads.minimap

-- Access WoWThreads using LibStub
local thread = LibStub("WoWThreads")
if not thread then
    print("Error: WoWThreads library not found!")
    return
end


-- Minimap icon implementation starts here!
local ICON_WOWTHREADS = 3528459
local dataObject = "WoWThreads"

local addon = LibStub("AceAddon-3.0"):NewAddon("WoWThreads", "AceConsole-3.0")

local WoWThreadsIconDB = LibStub("LibDataBroker-1.1"):NewDataObject(dataObject, 
{
    type = "data source",
    text = dataObject,
    icon = ICON_WOWTHREADS,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Left Click to open options window")
        tooltip:AddLine("Right Click for more options")
    end,
    OnClick = function(self, button)
        -- LEFT CLICK - Displays the options menu
        if button == "LeftButton" and not IsShiftKeyDown() then
            minimap:showOptionsPanel()
        end
    end,
})
local icon = LibStub("LibDBIcon-1.0")
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("WoWThreadsIconDB", 
    { profile = { 
                    minimap = { 
                        hide = false, 
                    }, 
                }, 
            }
    )
    if not icon:IsRegistered(dataObject) then
        icon:Register(dataObject, WoWThreadsIconDB, self.db.profile.minimap)
    end

    self:RegisterChatCommand("wowthreads", "iconCommands") 
end -- terminates OnInitialize
function addon:iconCommands() 
    self.db.profile.minimap.hide = not self.db.profile.minimap.hide 
    if self.db.profile.minimap.hide then 
        icon:Hide(dataObject) 
    else 
        icon:Show(dataObject) 
    end 
end

addon:OnInitialize()
