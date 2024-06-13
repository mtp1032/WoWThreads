local ADDON_NAME, _ = ... 


-- These are the two libraries supporting WoWThreads
local UtilsLib = LibStub("UtilsLib")
local utils = UtilsLib

local EnUSlib = LibStub("EnUSlib")


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

local LOCALE = GetLocale()      -- BLIZZ
if LOCALE == "enUS" then 
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
    strictDebugging = utils:debuggingIsEnabled()
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
    dataCollection = utils:dataCollectionIsEnabled()
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
        local messageText = frame:CreateFontString(nil, "ARTWORK","GameFontNormal")
        messageText:SetJustifyH("LEFT")
        messageText:SetPoint("TOP", 0, -40) -- was -70
        messageText:SetText(string.format("%s\n%s\n%s\n%s\n", 
        L["LINE1"], L["LINE2"], L["LINE3"], L["LINE4"] ))
      
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
            if strictDebugging then utils:enableDebugging() else utils:disableDebugging() end
            if dataCollection then utils:enableDataCollection() else utils:disableDataCollection() end
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

function minmap:showOptionsPanel()
    optionsPanel:Show()
end
local function hideOptionsPanel()
	optionsPanel:Hide()
end

local fileName = "Minimap.lua" 
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end
