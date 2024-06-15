local ADDON_NAME, _ = ...

-- Make sure the LibStub is available
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "UtilsLib", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly

-- Create a new library instance, or get the existing one
local UtilsLib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not UtilsLib then return end -- No need to update if the version loaded is newer
local utils = UtilsLib
-- =================================================
--              PROLOGUE
-- =================================================
local sprintf = _G.string.format
local function getExpansionName( )
    local expansionLevel = GetExpansionLevel()
    local expansionNames = { -- Use a table to map expansion levels to names
        [LE_EXPANSION_DRAGONFLIGHT] = "Dragon Flight",
        [LE_EXPANSION_SHADOWLANDS] = "Shadowlands",
        [LE_EXPANSION_CATACLYSM] = "Classic (Cataclysm)",
        [LE_EXPANSION_WRATH_OF_THE_LICH_KING] = "Classic (WotLK)",
        [LE_EXPANSION_CLASSIC] = "Classic (Vanilla)",

        [LE_EXPANSION_MISTS_OF_PANDARIA] = "Classic (Mists of Pandaria",
        [LE_EXPANSION_LEGION] = "Classic (Legion)",
        [LE_EXPANSION_BATTLE_FOR_AZEROTH] = "Classic (Battle for Azeroth)"
    }
    return expansionNames[expansionLevel] -- Directly return the mapped name
end

local libName = "UtilsLib"
local expansionName = getExpansionName()
local version       = C_AddOns.GetAddOnMetadata( ADDON_NAME, "Version")
local libraryName   = sprintf("%s-%s", libName, version )
--                      Initialize the library
function utils:getVersion()
    return version
end
function utils:getLibName()
    return libraryName
end
function utils:getExpansionName()
    return expansionName
end

local userMsgFrame = nil

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


-- =================================================
--                  DEBUGGING UTILITIES
-- =================================================
utils.DEBUGGING_ENABLED = true
local DEBUGGING_ENABLED = utils.DEBUGGING_ENABLED

function utils:enableDebugging()
    DEBUGGING_ENABLED = true
end
function utils:disableDebugging()
    DEBUGGING_ENABLED = false
end
function utils:debuggingIsEnabled()
    return DEBUGGING_ENABLED
end
-- function utils:enableDataCollection()
--     DATA_COLLECTION_ENABLED = true
-- end
-- function utils:disableDataCollection()
--     DATA_COLLECTION_ENABLED = false
-- end
-- function utils:dataCollectionIsEnabled()
--     return DATA_COLLECTION_ENABLED
-- end
--======================================================================
--                          STRING FUNCTIONS
-- =====================================================================

 -- Removes the Nth occurrence of a character in a specified string.@
 function removeCharByOccurrence(someString, charToRemove, charOccurrence)
    -- Input validation
    if type(someString) ~= "string" or type(charToRemove) ~= "string" or type(charOccurrence) ~= "number" then
        return nil, "Invalid input types!"
    end
    if #charToRemove == 0 or charOccurrence <= 0 then
        return nil, "Character to remove must be a non-empty string and occurrence must be a positive integer!"
    end

    local count = 0
    local position = 0

    -- Find the nth occurrence of the character
    for i = 1, #someString do
        if someString:sub(i, i) == charToRemove then
            count = count + 1
            if count == charOccurrence then
                position = i
                break
            end
        end
    end

    -- Error handling for not finding the character or the nth occurrence
    if count == 0 then
        return nil, "Specified character not found!"
    elseif count < charOccurrence then
        return nil, "Specified character not at specified position!"
    end

    -- Remove the character from the string
    if position > 0 then
        someString = someString:sub(1, position - 1) .. someString:sub(position + 1)
        return someString
    else
        return nil, "Character position exceeds length of string."
    end
end

function utils:removeDoubleQuotes(str)
    return (string.gsub(str, '%"', ""))
