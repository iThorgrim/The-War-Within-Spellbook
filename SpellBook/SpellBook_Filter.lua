SpellBook_SpellFilter = {}

--[[
 * Initializes the SpellFilter module
 *
 * @return void
--]]
function SpellBook_SpellFilter:Initialize()
    -- Nothing to initialize currently
end
SpellBook_SpellFilter:Initialize()

--[[
 * Checks if a spell matches search criteria
 *
 * @param spellIndex number The index of the spell
 * @param bookType string The type of spellbook
 * @param searchText string The text to search for
 * @param allRanksMode boolean Whether to include all ranks
 * @return boolean Whether the spell matches search criteria
--]]
function SpellBook_SpellFilter:SpellMatchesSearch(spellIndex, bookType, searchText, allRanksMode)
    -- If no search text, everything matches
    if not searchText or searchText:trim() == "" then
        return true
    end

    -- Normalize search text
    local normalizedSearch = SpellBook_Util:NormalizeText(searchText)

    -- Get spell information
    local spellName, spellRank = GetSpellName(spellIndex, bookType)
    local spellDescription = SpellBook_Util:GetSpellDescription(spellIndex, bookType)

    -- Normalize spell information for comparison
    local normalizedName = SpellBook_Util:NormalizeText(spellName)
    local normalizedRank = SpellBook_Util:NormalizeText(spellRank or "")
    local normalizedDescription = SpellBook_Util:NormalizeText(spellDescription)

    -- If not showing all ranks, check if this is the max rank
    if not allRanksMode then
        local maxRank = SpellBook_Util:GetMaxSpellRank(spellName)
        local currentRank = tonumber(spellRank and spellRank:match("%d+") or "0") or 0

        if currentRank < maxRank then
            return false
        end
    end

    -- Check if search text matches any part of the spell info
    return normalizedName:find(normalizedSearch, 1, true) or
            normalizedRank:find(normalizedSearch, 1, true) or
            normalizedDescription:find(normalizedSearch, 1, true)
end

--[[
 * Filters spells by search text
 *
 * @param searchText string The text to search for
 * @param allRanksMode boolean Whether to include all ranks
 * @return table The filtered spell data
--]]
function SpellBook_SpellFilter:FilterSpellsBySearch(searchText, allRanksMode)
    -- Update global search text
    SpellBook.Config.searchText = searchText or ""

    local spellData = {}
    local addedSpells = {}

    -- Iterate through all spell tabs
    for tab = 1, GetNumSpellTabs() do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)

        -- Create a section for this tab
        local tabSpells = {
            header = { templateKey = "Header", text = name },
            elements = {}
        }

        -- Add spells from this tab that match the search
        for spell = offset + 1, offset + numSpells do
            if self:SpellMatchesSearch(spell, BOOKTYPE_SPELL, searchText, allRanksMode) then
                local spellName = GetSpellName(spell, BOOKTYPE_SPELL)

                -- Avoid duplicates
                if not addedSpells[spellName] then
                    table.insert(tabSpells.elements, {
                        templateKey = "Sort",
                        spellIndex = spell,
                        bookType = BOOKTYPE_SPELL
                    })
                    addedSpells[spellName] = true
                end
            end
        end

        -- Only add tabs that have matching spells
        if #tabSpells.elements > 0 then
            table.insert(spellData, tabSpells)
        end
    end

    return spellData
end

--[[
 * Filters all spells based on current settings
 * Used to populate the initial spell book view
 *
 * @return table The filtered spell data
--]]
function SpellBook_SpellFilter:FilterAllSpells()
    local spellData = {}
    local addedSpells = {}
    local showAllRanks = SpellBook.Config.showAllRanks

    -- Iterate through all spell tabs
    for tab = 1, GetNumSpellTabs() do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)

        -- Create a section for this tab
        local tabSpells = {
            header = { templateKey = "Header", text = name },
            elements = {}
        }

        -- Process spells in this tab
        for spell = offset + 1, offset + numSpells do
            local spellName, spellRank = GetSpellName(spell, BOOKTYPE_SPELL)

            if spellName then
                -- Convert rank to number
                local rankNumber = tonumber(spellRank and spellRank:match("%d+") or "0") or 0
                local maxRank = SpellBook_Util:GetMaxSpellRank(spellName)

                -- Determine if this spell should be added
                local shouldAddSpell = false

                if showAllRanks then
                    -- Show all ranks
                    shouldAddSpell = true
                else
                    -- Show only max rank
                    shouldAddSpell = (rankNumber == maxRank)
                end

                -- Avoid duplicates with a unique key
                local uniqueKey = spellName .. (showAllRanks and spellRank or "")
                if shouldAddSpell and not addedSpells[uniqueKey] then
                    table.insert(tabSpells.elements, {
                        templateKey = "Sort",
                        spellIndex = spell,
                        bookType = BOOKTYPE_SPELL
                    })
                    addedSpells[uniqueKey] = true
                end
            end
        end

        -- Only add tabs that have spells
        if #tabSpells.elements > 0 then
            table.insert(spellData, tabSpells)
        end
    end

    return spellData
end