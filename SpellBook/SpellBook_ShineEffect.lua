SpellBook_ShineEffect = {
    config = {
        enabled = true,
        debugMode = false,
        
        animation = {
            cycleDuration = 2,
            baseAlpha = 0.2,
            pulseIntensity = 1,
            
            sparkleInterval = 2,
            sparkleCount = 0,
            sparkleSize = 16,
            sparkleAlpha = 0.5
        }
    },

    state = {
        animationTimer = 0,
        sparkleTimer = 0,
        activeButtons = {},
        animationFrame = nil
    },
    
    textures = {
        border = "Interface/SpellBook/SpellbookElements",
        sparkle = "Interface/CastingBar/UICastingBarFX"
    }
}

function SpellBook_ShineEffect:Initialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if self[event] then
            return self[event](self, ...)
        end
    end)
    
    local eventsToTrack = {
        "ACTIONBAR_SLOT_CHANGED",
        "PLAYER_ENTERING_WORLD", 
        "ACTIONBAR_PAGE_CHANGED",
        "CHARACTER_POINTS_CHANGED", 
        "ACTIVE_TALENT_GROUP_CHANGED"
    }
    
    for _, event in ipairs(eventsToTrack) do
        self.eventFrame:RegisterEvent(event)
    end
    
    -- Créer le frame d'animation principal
    self.state.animationFrame = CreateFrame("Frame")
    self.state.animationFrame:SetScript("OnUpdate", function(frame, elapsed)
        self:UpdateAnimations(elapsed)
    end)
    self.state.animationFrame:Hide()
end

-- Méthode de débogage
function SpellBook_ShineEffect:DebugLog(message)
    if self.config.debugMode then
        print("|cFFFFCC00SpellBook Shine:|r " .. message)
    end
end

-- Créer un effet de brillance avec sparkle
function SpellBook_ShineEffect:CreateSparkleEffect(button)
    if not button or not self.config.enabled then return end
    
    -- Nettoyer les effets existants
    self:ClearButtonEffects(button)
    
    -- Créer le conteneur
    local container = CreateFrame("Frame", nil, button)
    container:SetFrameLevel(button:GetFrameLevel() + 5)
    container:SetAllPoints(button.icon)
    container:Show()
    
    -- Créer la bordure
    local border = container:CreateTexture(nil, "OVERLAY")
    border:SetTexture(self.textures.border)
    border:SetTexCoord(0.000976562, 0.125, 0.661133, 0.785156)
    border:SetPoint("CENTER", container, "CENTER", 0, 0)
    border:SetBlendMode("ADD")
    border:SetWidth(32)
    border:SetHeight(32)
    
    -- Créer les étincelles
    local sparkles = {}
    for i = 1, self.config.animation.sparkleCount do
        local sparkle = container:CreateTexture(nil, "OVERLAY")
        sparkle:SetTexture("Interface\\GLUES\\LoadingBar\\UI-LoadingBar-Spark")  -- Texture standard de particule
        sparkle:SetBlendMode("ADD")
        sparkle:SetWidth(48/2)
        sparkle:SetHeight(15/2)
        sparkle:SetAlpha(0)
        
        -- Propriétés dynamiques
        sparkle.currentAlpha = 0
        sparkle.angle = math.random() * 2 * math.pi
        sparkle.radius = math.random(10, 20)
        
        -- Position initiale
        local angle = sparkle.angle
        local radius = sparkle.radius
        sparkle:SetPoint("CENTER", container, "CENTER", 
            math.cos(angle) * radius, 
            math.sin(angle) * radius)
        
        sparkles[i] = sparkle
    end
    
    -- Stocker l'effet
    button.shineEffect = {
        container = container,
        border = border,
        sparkles = sparkles,
        active = true
    }
    
    -- Ajouter aux boutons actifs
    self.state.activeButtons[button] = button.shineEffect
    
    -- Démarrer l'animation si nécessaire
    self:StartAnimations()
end

