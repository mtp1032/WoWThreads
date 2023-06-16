local _, WoWThreads = ... 

local Major ="WoWThreads-1.0"
local thread = LibStub:GetLibrary( Major )
if not thread then 
    return 
end
------------------ BEGIN Options Panel -----------------------------
local sprintf = _G.string.format

-- https://wow.gamepedia.com/API_Frame_SetBackdrop
-- https://wow.gamepedia.com/EdgeFiles
-- https://wow.gamepedia.com/API_FontInstance_SetFontObject

local WIDTH_TITLE_BAR = 500
local HEIGHT_TITLE_BAR = 45
local FRAME_WIDTH = 590
local FRAME_HEIGHT = 400

local DEFAULT_XPOS = 0
local DEFAULT_YPOS = 200

local L = setmetatable({}, { __index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

local sprintf = _G.string.format

-- English translations
local LOCALE = GetLocale()      -- BLIZZ
if LOCALE == "enUS" then 
    L["OPTIONS"] = "WoWThreads Options"
    L["OPTIONS_MENUS"]= sprintf("%s %s", L["OPTIONS"], "Menu")

    L["LINE1"] = "WoWThreads is a library of services that enable developers"
    L["LINE2"] = "add asynchronous, non-preemptve multithreading to their addons."
    L["LINE3"] =  "  "
    L["LINE4"] = "One of the most common uses of threads in gaming environments like WoW,"
    L["LINE5"] = "is to use threads to handle events. When an event is received, a thread"
    L["LINE6"] = "is signaled to handle/process the event or its payload."
    L["LINE7"] =  "        "
    L["LINE8"] = "You can read more about thread programming in the WoW Threads Libary"
    L["LINE9"] = "in the Docs directory."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"]     = "Check to collect thread congestion data."
    L["TOOTIP_DATA_COLLECTION"]     = "If checked, per thread congestion data will be collected."

    L["ENABLE_DEBUGGING"]           = "Check to enable strict debugging."
    L["TOOLTIP_DEBUGGING"]         = "If checked, most errors are not returned to the calling thread. Instead, the thread fails in place and generates an error message and a stack trace."
end

--------------------------------------------------------------------------
--                         CREATE THE VARIOUS BUTTONS
--------------------------------------------------------------------------
local function createDefaultsButton( f )
end
local function createAcceptButton( f )
end

local LINE_SEGMENT_LENGTH = 575
local X_START_POINT = 10
local Y_START_POINT = 10

local function drawLine( f, yPos)
	local lineFrame = CreateFrame("FRAME", nil, f )
	lineFrame:SetPoint("CENTER", -10, yPos )
	lineFrame:SetSize(LINE_SEGMENT_LENGTH, LINE_SEGMENT_LENGTH)
	
	local line = lineFrame:CreateLine(1)
	line:SetColorTexture(.5, .5, .5, 1) -- Grey per https://wow.gamepedia.com/Power_colors
	line:SetThickness(2)
	line:SetStartPoint("LEFT",X_START_POINT, Y_START_POINT)
	line:SetEndPoint("RIGHT", X_START_POINT, Y_START_POINT)
	lineFrame:Show() 
end
local strictDebugging   = false
local dataCollection    = false

local function showExecutionOptions( frame, yPos )

    -- Create check button to toggle strict debugging
    local debuggingButton = CreateFrame("CheckButton", "Toggle_DebuggingButton", frame, "ChatConfigCheckButtonTemplate")
	debuggingButton:SetPoint("TOPLEFT", 20, yPos )
    debuggingButton.tooltip = L["TOOLTIP_DEBUGGING"]
	_G[debuggingButton:GetName().."Text"]:SetText(L["ENABLE_DEBUGGING"])
    strictDebugging = thread:debuggingIsEnabled()
    debuggingButton:SetChecked( strictDebugging )
	debuggingButton:SetScript("OnClick", 
		function(self)
			strictDebugging = self:GetChecked() and true or false
    	end)
    -- Create check button to toggle data collection
    local dataCollectionButton = CreateFrame("CheckButton", "Toggle_DataCollectionButton", frame, "ChatConfigCheckButtonTemplate")
    dataCollectionButton:SetPoint("TOPLEFT", 290, yPos)
    dataCollectionButton.tooltip = L["TOOTIP_DATA_COLLECTION"]
	_G[dataCollectionButton:GetName().."Text"]:SetText(L["ENABLE_DATA_COLLECTION"])
    dataCollection = thread:dataCollectionIsEnabled()
	dataCollectionButton:SetChecked( dataCollection )
	dataCollectionButton:SetScript("OnClick", 
		function(self)
			dataCollection = self:GetChecked() and true or false
    	end)
end

local function createOptionsPanel()
		
	local frame = CreateFrame("Frame", L["OPTIONS"], UIParent, BackdropTemplateMixin and "BackdropTemplate")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 26,
        insets = {left = 9, right = 9, top = 9, bottom = 9},
    })
    frame:SetBackdropColor(0.0, 0.0, 0.0, 0.85)

    -- The Title Bar & Title
	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 12)
    frame.titleBar:SetSize( WIDTH_TITLE_BAR, HEIGHT_TITLE_BAR)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 4)
	frame.title:SetText(L["OPTIONS_MENUS"])

    -- Title text
	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")
	frame:SetHeight(frame.text:GetHeight() + 70)
	tinsert( UISpecialFrames, frame:GetName() )
    frame:SetSize( FRAME_WIDTH, FRAME_HEIGHT )
        -------------------- WARNING DESCRIPTION ---------------------------------------
        local DescrSubHeader = frame:CreateFontString(nil, "ARTWORK","GameFontNormalLarge")
        local messageText = frame:CreateFontString(nil, "ARTWORK","GameFontNormal")
        messageText:SetJustifyH("LEFT")
    
        -- local str2 = sprintf("WoWThreads is a library of services that enable developers")
        -- local str3 = sprintf("add asynchronous, non-preemptve multithreading to their addons.")
        -- local str4 = sprintf("   ")
        -- local str5 = sprintf("One of the most common uses of threads in gaming environments like WoW,")
        -- local str6 = sprintf("is to use threads to handle events. When an event is received, a thread")
        -- local str7 = sprintf("is signaled to handle/process the event or its payload.")
        -- local str8 = sprintf("         ")
        -- local str9 = sprintf("You can read more about thread programming in the WoW Threads Libary")
        -- local str10 = sprintf("in the Docs directory.")
        local messageText = frame:CreateFontString(nil, "ARTWORK","GameFontNormal")
        messageText:SetJustifyH("LEFT")
        messageText:SetPoint("TOP", 0, -40) -- was -70
        messageText:SetText(sprintf("%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s", 
        L["LINE1"], L["LINE2"], L["LINE3"], L["LINE4"], L["LINE5"], L["LINE6"], L["LINE7"], L["LINE8"], L["LINE9"]))
      
    showExecutionOptions( frame, -200 ) -- was -250
	-- drawLine( frame, 110 )	
    drawLine( frame, 20 )	

    -- Accept buttom, bottom right corner
	frame.hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.hide:SetText( L["ACCEPT_BUTTON_LABEL"] )
	frame.hide:SetHeight(20)
	frame.hide:SetWidth(80)
	frame.hide:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
	frame.hide:SetScript("OnClick",
		function( self )
            if strictDebugging then thread:enableDebugging() else thread:disableDebugging() end
            if dataCollection then thread:enableDataCollection() else thread:disableDataCollection() end
			frame:Hide()
		end)

    -- Dismiss Button at bottom left corner
	frame.hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.hide:SetText(L["DISMISS_BUTTON_LABEL"])
	frame.hide:SetHeight(20)
	frame.hide:SetWidth(80)
	frame.hide:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	frame.hide:SetScript("OnClick",
		function( self )
			frame:Hide()
		end)
    
    return frame   
