-- SpellBook_ActionHighlight.lua
SpellBook_ActionHighlight = {}

-- Table pour stocker les effets visuels
local shineEffects = {}

-- Frame d'animation unique pour tous les effets
local animationFrame

function SpellBook_ActionHighlight:Initialize()
    -- Créer le frame pour l'animation
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

-- Créer un effet de surbrillance pour un bouton
function SpellBook_ActionHighlight:CreateButtonShineEffect(button)
    if shineEffects[button] then
        return shineEffects[button]
    end
    
    -- Créer la bordure dorée
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 0.8, 0.2, 1) -- Doré
    border:SetWidth(button:GetWidth() * 1.8)
    border:SetHeight(button:GetHeight() * 1.8)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:Hide()
    
    -- Stocker les références
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

-- Vérifier si un sort est sur une barre d'action
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

-- Mettre en évidence un bouton d'action correspondant à un sort
function SpellBook_ActionHighlight:HighlightSpellActionButton(spellName)
    local found, slot = self:IsSpellOnActionBar(spellName)
    if not found then return end
    
    -- Déterminer le bon bouton en fonction de l'index
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
    
    -- Activer les effets visuels
    effect.border:Show()
    effect.timer = 0
    effect.direction = 1
    effect.borderTimer = 0
    effect.borderVisible = true
    effect.active = true
    
    -- S'assurer que le frame d'animation est actif
    animationFrame:Show()
    
    -- Jouer un son discret (optionnel)
    PlaySound("MINIMAPBUTTON_OPEN")
end

-- Désactiver tous les effets
function SpellBook_ActionHighlight:ClearAllEffects()
    for button, effect in pairs(shineEffects) do
        effect.border:Hide()
        effect.active = false
    end
    
    animationFrame:Hide()
end

SpellBook_ActionHighlight:Initialize()