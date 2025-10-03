-- MinimapIcon.lua

local addonName = WoWThreads.Core:getAddonInfo()
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local AceConsole = LibStub("AceConsole-3.0")
local utils = WoWThreads.UtilsLib
local options = WoWThreads.OptionsPanel

-- Version for debugging
local ADDON_VERSION = "1.6.0"

-- Saved variables for minimap icon
local minimapDB = {
    hide = false,
    minimapPos = 120, -- Default to 4:00 (120°, clockwise from 12:00 = 0°)
    lock = false,
}

-- LDB data object for the minimap icon
local dataObject = LDB:NewDataObject(addonName, {
    type = "launcher",
    icon = 3528459, -- Your icon texture
    OnClick = function(self, button)
        if button == "LeftButton" then
            if options then
                options:showOptionsPanel()
                -- -- utils:dbgPrint(addonName .. ": MinimapButton left-clicked - toggling options panel")
            else
                -- -- utils:dbgPrint(addonName .. ": Options panel not found!")
            end
        elseif button == "RightButton" then
            -- -- utils:dbgPrint(addonName .. ": Right-clicked minimap icon")
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText(addonName)
        tooltip:AddLine("Left-click: Toggle Options Panel\nRight-click and drag: Move icon", nil, nil, nil, true)
        tooltip:Show()
    end,
})

-- Initialize the minimap icon
local function InitializeMinimapIcon()
    -- Load or initialize saved variables
    WOWTHREADS_MINIMAP_DB = WOWTHREADS_MINIMAP_DB or minimapDB
    -- utils:postMsg(addonName .. ": WOWTHREADS_MINIMAP_DB initialized - minimapPos: " .. tostring(WOWTHREADS_MINIMAP_DB.minimapPos))

    -- Register with LibDBIcon
    LDBIcon:Register(addonName, dataObject, WOWTHREADS_MINIMAP_DB)
    -- -- utils:dbgPrint(addonName .. ": Minimap icon registered with LibDBIcon-1.0, version " .. ADDON_VERSION)

    -- Log minimap center and dimensions
    local minimapX, minimapY = Minimap:GetCenter()
    -- utils:postMsg(addonName .. ": Minimap center - x: " .. minimapX .. ", y: " .. minimapY .. ", width: " .. Minimap:GetWidth() .. ", height: " .. Minimap:GetHeight())
end

-- Reset command
AceConsole:RegisterChatCommand("wtreset", function()
    WOWTHREADS_MINIMAP_DB = minimapDB
    LDBIcon:Refresh(addonName, WOWTHREADS_MINIMAP_DB)
    -- utils:postMsg(addonName .. ": Minimap position reset to default - minimapPos: 120")
end)

-- Initialize on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- -- utils:dbgPrint(addonName .. ": PLAYER_LOGIN event fired")
        InitializeMinimapIcon()
        -- utils:dbgPrint(addonName .. ": MinimapButton initialized via PLAYER_LOGIN")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
return WoWThreads.MinimapIcon