local ADDON_NAME, TS = ...

------------------------------------------------------------------------------
-- Main window
------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "TeleportSearchFrame", UIParent, "BaseBasicFrameTemplate")
mainFrame:SetSize(300, 360)
mainFrame:SetPoint("CENTER")
mainFrame:EnableMouse(true)
mainFrame:SetAlpha(0.9)
mainFrame:SetMovable(true)
mainFrame:SetClampedToScreen(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide()
tinsert(UISpecialFrames, "TeleportSearchFrame")
TS.mainFrame = mainFrame

local background = mainFrame:CreateTexture(nil, "BACKGROUND")
background:SetTexture("Interface\\AddOns\\TeleportSearch\\Textures\\mft.tga")
background:SetAllPoints(mainFrame)

local seasonTitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
seasonTitle:SetPoint("TOP", mainFrame, "TOP", 0, -3)
seasonTitle:SetTextColor(1, 0.82, 0)

function TS.updateSeasonTitle()
    local currentSeason = C_MythicPlus.GetCurrentUIDisplaySeason() or 0
    if currentSeason > 0 then
        seasonTitle:SetText("Teleports - Season " .. currentSeason)
    else
        seasonTitle:SetText("Teleport Search")
    end
end
TS.updateSeasonTitle()

------------------------------------------------------------------------------
-- Search box and scroll area
------------------------------------------------------------------------------
local searchBox = CreateFrame("EditBox", "TeleportSearchBox", mainFrame, "SearchBoxTemplate")
searchBox:SetSize(250, 20)
searchBox:SetPoint("TOP", mainFrame, "TOP", 0, -34)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("ChatFontNormal")
searchBox:HookScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)
TS.searchBox = searchBox

local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(280, 280)
scrollFrame:SetPoint("TOP", 0, -64)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollFrame:SetScrollChild(scrollChild)
scrollChild:SetSize(260, 40)
TS.scrollChild = scrollChild

------------------------------------------------------------------------------
-- Row buttons (pooled secure buttons, reused between searches)
------------------------------------------------------------------------------
TS.ROW_HEIGHT = 40

local ROW_HEIGHT = TS.ROW_HEIGHT
local buttonPool = {}

local function formatTime(seconds)
    if seconds <= 0 then
        return ""
    elseif seconds < 3600 then
        return string.format("%d min", math.ceil(seconds / 60))
    else
        return string.format("%.1f h", seconds / 3600)
    end
end

local function updateSpellCooldown(btn, spellID)
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if cooldownInfo and cooldownInfo.duration and cooldownInfo.duration > 0 then
        btn.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
        btn.cooldownText:SetText(formatTime(cooldownInfo.startTime + cooldownInfo.duration - GetTime()))
    else
        btn.cooldown:Clear()
        btn.cooldownText:SetText("")
    end
end

local function updateItemCooldown(btn, itemID)
    local startTime, duration = C_Container.GetItemCooldown(itemID)
    if startTime and duration and duration > 0 then
        btn.cooldown:SetCooldown(startTime, duration)
        btn.cooldownText:SetText(formatTime(startTime + duration - GetTime()))
    else
        btn.cooldown:Clear()
        btn.cooldownText:SetText("")
    end
end

local function createRow(index)
    local btn = CreateFrame("Button", nil, scrollChild, "SecureActionButtonTemplate")
    btn:SetSize(260, ROW_HEIGHT)
    btn:SetPoint("TOP", 0, -ROW_HEIGHT * (index - 1))
    -- Secure buttons only react to the click edge selected by the
    -- "ActionButtonUseKeyDown" CVar. Registering both down and up makes the
    -- button work for every user setting (the action still fires only once).
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("unit", "player")

    btn.stripe = btn:CreateTexture(nil, "BACKGROUND")
    btn.stripe:SetAllPoints(btn)
    btn.stripe:SetColorTexture(1, 1, 1, 0.04)
    btn.stripe:SetShown(index % 2 == 0)

    btn.seasonBar = btn:CreateTexture(nil, "BORDER")
    btn.seasonBar:SetPoint("TOPLEFT", 1, -3)
    btn.seasonBar:SetPoint("BOTTOMLEFT", 1, 3)
    btn.seasonBar:SetWidth(3)
    btn.seasonBar:SetColorTexture(1, 0.82, 0, 0.9)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(32, 32)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.name:SetPoint("LEFT", btn.icon, "RIGHT", 10, 0)
    btn.name:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.name:SetJustifyH("LEFT")
    btn.name:SetWordWrap(false)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(true)

    btn.cooldownText = btn.cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.cooldownText:SetPoint("CENTER", btn.cooldown, "CENTER", 0, 0)

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipSpellID then
            GameTooltip:SetSpellByID(self.tooltipSpellID)
        elseif self.tooltipToyID then
            GameTooltip:SetToyByItemID(self.tooltipToyID)
        elseif self.tooltipItemID then
            GameTooltip:SetItemByID(self.tooltipItemID)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    return btn
