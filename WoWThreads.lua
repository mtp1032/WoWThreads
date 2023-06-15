----------------------------------------------------------------------------------------
-- FILE NAME:		WoWThreads.Lua
-- ORIGINAL DATE:   14 March, 2023
----------------------------------------------------------------------------------------
-- local ADDON_NAME, _ = ...
local _, WoWThreads = ...

-- Initialize the library

local ADDON_NAME = "WoWThreads"
local libName = "WoWThreads-1.0"
local version = 1

local thread = LibStub:NewLibrary( libName, version)
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
local DATA_COLLECTION_ENABLED   = false
local DEFAULT_YIELD_TICKS       = 5
local threadSequenceNumber      = 5

local DEFAULT_FRAME_WIDTH   = 600
local DEFAULT_FRAME_HEIGHT  = 400

local errorMsgFrame = nil

local threadControlBlock = {}
local graveyard = {}
local signalNameTable       = { "SIG_ALERT", "SIG_JOIN_DATA_READY", "SIG_TERMINATE", "SIG_METRICS", "SIG_NONE_PENDING"}


local function getExpansionName()
	local expansionName = nil
	local expansionLevel = GetServerExpansionLevel()

	if expansionLevel == LE_EXPANSION_CLASSIC then
		expansionName = "Classic (Vanilla)"
	end
	if expansionLevel == LE_EXPANSION_WRATH_OF_THE_LICH_KING then
		expansionName = "Classic (WotLK)"
	end
	if expansionLevel == LE_EXPANSION_DRAGONFLIGHT then
		expansionName = "Dragon Flight"
	end

	if isValid == false then
		local errMsg = sprintf("Invalid Expansion Code, %d", expansionLevel )
		DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s", errMsg), 1.0, 1.0, 0.0 )
	end
	return expansionName
end

local addonVersion	= GetAddOnMetadata( ADDON_NAME, "Version")
local expansionName = getExpansionName()
local clockInterval	= 1/GetFramerate() * 1000
local msPerTick 	= sprintf("Clock interval: %0.01f milliseconds per tick.\n", clockInterval )

local LOCALE = GetLocale()
if LOCALE == "enUS" then

	-- WoWThreads Localizations
	L["ADDON_NAME"]				= ADDON_NAME
	L["VERSION"] 				= addonVersion
	L["EXPANSION"] 				= expansionName

	L["ADDON_NAME_AND_VERSION"] = sprintf("%s %s (%s)", L["ADDON_NAME"], L["VERSION"],L["EXPANSION"])
	L["ADDON_LOADED_MESSAGE"] 	= sprintf("%s loaded", L["ADDON_NAME_AND_VERSION"] )
	L["MS_PER_TICK"] 			= sprintf("Clock interval: %0.01f milliseconds per tick\n", clockInterval )

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
	L["HANDLE_INVALID_TABLE_SIZE"] 		= "[ERROR] Thread handle size invalid. "
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
local TH_EXECUTABLE_IMAGE   = 1   -- the coroutine created to execute the thread's function
local TH_SEQUENCE_ID        = 2   -- a number representing the order in which the thread was created 
local TH_SIGNAL_QUEUE       = 3   -- a table of all currently pending signals
local TH_TICKS_PER_YIELD    = 4   -- the time in clock ticks a thread is supendend after a yield
local TH_REMAINING_TICKS    = 5   -- decremented on every clock tick. When 0 the thread is queued.
local TH_YIELD_COUNT        = 6   -- the number of times the coroutine has been resumed by the dispatcher.
local TH_LIFETIME           = 7
local TH_ACCUM_YIELD_TIME   = 8
local TH_JOIN_DATA          = 9
local TH_JOIN_QUEUE         = 10
local TH_CHILD_THREADS      = 11
local TH_PARENT_THREAD      = 12
local TH_EXECUTION_STATE    = 13   -- running, suspended, waiting, completed

local TH_NUM_ELEMENTS       = TH_EXECUTION_STATE

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data.
-- the data element, for the moment is unused.
thread.SIG_ALERT           = 1
thread.SIG_JOIN_DATA_READY = 2
thread.SIG_TERMINATE       = 3
thread.SIG_METRICS         = 4
thread.SIG_NONE_PENDING    = 5

local SIG_ALERT           = thread.SIG_ALERT
local SIG_JOIN_DATA_READY = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE       = thread.TERMINATE
local SIG_METRICS         = thread.METRICS
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
            self:GetParent().Text:SetText("") 
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
            self:GetParent().Text:SetText("") 
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
local function createErrorMsgFrame(title)
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
	
    createResizeButton(f)
    createTextDisplay(f)
    createSelectButton(f, "BOTTOMRIGHT",f, 5, 5)
    createReloadButton(f, "BOTTOMLEFT",f, 5, 5)
    return f
