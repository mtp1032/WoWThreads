----------------------------------------------------------------------------------------
-- FILE NAME:		WoWThreads.Lua
-- ORIGINAL DATE:   14 March, 2023
----------------------------------------------------------------------------------------
local _, WoWThreads = ...
local ADDON_NAME = "WoWThreads"
-- Initialize the library
local thread = LibStub:NewLibrary( "WoWThreads-1.0", 1 )
if not thread then return end

local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

local sprintf = _G.string.format

thread.SUCCESS      = true
thread.FAILURE      = false
thread.EMPTY_STR    = ""

local EMPTY_STR 		        = thread.EMPTY_STR
local SUCCESS 		            = thread.SUCCESS
local FAILURE 		            = thread.FAILURE
local DEBUGGING_ENABLED         = true
local DATA_COLLECTION_ENABLED   = true
local DEFAULT_YIELD_TICKS       = 2
local THREAD_SEQUENCE_NUMBER    = 4

local DEFAULT_FRAME_WIDTH   = 800
local DEFAULT_FRAME_HEIGHT  = 400

local errorMsgFrame = nil
local userMsgFrame  = nil

local threadControlBlock    = {}
local Morgue                = {}
local Graveyard             = {}
local signalNameTable       = { "SIG_ALERT", "SIG_JOIN_DATA_READY", "SIG_TERMINATE", "SIG_METRICS", "SIG_STOP", "SIG_NONE_PENDING"}

local function getExpansionName()
    local expansionName = nil

    local expansionLevel = GetServerExpansionLevel()
    if expansionLevel == LE_EXPANSION_LEVEL_CLASSIC then
        expansionName = "Classic( Vanilla)"
    end
    if expansionLevel == LE_EXPANSION_BURNING_CRUSADE then
        expansionName = "Classic (TBC)"
    end
    if expansionLevel == LE_EXPANSION_WRATH_OF_THE_LICH_KING then
        expansionName = "Classic (WotLK)"
    end
    if expansionLevel == LE_EXPANSION_DRAGONFLIGHT then
        expansionName = "Dragonflight"
    end

	return expansionName
end
local function getAddonName()
    local st = debugstack(2)
    local chunks = strsplittable( "\/", st )
    return chunks[12]
end
local addonVersion	= GetAddOnMetadata( ADDON_NAME, "Version")
local expansionName = getExpansionName()
local CLOCK_INTERVAL	= 1/GetFramerate() * 1000
local msPerTick 	= sprintf("Clock interval: %0.01f milliseconds per tick.\n", CLOCK_INTERVAL )

