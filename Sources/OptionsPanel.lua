WoWThreads = WoWThreads or {}
WoWThreads.OptionsPanel = WoWThreads.OptionsPanel or {}

if not WoWThreads.Mgmt.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "WoWThreadsMgmt.lua not loaded.", 1, 0, 0)
    return
end

local thread = WoWThreads.ThreadLib

local options = WoWThreads.OptionsPanel

local L = WoWThreads.Locales.L

local WIDTH_TITLE_BAR = 500
local HEIGHT_TITLE_BAR = 45
local FRAME_WIDTH = 590
local FRAME_HEIGHT = 400

local DEFAULT_XPOS = 0
local DEFAULT_YPOS = 200

local enableDebugging = false
local enableDataCollection = false
--------------------------------------------------------------------------
--                         CREATE THE VARIOUS BUTTONS
--------------------------------------------------------------------------
local function createDefaultsButton(f)
    -- Implementation for the defaults button
end

local function createAcceptButton(f)
    -- Implementation for the accept button
end

local LINE_SEGMENT_LENGTH = 575
local X_START_POINT = 10
local Y_START_POINT = 10

local function drawLine(f, yPos)
    local lineFrame = CreateFrame("FRAME", nil, f)
    lineFrame:SetPoint("CENTER", -10, yPos)
    lineFrame:SetSize(LINE_SEGMENT_LENGTH, 2)
    
    local line = lineFrame:CreateLine(nil, "ARTWORK")
    line:SetColorTexture(.5, .5, .5, 1) -- Grey per https://wow.gamepedia.com/Power_colors
    line:SetThickness(2)
    line:SetStartPoint("LEFT", 0, 0)
    line:SetEndPoint("RIGHT", 0, 0)
    lineFrame:Show()
end

local function showExecutionOptions(frame, yPos)

    -- Create check button to toggle strict debugging
    local debuggingButton = CreateFrame("CheckButton", "Toggle_DebuggingButton", frame, "ChatConfigCheckButtonTemplate")
    debuggingButton:SetPoint("TOPLEFT", 20, yPos)
    debuggingButton.tooltip = L["TOOLTIP_DEBUGGING"]
    _G[debuggingButton:GetName().."Text"]:SetText(L["ENABLE_ERROR_LOGGING"])
    print( "line 63 debuggingIsEnabled()", thread:isDebuggingEnabled() )
    debuggingButton:SetChecked( thread:isDebuggingEnabled() )
    debuggingButton:SetScript("OnClick", 
        function(self)
            local isTrue = self:GetChecked() and true or false
            enableDebugging = isTrue
            if isTrue then 
                thread:enableDebugging()
            else
                thread:disableDebugging()
            end
        end)

    -- Create check button to toggle data collection
    local dataCollectionButton = CreateFrame("CheckButton", "Toggle_DataCollectionButton", frame, "ChatConfigCheckButtonTemplate")
    dataCollectionButton:SetPoint("TOPLEFT", 290, yPos)
    dataCollectionButton.tooltip = L["TOOLTIP_DATA_COLLECTION"]
    _G[dataCollectionButton:GetName().."Text"]:SetText(L["ENABLE_DATA_COLLECTION"])
    print( "line 81 dataCollectionIsEnabled()", thread:dataCollectionIsEnabled())
    dataCollectionButton:SetChecked( thread:dataCollectionIsEnabled() )
    dataCollectionButton:SetScript("OnClick", 
        function(self)
            local isTrue = self:GetChecked() and true or false
            enableDataCollection = isTrue
            if isTrue then
                thread:enableDataCollection()
            else
                thread:disableDataCollection()
            end
        end)
end

local function createOptionsPanel()
    local frame = CreateFrame("Frame", "MyAddonOptionsPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate")
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
    frame.titleBar:SetSize(WIDTH_TITLE_BAR, HEIGHT_TITLE_BAR)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, 4)
    frame.title:SetText(L["OPTIONS_MENUS"])

    -- Title text
    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.text:SetPoint("TOPLEFT", 12, -22)
    frame.text:SetWidth(frame:GetWidth() - 20)
    frame.text:SetJustifyH("LEFT")
    frame:SetHeight(frame.text:GetHeight() + 70)
    tinsert(UISpecialFrames, frame:GetName())
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    -- Warning description
    local messageText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    messageText:SetJustifyH("LEFT")
    messageText:SetPoint("TOP", 0, -40)
    messageText:SetText(string.format("%s\n%s\n%s\n%s\n", L["LINE1"], L["LINE2"], L["LINE3"], L["LINE4"]))

    showExecutionOptions(frame, -200)
    drawLine(frame, 20)

    -- Accept button, bottom right corner
    frame.acceptButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.acceptButton:SetText(L["ACCEPT_BUTTON_LABEL"])
    frame.acceptButton:SetHeight(20)
    frame.acceptButton:SetWidth(80)
    frame.acceptButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.acceptButton:SetScript("OnClick",
        function(self)
            if enableDebugging then 
                thread:enableDebugging() 
            else 
                thread:disableDebugging() 
            end
            if enableDataCollection then 
                thread:enableDataCollection() 
            else 
                thread:disableDataCollection() 
            end
            
            frame:Hide()
        end)

    -- Dismiss button, bottom left corner
    frame.dismissButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.dismissButton:SetText(L["DISMISS_BUTTON_LABEL"])
    frame.dismissButton:SetHeight(20)
    frame.dismissButton:SetWidth(80)
    frame.dismissButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    frame.dismissButton:SetScript("OnClick",
        function(self)
            frame:Hide()
        end)

    return frame
end


local optionsPanel = nil

function options:showOptionsPanel()
    if optionsPanel == nil then
        optionsPanel = createOptionsPanel()
    end
    optionsPanel:Show()
end

local function hideOptionsPanel()
	if optionsPanel then optionsPanel:Hide() end
end

WoWThreads.OptionsPanel.loaded = true