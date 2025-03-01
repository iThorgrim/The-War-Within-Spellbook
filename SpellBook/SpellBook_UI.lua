SpellBook_UI = {}

-- ==========================================
-- Constantes privées
-- ==========================================
local DEFAULT_SEARCH_TEXT = "Rechercher un sort..."

-- ==========================================
-- État interne du module
-- ==========================================
local state = {
    isInitialized = false,
    frames = {
        main = nil,
        spellBook = nil,
        searchBox = nil,
        rankFilterCheckbox = nil
    }
}

-- ==========================================
-- Gestionnaires d'événements privés
-- ==========================================
local eventHandlers = {
    SPELLS_CHANGED = function()
        if state.frames.spellBook and state.frames.spellBook:IsVisible() then
            SpellBook_UI:UpdateSpellBookContent()
        end
    end,

    SPELL_UPDATE_COOLDOWN = function()
        if state.frames.spellBook and state.frames.spellBook:IsVisible() then
            SpellBook_UI:UpdateCooldowns()
        end
    end
}

-- ==========================================
-- Factory pour la création d'éléments UI
-- ==========================================
local UIFactory = {
    CreateRankFilterCheckbox = function(parent)
        local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkbox:SetSize(24, 24)
        checkbox:SetPoint("BOTTOMLEFT", parent.PageView1, "TOPLEFT", 0, 5)

        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        text:SetText("Afficher tous les rangs")

        checkbox:SetHitRectInsets(-100, 0, 0, 0)

        return checkbox, text
    end,

    CreateSearchBox = function(parent, relativeTo)
        local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        searchBox:SetSize(150, 20)
        searchBox:SetPoint("BOTTOMLEFT", relativeTo, "TOPLEFT", 0, 5)
        searchBox:SetAutoFocus(false)

        return searchBox
    end
}

-- ==========================================
-- Fonctions privées pour le SpellBook_UI
-- ==========================================
local function SetupSearchBox(searchBox)
    searchBox:SetText(DEFAULT_SEARCH_TEXT)

    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == DEFAULT_SEARCH_TEXT then
            self:SetText("")
        end
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText(DEFAULT_SEARCH_TEXT)
        end
    end)

    searchBox:SetScript("OnEnterPressed", function(self)
        local currentText = self:GetText()

        if currentText == "" or currentText == DEFAULT_SEARCH_TEXT then
            SpellBook_UI:UpdateSpellBookContent()
            self:ClearFocus()
            return
        end

        if #currentText >= 3 then
            SpellBook_UI:UpdateSpellBookContent()
        end

        self:ClearFocus()
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(DEFAULT_SEARCH_TEXT)
        SpellBook_UI:UpdateSpellBookContent()
    end)
end

local function SetupPaginationCallbacks(spellBookFrame, pageText)
    spellBookFrame:RegisterCallback("OnPageChanged", function()
        if spellBookFrame.currentPage and spellBookFrame.maxPages then
            pageText:SetText(string.format("Page %d / %d", spellBookFrame.currentPage, spellBookFrame.maxPages))
        end
        PlaySound("igAbiliityPageTurn")
    end)
end

local function SetupRankFilterCheckbox(checkbox)
    checkbox:SetChecked(SpellBook.Config.showAllRanks)

    checkbox:SetScript("OnClick", function(self)
        SpellBook.Config.showAllRanks = self:GetChecked()
        SpellBook:SaveConfig()

        if SpellBook_UI.SpellBookFrame and SpellBook_UI.SpellBookFrame.pools then
            for template, pool in pairs(SpellBook_UI.SpellBookFrame.pools) do
                if template == "SpellBookItemTemplate" then
                    for i = 1, pool.numActive do
                        local button = pool.frames[i]
                        if button and button.TextContainer and button.TextContainer.RequiredLevel then
                            if SpellBook.Config.showAllRanks then
                                button.TextContainer.RequiredLevel:Show()
                            else
                                button.TextContainer.RequiredLevel:Hide()
                            end
                        end
                    end
                end
            end
        end

        SpellBook_UI:UpdateSpellBookContent()
    end)
end

