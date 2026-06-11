local ADDON_NAME, TS = ...

local mainFrame = TS.mainFrame
local searchBox = TS.searchBox
local scrollChild = TS.scrollChild

local stoneToysID = {}
local mapNames = {}
local wasShownBeforeCombat = false

local JAINA_LOCKET_ITEM_ID = 52251
local MAGE_FLYOUTS = { [1] = true, [11] = true }

local function isMageFlyoutId(flyoutID)
    return MAGE_FLYOUTS[flyoutID] or false
end

local function addHearthstoneToysID()
    local bindLocation = GetBindLocation():lower()
    local hasHS = C_Container.PlayerHasHearthstone() ~= nil

    stoneToysID = {
        140192, -- Dalaran Hearthstone
        110560, -- Garrison Hearthstone
    }

    if bindLocation and not hasHS then
        local i = 1
        local hsFound = false
        while i <= C_ToyBox.GetNumToys() and not hsFound do
            local toyID = C_ToyBox.GetToyFromIndex(i)
            if toyID then
                local _, spellID = GetItemSpell(toyID)
                if spellID then
                    local spellDescription = C_Spell.GetSpellDescription(spellID)
                    if spellDescription and PlayerHasToy(toyID) and spellDescription:lower():find(bindLocation, 1, true) then
                        table.insert(stoneToysID, toyID)
                        hsFound = true
                    end
                end
            end
            i = i + 1
        end
    end
end

local function millisToHour(millis)
    return math.floor(millis / 3600000)
end

local function getSpellCooldownMillis(spellID)
    return GetSpellBaseCooldown(spellID) or 0
end

local function checkMapNamesInDescription(description)
    local lowerDescription = string.gsub(description:lower(), "-", "")

    for _, mapName in ipairs(mapNames) do
        local lowerMapName = mapName:lower()
        local dashIndex = string.find(lowerMapName, "-")
        if dashIndex then
            lowerMapName = string.sub(lowerMapName, 1, dashIndex - 2)
        end

        if lowerDescription:find(lowerMapName, 1, true) then
            return true
        end
    end

    return false
end

local function isInArray(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

local function storeMapNames()
    mapNames = {}
    for _, mapID in pairs(C_ChallengeMode.GetMapTable()) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then
            table.insert(mapNames, name)
        end
    end
end

local function createItemSpellButtonByItemID(itemID, buttonIndex, filterText)
    if GetItemCount(itemID) > 0 then
        local itemName = GetItemInfo(itemID)
        local _, spellID = GetItemSpell(itemID)
        if itemName and spellID then
            local spellDescription = C_Spell.GetSpellDescription(spellID)
            if spellDescription and (itemName:lower():find(filterText, 1, true) or spellDescription:lower():find(filterText, 1, true)) then
                TS.createItemButton(itemID, buttonIndex)
                buttonIndex = buttonIndex + 1
            end
        end
    end

    return buttonIndex
end

local function updateTeleportDB()
    if InCombatLockdown() then
        return
    end

    local filterText = searchBox:GetText():lower()
    local buttonIndex = 1
    local spellIDs = {}
    local currentSeasonSpellIDs = {}

    storeMapNames()
    addHearthstoneToysID()
    TS.hideAllRows()

    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        for j = 1, skillLineInfo.numSpellBookItems do
            local spellIndex = skillLineInfo.itemIndexOffset + j
            local spellType, ID = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)

            if spellType == Enum.SpellBookItemType.Flyout then
                local _, _, numSlots, isKnown = GetFlyoutInfo(ID)

                if isKnown and numSlots > 0 then
                    for k = 1, numSlots do
                        local spellID, _, isSlotKnown = GetFlyoutSlotInfo(ID, k)
                        local cooldownHours = millisToHour(getSpellCooldownMillis(spellID))

                        if (isSlotKnown and cooldownHours == 8) or isMageFlyoutId(ID) then
                            local spellInfo = C_Spell.GetSpellInfo(spellID)
                            local description = string.gsub(C_Spell.GetSpellDescription(spellID):lower(), "-", "")
                            if spellInfo and IsSpellKnown(spellID)
                                and (spellInfo.name:lower():find(filterText, 1, true) or description:find(filterText, 1, true)) then
                                if checkMapNamesInDescription(description) then
                                    table.insert(spellIDs, 1, spellID)
                                    table.insert(currentSeasonSpellIDs, spellID)
                                else
                                    table.insert(spellIDs, spellID)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, spellID in ipairs(spellIDs) do
        TS.createSpellButton(spellID, buttonIndex, isInArray(currentSeasonSpellIDs, spellID))
        buttonIndex = buttonIndex + 1
    end

    for _, toyID in ipairs(stoneToysID) do
        local _, toyName = C_ToyBox.GetToyInfo(toyID)
        local _, spellID = GetItemSpell(toyID)
        if toyName and spellID then
            local spellDescription = C_Spell.GetSpellDescription(spellID)
            if spellDescription and PlayerHasToy(toyID)
                and (toyName:lower():find(filterText, 1, true) or spellDescription:lower():find(filterText, 1, true)) then
                TS.createToyButton(toyID, buttonIndex)
                buttonIndex = buttonIndex + 1
            end
        end
    end

    local hearthstoneItemID = C_Container.PlayerHasHearthstone()
    if hearthstoneItemID then
        buttonIndex = createItemSpellButtonByItemID(hearthstoneItemID, buttonIndex, filterText)
    end

    buttonIndex = createItemSpellButtonByItemID(JAINA_LOCKET_ITEM_ID, buttonIndex, filterText)

    scrollChild:SetHeight(math.max(TS.ROW_HEIGHT * (buttonIndex - 1), 1))
end

local function clearSearchBox()
    searchBox:SetText("")
end

searchBox:SetScript("OnTextChanged", function(self, userInput)
    SearchBoxTemplate_OnTextChanged(self)
    if userInput then
        updateTeleportDB()
    end
end)
searchBox.clearButton:SetScript("OnClick", function(self)
    clearSearchBox()
    updateTeleportDB()
    SearchBoxTemplateClearButton_OnClick(self)
end)

mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("SPELLS_CHANGED")
mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            TeleportSearchDB = TeleportSearchDB or {}
            TS.minimapButton:UpdatePosition()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "SPELLS_CHANGED" then
        if self:IsShown() then
            updateTeleportDB()
        end
        self:UnregisterEvent("SPELLS_CHANGED")
    elseif event == "PLAYER_REGEN_DISABLED" then
        if self:IsShown() then
            wasShownBeforeCombat = true
            self:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if wasShownBeforeCombat or TS.showAfterCombat then
            wasShownBeforeCombat = false
            TS.showAfterCombat = nil
            self:Show()
        end
    end
end)

mainFrame:SetScript("OnShow", function()
    clearSearchBox()
    updateTeleportDB()
    TS.updateSeasonTitle()
end)

mainFrame:SetScript("OnHide", function()
    clearSearchBox()
end)
