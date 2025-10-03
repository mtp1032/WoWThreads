-- UtilsLib.lua
WoWthreads = WoWthreads or {}
WoWThreads.UtilsLib = WoWThreads.UtilsLib or {}

if not WoWThreads.Locales.loaded then
    DEFAULT_CHAT_FRAME:AddMessage("Localizations.lua not loaded", 1, 0, 0 )
    return
end

local utils = WoWThreads.UtilsLib
local L = WoWThreads.Locales.L

-- =================================================
--              PROLOGUE
-- =================================================

local infoNotificationFrame = nil
local resultNotificationFrame = nil

utils.EMPTY_STR = ""
local EMPTY_STR = utils.EMPTY_STR

-- This is a function that will print all of the visible symbols from an addon's symbol table.

-- Helper function to recursively print the contents of a table
local function printTable(t, indent)
    indent = indent or "   "
    for k, v in pairs(t) do
        if type(v) == "table" then
            local str = indent .. k .. ":"
            utils:postMsg(string.format("%s\n", str ))
            printTable(v, indent .. "  ")
        else
            local str = indent .. k .. ": " .. tostring(v)
            utils:postMsg( string.format("%s\n", str ))
        end
    end
end
-- Function to get all global variables for a specified addon
function utils:printGlobalVars( addonName )SLASH_PRINTGLOBALS1 = "/printglobals"
    SlashCmdList["PRINTGLOBALS"] = function(msg)
        local addonName = msg:match("^(%S+)$")
        if addonName then
            _G.printGlobalVars(addonName)
        else
            print("Usage: /printglobals <AddonName>")
        end
    end
    local globals = {}
    
    for k, v in pairs(_G) do
        -- Check if the variable name starts with the addon name
        if type(k) == "string" and k:find("^" .. addonName) then
            globals[k] = v
        end
    end
    
    printTable( globals )
end

-- Register the table globally for other addon files to use
-- Add the printGlobalVars function to the global namespace
_G.printGlobalVars = function(addonName)
    utils:printGlobalVars(addonName)
end 
    
-- Example Usage:
SLASH_PRINTGLOBALS1 = "/printglobals"
SlashCmdList["PRINTGLOBALS"] = function(msg)
    local addonName = msg:match("^(%S+)$")
    if addonName then
        _G.printGlobalVars(addonName)
    else
        print("Usage: /printglobals <AddonName>")
    end
end

--======================================================================
--                          POST MESSAGE METHODS
-- =====================================================================
local DEFAULT_FRAME_WIDTH = 1000
local DEFAULT_FRAME_HEIGHT = 400

local function createResizeButton( f )
	f:SetResizable( true )
	local resizeButton = CreateFrame("Button", nil, f)
	resizeButton:SetSize(16, 16)
	resizeButton:SetPoint("BOTTOMRIGHT")
	resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resizeButton:SetScript("OnMouseDown", function(self, button)
    	f:StartSizing("BOTTOMRIGHT")
    	f:SetUserPlaced(true)
	end)
 
	resizeButton:SetScript("OnMouseUp", function(self, button)
		f:StopMovingOrSizing()
		local frameWidth, frameHeight= f:GetSize()
	end)
end
local function createClearButton( f, placement, offX, offY )
    local clearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearButton:SetPoint(placement, f, 5, 5)
    clearButton:SetHeight(25)
    clearButton:SetWidth(70)
    clearButton:SetText( "Clear" )
    clearButton:SetScript("OnClick", 
        function(self)
            self:GetParent().Text:EnableMouse( false )    
            self:GetParent().Text:EnableKeyboard( false )   
            self:GetParent().Text:SetText( EMPTY_STR ) 
            self:GetParent().Text:ClearFocus()
        end)
    f.clearButton = clearButton
end
local function createSelectButton( f, placement, offX, offY )
    local selectButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectButton:SetPoint(placement, f, -5, 5)

    selectButton:SetHeight(25)
    selectButton:SetWidth(70)
    selectButton:SetText( "Select" )
    selectButton:SetScript("OnClick", 
        function(self)
            self:GetParent().Text:EnableMouse( true )    
            self:GetParent().Text:EnableKeyboard( true )   
            self:GetParent().Text:HighlightText()
            self:GetParent().Text:SetFocus()
        end)
    f.selectButton = selectButton
end
local function createResetButton( f, placement, offX, offY )
    local resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetButton:SetPoint(placement, f, 5, 5)
    resetButton:SetHeight(25)
    resetButton:SetWidth(70)
    resetButton:SetText( "Reset" )
    resetButton:SetScript("OnClick", 
        function(self)
            self:GetParent().Text:EnableMouse( false )    
            self:GetParent().Text:EnableKeyboard( false )   
            self:GetParent().Text:SetText( EMPTY_STR )
            self:GetParent().Text:ClearFocus()
           end)
    f.resetButton = resetButton
end
local function createReloadButton( f, placement, offX, offY )
    local reloadButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	reloadButton:SetPoint(placement, f, 5, 5) -- was -175, 10
    reloadButton:SetHeight(25)
    reloadButton:SetWidth(70)
    reloadButton:SetText( "Reload UI" )
    reloadButton:SetScript("OnClick", 
        function(self)
            ReloadUI()
        end)
    f.reloadButton = reloadButton
end
local function createTopFrame( frameName, width, height, red, blue, green )
	local f = CreateFrame( "Frame", frameName, UIParent, "BasicFrameTemplateWithInset" )
	if width == nil then
		width = DEFAULT_FRAME_WIDTH
	end
	if height == nil then
		height = DEFAULT_FRAME_HEIGHT
	end
	f:SetSize( width, height )
	return f
