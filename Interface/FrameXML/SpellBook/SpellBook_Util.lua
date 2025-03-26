SpellBook_Util = {}

--[[
 * Initializes the Utility module
 *
 * @return void
--]]
function SpellBook_Util:Initialize()
    -- Set up accent mapping for text normalization
    self.accentMap = {
        ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a',
        ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e',
        ['î'] = 'i', ['ï'] = 'i',
        ['ô'] = 'o', ['ö'] = 'o',
        ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u',
        ['ç'] = 'c',
        ['ñ'] = 'n'
    }
end
SpellBook_Util:Initialize()

--[[
 * Normalizes text by removing accents and converting to lowercase
 * Used for search functionality to make it accent-insensitive
 *
 * @param text string The text to normalize
 * @return string The normalized text
--]]
function SpellBook_Util:NormalizeText(text)
    if not text then return "" end

    text = string.lower(text)
    return text:gsub('[àâäéèêëîïôöùûüçñ]', self.accentMap)
end

--[[
 * Gets a spell description using GameTooltip
 * Creates a temporary tooltip to extract spell description text
 *
 * @param spellIndex number The index of the spell
 * @param bookType string The type of spellbook (BOOKTYPE_SPELL, etc.)
 * @return string The spell description
--]]
function SpellBook_Util:GetSpellDescription(spellIndex, bookType)
    -- Create a temporary tooltip frame if it doesn't exist
    if not self.descriptionTooltip then
        self.descriptionTooltip = CreateFrame("GameTooltip", "SpellDescriptionTooltip", nil, "GameTooltipTemplate")
        self.descriptionTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    local tooltip = self.descriptionTooltip
    tooltip:ClearLines()
    tooltip:SetSpell(spellIndex, bookType)

    -- Extract description (skip the first line which is usually the spell name)
    local description = ""
    for i = 2, tooltip:NumLines() do
        local line = _G["SpellDescriptionTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and not text:match("^%s*Rang%s*%d+%s*$") and not text:match("^%s*Rank%s*%d+%s*$") then
                description = description .. (description ~= "" and " " or "") .. text
            end
        end
    end

    return description or ""
end

--[[
 * Cleans a spell name by removing parenthesized content and extra spaces
 *
 * @param spellName string The spell name to clean
 * @return string The cleaned spell name
--]]
function SpellBook_Util:CleanSpellName(spellName)
    -- Remove content between parentheses
    local cleanName = spellName:gsub("%s*%(.-%)%s*", "")

    -- Remove extra spaces
    cleanName = cleanName:gsub("^%s+", ""):gsub("%s+$", "")

    return cleanName
end

--[[
 * Gets the maximum rank for a spell
 *
 * @param spellName string The name of the spell
 * @return number The maximum rank of the spell
--]]
function SpellBook_Util:GetMaxSpellRank(spellName)
    local maxRank = 0
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local currentSpellName, currentRank = GetSpellName(i, BOOKTYPE_SPELL)
            if currentSpellName == spellName then
                local rankNumber = tonumber(currentRank and currentRank:match("%d+") or "0") or 0
                maxRank = math.max(maxRank, rankNumber)
            end
        end
    end
    return maxRank
end

--[[
 * Gets the required level for a spell from tooltip
 *
 * @param spellIndex number The index of the spell
 * @param bookType string The type of spellbook
 * @return number The required level for the spell
--]]
function SpellBook_Util:GetSpellRequiredLevel(spellIndex, bookType)
    -- Create a temporary invisible tooltip if needed
    if not self.levelTooltip then
        self.levelTooltip = CreateFrame("GameTooltip", "SpellLevelTooltip", nil, "GameTooltipTemplate")
        self.levelTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    local tooltip = self.levelTooltip
    tooltip:ClearLines()
    tooltip:SetSpell(spellIndex, bookType)

    -- Check tooltip lines for required level
    for i = 2, tooltip:NumLines() do
        local line = _G["SpellLevelTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- French version
                local level = text:match("Niveau (%d+)")
                if level then
                    return tonumber(level)
                end

                -- English version
                level = text:match("Level (%d+)")
                if level then
                    return tonumber(level)
                end
            end
        end
    end

    -- If no required level is found, assume it's 1
    return 1
end

--[[
 * Gets the available level for a spell from API
 *
 * @param spellID number The ID of the spell
 * @return number The available level for the spell
--]]
function SpellBook_Util:GetSpellAvailableLevel(spellID)
    -- Check if the function is available
    if not GetSpellAvailableLevel then
        return nil
    end

    return GetSpellAvailableLevel(spellID)
end

--[[
 * Gets the required level for a spell
 *
 * @param spellIndex number The index of the spell
 * @param bookType string The type of spellbook
 * @return number The required level for the spell
--]]
function SpellBook_Util:GetRequiredLevel(spellIndex, bookType)
    local spellName, rank = GetSpellName(spellIndex, bookType)
    local spellID = nil

    -- Method 1: Use tooltip (works in most cases)
    local levelFromTooltip = self:GetSpellRequiredLevel(spellIndex, bookType)
    if levelFromTooltip and levelFromTooltip > 1 then
        return levelFromTooltip
    end

    -- Method 2: Use GetSpellAvailableLevel if available
    if spellID then
        local levelFromAPI = self:GetSpellAvailableLevel(spellID)
        if levelFromAPI then
            return levelFromAPI
        end
    end

    -- Default to level 1
    return 1
end