local function SetupSpellButtonTemplate(spellBookFrame)
    spellBookFrame:SetElementTemplateData({
        ["Sort"] = {
            template = "SpellBookItemTemplate",
            initFunc = function(button, data)
                local spellName, rank = GetSpellName(data.spellIndex, data.bookType)
                local texture = GetSpellTexture(data.spellIndex, data.bookType)

                local cleanName = SpellBook_Util:CleanSpellName(spellName)

                button.icon:SetTexture(texture)
                button.TextContainer.Name:SetText(cleanName)

                if not button.cooldown then
                    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    button.cooldown:SetAllPoints(button.icon)
                end

                local start, duration, enabled = GetSpellCooldown(data.spellIndex, data.bookType)
                if start and duration then
                    button.cooldown:SetCooldown(start, duration)
                end

                if (rank ~= "") then
                    button.TextContainer.RequiredLevel:SetText("(" .. rank .. ")")
                    button.TextContainer.RequiredLevel:SetPoint("TOPLEFT", button.TextContainer.Name, "BOTTOMLEFT", 0, -2)
                    button.TextContainer.RequiredLevel:SetPoint("TOPRIGHT", button.TextContainer.Name, "BOTTOMRIGHT", 0, -2)

                    if SpellBook.Config.showAllRanks then
                        button.TextContainer.RequiredLevel:Show()
                    else
                        button.TextContainer.RequiredLevel:Hide()
                    end
                end

                local isPassive = IsPassiveSpell(data.spellIndex, data.bookType)
                button.isPassive = isPassive

                local portraitFrame = button.PortraitFrame
                if isPassive then
                    portraitFrame.PassiveBorder:Show()
                    portraitFrame.ActiveBorder:Hide()
                    portraitFrame.ActiveHoverBorder:Hide()

                    if button.shineEffect then
                        SpellBook_ShineEffect:ClearButtonEffects(button)
                    end
                else
                    portraitFrame.PassiveBorder:Hide()
                    portraitFrame.ActiveBorder:Show()
                    portraitFrame.ActiveHoverBorder:Hide()
                end

                button.spellIndex = data.spellIndex

                button:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpell(self.spellIndex, data.bookType)
                    GameTooltip:Show()
                    
                    if not self.isPassive then
                        self.PortraitFrame.ActiveHoverBorder:Show()
                        
                        -- Ajouter l'effet de surbrillance sur les barres d'action
                        local spellName = GetSpellName(self.spellIndex, data.bookType)
                        if spellName then
                            -- Vérifier si le module ActionHighlight est disponible
                            if SpellBook_ActionHighlight then
                                SpellBook_ActionHighlight:HighlightSpellActionButton(spellName)
                            end
                        end
                    end
                end)

                button:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                    
                    if not self.isPassive then
                        self.PortraitFrame.ActiveHoverBorder:Hide()
                    end
                    
                    -- Désactiver les effets de surbrillance
                    if SpellBook_ActionHighlight then
                        SpellBook_ActionHighlight:ClearAllEffects()
                    end
                end)

                button:SetScript("OnClick", function(self, mouseButton)
                    if mouseButton == "LeftButton" and IsShiftKeyDown() then
                        PickupSpell(self.spellIndex, data.bookType)
                    elseif mouseButton == "LeftButton" then
                        CastSpell(self.spellIndex, data.bookType)
                    end
                end)

                button:RegisterForDrag("LeftButton")
                button:SetScript("OnDragStart", function(self)
                    PickupSpell(self.spellIndex, data.bookType)
                end)

                button:SetScript("OnReceiveDrag", function(self)
                    PickupSpell(self.spellIndex, data.bookType)
                end)

                button:SetAttribute("type", "spell")
                button:SetAttribute("spell", spellName)
            end
        },

        ["Header"] = {
            template = "SpellBookHeaderTemplate",
            initFunc = function(header, data)
                header.Text:SetText(data.text)
            end
        }
    })
end

-- Configure le mixine PagedContent pour le SpellBook
local function SetupPagedContentMixin(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame
    local pageView1 = spellBookFrame.PageView1
    local pageView2 = spellBookFrame.PageView2

    for k, v in pairs(PagedContentFrameMixin) do
        spellBookFrame[k] = v
    end

    spellBookFrame.config = {
        viewsPerPage = 2,
        itemsPerView = 23,
        columnWidth = 130,
        columnSpacing = 30,
        rowHeight = 35,
        rowSpacing = 15,
        headerHeight = 30,
        headerBottomMargin = 10,
        headerTopMargin = 15,
        maxColumnsPerRow = 3
    }

    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    spellBookFrame.ViewFrames = {pageView1, pageView2}

    spellBookFrame:OnLoad()

    spellBookFrame:SetEmptyDataProviderFallback(function()
        return SpellBook_SpellFilter:FilterAllSpells()
    end)
end

-- ==========================================
-- API publique du module SpellBook_UI
-- ==========================================

--[[
    Initialise le module UI et met en place la gestion des événements
    
    @return void
]]--
function SpellBook_UI:Initialize()
    if state.isInitialized then return end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(self, event, ...)
        if eventHandlers[event] then
            eventHandlers[event](...)
        end
    end)

    frame:RegisterEvent("SPELLS_CHANGED")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    state.frames.main = frame
    state.isInitialized = true
end

--[[
    Met à jour les cooldowns pour tous les boutons de sort dans le grimoire
    
    @return void
]]--
function SpellBook_UI:UpdateCooldowns()
    local spellBookFrame = state.frames.spellBook
    if not spellBookFrame or not spellBookFrame.pools then return end

    for template, pool in pairs(spellBookFrame.pools) do
        if template == "SpellBookItemTemplate" then
            for i = 1, pool.numActive do
                local button = pool.frames[i]
                if button and button.spellIndex then
                    local start, duration, enabled = GetSpellCooldown(button.spellIndex, BOOKTYPE_SPELL)
                    if start and duration and button.cooldown then
                        button.cooldown:SetCooldown(start, duration)
                    end
                end
            end
        end
    end