-- Nettoyer les effets d'un bouton
function SpellBook_ShineEffect:ClearButtonEffects(button)
    if button.shineEffect then
        if button.shineEffect.container then
            button.shineEffect.container:Hide()
            button.shineEffect.container:SetParent(nil)
        end
        
        -- Retirer des boutons actifs
        self.state.activeButtons[button] = nil
        button.shineEffect = nil
    end
end

-- Démarrer les animations
function SpellBook_ShineEffect:StartAnimations()
    if not next(self.state.activeButtons) then return end
    
    if not self.state.animationFrame:IsShown() then
        self.state.animationTimer = 0
        self.state.sparkleTimer = 0
        self.state.animationFrame:Show()
    end
end

-- Mettre à jour les animations
-- Mettre à jour les animations
function SpellBook_ShineEffect:UpdateAnimations(elapsed)
    -- Vérifier si des effets sont toujours actifs
    if not next(self.state.activeButtons) then
        self.state.animationFrame:Hide()
        return
    end
    
    -- Mettre à jour les timers
    self.state.animationTimer = (self.state.animationTimer + elapsed) % self.config.animation.cycleDuration
    self.state.sparkleTimer = self.state.sparkleTimer + elapsed
    
    -- Animation de pulsation
    local pulseValue = math.sin((self.state.animationTimer / self.config.animation.cycleDuration) * (2 * math.pi))
    local alpha = self.config.animation.baseAlpha + 
                  self.config.animation.pulseIntensity * ((pulseValue + 1) / 2)
    
    -- Animation des étincelles plus fluide
    if self.state.sparkleTimer >= self.config.animation.sparkleInterval then
        self:UpdateSparkles(elapsed)
        self.state.sparkleTimer = 0
    end
    
    -- Mettre à jour tous les effets de brillance
    for button, effect in pairs(self.state.activeButtons) do
        if effect.border then
            effect.border:SetAlpha(alpha)
        end
        
        -- Mise à jour continue des étincelles
        if effect.sparkles then
            for _, sparkle in ipairs(effect.sparkles) do
                -- Variation subtile de l'alpha
                local currentAlpha = sparkle.currentAlpha or 0
                local cycleProgress = (self.state.animationTimer / self.config.animation.cycleDuration)

                local targetAlpha
                if cycleProgress < 0.25 then
                    targetAlpha = cycleProgress * 4
                elseif cycleProgress < 0.75 then
                    targetAlpha = 1
                else
                    targetAlpha = (1 - cycleProgress) * 4
                end
                
                -- Interpolation douce de l'alpha
                sparkle:SetAlpha(targetAlpha)
                
                -- Réinitialiser la position uniquement quand l'alpha est très proche de zéro
                if cycleProgress >= 0.75 and not sparkle.needsReposition then
                    -- Nouvelle position complètement aléatoire
                    local angle = math.random() * 2 * math.pi
                    local radius = math.random(10, 20)
                    
                    sparkle:SetPoint("CENTER", effect.container, "CENTER", 
                        math.cos(angle) * radius, 
                        math.sin(angle) * radius)
                    
                    sparkle.repositioned = true
                end
                
                -- Réinitialiser le flag quand l'alpha remonte
                if sparkle.currentAlpha > 0.1 then
                    sparkle.needsReposition = false
                end
                
                -- Animation de déplacement continue
                local angle = sparkle.angle or (math.random() * 2 * math.pi)
                local radius = sparkle.radius or math.random(10, 20)
                
                -- Mouvement circulaire
                local newX = math.cos(angle) * radius * math.sin(self.state.animationTimer * 2)
                local newY = math.sin(angle) * radius * math.cos(self.state.animationTimer * 2)
                
                sparkle.offsetX = newX
                sparkle.offsetY = newY
                sparkle:SetPoint("CENTER", effect.container, "CENTER", newX, newY)
            end
        end
    end
end