end

local function acquireRow(index)
    local btn = buttonPool[index]
    if not btn then
        btn = createRow(index)
        buttonPool[index] = btn
    end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("toy", nil)
    btn:SetAttribute("item", nil)
    btn.tooltipSpellID = nil
    btn.tooltipToyID = nil
    btn.tooltipItemID = nil
    btn.seasonBar:Hide()
    btn.name:SetTextColor(1, 1, 1)
    btn:Show()
    return btn
end

function TS.hideAllRows()
    for _, btn in ipairs(buttonPool) do
        btn:Hide()
    end
end

function TS.createSpellButton(spellID, index, isCurrentSeason)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        return
    end
    local btn = acquireRow(index)
    btn.icon:SetTexture(spellInfo.iconID)
    btn.name:SetText(spellInfo.name)
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", spellID)
    btn.tooltipSpellID = spellID
    if isCurrentSeason then
        btn.name:SetTextColor(1, 0.82, 0)
        btn.seasonBar:Show()
    end
    updateSpellCooldown(btn, spellID)
end

function TS.createToyButton(toyID, index)
    local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyID)
    local btn = acquireRow(index)
    btn.icon:SetTexture(toyIcon)
    btn.name:SetText(toyName)
    btn:SetAttribute("type", "toy")
    btn:SetAttribute("toy", toyID)
    btn.tooltipToyID = toyID
    updateItemCooldown(btn, toyID)
end

function TS.createItemButton(itemID, index)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
    local btn = acquireRow(index)
    btn.icon:SetTexture(itemIcon)
    btn.name:SetText(itemName)
    btn:SetAttribute("type", "item")
    btn:SetAttribute("item", "item:" .. itemID)
    btn.tooltipItemID = itemID
    updateItemCooldown(btn, itemID)
end

------------------------------------------------------------------------------
-- Toggle (combat safe)
------------------------------------------------------------------------------
function TS.toggleFrame()
    if InCombatLockdown() then
        if TS.showAfterCombat then
            TS.showAfterCombat = nil
            print("|cff69ccf0Teleport Search|r: opening after combat cancelled.")
        else
            TS.showAfterCombat = true
            print("|cff69ccf0Teleport Search|r: teleports can't be used in combat. The window will open when combat ends.")
        end
        return
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        searchBox:SetFocus()
    end
end

------------------------------------------------------------------------------
-- Minimap button (round, draggable around the minimap)
------------------------------------------------------------------------------
local minimapButton = CreateFrame("Button", "TeleportSearchMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
TS.minimapButton = minimapButton

local mbOverlay = minimapButton:CreateTexture(nil, "OVERLAY")
mbOverlay:SetSize(53, 53)
mbOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbOverlay:SetPoint("TOPLEFT")

local mbBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
mbBackground:SetSize(20, 20)
mbBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mbBackground:SetPoint("TOPLEFT", 7, -5)

local mbIcon = minimapButton:CreateTexture(nil, "ARTWORK")
mbIcon:SetSize(18, 18)
mbIcon:SetTexture("Interface\\Icons\\Spell_nature_massteleport")
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)

function minimapButton:UpdatePosition()
    local angle = math.rad((TeleportSearchDB and TeleportSearchDB.minimapAngle) or 26)
    local radius = (Minimap:GetWidth() / 2) + 5
    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end
minimapButton:UpdatePosition()

minimapButton:SetScript("OnDragStart", function(self)
    TeleportSearchDB = TeleportSearchDB or {}
    self:SetScript("OnUpdate", function(updateSelf)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        TeleportSearchDB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        updateSelf:UpdatePosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
    TS.toggleFrame()
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Teleport Search", 1, 1, 1)
    GameTooltip:AddLine("Click to search for a teleport.", nil, nil, nil, true)
    GameTooltip:AddLine("Drag to move this button.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", GameTooltip_Hide)

------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------
SLASH_TELEPORTSEARCH1 = "/ts"
SLASH_TELEPORTSEARCH2 = "/teleportsearch"

SlashCmdList["TELEPORTSEARCH"] = function()
    TS.toggleFrame()
end