end

--[[
    Met à jour le contenu du grimoire en fonction des filtres et critères de recherche actuels
    
    @return void
]]--
function SpellBook_UI:UpdateSpellBookContent()
    local spellBookFrame = state.frames.spellBook
    if not spellBookFrame then return end

    local searchBox = state.frames.searchBox
    local rankFilterCheckbox = state.frames.rankFilterCheckbox

    local searchText = searchBox and searchBox:GetText()
    local showAllRanks = rankFilterCheckbox and rankFilterCheckbox:GetChecked()

    if searchText == DEFAULT_SEARCH_TEXT then
        searchText = ""
    end

    SpellBook.Config.showAllRanks = showAllRanks

    local spellData
    if searchText and searchText ~= "" then
        spellData = SpellBook_SpellFilter:FilterSpellsBySearch(searchText, showAllRanks)
    else
        spellData = SpellBook_SpellFilter:FilterAllSpells()
    end

    if spellBookFrame.SetDataProviderWithFade then
        spellBookFrame:SetDataProviderWithFade(spellData)
    else
        spellBookFrame:SetDataProvider(spellData)
    end

    if SpellBook_ShineEffect then
        C_Timer.After(.35, function() 
            SpellBook_ShineEffect:ApplyShineToUnusedSpells()
        end)
    end
end

--[[
    Crée les contrôles de pagination pour le grimoire
    
    @param {table} parentFrame Le frame parent auquel attacher les contrôles de pagination
    @return void
]]--
function SpellBook_UI:CreatePaginationSystem(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame

    spellBookFrame.PagingButtons = {
        Prev = spellBookFrame.PageView2.PrevPageButton,
        Next = spellBookFrame.PageView2.NextPageButton
    }
    spellBookFrame.PageText = spellBookFrame.PageView2.PageText.Value

    SetupPaginationCallbacks(spellBookFrame, spellBookFrame.PageText)
end

--[[
    Crée les contrôles de filtrage pour le grimoire
    
    @param {table} parentFrame Le frame parent auquel attacher les contrôles de filtrage
    @return void
]]--
function SpellBook_UI:CreateFilterControls(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame

    local rankFilterCheckbox = UIFactory.CreateRankFilterCheckbox(spellBookFrame)

    local searchBox = UIFactory.CreateSearchBox(spellBookFrame, rankFilterCheckbox)

    state.frames.searchBox = searchBox
    state.frames.rankFilterCheckbox = rankFilterCheckbox
    spellBookFrame.SearchBox = searchBox
    spellBookFrame.RankFilterCheckbox = rankFilterCheckbox

    SetupSearchBox(searchBox)
    SetupRankFilterCheckbox(rankFilterCheckbox)
end

-- ==========================================
-- Fonctions publiques appelées par les events externes
-- ==========================================

--[[
    Handler pour le chargement du frame des sorts du joueur
    
    @param {table} frame Le frame principal des sorts du joueur
    @return void
]]--
function PlayerSpellsFrame_OnLoad(frame)
    SpellBook_UI.PlayerFrame = frame
    SpellBook_UI.SpellBookFrame = frame.SpellBookFrame
    state.frames.spellBook = frame.SpellBookFrame

    SetupPagedContentMixin(frame)
    SetupSpellButtonTemplate(frame.SpellBookFrame)
    SpellBook_UI:CreatePaginationSystem(frame)
    SpellBook_UI:CreateFilterControls(frame)

    if SpellBook_ShineEffect and SpellBook_ShineEffect.Initialize then
        SpellBook_ShineEffect:Initialize()
    end

    SetFramePortrait(frame, "Interface\\Icons\\INV_Misc_Book_09")
end

--[[
    Handler pour l'affichage du frame des sorts du joueur
    
    @param {table} frame Le frame principal des sorts du joueur
    @return void
]]--
function PlayerSpellsFrame_OnShow(frame)
    if MultiActionBar_ShowAllGrids then
        MultiActionBar_ShowAllGrids()
    end

    if UpdateMicroButtons then
        UpdateMicroButtons()
    end

    PlaySound("igSpellBookOpen")

    SpellBook_UI:UpdateSpellBookContent()
    SpellBook_UI:UpdateCooldowns()
end

-- ==========================================
-- Initialisation du module
-- ==========================================

-- Shim pour C_Timer.After si non disponible
if not C_Timer then
    C_Timer = {}
    function C_Timer.After(delay, callback)
        local frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame.delay = delay
        frame.callback = callback
        
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= self.delay then
                self:SetScript("OnUpdate", nil)
                self.callback()
            end
        end)
    end
end

-- Initialiser le module
SpellBook_UI:Initialize()