end

local optionsPanel = createOptionsPanel()

local function showOptionsPanel()
    optionsPanel:Show()
end
local function hideOptionsPanel()
	optionsPanel:Hide()
end
--*********************** END WOWTHREADS OPTIONS PANEL

---------------------- MinimapIcon.lua -----------------------------
local ICON_WOWTHREADS = 3528459
local dataObject = "WoWThreadsLib"
local savedVarDB = bunnyLDP

local addon = LibStub("AceAddon-3.0"):NewAddon("Bunnies", "AceConsole-3.0")

local shiftLeftClick    = (button == "LeftButton") and IsShiftKeyDown()
local shiftRightClick   = (button == "RightButton") and IsShiftKeyDown()
local altLeftClick      = (button == "LeftButton") and IsAltKeyDown()
local altRightClick     = (button == "RightButton") and IsAltKeyDown()
local rightButtonClick  = (button == "RightButton")

-- local addon = LibStub("AceAddon-3.0"):NewAddon("Bunnies", "AceConsole-3.0")
local WoWThreadsIconDB = LibStub("LibDataBroker-1.1"):NewDataObject(dataObject, 
{
    type = "data source",
    text = dataObject,
    icon = ICON_WOWTHREADS,
    OnTooltipShow = function( tooltip )
        tooltip:AddLine( "Hello" )
        tooltip:AddLine( "Goodbye")
    end,
    OnClick = function(self, button ) 
        -- LEFT CLICK - Displays the options menu
        if button == "LeftButton" and not IsShiftKeyDown() then
            showOptionsPanel()
        end
        -- RIGHT CLICK - Displays a list of excluded items
        if button == "RightButton" and not IsShiftKeyDown() then
            print("Strict Debugging Enabled!")
        end
        -- SHIFT RIGHT CLICK - Deletes the exclusion table
        if button == "RightButton" and IsShiftKeyDown() then
            print("Performance data collection selected")
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
    icon:Register(dataObject, WoWThreadsIconDB, self.db.profile.minimap) 
    self:RegisterChatCommand("bunnies", "iconCommands") 
end -- terminates OnInitialize

function addon:iconCommands() 
    self.db.profile.minimap.hide = not self.db.profile.minimap.hide 
    if self.db.profile.minimap.hide then 
        icon:Hide(dataObject) 
    else 
        icon:Show(dataObject) 
    end 
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent( self, event, ... )
    local addonName = ...

    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        addon:OnInitialize()
        eventFrame:UnregisterEvent("ADDON_LOADED")  
    end
    return
end
eventFrame:SetScript( "OnEvent", OnEvent )
