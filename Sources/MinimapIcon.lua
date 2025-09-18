--=================================================================================
-- Filename: MinimapIcon.lua
-- Date: 13 March, 2021 (Updated: 13 June, 2024)
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 13 March, 2021
--=================================================================================
WoWThreads = WoWThreads or {}
WoWThreads.MinimapIcon = WoWThreads.MinimapIcon or {}

if not WoWThreads.OptionsPanel.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("OptionsPanel not loaded.", 1, 0, 0 )
end

local core = WoWThreads.Core
local icon = WoWThreads.Icon
local options = WoWThreads.OptionsPanel
local L = WoWThreads.Locales

-- Minimap icon implementation starts here!
local addonName = core:getAddonInfo()
local dataObject = addonName
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0")

local WoWThreadsIconDB = LibStub("LibDataBroker-1.1"):NewDataObject(dataObject, 
{
    type = "data source",
    text = dataObject,
    icon = 3528459,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Left Click to open options window")
        tooltip:AddLine("Right Click for more options")
    end,
    OnClick = function(self, button)
        -- LEFT CLICK - Displays the options menu
        if button == "LeftButton" and not IsShiftKeyDown() then
            options:showOptionsPanel()
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

    local addonName = core:getAddonInfo()
    self:RegisterChatCommand(addonName, "iconCommands") 
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
