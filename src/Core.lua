StoneToysID = {}
spellIDs = {}
currentSeasonSpellIDs = {}
mapNames = {}

jainaLocketItemID = 52251

function isHearthstoneId(id)
    return id == 6948
end

function isMageFlyoutId(flyoutID)
    return flyoutID == 1 or flyoutID == 11
end

function addHearthstoneToysID()
    local bindLocation = GetBindLocation():lower()
    local hasHS = C_Container.PlayerHasHearthstone() ~= nil

    StoneToysID = {
        140192,
        110560,
    }

    if bindLocation and not hasHS then
        local i = 1
        local hsFound = false
        while i <= C_ToyBox.GetNumToys() and not hsFound do
            local toyID = C_ToyBox.GetToyFromIndex(i)
            if toyID then
                local _, spellID = GetItemSpell(toyID)
                if spellID then
                    local spellDescription = C_Spell.GetSpellDescription(spellID):lower()
                    if spellDescription and PlayerHasToy(toyID) and spellDescription:find(bindLocation) then
                        table.insert(StoneToysID, toyID)
                        hsFound = true
                    end
                end
            end
            i = i + 1
        end
    end
end

function formatTime(seconds)
    if seconds <= 0 then
        return ""
    elseif seconds < 3600 then
        return string.format("%d min", math.ceil(seconds / 60))
    else
        return string.format("%.1f h", seconds / 3600)
    end
end

local function millisToHour(millis)
    return math.floor(millis / 3600000)
end

local function getSpellCooldownMillis(spellID)
    local cooldown = GetSpellBaseCooldown(spellID)
    if cooldown == nil then
        cooldown = 0
    end
    return cooldown
end

local function checkMapNamesInDescription(description)
    local lowerDescription = description:lower()

    for _, mapName in ipairs(mapNames) do
        local lowerMapName = mapName:lower()

        if lowerDescription:find(lowerMapName) then
            return true
        end
    end

    return false
end

function isInArray(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

local function clearSearchBox()
    if searchBox then
        searchBox:SetText("")
    end
end

local function clearScroll()
    if scrollChild and scrollChild.GetChildren then
        local children = {scrollChild:GetChildren()}
        if children then
            for i = 1, #children do
                local child = children[i]
                child:Hide()
                child:SetParent(nil)
            end
        end
    end
end

local function storeMapNames()
    mapNames = {}
    for key, value in pairs(C_ChallengeMode.GetMapTable()) do
        name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(value)
        table.insert(mapNames, name)
    end
end

local function createItemSpellButtonByItemID(itemID, buttonIndex, filterText)
    local itemCount = GetItemCount(itemID)

    if itemCount > 0 then
        local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
        local _, spellID = GetItemSpell(itemID)
        if itemName and spellID then
            local spellDescription = C_Spell.GetSpellDescription(spellID):lower()
            if spellDescription and (itemName:lower():find(filterText) or spellDescription:find(filterText)) then
                createItemButton(scrollChild, itemID, buttonIndex)
                buttonIndex = buttonIndex + 1
            end
        end
    end

    return buttonIndex
end

local function updateTeleportDB()
    local filterText = searchBox:GetText():lower()
    local buttonIndex = 1
    spellIDs = {}
    currentSeasonSpellIDs = {}

    storeMapNames()
    addHearthstoneToysID()
    clearScroll()

    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        for j = 1, skillLineInfo.numSpellBookItems do
            local spellIndex = skillLineInfo.itemIndexOffset + j
            local spellType, ID = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)

            if spellType == Enum.SpellBookItemType.Flyout then
                local _, _, numSlots, isKnown = GetFlyoutInfo(ID)

                if isKnown and (numSlots > 0) then
                    for k = 1, numSlots do
                        local spellID, _, isSlotKnown = GetFlyoutSlotInfo(ID, k)
                        local cooldownHours = millisToHour(getSpellCooldownMillis(spellID))

                        if (isSlotKnown and cooldownHours == 8) or isMageFlyoutId(ID) then
                            local spellInfo = C_Spell.GetSpellInfo(spellID)
                            local description = C_Spell.GetSpellDescription(spellID):lower()

                            if IsSpellKnown(spellID) and (spellInfo.name:lower():find(filterText) or description:find(filterText)) then
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

    for i, spellID in ipairs(spellIDs) do
        createSpellButton(scrollChild, spellID, buttonIndex, isInArray(currentSeasonSpellIDs, spellID))
        buttonIndex = buttonIndex + 1
    end

    for i, toyID in ipairs(StoneToysID) do
        local _, toyName, icon = C_ToyBox.GetToyInfo(toyID)
        local _, spellID = GetItemSpell(toyID)
        if toyName and spellID then
            local spellDescription = C_Spell.GetSpellDescription(spellID):lower()
            if spellDescription and PlayerHasToy(toyID) and (toyName:lower():find(filterText) or spellDescription:find(filterText)) then
                createToyButton(scrollChild, toyID, buttonIndex)
                buttonIndex = buttonIndex + 1
            end
        end
    end

    local itemID = C_Container.PlayerHasHearthstone()
    if itemID then
        buttonIndex = createItemSpellButtonByItemID(itemID, buttonIndex, filterText)
    end

    createItemSpellButtonByItemID(jainaLocketItemID, buttonIndex, filterText)

    scrollChild:SetHeight(40 * buttonIndex)
end

searchBox:SetScript("OnTextChanged", function(self, userInput)
    SearchBoxTemplate_OnTextChanged(self)
    if userInput then
        updateTeleportDB()
    end
end)
searchBox:SetScript("OnMouseDown", function(self)
    self:SetText("")
end)
searchBox.clearButton:SetScript("OnClick", function(self)
    clearSearchBox()
    updateTeleportDB()
    SearchBoxTemplateClearButton_OnClick(self);
end)

mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "TeleportSearch" then
            minimapButton:UpdatePosition()

            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "SPELLS_CHANGED" then
        addHearthstoneToysID()
        updateTeleportDB()

        self:UnregisterEvent("SPELLS_CHANGED")
    end
end)

mainFrame:SetScript("OnShow", function()
    clearSearchBox()
    updateTeleportDB()
end)

mainFrame:SetScript("OnHide", function()
    clearSearchBox()
    updateTeleportDB()
end)