end
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
local function setResult( errMsg, stackTrace )
	local result = { FAILURE, EMPTY_STR, EMPTY_STR }

	local msg = sprintf("%s %s:\n", dbgPrefix( stackTrace ), errMsg )
	result[2] = msg

	if stackTrace ~= nil then
		result[3] = stackTrace
	end
	return result
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

-- ***********************************************************************
-- *                               LOCAL FUNCTIONS                       *
-- ***********************************************************************
-- RETURNS: state - "completed", "running", "queued", "suspended"
local function getThreadState( H )
    local state = coroutine.status( H[TH_EXECUTABLE_IMAGE])

    if state == "dead" then 
        state = "completed" 
    end
    if state == "normal" then state = "queued" end
    return state
end
-- RETURNS: Handle metrics entry = { threadId, ticksPerYield, yieldCount, timeSuspended, lifetime }
local function convertHandleToEntry( H )

    local threadId         = H[TH_SEQUENCE_ID]
    local ticksPerYield    = H[TH_TICKS_PER_YIELD]
    local yieldCount       = H[TH_YIELD_COUNT]
    local timeSuspended    = H[TH_ACCUM_YIELD_TIME]
    local lifetime         = H[TH_LIFETIME]
	local congestion = (1 - (timeSuspended / lifetime))

    local entry = { threadId, ticksPerYield, yieldCount, timeSuspended, lifetime, congestion }
    return entry
end
-- RETURNS void
local function scheduleThreads()
    for i, H in ipairs( threadControlBlock ) do  
        
        -- remove any/all dead threads from the TCB and move
        -- them into the graveyard
        H[TH_EXECUTION_STATE] = getThreadState(H)

        if H[TH_EXECUTION_STATE] == "completed" then
            table.remove( threadControlBlock, i )
            table.insert( graveyard, H )
            if dataCollectionIsEnabled() then
                local lifetime = debugprofilestop() - H[TH_LIFETIME]
                H[TH_LIFETIME] = lifetime
            end
        elseif H[TH_EXECUTION_STATE] == "suspended" then

            -- decrement the remaining tick count. If equal
            -- to 0 then the coroutine will be resumed.
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] == 0 then

                -- replenish the remaining ticks counter and resume this thread.
                H[TH_REMAINING_TICKS] = H[TH_TICKS_PER_YIELD]

                -- NOTE: under some circumstataces a thread will
                -- complete and be signaled before we can set the thread's state. So, if
                -- we find a thread at this point in the loop through the TCB, we
                -- move the thread from the TCB to the graveyard.
                local wasResumed, retValue = coroutine.resume( H[TH_EXECUTABLE_IMAGE] )
                if not wasResumed then
                    local errMsg = sprintf("Thread[%d] faulted in the thread's function: Stack trace follows:\n%s\n", H[TH_SEQUENCE_ID], retValue )
                    print( errMsg )
                    local state = coroutine.status( H[TH_EXECUTABLE_IMAGE])
                    if state == "dead" then
                        -- remove from TCB
                        for i, h in ipairs( threadControlBlock ) do
                            if H[TH_SEQUENCE_ID] == h[TH_SEQUENCE_ID] then
                                table.remove( threadControlBlock, i )
                                table.insert( graveyard, H )
                                if dataCollectionIsEnabled() then
                                    local lifetime = debugprofilestop() - H[TH_LIFETIME]
                                    H[TH_LIFETIME] = lifetime
                                end
                            end
                        end
                    end
                end
            end 
        end
    end
end
-- RETURNS: a thread metric entry and the number of remaing threads in the graveyard.
local function getThreadMetrics( H )
    local entry = nil
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if #graveyard == 0 then 
        return nil, #graveyard, result 
    end

    local numInGrave = #graveyard
    for i = 1, numInGrave do
        local h = graveyard[i]
        if H[TH_SEQUENCE_ID] == h[TH_SEQUENCE_ID] then
            entry = convertHandleToEntry( H )
            wipe( H )
            return entry, #graveyard, result
        end
    end
    return entry, numInGrave, result
end
-- RETURNS: the parent thread of H. if H is a top level thread, then nil is returned
local function getThreadParent( H )
    local parent_h = nil

    if H[TH_PARENT_THREAD] ~= EMPTY_STR then
        parent_h = H[TH_PARENT_THREAD]
    end
    return parent_h
