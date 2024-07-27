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

local function updateTeleportDB()
    local filterText = searchBox:GetText():lower()
    local buttonIndex = 1

    clearScroll()

    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSpells do
            local spellType, ID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)

            if spellType == Enum.SpellBookItemType.Flyout then
                local _, _, numSlots, isKnown = GetFlyoutInfo(ID)

                if isKnown and (numSlots > 0) then
                    for k = 1, numSlots do
                        local spellID, _, isSlotKnown = GetFlyoutSlotInfo(ID, k)
                        local cooldownHours = millisToHour(getSpellCooldownMillis(spellID))

                        if spellID == 361584 then
                            createSpellButton(scrollChild, spellID, buttonIndex)
                            buttonIndex = buttonIndex + 1
                        end

                        if isSlotKnown and cooldownHours == 8 then
                            local name, _, _ = GetSpellInfo(spellID)
                            local description = GetSpellDescription(spellID):lower()

                            if (name:lower():find(filterText) or description:find(filterText)) then
                                createSpellButton(scrollChild, spellID, buttonIndex)
                                buttonIndex = buttonIndex + 1
                            end
                        end
                    end
                end
            end
        end
    end

    scrollChild:SetHeight(40 * buttonIndex)
end


searchBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        updateTeleportDB()
    end
end)
searchBox:SetScript("OnMouseDown", function(self)
    self:SetText("")
end)

mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "TeleportSearch" then
            updateTeleportDB()
            minimapButton:UpdatePosition()

            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitID = ...
        if unitID == "player" then
            
            mainFrame:Hide()
        end
    end
end)

mainFrame:SetScript("OnHide", function()
    clearSearchBox()
    updateTeleportDB()
end)