-- OptionsPanel.lua

WoWThreads = WoWThreads or {}
WoWThreads.OptionsPanel = WoWThreads.OptionsPanel or {}

if not WoWThreads.Mgmt.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("WoWThreadsMgmt.lua not loaded.", 1, 0, 0)
    return
end

local addonName = WoWThreads.Core:getAddonInfo()
local thread = LibStub("WoWThreads")
local utils = WoWThreads.UtilsLib
local options = WoWThreads.OptionsPanel
local L = WoWThreads.Locales.L

local WIDTH_TITLE_BAR = 590 -- Match FRAME_WIDTH
local HEIGHT_TITLE_BAR = 45
local FRAME_WIDTH = 590
local FRAME_HEIGHT = 400

local LINE_SEGMENT_LENGTH = 575
local X_START_POINT = 10
local Y_START_POINT = 10

-- Temporary variables for checkbox states
local tempDebuggingEnabled = WOWTHREADS_SAVED_VARS.debuggingIsEnabled or false
local tempDataCollectionEnabled = WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled or false

local function drawLine(f, yPos)
    local lineFrame = CreateFrame("FRAME", nil, f)
    lineFrame:SetPoint("CENTER", -10, yPos)
    lineFrame:SetSize(LINE_SEGMENT_LENGTH, 2)
    
    local line = lineFrame:CreateLine(nil, "ARTWORK")
    line:SetColorTexture(.5, .5, .5, 1) -- Grey
    line:SetThickness(2)
    line:SetStartPoint("LEFT", 0, 0)
    line:SetEndPoint("RIGHT", 0, 0)
    lineFrame:Show()
end

local function showExecutionOptions(frame, yPos)
    -- Create check button to toggle debugging
    local debuggingButton = CreateFrame("CheckButton", "Toggle_DebuggingButton", frame, "ChatConfigCheckButtonTemplate")
    debuggingButton:SetPoint("TOPLEFT", 20, yPos)
    debuggingButton.tooltip = L["TOOLTIP_DEBUGGING"]
    _G[debuggingButton:GetName().."Text"]:SetText(L["ENABLE_ERROR_LOGGING"])
    debuggingButton:SetChecked(WOWTHREADS_SAVED_VARS.debuggingIsEnabled)
    debuggingButton:SetScript("OnClick", 
        function(self)
            tempDebuggingEnabled = self:GetChecked()
            -- utils:dbgPrint(addonName .. ": Debugging checkbox toggled - tempDebuggingEnabled: " .. tostring(tempDebuggingEnabled))
        end)

    -- Create check button to toggle data collection
    local dataCollectionButton = CreateFrame("CheckButton", "Toggle_DataCollectionButton", frame, "ChatConfigCheckButtonTemplate")
    dataCollectionButton:SetPoint("TOPLEFT", 290, yPos)
    dataCollectionButton.tooltip = L["TOOLTIP_DATA_COLLECTION"]
    _G[dataCollectionButton:GetName().."Text"]:SetText(L["Enable Data Collection"])
    dataCollectionButton:SetChecked(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled)
    dataCollectionButton:SetScript("OnClick", 
        function(self)
            tempDataCollectionEnabled = self:GetChecked()
            -- utils:dbgPrint(addonName .. ": Data collection checkbox toggled - tempDataCollectionEnabled: " .. tostring(tempDataCollectionEnabled))
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

    -- Title Bar & Title
    frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
    frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    frame.titleBar:SetPoint("TOP", 0, 12)
    frame.titleBar:SetSize(WIDTH_TITLE_BAR, HEIGHT_TITLE_BAR)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, 4)
    frame.title:SetText("Options Menu")

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
           WOWTHREADS_SAVED_VARS.debuggingIsEnabled = tempDebuggingEnabled
            if WOWTHREADS_SAVED_VARS.debuggingIsEnabled then
                thread:enableDebugging()
            else
                thread:disableDebugging()
            end
           WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled = tempDataCollectionEnabled
            if WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled then
                thread:enableDataCollection()
            else
                thread:disableDataCollection()
            end
            -- utils:postMsg(addonName .. ": Accept button clicked -WOWTHREADS_SAVED_VARS.debuggingIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.debuggingIsEnabled) .. ",WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled))
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
            -- Reset temporary variables and checkboxes to saved state
            tempDebuggingEnabled = WOWTHREADS_SAVED_VARS.debuggingIsEnabled
            tempDataCollectionEnabled = WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled
            _G["Toggle_DebuggingButton"]:SetChecked( WOWTHREADS_SAVED_VARS.debuggingIsEnabled)
            _G["Toggle_DataCollectionButton"]:SetChecked(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled)
            -- -- utils:dbgPrint(addonName .. ": Dismiss button clicked - Reset toWOWTHREADS_SAVED_VARS.debuggingIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.debuggingIsEnabled) .. ",WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled))
            frame:Hide()
        end)

    return frame
end

local optionsPanel = nil

function options:showOptionsPanel()
    if optionsPanel == nil then
        optionsPanel = createOptionsPanel()
    end
    -- Ensure checkboxes reflect current saved state
    _G["Toggle_DebuggingButton"]:SetChecked(WOWTHREADS_SAVED_VARS.debuggingIsEnabled)
    _G["Toggle_DataCollectionButton"]:SetChecked(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled)
    tempDebuggingEnabled = WOWTHREADS_SAVED_VARS.debuggingIsEnabled
    tempDataCollectionEnabled = WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled
    -- -- utils:dbgPrint(addonName .. ": Options panel opened -WOWTHREADS_SAVED_VARS.debuggingIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.debuggingIsEnabled) .. ",WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled: " .. tostring(WOWTHREADS_SAVED_VARS.dataCollectionIsEnabled))
    optionsPanel:Show()
end

local function hideOptionsPanel()
    if optionsPanel then
        optionsPanel:Hide()
        -- utils:dbgPrint(addonName .. ": Options panel hidden")
    end
end

WoWThreads.OptionsPanel.loaded = true