-- Mettre à jour les étincelles
function SpellBook_ShineEffect:UpdateSparkles(elapsed)
    for button, effect in pairs(self.state.activeButtons) do
        if effect.sparkles then
            for _, sparkle in ipairs(effect.sparkles) do
                sparkle.angle = math.random() * 2 * math.pi
            end
        end
    end
end

-- Vérifier si un sort est sur une barre d'action
function SpellBook_ShineEffect:IsSpellNotOnActionBar(spellIndex, bookType)
    local spellName = GetSpellName(spellIndex, bookType)
    if not spellName then return false end
    
    local cleanSpellName = spellName:gsub("%s*%(.-%)%s*", "")
    
    self:DebugLog("Checking spell: " .. cleanSpellName)
    
    -- Vérifications multiples (barres d'action, macros, stances)
    local checkMethods = {
        self.CheckActionBars,
        self.CheckMacros,
        self.CheckStanceBars
    }
    
    for _, method in ipairs(checkMethods) do
        if not method(self, cleanSpellName) then
            return false
        end
    end
    
    self:DebugLog("Spell not found on any bar")
    return true
end

-- Vérifier les barres d'action
function SpellBook_ShineEffect:CheckActionBars(cleanSpellName)
    for slot = 1, 120 do
        local actionType, _, _, id = GetActionInfo(slot)
        if actionType == "spell" then
            local actionSpellName = GetSpellInfo(id)
            if actionSpellName then
                local cleanActionName = actionSpellName:gsub("%s*%(.-%)%s*", "")
                if cleanActionName == cleanSpellName then
                    self:DebugLog("Found on action bar: " .. cleanSpellName)
                    return false
                end
            end
        end
    end
    return true
end

function SpellBook_ShineEffect:CheckMacros(cleanSpellName)
    local function checkMacroBody(body)
        return body and body:lower():find(cleanSpellName:lower())
    end

    for slot = 1, 120 do
        local actionType, _, _, id = GetActionInfo(slot)
        if actionType == "macro" then
            local name, _ = GetMacroSpell(slot)
            if name then
                if checkMacroBody(name) then
                    return false
                end
            end
        end
    end

    return true
end

-- Vérifier les barres de stances
function SpellBook_ShineEffect:CheckStanceBars(cleanSpellName)
    for i = 1, GetNumShapeshiftForms() do
        local _, name = GetShapeshiftFormInfo(i)
        if name then
            local cleanStanceName = name:gsub("%s*%(.-%)%s*", "")
            if cleanStanceName:lower() == cleanSpellName:lower() then
                self:DebugLog("Found in stance bar: " .. cleanSpellName)
                return false
            end
        end
    end
    return true
end

-- Appliquer les effets de brillance aux sorts inutilisés
function SpellBook_ShineEffect:ApplyShineToUnusedSpells()
    if not SpellBook_UI or not SpellBook_UI.SpellBookFrame then 
        self:DebugLog("SpellBookFrame not available")
        return 
    end
    
    local spellBookFrame = SpellBook_UI.SpellBookFrame
    
    if not spellBookFrame.pools then return end
    
    for template, pool in pairs(spellBookFrame.pools) do
        if template == "SpellBookItemTemplate" then
            for i = 1, pool.numActive do
                local button = pool.frames[i]
                if button and button.spellIndex then
                    -- Vérifier si le sort n'est pas sur une barre d'action
                    local isSpellUsable = not button.isPassive and 
                                          self:IsSpellNotOnActionBar(button.spellIndex, BOOKTYPE_SPELL)
                    
                    -- Gérer l'effet de brillance
                    if isSpellUsable then
                        self:CreateSparkleEffect(button)
                    else
                        self:ClearButtonEffects(button)
                    end
                end
            end
        end
    end
end

-- Gestionnaires d'événements
local events = {
    "ACTIONBAR_SLOT_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "ACTIONBAR_PAGE_CHANGED", 
    "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED"
}

for _, event in ipairs(events) do
    SpellBook_ShineEffect[event] = SpellBook_ShineEffect.ApplyShineToUnusedSpells
end

-- Initialiser le module
SpellBook_ShineEffect:Initialize()