end
local function createTextDisplay(f)
    f.SF = CreateFrame("ScrollFrame", "$parent_DF", f, "UIPanelScrollFrameTemplate")
    f.SF:SetPoint("TOPLEFT", f, 12, -30)
    f.SF:SetPoint("BOTTOMRIGHT", f, -30, 40)

    --                  Now create the EditBox
    f.Text = CreateFrame("EditBox", nil, f)
    f.Text:SetMultiLine(true)
    f.Text:SetSize(DEFAULT_FRAME_WIDTH - 20, DEFAULT_FRAME_HEIGHT )
    f.Text:SetPoint("TOPLEFT", f.SF)    -- ORIGINALLY TOPLEFT
    f.Text:SetPoint("BOTTOMRIGHT", f.SF) -- ORIGINALLY BOTTOMRIGHT
    f.Text:SetMaxLetters(99999)
    f.Text:SetFontObject(GameFontNormalLarge) -- Color this R 99, G 14, B 55
    f.Text:SetHyperlinksEnabled( true )
    f.Text:SetTextInsets(5, 5, 5, 5, 5)
    f.Text:SetAutoFocus(false)
    f.Text:EnableMouse( false )
    f.Text:EnableKeyboard( false )
    f.Text:SetScript("OnEscapePressed", 
        function(self) 
            self:ClearFocus() 
        end) 
    f.SF:SetScrollChild(f.Text)
end
local function createMsgFrame(title)
    local f = createTopFrame( "ErrorMsgFrame",DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT, 0, 0 )
    -- f:SetPoint("CENTER", 0, 200)
	    f:SetPoint("CENTER", 100, 200)

    f:SetFrameStrata("BACKGROUND")
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetMovable(true)
    f:Hide()
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY")
	f.title:SetFontObject("GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 5, 0)
	f.title:SetText( title)
	
    createTextDisplay(f)
    createResizeButton(f)
    createSelectButton(f, "BOTTOMRIGHT",f, 5, 5)
    createReloadButton(f, "BOTTOMLEFT", f, 5, 5)
    return f
end
function utils:postMsg( msg )
    if infoNotificationFrame == nil then
        infoNotificationFrame = createMsgFrame( "LOG: WoWThreads Message(s)" )
    end

    if msg == nil then
        local stackTrace = debugstack(2)
        stackTrace = utils:simplifyStackTrace( stackTrace )
        msg = string.format("%s - Stack Trace:\n%s\n", L["PARAMETER_NIL"], stackTrace )
        error( "Error: Program Stopped")
    end
	infoNotificationFrame.Text:Insert( msg )
	infoNotificationFrame:Show()
end
function utils:postResult( result )
    if result == nil then error( "Input 'result' was nil!") end
    if type(result) ~= 'table' then error( "Input 'result' not a table") end

    if resultNotificationFrame == nil then
        resultNotificationFrame = createMsgFrame( "Results" )
    end
        
    local resultStr = string.format( "\n%s\nStack Trace:%s\n", result[1], result[2])
	if infoNotificationFrame then infoNotificationFrame.Text:Insert( resultStr ) end
	if infoNotificationFrame then infoNotificationFrame:Show()end
end

--======================================================================
--                          DEBUG UTILITIES
-- =====================================================================
function utils:simplifyStackTrace(stackTrace)
    local addonName = string.match(stackTrace, "AddOns/([^/]+)")
    local subDirs = string.match(stackTrace, "AddOns/[^/]+/(.-)/[^/]+%.lua")
    local fileName = string.match(stackTrace, "/([^/]+%.lua)")
    local lineNumber = string.match(stackTrace, ":(%d+):")

    if not addonName or not fileName or not lineNumber then
        return stackTrace -- fallback to raw trace
    end

    if subDirs then
        return string.format("%s/%s/%s:%s", addonName, subDirs, fileName, lineNumber)
    else
        return string.format("%s/%s:%s", addonName, fileName, lineNumber)
    end
end

local DEBUG_ENABLED = true

function utils:isDebuggingEnabled()
    return DEBUG_ENABLED
end
function utils:enableDebugging()
    DEBUG_ENABLED = true
end
function utils:disableDebugging()
    DEBUG_ENABLED = false
end

function utils:dbgPrefix(stackTrace)
    stackTrace = stackTrace or debugstack(2)
    
    -- Extract the relevant part of the stack trace (filename and line number)
    local fileName, lineNumber = stackTrace:match("[\\/]([^\\/:]+):(%d+)")
    if not fileName or not lineNumber then
        return "[Unknown:0] "
    end

    -- Remove any trailing unwanted characters (e.g., `"]`, `*]`, `"`) from the filename
    fileName = fileName:gsub("[%]*\"]", "")

    -- Create the prefix with file name and line number, correctly formatted
    -- local prefix = string.format("[%s:%d] ", fileName, tonumber(lineNumber))
        local prefix = string.format("[%s:%d] ", fileName, tonumber(lineNumber))
        -- DEFAULT_CHAT_FRAME:AddMessage(prefix)
    return prefix
end
function utils:dbgPrint(...)
    local prefix = utils:dbgPrefix(debugstack(2))

    -- Convert all arguments to strings and concatenate them with a space delimiter
    local args = {...}
    for i, v in ipairs(args) do
        args[i] = tostring(v)
    end

    prefix = string.format("|cffff9900%s|r", prefix)
    local output = prefix .. table.concat(args, " ")

    -- Directly call the global print function
    DEFAULT_CHAT_FRAME:AddMessage(output)
end

WoWThreads.UtilsLib.loaded = true
return WoWThreads.UtilsLib