local LOCALE = GetLocale()
if LOCALE == "enUS" then

	-- WoWThreads Localizations
	L["ADDON_NAME"]				= ADDON_NAME
	L["VERSION"] 				= addonVersion
	L["EXPANSION"] 				= expansionName

	L["ADDON_NAME_AND_VERSION"] = sprintf("%s %s (%s)", L["ADDON_NAME"], L["VERSION"],L["EXPANSION"])
	L["ADDON_LOADED_MESSAGE"] 	= sprintf("%s loaded", L["ADDON_NAME_AND_VERSION"] )
	L["MS_PER_TICK"] 			= sprintf("Clock interval: %0.01f milliseconds per tick\n", CLOCK_INTERVAL )

	L["LEFTCLICK_FOR_OPTIONS_MENU"]	= "Left click for options menu."
	L["RIGHTCLICK_SHOW_COMBATLOG"]	= "Right click for fun"
	L["SHIFT_LEFTCLICK_DISMISS_COMBATLOG"] = "Some other function."
	L["SHIFT_RIGHTCLICK_ERASE_TEXT"]	= "Yet another function"

 	-- Generic Error MessageS
	L["INPUT_PARM_NIL"]		= "[ERROR] Input parameter nil "
	L["INVALID_TYPE"]		= "[ERROR] Input datatype invalid . "
	L["PARAM_ILL_FORMED"]	= "[ERROR] Input paramter improperly formed. "
	L["ENTRY_NOT_FOUND"]	= "[ERROR] Entry in thread performance table not found. " 

	-- Thread specific messages
	L["HANDLE_NIL"] 				    = "[ERROR] Thread handle nil. "
	L["HANDLE_ELEMENT_IS_NIL"]			= "[ERROR] Thread handle element is nil. "
	L["HANDLE_NOT_TABLE"] 				= "[ERROR] Thread handle not a table. "
	L["HANDLE_NOT_FOUND"]				= "[ERROR] handle not found in thread control block."
	L["HANDLE_INVALID_TABLE_SIZE"] 		= "[ERROR] Invalid handle size. "
	L["HANDLE_COROUTINE_NIL"]			= "[ERROR] Thread coroutine in handle is nil. "
	L["INVALID_COROUTINE_TYPE"]			= "[ERROR] Thread coroutine is not a thread. "
	L["INVALID_COROUTINE_STATE"]		= "[ERROR] Unknown or invalid coroutine state. "
	L["THREAD_RESUME_FAILED"]			= "[ERROR] Thread was dead. Resumption failed. "
	L["THREAD_STATE_INVALID"]			= "[ERROR] Operation failed. Thread state does not support the operation. "

	L["SIGNAL_OUT_OF_RANGE"]			= "[ERROR] Signal is invalid (out of range) "
	L["SIGNAL_ILLEGAL_OPERATION"]		= "[WARNING] Cannot signal a completed thread. "
	L["RUNNING_THREAD_NOT_FOUND"]		= "[ERROR] Failed to retrieve running thread. "
	L["THREAD_INVALID_CONTEXT"] 		= "[ERROR] Operation requires thread context "
	L["DEBUGGING_NOT_ENABLED"]			= "[ERROR] Debugging has not been enabled. "
	L["DATA_COLLECTION_NOT_ENABLED"]	= "[ERROR] Data collection has not been enabled. "

	L["ASSERT"]	= "ASSERT FAILED: "
end

local TH_EXECUTABLE_IMAGE     = 1   -- the coroutine created to execute the thread's function
local TH_SEQUENCE_ID          = 2   -- a number representing the order in which the thread was created 
local TH_SIGNAL_QUEUE         = 3   -- a table of all currently pending signals
local TH_REMAINING_TICKS      = 4   -- decremented on every clock tick. When 0 the thread is queued.
local TH_TICKS_PER_YIELD      = 5   -- the time in clock ticks a thread is supendend after a yield
local TH_CHILDREN             = 6
local TH_PARENT               = 7
local TH_ADDON_NAME           = 8
local TH_EXECUTION_STATE      = 9   -- running, suspended, waiting, completed, failed

    -- Metrics
local TH_CREATION_TIME        = 10
local TH_TIMESTAMP            = 11
local TH_ACCUM_RUNTIME        = 12
local TH_ACCUM_SUSPEND_TIME   = 13
local TH_CURRENT_LIFETIME     = 14

local TH_NUM_ELEMENTS         = TH_CURRENT_LIFETIME

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
thread.SIG_ALERT           = 1
thread.SIG_JOIN_DATA_READY = 2
thread.SIG_TERMINATE       = 3
thread.SIG_METRICS         = 4
thread.SIG_STOP            = 5
thread.SIG_NONE_PENDING    = 6

local SIG_ALERT           = thread.SIG_ALERT
local SIG_JOIN_DATA_READY = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_METRICS         = thread.SIG_METRICS
local SIG_STOP            = thread.SIG_STOP
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING

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
    f.Text:SetFontObject(GameFontNormal) -- Color this R 99, G 14, B 55
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
    local f = createTopFrame( "ErrorMsgFrame",600, 200, 0, 0 )
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
    createClearButton(f, "BOTTOMLEFT",f, 5, 5)
    return f
end
local msgFrame = createMsgFrame( "WoWThreads Messages")
local function dbgPrefix( stackTrace )
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
local function dbgPrint( msg )
	local fileAndLine = dbgPrefix( debugstack(2) )
	local str = msg
	if str then
		str = sprintf("%s %s", fileAndLine, str )
	else
		str = fileAndLine
	end
	DEFAULT_CHAT_FRAME:AddMessage( str, 0.0, 1.0, 1.0 )