end
-- RETURNS: childTable, childCount. nil, 0 if no child threads
local function getThreadChildren( H )
    local childTable = nil
    local childCount = 0

    local childCount = #H[TH_CHILD_THREADS]
    if childCount ~= 0 then
        childTable = H[TH_CHILD_THREADS]
    end
    return childTable, childCount
end
-- RETURNS: void
local function startTimer( clockInterval )

    scheduleThreads()
   
    C_Timer.After( clockInterval, 
        function() 
            startTimer( clockInterval )
        end)
    return
end
local function checkRunningHandle(H, entryPoint )
    if H == nil then
        local errMsg = sprintf("%s (%s)", L["THREAD_INVALID_CONTEXT"], entryPoint )
        local result = setResult( errMsg, debugstack(1))
        thread:postResult( result )
        local n = nil
        n[1] = 1
    end
end
-- RETURNS: running thread, threadId. nil, -1 if thread not found.
local function getRunningHandle()
    local H = nil

    -- only one thread can be "running"
    for _, H in ipairs( threadControlBlock ) do
        local state = coroutine.status( H[TH_EXECUTABLE_IMAGE] )
        if state == "running" then
            return H, H[TH_SEQUENCE_ID]
        end
    end
    -- if we're here, it's because the WoW Client has issued
    -- this call. That's why there is not "running" thread
    -- in the TCB.
    return nil, -1
end
-- RETURNS: void
local function yield( H)

    local startTime = 0
    if dataCollectionIsEnabled() then
        startTime = debugprofilestop()
    end

    coroutine.yield()
        
    if dataCollectionIsEnabled() then
        local elapsedTime = debugprofilestop() - startTime
        H[TH_ACCUM_YIELD_TIME] = H[TH_ACCUM_YIELD_TIME] + elapsedTime
        H[TH_YIELD_COUNT] = H[TH_YIELD_COUNT] + 1
    end
end        
-- RETURNS: void
local function deliverSignal( H, signal )
    local sender_h = nil

    sender_h = getRunningHandle()
    checkRunningHandle(H, "deliverSignal")

    local sigEntry = {signal, sender_h, EMPTY_STR }

    if  signal == SIG_ALERT or 
        signal == SIG_TERMINATE or
        signal == SIG_JOIN_DATA_READY then
            H[TH_REMAINING_TICKS] = 1
    end

    table.insert( H[TH_SIGNAL_QUEUE], sigEntry )
end
-- RETURNS: signal name
local function getSignalName( signal )
    return signalNameTable[signal]