end
-- @Description: Searches for and removes the first occurrence of the specified character in a string.@
function utils:removeCharacter(str, charToRemove)
    -- Replace all occurrences of charToRemove in str with an empty string
    return (string.gsub(str, charToRemove, ""))
end
-- @Description: Removes all spaces in a strings.@
function utils:removeSpaces(str)
    -- Replace all spaces in str with an empty string
    return (string.gsub(str, "%s", ""))
end
-- @Description: Returns the position of the nth occurrence of a specified character in a strings.@
function utils:findCharPosition(str, n, char)
    local count = 0
    for i = 1, #str do
        if str:sub(i, i) == char then
            count = count + 1
            if count == n then
                return i -- Return position as soon as the character is found
            end
        end
    end
    return nil -- Return nil if the character is not found
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
		frameWidth, frameHeight= f:GetSize()
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
    f:SetPoint("CENTER", 0, 200)
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
function utils:simplifyStackTrace(stackTrace)
    local addonName = string.match(stackTrace, "@Interface/AddOns/(%w+)")
    local subDirs = string.match(stackTrace, "/(%w+)/(%w+)")
    local fileName = string.match(stackTrace, "/(%w+%.lua)")
    local lineNumber = string.match(stackTrace, "(%d+):")

    if subDirs then
        subDirs = string.gsub(subDirs, "/", "/")
        return addonName .. "/" .. subDirs .. "/" .. fileName .. ":" .. lineNumber
    else
        return addonName .. "/" .. fileName .. ":" .. lineNumber
    end
end
function utils:postMsg( msg )
    if userMsgFrame == nil then
        userMsgFrame = createMsgFrame( "Error Messages (WoWThreads-1.0)" )
    end

    if msg == nil then
        utils:dbgPrint("msg is nil" )
        local stackTrace = debugstack(2)
        stackTrace = utils:simplifyStackTrace( stackTrace )
        msg = sprintf("Invalid: 'msg' Was nil\nStack Trace:\n%s", stackTrace )
        utils:postMsg( msg )
        error( "Error: Program Stopped")
    end
	userMsgFrame.Text:Insert( msg )
	userMsgFrame:Show()
end
--======================================================================
--                 DEBUG AND ERROR HANDLING METHODS
-- =====================================================================

function utils:dbgPrefix( stackTrace )
	if stackTrace == nil then stackTrace = debugstack(2) end
	
	local pieces = {strsplit( ":", stackTrace, 5 )}
	local segments = {strsplit( "\\", pieces[1], 5 )}

	local fileName = segments[#segments]
	
	local strLen = string.len( fileName )
	local fileName = string.sub( fileName, 1, strLen - 2 )
	local names = strsplittable( "\/", fileName )
	local lineNumber = tonumber(pieces[2])

	local location = sprintf("[%s:%d] ", names[#names], lineNumber)
	return location
end
function utils:dbgPrint(...)
    local prefix = utils:dbgPrefix( debugstack(2) )

    -- The '...' collects all extra arguments passed to the function
    local args = {...}  -- This creates a table 'args' containing all extra arguments

    -- Convert all arguments into strings to ensure proper formatting for print
    local output = {prefix}
    for i, v in ipairs(args) do
        table.insert(output, tostring(v))
    end

    -- Use the unpack function to pass all elements of 'output' as separate arguments to the built-in print function
    -- numArgs = #output
    _G.print(unpack(output))
end
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end

-- only called when utils:debuggingIsEnabled() is true
-- Messages are, for the moment, may be non-localized.
function utils:dbgLog( msg, stackTrace ) -- use debugstack(2)
    local newMsg = nil
    local st = ""
    if stackTrace ~= nil then
        st = utils:simplifyStackTrace( stackTrace )
    end
    newMsg = string.format("[LOG] %s : %s\n", msg, st )
    DEFAULT_CHAT_FRAME:AddMessage( newMsg, 0.0, 1.0, 1.0 )
    return newMsg
end



local fileName = "UtilsLib.lua"
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end