end	
local function dbgPrintx( ... )
	local prefix = dbgPrefix( debugstack(2) )
	DEFAULT_CHAT_FRAME:AddMessage( prefix, ... , 0.0, 1.0, 1.0 )

	local str = msg
	if str then
		str = sprintf("%s %s", fileAndLine, str )
	else
		str = fileAndLine
	end
	DEFAULT_CHAT_FRAME:AddMessage( str, 0.0, 1.0, 1.0 )
end	
-- ***********************************************************************
-- *                               LOCAL FUNCTIONS                       *
-- ***********************************************************************
local function postInfo( msg )
    if userMsgFrame == nil then
		userMsgFrame = createMsgFrame("WoWThread Messages")
	end
	userMsgFrame.Text:Insert( msg )
	userMsgFrame:Show()
end
local function printDirTree()
        local st = debugstack(2)
        local chunks = strsplittable( "\/", st )
        for i = 1, #chunks do
            postInfo( sprintf( "[%d] %s\n",i, chunks[i]))
        end
        return "not yet known"
end    
local function dataCollectionIsEnabled()
    return DATA_COLLECTION_ENABLED
end
local function enableDataCollection()
    DATA_COLLECTION_ENABLED = true
    DEFAULT_CHAT_FRAME:AddMessage( "Performance Data Collection is Now ENABLED", 0.0, 1.0, 1.0 )
end
local function disableDataCollection()
    DATA_COLLECTION_ENABLED = false  
    DEFAULT_CHAT_FRAME:AddMessage( "Performance Data Collection is Now DISABLED", 0.0, 1.0, 1.0 )
end
local function enableDebugging()
	DEBUGGING_ENABLED = true
	DEFAULT_CHAT_FRAME:AddMessage( "Debugging is Now ENABLED", 0.0, 1.0, 1.0 )
end
local function disableDebugging()
	DEBUGGING_ENABLED = false
	DEFAULT_CHAT_FRAME:AddMessage( "Debugging is Now DISABLED", 0.0, 1.0, 1.0 )
end
local function debuggingIsEnabled()
	return DEBUGGING_ENABLED
end
-- RETURNS: state - "completed", "running", "queued", "suspended", "failed"
local function getThreadState( thread_h )
    local state = coroutine.status( thread_h[TH_EXECUTABLE_IMAGE])

    if state == "dead" then -- check whether it is dead because it failed.
        state = "completed" 
    end
    if state == "normal" then state = "queued" end
    return state
end
-- RETURNS void
local function scheduleThreads()
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    for i, H in ipairs( threadControlBlock ) do  
        H[TH_CURRENT_LIFETIME] = debugprofilestop() - H[TH_CREATION_TIME]

        -- remove any/all dead threads from the TCB and move
        -- them into the Morgue
        H[TH_EXECUTION_STATE] = coroutine.status( H[TH_EXECUTABLE_IMAGE])
        
        if H[TH_EXECUTION_STATE] == "dead" then
            table.remove( threadControlBlock, i )
            table.insert( Morgue, H)
        end

        if H[TH_EXECUTION_STATE] == "suspended" then

            -- decrement the remaining tick count. If equal
            -- to 0 then the coroutine will be resumed.
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
        end
        
        if H[TH_REMAINING_TICKS] == 0 then

            -- replenish the remaining ticks counter and resume this thread.
            H[TH_REMAINING_TICKS] = H[TH_TICKS_PER_YIELD]
            
            -- resume the thread
            local co = H[TH_EXECUTABLE_IMAGE]
            
            local wasResumed, retValue = coroutine.resume( co ) 
            if not wasResumed then
                local state = coroutine.status( H[TH_EXECUTABLE_IMAGE])
                if state == "dead" then state = "failed" end
                local errorMsg = sprintf("%s (Thread[%d] from %s)\n", L["THREAD_RESUME_FAILED"], H[TH_SEQUENCE_ID], H[TH_ADDON_NAME] )
                result = setResult( errorMsg, debugstack(2) )

                -- remove from TCB and insert into the Morgue
                table.remove( threadControlBlock, i )
                table.insert( Morgue, H )
                return result
            end
        end
    end
    return result
    end
