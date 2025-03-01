-- SpellBook_ActionHighlight.lua
SpellBook_ActionHighlight = {}

-- Table to store visual effects
local shineEffects = {}

-- Single animation frame for all effects
local animationFrame

--[[
    Initialize the action highlight module
    
    @return void
]]--
function SpellBook_ActionHighlight:Initialize()
    -- Create the animation frame
    animationFrame = CreateFrame("Frame")

    animationFrame:SetScript("OnUpdate", function(self, elapsed)
        local hasActiveEffects = false
        for button, effect in pairs(shineEffects) do
            if effect.active then
                hasActiveEffects = true

                effect.borderTimer = (effect.borderTimer or 0) + elapsed
                local alphaPulse = 0.1 + (1 * (math.sin(effect.borderTimer * 4) * 0.5 + 0.5))
                effect.border:SetAlpha(alphaPulse)
            end
        end
        
        if not hasActiveEffects then
            self:Hide()
        end
    end)

    animationFrame:Hide()
end

--[[
    Create a highlight effect for a button
    
    @param button table The button to create the effect for
    @return table The created effect
]]--
function SpellBook_ActionHighlight:CreateButtonShineEffect(button)
    if shineEffects[button] then
        return shineEffects[button]
    end
    
    -- Create the golden border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 0.8, 0.2, 1) -- Golden
    border:SetWidth(button:GetWidth() * 1.8)
    border:SetHeight(button:GetHeight() * 1.8)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:Hide()
    
    -- Store references
    shineEffects[button] = {
        border = border,
        borderTimer = 0,
        borderVisible = true,
        timer = 0,
        direction = 1,
        active = false
    }
    
    return shineEffects[button]
end

--[[
    Check if a spell is on an action bar
    
    @param spellName string The name of the spell to check
    @return boolean, number Whether the spell is on an action bar and in which slot
]]--
function SpellBook_ActionHighlight:IsSpellOnActionBar(spellName)
    for slot = 1, 120 do
        local actionType, _, _, id = GetActionInfo(slot)
        if actionType == "spell" and id then
            local name = GetSpellInfo(id)
            if name == spellName then
                return true, slot
            end
        end
    end
    return false, nil
end

--[[
    Highlight an action button corresponding to a spell
    
    @param spellName string The name of the spell to highlight
    @return void
]]--
function SpellBook_ActionHighlight:HighlightSpellActionButton(spellName)
    local found, slot = self:IsSpellOnActionBar(spellName)
    if not found then return end
    
    -- Determine the correct button based on the index
    local buttonName
    if slot <= 12 then
        buttonName = "ActionButton" .. slot
    elseif slot <= 24 then
        buttonName = "MultiBarBottomLeftButton" .. (slot - 12)
    elseif slot <= 36 then
        buttonName = "MultiBarBottomRightButton" .. (slot - 24)
    elseif slot <= 48 then
        buttonName = "MultiBarRightButton" .. (slot - 36)
    else
        buttonName = "MultiBarLeftButton" .. (slot - 48)
    end
    
    local button = _G[buttonName]
    if not button then return end
    
    local effect = self:CreateButtonShineEffect(button)
    
    -- Activate visual effects
    effect.border:Show()
    effect.timer = 0
    effect.direction = 1
    effect.borderTimer = 0
    effect.borderVisible = true
    effect.active = true
    
    -- Ensure animation frame is active
    animationFrame:Show()
    
    -- Play a subtle sound (optional)
    PlaySound("MINIMAPBUTTON_OPEN")
end

--[[
    Clear all highlight effects
    
    @return void
]]--
function SpellBook_ActionHighlight:ClearAllEffects()
    for button, effect in pairs(shineEffects) do
        effect.border:Hide()
        effect.active = false
    end
    
    animationFrame:Hide()
end

-- Initialize the module on load
SpellBook_ActionHighlight:Initialize()