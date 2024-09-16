mainFrame = CreateFrame("Frame", "TeleportSearchFrame", UIParent, "BaseBasicFrameTemplate")
mainFrame:SetSize(300, 360)
mainFrame:SetPoint("CENTER")
mainFrame:EnableMouse(true)
mainFrame:SetAlpha(0.9)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("SPELLS_CHANGED")
mainFrame:Hide()
tinsert(UISpecialFrames, "TeleportSearchFrame")

local mainFrameTexture = mainFrame:CreateTexture(nil, "BACKGROUND")
mainFrameTexture:SetTexture("Interface\\AddOns\\TeleportSearch\\Textures\\mft.tga")
mainFrameTexture:SetAllPoints(mainFrame)

local function createScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(280, 270)
    scrollFrame:SetPoint("TOP", 0, -80)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(260, 1)
    scrollChild:SetHeight(40)

    return scrollFrame, scrollChild
end

local function createSearchBox(parent)
    local searchBox = CreateFrame("EditBox", "TeleportSearchBox", parent, "SearchBoxTemplate")
    searchBox:SetSize(260, 10)
    searchBox:SetPoint("TOP", parent, "TOP", 0, -50)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")

    return searchBox
end

local function createSearchLabel(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 2)
    label:SetText("Search:")
    return label
end

scrollFrame, scrollChild = createScrollFrame(mainFrame)
searchBox = createSearchBox(mainFrame)

function createSpellButton(parent, spellID, index)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(260, 40)
    btn:SetPoint("TOP", 0, -40 * (index - 1))

    local spellIcon = btn:CreateTexture(nil, "ARTWORK")
    spellIcon:SetSize(36, 36)
    spellIcon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    spellIcon:SetTexture(spellInfo.iconID)

    local spellName = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellName:SetPoint("LEFT", spellIcon, "RIGHT", 10, 0)
    spellName:SetText(spellInfo.name)

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(spellIcon)
    cooldown:SetDrawEdge(true)

    local cooldownText = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownText:SetPoint("CENTER", cooldown, "CENTER", 0, 0)

    btn.cooldown = cooldown
    btn.cooldownText = cooldownText

    btn:RegisterForClicks("LeftButtonDown")
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("unit", "player")
    btn:SetAttribute("spell", spellID)

    updateCooldown(btn, spellID)

    return btn
end

function createToyButton(parent, toyID, index)
    local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyID)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(260, 40)
    btn:SetPoint("TOP", 0, -40 * (index - 1))

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    icon:SetTexture(toyIcon)

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetText(toyName)

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(true)

    local cooldownText = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownText:SetPoint("CENTER", cooldown, "CENTER", 0, 0)

    btn.cooldown = cooldown
    btn.cooldownText = cooldownText

    btn:RegisterForClicks("LeftButtonDown")
    btn:SetAttribute("type", "toy")
    btn:SetAttribute("toy", toyID)

    updateItemCooldown(btn, toyID)

    return btn
end

function createItemButton(parent, itemID, index)
    local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(260, 40)
    btn:SetPoint("TOP", 0, -40 * (index - 1))

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    icon:SetTexture(itemIcon)

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetText(itemName)

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(true)

    local cooldownText = cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownText:SetPoint("CENTER", cooldown, "CENTER", 0, 0)

    btn.cooldown = cooldown
    btn.cooldownText = cooldownText

    btn:RegisterForClicks("LeftButtonDown")
    btn:SetAttribute("type", "item")
    btn:SetAttribute("item", "item:" .. itemID)
    
    updateItemCooldown(btn, itemID)

    return btn
end


function updateCooldown(btn, spellID)
    local start, duration = C_Spell.GetSpellCooldown(spellID)
    if start and duration and duration > 0 then
        local endTime = start + duration
        local timeLeft = endTime - GetTime()
        btn.cooldown:SetCooldown(start, duration)
        btn.cooldownText:SetText(formatTime(timeLeft))
    else
        btn.cooldownText:SetText("")
    end
end

function updateItemCooldown(btn, itemID)
    local start, duration = GetItemCooldown(itemID)
    if start and duration and duration > 0 then
        local endTime = start + duration
        local timeLeft = endTime - GetTime()
        btn.cooldown:SetCooldown(start, duration)
        btn.cooldownText:SetText(formatTime(timeLeft))
    else
        btn.cooldownText:SetText("")
    end
end

minimapButton = CreateFrame("Button", "MyAddonMinimapButton", Minimap, "GameMenuButtonTemplate")
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetAlpha(1)
minimapButton:SetScale(1)
minimapButton:EnableMouse(true)
minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapButton.icon:SetSize(20, 20)
minimapButton:SetNormalTexture("Interface\\Icons\\Spell_nature_massteleport")
minimapButton.icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
minimapButton:SetPoint("CENTER", Minimap, "CENTER", 0, 0)

function minimapButton:UpdatePosition()
    local angle = math.rad(26)
    local x, y = math.cos(angle), math.sin(angle)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local minimapSize = Minimap:GetWidth()/2

    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x * minimapSize, y * minimapSize)
end


minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
            searchBox:SetFocus()
        end
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Teleport Search", 1, 1, 1)
    GameTooltip:AddLine("Click to search for a teleport.", nil, nil, nil, true)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

SLASH_TELEPORTSEARCH1 = '/ts'
SLASH_TELEPORTSEARCH2 = '/teleportsearch'

SlashCmdList["TELEPORTSEARCH"] = function(msg)
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        searchBox:SetFocus()
    end
end