-- RETURNS: childTable, childCount. nil, 0 if no child threads
local function getThreadChildren( H )
    local childTable = nil
    local childCount = 0

    local childCount = #H[TH_CHILDREN]
    if childCount ~= 0 then
        childTable = H[TH_CHILDREN]
    end
    return childTable, childCount
end
-- RETURNS: void
local function startTimer( CLOCK_INTERVAL )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    result = scheduleThreads()
    if not result[1] then return result end
   
    C_Timer.After( CLOCK_INTERVAL, 
        function() 
            result = startTimer( CLOCK_INTERVAL )
            if not result[1] then return result end
        end)
    return result
end
-- RETURNS: running thread, threadId. nil, -1 if thread not found.
local function getRunningHandle()
    -- only one thread can be "running"
    for _, H in ipairs( threadControlBlock ) do
        local state = coroutine.status( H[TH_EXECUTABLE_IMAGE] )
        if state == "running" then
            return H, H[TH_SEQUENCE_ID]
        end
    end
    -- if we're here, it's because the WoW Client has issued
    -- this call. That's why there is not A "running" thread
    -- in the TCB.
    return nil, -1
end
-- RETURNS: void
local function yield( H )

    local beforeYield = debugprofilestop()
    H[TH_ACCUM_RUNTIME]   = H[TH_ACCUM_RUNTIME] + (beforeYield - H[TH_TIMESTAMP])
    H[TH_TIMESTAMP] = beforeYield
    
    coroutine.yield()
    
    local afterYield = debugprofilestop()
    H[TH_ACCUM_SUSPEND_TIME] = H[TH_ACCUM_SUSPEND_TIME] + afterYield - H[TH_TIMESTAMP]
    H[TH_TIMESTAMP]          = afterYield
end
-- RETURNS: signal name
local function getSignalName( signal )
    return signalNameTable[signal]