end
-- RETURNS: signal, sender_h (SIG_NONE_PENDING if thread's signal queue is empty.)
-- NOTE: signals are returned in the order they are received (FIFO)
local function getSignal()
    local signal = SIG_NONE_PENDING
    local sender_h = nil

    local H, threadId = getRunningHandle()
    local signalQueue = H[TH_SIGNAL_QUEUE]
    if #signalQueue == 0 then
        return signal, sender_h
    end

    if #signalQueue > 0 then
        local sigEntry = table.remove(H[TH_SIGNAL_QUEUE], 1 )
        signal = sigEntry[1]
        sender_h = sigEntry[2]
    end

    return signal, sender_h
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
-- RETURNS; true / false
local function inThreadContext()
    if H == nil then return false else return true end
end
-- RETURNS: result
local function handleIsNil( H )
    if H == nil then return true else return false end
end
-- RETURNS: result
local function checkIfHandleDataValid( H )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        assert(#H == TH_NUM_ELEMENTS, L["HANDLE_INVALID_TABLE_SIZE"])
        assert( type(H) == "table", L["HANDLE_NOT_TABLE"])
        assert( H[TH_EXECUTABLE_IMAGE] ~= nil, L["HANDLE_COROUTINE_NIL"] )
        assert( type(H[TH_EXECUTABLE_IMAGE]) == "thread", L["INVALID_COROUTINE_TYPE"] )
    else
        if type(H[TH_EXECUTABLE_IMAGE]) ~= "thread" then
            result = setResult(L["INVALID_TYPE"] .. " Expected type == 'thread'", debugstack(1))
            return result
        end
        if type(H) ~= "table" then
            result = setResult(L["HANDLE_NOT_TABLE"], debugstack(1) )
            return result
        end        
        if #H ~= TH_NUM_ELEMENTS then
            result = setResult(L["HANDLE_INVALID_TABLE_SIZE"], debugstack(1) )
            return result
        end
        for i = 1, TH_NUM_ELEMENTS do
            if H[i] == nil then
                local s = sprintf("H[%d] is nil.", i)
                result = setResult( s, debugstack(1) )
                return result
            end
        end
    end
    return result        
end
-- RETURNS: partial handle, result
local function createHandle( durationTicks, func )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR }
    local H = {}
    if durationTicks < DEFAULT_YIELD_TICKS then
        durationTicks = DEFAULT_YIELD_TICKS
    end
    threadSequenceNumber = threadSequenceNumber + 1

    H[TH_EXECUTABLE_IMAGE]  = coroutine.create( func )
    H[TH_SEQUENCE_ID]       = threadSequenceNumber
    H[TH_SIGNAL_QUEUE]      = {}
    H[TH_TICKS_PER_YIELD]   = durationTicks
    H[TH_REMAINING_TICKS]   = 1
    H[TH_YIELD_COUNT]       = 0
    H[TH_LIFETIME]          = debugprofilestop()
    H[TH_ACCUM_YIELD_TIME]  = 0
    H[TH_JOIN_DATA]         = EMPTY_STR
    H[TH_JOIN_QUEUE]        = {}
    H[TH_CHILD_THREADS]     = {}
    H[TH_PARENT_THREAD]     = EMPTY_STR
    H[TH_EXECUTION_STATE]   = EMPTY_STR

    local running_h, runningId = getRunningHandle() 
    if running_h ~= nil then

        -- this call is being executed by a WoW Thread. Therefore,
        -- the running thread is the parent and this handle will be 
        -- the child of the running thread.
        table.insert( running_h[TH_CHILD_THREADS], H )
        H[TH_PARENT_THREAD] = running_h
    end

    return H, result
end
local function validateThreadHandle( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        assert( thread_h ~= nil, L["HANDLE_NIL"])
    else
        if thread_h == nil then
            local errMsg = sprintf("Input thread handle nil - %s\n", L["HANDLE_NIL"])
            result = setResult(L["HANDLE_NIL"], debugstack(1) )
            return result
        end 
    end 
    -- validate the thread handle's elements
    result = checkIfHandleDataValid( thread_h )
    if not result[1] then return result end
   
    return result
end
-- DESCRIPTION:
-- RETURNS: result
local function validateThreadCreateParms( ticks, func )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 

    if ticks == nil then
        local errMsg = sprintf("%s - ticks not specified.\n", L["INPUT_PARM_NIL"])
        result = setResult( errMsg, debugstack(1))
    end
    if type( ticks ) ~= "number" then
        local errMsg = sprintf("%s - ticks not a number.\n", L["INVALID_TYPE"])
        result = setResult( errMsg, debugstack(1))
    end
    if func == nil then
        local errMsg = sprintf("%s - Thread function not specified.\n", L["INPUT_PARM_NIL"])
        result = setResult( errMsg, debugstack(1))
    end
    if type(func) ~= "function" then
        local errMsg = sprintf("%s - Parameter 2 not a function.\n", L["INVALID_TYPE"])
        result = setResult( errMsg, debugstack(1))
    end    
    return result
end
-- DESCRIPTION: Create a new thread.
-- RETURNS: (handle) thread_h, result
function thread:create( ticks, func, ... )
    local result = { SUCCESS, EMPTY_STR, EMPTY_STR } 
    result = validateThreadCreateParms( ticks, func )
    if not result[1] then return nil, result end

    -- Create a handle with a suspended coroutine
    local H, result = createHandle( ticks, func )
    if not result[1] then 
        dbgPrint()
        return nil, result 
    end

    local co = getCoroutine( H )
    insertHandleIntoTCB(H)
    local resumed, val = coroutine.resume( co, ... )
    if not resumed then
        dbgPrint()
        local threadId = getThreadId( H )
        local threadState = coroutine.status( co )
        local msg = sprintf("Thread[%d] %s: %s,\n%s\n", threadId, threadState, L["THREAD_RESUME_FAILED"], val)
        result = setResult( msg, debugstack(2) )
        return nil, result
    end
    assert( H ~= nil, "ASSERT FAILED")
    assert( result[1] == SUCCESS, sprintf( "%s: Expected 'true', got %s", "ASSERT_FAILED", tostring(result[1]) ))
    return H, result
end 
-- DESCRIPTION: yields execution of the number of ticks specified in thread:create()
-- RETURNS; void
function thread:yield()
    local H = getRunningHandle()
    checkRunningHandle(H, "thread:yield")
    yield(H)
end
function thread:delay( delayTicks )
    local H = getRunningHandle()
    checkRunningHandle(H, "thread:delay")

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
        thread_h, threadId = getRunningHandle()
        checkRunningHandle(thread_h, "thread:getId")
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
-- RETURNS: (handle) thread_h, (number) threadId
function thread:self()
    local self_h, selfId = getRunningHandle()
    checkRunningHandle(self_h, "thread:self")
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
        checkRunningHandle( thread_h, "thread:getParent")
    else
        result = checkIfHandleDataValid( thread_h ) 
        if not result[1] then 
            return nil, result 
        end
    end

    local parent_h = getThreadParent( thread_h )
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
        checkRunningHandle( thread_h, "thread:getChildThreads")
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
-- thread is currently executing and "running" is returned.
-- RETURNS: (string) state ( = "completed", "suspended", "queued", ), result.
function thread:getState( thread_h )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = validateThreadHandle( thread_h )
    if not result[1] then return nil, result end
            
    local state = getThreadState( thread_h )
    return state, result
end
-- RETURNS: result
local function validateSignal( signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    if debuggingIsEnabled() then
        assert( signal ~= nil, sprintf("%s\n    %s\n", L["INPUT_PARM_NIL"], debugstack(1) ))
        assert( type(signal) == "number",L["INVALID_TYPE"])
        assert( signal >= SIG_ALERT, L["SIGNAL_OUT_OF_RANGE"])
        assert( signal <= SIG_NONE_PENDING, L["SIGNAL_OUT_OF_RANGE"])
        return result
    else
        -- validate the signal
        if signal == nil then
            result = setResult(L["INPUT_PARM_NIL"], debugstack(1))
            return result
        end
        if type( signal ) ~= "number" then
            result = setResult(L["INVALID_TYPE"], debugstack(1) )
            return result
        end

        -- return signal <= SIG_ALERT  and signal >= SIG_NONE_PENDING
        if signal < SIG_ALERT and signal > SIG_NONE_PENDING then 
            result = setResult( L["SIGNAL_OUT_OF_RANGE"] )
            return isValid, result
        end
    end

    return result
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
-- RETURNS: result. 
function thread:sendSignal( thread_h, signal )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = validateThreadHandle( thread_h )
    if not result[1] then return result end
    
    result = validateSignal( signal )
    if not result[1] then return result end

    local state = getThreadState( thread_h )
    if state == "completed" then
        setResult(L["THREAD_ILLEGAL_OPERATION"], debugstack(1) )
        return result
    end
    
    -- everything is hunky dory
    deliverSignal( thread_h, signal )
    return result
end
-- DESCRIPTION: retrieves a signal sent to the calling thread.
-- RETURNS: (number) signal, (handle) sender_h
function thread:getSignal()
    signal, sender_h = getSignal()
    local thread_h, threadId = getRunningHandle() 
    checkRunningHandle( thread_h, "thread:getSignal")
    return signal, sender_h
end
function thread:getCongestionEntry( H )
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local count = 0
    local entry = nil
    result = validateThreadHandle(H)
    if not result[1] then return result end
    
    if not dataCollectionIsEnabled() then
        result = setResult( L["DATA_COLLECTION_NOT_ENABLED"], debugstack(1) )
        return nil, count, result
    end

    local entry, count, result = getThreadMetrics(H)
    if not result[1] then return nil, remainingEntries, result end
    return entry, count, result
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
function thread:setResult( errMsg, stackTrace )
	local result = { FAILURE, EMPTY_STR, EMPTY_STR }

	local msg = sprintf("%s %s:\n", thread:prefix( stackTrace ), errMsg )
	result[2] = msg

	if stackTrace ~= nil then
		result[3] = stackTrace
	end
	return result
end
function thread:postResult( result )
	if errorMsgFrame == nil then
		errorMsgFrame = createErrorMsgFrame("Error Message")
	end

	if result[1] ~= FAILURE then 
		return
	end

	local resultMsg = sprintf("%s:\n%s\n", result[2], result[3])
	errorMsgFrame.Text:Insert( resultMsg )
	errorMsgFrame:Show()
end
function thread:enableDebugging()
    enableDebugging()
end
function thread:disableDebugging()
    disableDebugging()
end
function thread:debuggingIsEnabled()
    debuggingIsEnabled()
end
local WoWThreadsStarted = false
local function WoWThreadLibInit()
    if not WoWThreadsStarted then 
        local clockInterval = (1/GetFramerate())
        startTimer( clockInterval )
        WoWThreadsStarted = true
    end
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent( self, event, ... )
    local addonName = ...

    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
        
		WoWThreadLibInit()

        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_LOADED_MESSAGE"], 0.0, 1.0, 1.0 )
        DEFAULT_CHAT_FRAME:AddMessage( L["MS_PER_TICK"], 0.0, 1.0, 1.0 )
        eventFrame:UnregisterEvent("ADDON_LOADED")  
    end
    return
end
eventFrame:SetScript( "OnEvent", OnEvent )
