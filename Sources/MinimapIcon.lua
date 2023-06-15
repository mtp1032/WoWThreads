--------------------------------------------------------------------------------------
-- MiniMapIcon.lua
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 29 October, 2022
local _, WoWThreads = ...
WoWThreads.MiniMapIcon = {}
icon = WoWThreads.MiniMapIcon

local L = WoWThreads.L
local sprintf = _G.string.format

-- local dbg = WoWThreads.errors			-- use for debugging services

local sprintf = _G.string.format

local ICON_WOWTHREADS = "Interface\\Icons\\spell_holy_senseundead"

-- register the addon with ACE
local addon = LibStub("AceAddon-3.0"):NewAddon(L["ADDON_NAME"], "AceConsole-3.0")

-- found at wowhead's icon repository
-- https://www.wowhead.com/icon=135974/spell-holy-senseundead
local shiftLeftClick = (button == "LeftButton") and IsShiftKeyDown()
local shiftRightClick = (button == "RightButton") and IsShiftKeyDown()
local altLeftClick = (button == "LeftButton") and IsAltKeyDown()
local altRightClick = (button == "RightButton") and IsAltKeyDown()
local rightButtonClick = (button == "RightButton")

-- The addon's icon state (e.g., position, etc.,) is kept in the WoWThreadsDB. Therefore
--  this is set as the ##SavedVariable in the .toc file
local WoWThreadsDB = LibStub("LibDataBroker-1.1"):NewDataObject(L["ADDON_NAME"],
	{
		type = "data source",
		text = L["ADDON_NAME"],
		icon = ICON_WOWTHREADS,
		OnTooltipShow = function( tooltip )
			tooltip:AddLine( L["ADDON_NAME_AND_VERSION"] )
			tooltip:AddLine(L["LEFTCLICK_FOR_OPTIONS_MENU"])
			tooltip:AddLine(L["RIGHTCLICK_SHOW_COMBATLOG"])
			tooltip:AddLine(L["SHIFT_LEFTCLICK_DISMISS_COMBATLOG"])
			tooltip:AddLine(L["SHIFT_RIGHTCLICK_ERASE_TEXT"])
		end,
		OnClick = function(self, button ) 
			-- LEFT CLICK - Displays the options menu
			if button == "LeftButton" and not IsShiftKeyDown() then
				mf:showOptionsPanel()
			end
			-- RIGHT CLICK - Displays a list of excluded items
			if button == "RightButton" and not IsShiftKeyDown() then
				print("debugging turned on")
			end
			-- SHIFT RIGHT CLICK - Deletes the exclusion table
			if button == "RightButton" and IsShiftKeyDown() then
				print("Performance data collection selected")
			end
		end,
	})

-- so far so good. Now, create the actual icon	
local icon = LibStub("LibDBIcon-1.0")

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("WoWThreadsDB", 
					{ profile = { minimap = { hide = false, }, }, }) 
	icon:Register(L["ADDON_NAME"], WoWThreadsDB, self.db.profile.minimap) 
end

-- What to do when the player clicks the minimap icon
local eventFrame = CreateFrame("Frame" )
eventFrame:RegisterEvent( "ADDON_LOADED")
eventFrame:SetScript("OnEvent", 
function( self, event, ... )
	local arg1, arg2, arg3 = ...

	if event == "ADDON_lOADED" and arg1 == L["ADDON_NAME"] then
		addon:OnInitialize()
	end
end)

local fileName = "MinimapIcon.lua"
if core:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