end
-- RETURNS: signal, sender_h (SIG_NONE_PENDING if thread's signal queue is empty.)
-- NOTE: signals are returned in the order they are received (FIFO)
local function getSignal()
    local signal    = SIG_NONE_PENDING
    local sender_h  = nil
    local data      = nil

    local H, threadId = getRunningHandle()
    local signalQueue = H[TH_SIGNAL_QUEUE]
    local addon = H[TH_ADDON_NAME]

    if #signalQueue == 0 then
        return signal, sender_h, data
    end

    local sigEntry = table.remove(H[TH_SIGNAL_QUEUE], 1 )
    signal = sigEntry[1]
    sender_h = sigEntry[2]
    local data = sigEntry[3]
    return signal, sender_h, data
end
-- RETURNS: Thread Id
local function getThreadId( H )
    return H[TH_SEQUENCE_ID]
end
-- RETURNS: TCB thread count.
local function insertHandleIntoTCB( H )
    table.insert( threadControlBlock, H)
    return #threadControlBlock
end 
-- RETURNS: Handle's coroutine 
local function getCoroutine( H )
    return H[TH_EXECUTABLE_IMAGE]
end
-- RETURNS: result
local function checkIfHandleDataValid( H )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        assert(#H == TH_NUM_ELEMENTS, L["HANDLE_INVALID_TABLE_SIZE"] )
        assert( type(H) == "table", L["HANDLE_NOT_TABLE"])
        assert( H[TH_EXECUTABLE_IMAGE] ~= nil, L["HANDLE_COROUTINE_NIL"] )
        assert( type(H[TH_EXECUTABLE_IMAGE]) == "thread", L["INVALID_COROUTINE_TYPE"] )
    else
        if type(H[TH_EXECUTABLE_IMAGE]) ~= "thread" then
            result = setResult(L["INVALID_TYPE"] .. " Expected type == 'thread'", debugstack(2))
            return result
        end
        if type(H) ~= "table" then
            result = setResult(L["HANDLE_NOT_TABLE"], debugstack(2) )
            return result
        end        
        if #H ~= TH_NUM_ELEMENTS then
            result = setResult(L["HANDLE_INVALID_TABLE_SIZE"], debugstack(2) )
            return result
        end
        for i = 1, TH_NUM_ELEMENTS do
            if H[i] == nil then
                local s = sprintf("H[%d] is nil.", i)
                result = setResult( s, debugstack(2) )
                return result
            end
        end
    end
    return result        
end
local function signalValueIsValid( signal )
    local isValid = false

    if signal >= SIG_ALERT then
        if signal <= SIG_NONE_PENDING then
            isValid = true
        end
    end
    return isValid
end
-- RETURNS: result
local function validateSignal( signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        assert( signal ~= nil, sprintf("%s\n    %s\n", L["INPUT_PARM_NIL"], debugstack(2) ))
        assert( type(signal) == "number",L["INVALID_TYPE"])
        assert( signalValueIsValid(signal), L["SIGNAL_OUT_OF_RANGE"])
        return result
    else
        -- validate the signal
        if signal == nil then
            result = setResult(L["INPUT_PARM_NIL"], debugstack(2))
            return result
        end
        if type( signal ) ~= "number" then
            result = setResult(L["INVALID_TYPE"], debugstack(2) )
            return result
        end

        if not signalIsValid( signal ) then
            result = setResult( L["SIGNAL_OUT_OF_RANGE"], debugstack(2) )
        end
    end

    return result
end
-- RETURNS: partial handle, result
local function validateThreadHandle( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        if thread_h == nil then
            result = setResult("Thread handle was nil", debugstack(2))
            return result
        end
        assert( thread_h ~= nil, L["HANDLE_NIL"])
    else
        if thread_h == nil then
            local errMsg = sprintf("Input thread handle nil - %s\n", L["HANDLE_NIL"])
            result = setResult(L["HANDLE_NIL"], debugstack(2) )
            return result
        end 
    end 
    -- validate the thread handle's elements
    result = checkIfHandleDataValid( thread_h )
    if not result[1] then return result end
   
    return result
end
local function validateThreadCreateParms( ticks, func )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 

    if ticks == nil then
        local errMsg = sprintf("[thread:create()] %s - ticks not specified.\n", L["INPUT_PARM_NIL"])
        result = setResult( errMsg, debugstack(2))

    elseif type( ticks ) ~= "number" then
        local errMsg = sprintf("[thread:create()] %s - ticks not a number.\n", L["INVALID_TYPE"])
        result = setResult( errMsg, debugstack(2))
    
    elseif func == nil then
        local errMsg = sprintf("[thread:create()] %s - function not specified.\n", L["INPUT_PARM_NIL"])
        result = setResult( errMsg, debugstack(2))
    
    elseif type(func) ~= "function" then
        local errMsg = sprintf("[thread:create()] %s - Parameter 2 not a function.\n", L["INVALID_TYPE"])
        result = setResult( errMsg, debugstack(2))
    end    
    return result
end
local function validateResult( result )
    if debuggingIsEnabled() then 
        assert( result ~= nil, "ASSERT FAILURE: 'result' parameter was nil")
        assert( type( result ) == "table", "ASSERT FAILURE: Expected type 'table', got %s", type( result ))
        assert( #result == 3, "ASSERT FAILURE: Expected table size 3, got %d", #result )
        assert( type(result[2]) == "string", "ASSERT FAILURE: result[2] not a string")
        assert( type(result[3]) == "string", "ASSERT FAILURE: result[3] not a string")
    end
end
local function setResult( errMsg, stackTrace )
    assert( errMsg ~= nil, "ASSERT FAILURE: input error message was nil")
    assert( stackTrace ~= nil, "ASSERT FAILURE: input stack trace was nil")
    assert( type( errMsg) == "string", "ASSERT FAILURE: Param 1 - Bad type. Expected string")
    assert( type( stackTrace) == "string", "ASSERT FAILURE: Param 2 - Bad type. Expected string")

    local prefix = dbgPrefix( stackTrace )
	local errMsg = sprintf("[%s] %s\n STACK TRACE:\n", prefix, errMsg )

    local result = {FAILURE, errMsg, stackTrace  }
	return result
end

local function createHandle( durationTicks, func )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

    local H = {}
    if durationTicks < DEFAULT_YIELD_TICKS then
        durationTicks = DEFAULT_YIELD_TICKS
    end

    THREAD_SEQUENCE_NUMBER = THREAD_SEQUENCE_NUMBER + 1

    H[TH_EXECUTABLE_IMAGE]      = coroutine.create( func )
    H[TH_SEQUENCE_ID]           = THREAD_SEQUENCE_NUMBER
    H[TH_SIGNAL_QUEUE]          = {}
    H[TH_REMAINING_TICKS]       = 1
    H[TH_TICKS_PER_YIELD]       = durationTicks
    -- H[TH_JOIN_DATA]             = EMPTY_STR
    -- H[TH_JOIN_QUEUE]            = {}
    H[TH_CHILDREN]              = {}
    H[TH_PARENT]                = EMPTY_STR
    H[TH_ADDON_NAME]            = getAddonName()
    H[TH_EXECUTION_STATE]       = EMPTY_STR
    
    -- Metrics
    H[TH_TIMESTAMP]             = debugprofilestop()
    H[TH_CREATION_TIME]         = H[TH_TIMESTAMP]
    H[TH_CURRENT_LIFETIME]      = H[TH_CREATION_TIME]
    H[TH_ACCUM_RUNTIME]         = 0
    H[TH_ACCUM_SUSPEND_TIME]    = 0

    local parent_h, parentId = getRunningHandle() 
    if parent_h ~= nil then
        -- this call is being executed by a WoW Thread. Therefore,
        -- the running thread is the parent and this handle will be 
        -- the child of the running thread.
        table.insert( parent_h[TH_CHILDREN], H )
        H[TH_PARENT] = parent_h
    end
    return H
end
-- DESCRIPTION: Create a new thread.
-- RETURNS: (handle) thread_h, result
function thread:create( ticks, func, ... )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 

    result = validateThreadCreateParms( ticks, func )
    if not result[1] then return nil, result end

    -- Create a handle with a suspended coroutine
    local H = createHandle( ticks, func )

    local co = getCoroutine( H )
    insertHandleIntoTCB(H)
    local resumed, val = coroutine.resume( co, ... )
    if not resumed then

        local threadId = H[TH_SEQUENCE_ID]
        local Id = threadId
        local addon = H[TH_ADDON_NAME]
        local threadState = coroutine.status( co )
        if threadState == "dead" then threadState = "failed" end

        for i, H in ipairs( threadControlBlock ) do  
            if threadId == H[TH_SEQUENCE_ID] then
                table.remove( threadControlBlock, i )
                table.insert( Morgue, H )
                local errorMsg = sprintf("%s thread[%d] failed to start. Inserted into Morgue ", dbgPrefix(), threadId, addon )
                print( dbgPrefix(), "val = " .. val )
                result = {FAILURE, errorMsg, val }
                return nil, result
            end
        end
    end
    return H, result
end 
-- DESCRIPTION: yields execution of the number of ticks specified in thread:create()
-- REQUIRES: thread context
-- RETURNS; void
function thread:yield()
    local H = getRunningHandle()
    yield(H)
end
function thread:delay( delayTicks )
    local H = getRunningHandle()
    H[TH_REMAINING_TICKS] = delayTicks
    yield(H)
end
-- DESCRIPTION: returns the thread numerical Id
-- REQUIRES: thread context
-- RETURNS: (number) threadId, result
function thread:getId( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local threadId = nil

    if thread_h == nil then
        _, threadId = getRunningHandle()
        return threadId, result
    else -- thread_h was not nil
        result = checkIfHandleDataValid( thread_h )
        if not result[1] then return nil, result end
    end
    if threadId == nil then
        threadId = getThreadId( thread_h )
    end
    return threadId, result
end
-- DESCRIPTION: Returns the handle of the calling thread.
-- REQUIRES: thread context
-- RETURNS: (handle) thread_h, (number) threadId
function thread:self()
    local self_h, selfId = getRunningHandle()
    return self_h, selfId
end
-- DESCRIPTION: determines whether two threads are the same
-- REQUIRES: WoW client or thread context
-- RETURNS: (boolean) true if equal, result
function thread:areEqual( H1, H2 )
    local areEqual = false
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = validateThreadHandle( H1 )
    if not result[1] then return nil, result end
    result = validateThreadHandle( H2 )
    if not result[1] then return nil, result end

    local H1Id = H1[TH_SEQUENCE_ID]
    local H2Id = H2[TH_SEQUENCE_ID]

    return H1Id == H2Id
end
-- DESCRIPTION: gets the specified thread's parent
-- REQUIRES: thread context
-- RETURNS: (handle) parent_h, result
function thread:getParent( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h == nil then
        thread_h = getRunningHandle()
    else
        result = checkIfHandleDataValid( thread_h ) 
        if not result[1] then 
            return nil, result 
        end
    end

    local parent_h = thread_h[TH_PARENT]
    return parent_h, result
end
-- DESCRIPTION: gets a table of the specified thread's children.
-- REQUIRES: thread context
-- RETURNS: (table) childThreads, result
function thread:getChildThreads( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local thread_h = nil
    local threadId = -1

    -- if thread_h is nil then this is equivalent to "getMyParent"
    if thread_h == nil then
        thread_h, threadId = getRunningHandle()
    else
        result = checkIfHandleDataValid( thread_h )
        if not result[1] then 
            return nil, result 
        end
    end

    local children, tableCount = getThreadChildren( thread_h )
    if tableCount == 0 then 
        children = nil 
    end
    return children, result
end 
-- DESCRIPTION: gets the specified thread's execution state. If nil, the
--      thread is currently executing and "running" is returned.
-- RETURNS: (string) state ( = "completed", "suspended", "queued", "failed", "running" ), result.
function thread:getState( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = validateThreadHandle( thread_h )
    if not result[1] then return nil, result end
            
    local state = getThreadState( thread_h )
    return state, result
end
-- DESCRIPTION: gets the string name of the specified signal
-- RETURNS: (string) signalName. result
function thread:getSignalName( signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = validateSignal( signal )
    if not result[1] then return nil, result end

    local signalName = getSignalName( signal )
    return signalName, result
end
-- DESCRIPTION: sends a signal to the specified thread. 
-- RETURNS: result 
function thread:sendSignal( thread_h, signal, data )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    if data == nil then data = EMPTY_STR end

    result = validateThreadHandle( thread_h )
    if not result[1] then return result, nil end
    
    result = validateSignal( signal )
    if not result[1] then return result, nil end

    local sender_h, senderId = getRunningHandle()
    local sigEntry = {signal, sender_h, data }
    table.insert( thread_h[TH_SIGNAL_QUEUE], sigEntry)

    if signal ~= SIG_NONE_PENDING then
        thread_h[TH_REMAINING_TICKS] = 1
    end

    return result
end
-- DESCRIPTION: retrieves a signal sent to the calling thread.
-- RETURNS: (number) signal, (handle) sender_h
function thread:getSignal()
    signal, sender_h = getSignal()
    local thread_h, threadId = getRunningHandle() 
    return signal, sender_h, data
end
function thread:prefix( stackTrace )
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
function thread:print( msg )
	local fileAndLine = thread:prefix( debugstack(2) )
	local str = msg
	if str then
		str = sprintf("%s %s", fileAndLine, str )
	else
		str = fileAndLine
	end
	DEFAULT_CHAT_FRAME:AddMessage( str, 0.0, 1.0, 1.0 )
end	
function thread:printx( ... )
	local prefix = thread:prefix( debugstack(2) )
    print( prefix, ... )
end	
function thread:postResult( result )
    validateResult( result )

    if result[2] == EMPTY_STR then
        assert( false, "ASSERT FAILURE: result[2] contains EMPTY_STR")
    end

    if result[3] == EMPTY_STR then
        assert( false ~= EMPTY_STR, "ASSERT FAILURE: result[3] contains EMPTY_STR")
    end

    if result == nil then
        result = setResult( "result parameter was nil - thread:postResult()", debugstack() )
        return result
    end

	if errorMsgFrame == nil then
		errorMsgFrame = createMsgFrame("Error Message")
	end

	local str = sprintf("%s %s\nStack Trace: %s\n", dbgPrefix(), result[2], result[3])
	errorMsgFrame.Text:Insert( str )
	errorMsgFrame:Show()
end
function thread:postMsg( msg )
    postInfo( msg )
end
function thread:enableDebugging()
    enableDebugging()
end
function thread:disableDebugging()
    disableDebugging()
end
function thread:debuggingIsEnabled()
    return debuggingIsEnabled()
end
function thread:enableDataCollection()
    enableDataCollection()
end
function thread:disableDataCollection()
    disableDataCollection()
end
function thread:dataCollectionIsEnabled()
    return dataCollectionIsEnabled()
end
------------------------- MANAGEMENT INTERFACE --------------------
function thread:mgmtGetAddonName( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local result = validateThreadHandle(thread_h)
    if not result[1] then return nil, result end

    return thread_h[TH_ADDON_NAME], result
end
-- RETURNS: table of metric entries were each entry is
--      entry = { threadId, addonName, runtime, suspendedTime, lifetime }
--      result:
function thread:mgmtGetMetricsByAddon( addonName )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    local threadId = nil
    local addonName = nil
    local runtime = nil
    local suspendedTime = nil
    local state = nil
    local lifetime = nil
    local threadTable = {}
    for _, H in ipairs( threadControlBlock ) do
        if addonName == H[TH_ADDON_NAME] then
            
            threadId      = H[TH_SEQUENCE_ID]
            addonName     = H[TH_ADDON_NAME]
            runtime       = H[TH_ACCUM_RUNTIME]
            suspendedTime = H[TH_ACCUM_SUSPEND_TIME]
            state = getThreadState( H )
            lifetime = H[TH_CURRENT_LIFETIME]
            if state ~= "completed" then
                lifetime = debugprofilestop() - H[TH_CREATION_TIME]
            end
            entry = { threadId, addonName, runtime, suspendedTime, lifetime }
            table.insert( threadTable, entry )
        end
    end    
    return threadTable, entry
end
-- RETURNS: entry = { threadId, addonName, runtime, suspendedTime, lifetime }
-- result
function thread:mgmtGetMetricsByThread( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local entry = nil

    result = validateThreadHandle( thread_h )
    if not result[1] then return nil, result end

    local threadId = nil
    local addonName = nil
    local runtime = nil
    local suspendedTime = nil
    local state = nil
    local lifetime = nil

    for _, H in ipairs( threadControlBlock ) do
        if thread_h[TH_SEQUENCE_ID] == H[TH_SEQUENCE_ID] then
            
            threadId      = H[TH_SEQUENCE_ID]
            addonName     = H[TH_ADDON_NAME]
            runtime       = H[TH_ACCUM_RUNTIME]
            suspendedTime = H[TH_ACCUM_SUSPEND_TIME]
            state = getThreadState( H )
            lifetime = H[TH_CURRENT_LIFETIME]
            if state ~= "completed" then
                lifetime = debugprofilestop() - H[TH_CREATION_TIME]
            end
        end
        local entry = { threadId, addonName, runtime, suspendedTime, lifetime }
        return entry, result
    end
end
-- RETURNS: table of metric entries for each thread in the TCB where each
--          entry = { threadId, addonName, runtime, suspendedTime, lifetime }
--          result:
function thread:mgmtGetThreadTable()
    local metricsTable = {}
    for _, H in ipairs( threadControlBlock) do
        local entry = thread:mgmtGetMetricsByThread(H)
        table.insert( metricsTable, entry)
    end
    return metricsTable
end
local WoWThreadsStarted = false
local function WoWThreadLibInit()
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if not WoWThreadsStarted then 
        local CLOCK_INTERVAL = (1/GetFramerate())
        result = startTimer( CLOCK_INTERVAL )
        if not result[1] then return result end
    end
    WoWThreadsStarted = true
    return result
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent( self, event, ... )
    local addonName = ...

    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
        local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

		result = WoWThreadLibInit()
        if not result[1] then postResult( result ) return end

        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_LOADED_MESSAGE"], 0.0, 1.0, 1.0 )
        DEFAULT_CHAT_FRAME:AddMessage( L["MS_PER_TICK"], 0.0, 1.0, 1.0 )
        eventFrame:UnregisterEvent("ADDON_LOADED")  
    end
    return
end
eventFrame:SetScript( "OnEvent", OnEvent )