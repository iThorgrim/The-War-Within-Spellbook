SpellBook_UI = {}

-- ==========================================
-- Private constants
-- ==========================================
local DEFAULT_SEARCH_TEXT = "Search for a spell..."

-- ==========================================
-- Internal module state
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
-- Private event handlers
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
-- UI Element Factory
-- ==========================================
local UIFactory = {
    CreateRankFilterCheckbox = function(parent)
        local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkbox:SetSize(24, 24)
        checkbox:SetPoint("BOTTOMRIGHT", parent.PageView2, "TOPRIGHT", -150, 40)

        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        text:SetText("Show all ranks")

        checkbox:SetHitRectInsets(0, -90, 0, 0)
        return checkbox, text
    end,

    CreateSearchBox = function(parent, relativeTo)
        local searchBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        searchBox:SetSize(150, 20)
        searchBox:SetPoint("BOTTOMRIGHT", relativeTo, "TOPRIGHT", -30, -21)
        searchBox:SetAutoFocus(false)

        return searchBox
    end
}

-- ==========================================
-- Private functions for SpellBook_UI
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
        ["Spell"] = {
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
                        
                        local spellName = GetSpellName(self.spellIndex, data.bookType)
                        if spellName then
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
-- Public API for SpellBook_UI module
-- ==========================================

--[[
    Initialize the UI module and set up event handling
    
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
    Update cooldowns for all spell buttons in the spellbook
    
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
    Update spellbook content based on current filters and search criteria
    
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

    spellBookFrame:SetDataProvider(spellData, true)
    SpellBook_ShineEffect:ApplyShineToUnusedSpells()
end

--[[
    Create pagination controls for the spellbook
    
    @param {table} parentFrame The parent frame to attach pagination controls to
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
    Create filter controls for the spellbook
    
    @param {table} parentFrame The parent frame to attach filter controls to
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
-- Public functions called by external events
-- ==========================================

--[[
    Handler for player spells frame loading
    
    @param {table} frame The main player spells frame
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
    tinsert(UISpecialFrames, frame:GetName())
end

--[[
    Handler for player spells frame showing
    
    @return void
]]--
function PlayerSpellsFrame_OnShow()
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

--[[
    Handler for player spells frame hinding

    @return void
]]--
function PlayerSpellsFrame_OnHide()
    if MultiActionBar_HideAllGrids then
        MultiActionBar_HideAllGrids()
    end

    if UpdateMicroButtons then
        UpdateMicroButtons()
    end

    PlaySound("igSpellBookClose");

    SpellBook_ShineEffect:OnHide()
end

-- ==========================================
-- Module initialization
-- ==========================================

-- Initialize the module
SpellBook_UI:Initialize()

--[[
 * Récupère la description d'un sort à partir de son ID,
 * même si le joueur n'a pas encore appris ce sort.
 *
 * @param spellID number L'identifiant du sort
 * @return string La description du sort ou une chaîne vide si non trouvée
--]]
function GetSpellDescriptionByID(spellID)
    local tooltipName = "SpellInfoTooltip"
    local tooltip = _G[tooltipName]

    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    tooltip:SetHyperlink("spell:" .. spellID)

    local description = ""
    for i = 2, tooltip:NumLines() do
        local textLeft = _G[tooltipName .. "TextLeft" .. i]

        if textLeft then
            local text = textLeft:GetText()
            if text and not text:match("^%s*Rank%s*%d+%s*$") and not text:match("^%s*Level%s*%d+%s*$") then
                if description ~= "" then
                    description = description .. " "
                end
                description = description .. text
            end
        end
    end

    return description
end

--[[
 * Version améliorée qui sépare la description du coût du sort,
 * du temps d'incantation et d'autres métadonnées.
 *
 * @param spellID number L'identifiant du sort
 * @return table Table contenant description, coût, temps d'incantation, etc.
--]]
function GetDetailedSpellInfoByID(spellID)
    local tooltipName = "SpellInfoTooltip"
    local tooltip = _G[tooltipName]

    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    tooltip:SetHyperlink("spell:" .. spellID)

    local result = {
        name = "",
        description = "",
        castTime = "",
        cooldown = "",
        cost = "",
        range = "",
        requiredLevel = nil
    }

    -- Récupérer le nom du sort depuis la première ligne
    local nameText = _G[tooltipName .. "TextLeft1"]
    if nameText then
        result.name = nameText:GetText() or ""
    end

    -- Parcourir toutes les lignes pour extraire les différentes informations
    for i = 2, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]

        if line then
            local text = line:GetText()

            if text then
                -- Extraire le temps d'incantation
                if text:match("^%d+%.?%d*%s+sec%s+d'incantation$") or
                        text:match("^%d+%.?%d*%s+sec%s+cast$") then
                    result.castTime = text

                    -- Extraire le coût en mana/rage/énergie
                elseif text:match("^%d+%s+[Mm]ana$") or
                        text:match("^%d+%s+[Rr]age$") or
                        text:match("^%d+%s+[Éé]nergie$") or
                        text:match("^%d+%s+[Ee]nergy$") then
                    result.cost = text

                    -- Extraire la portée
                elseif text:match("^%d+%s+m$") or
                        text:match("^%d+%s+yd$") then
                    result.range = text

                    -- Extraire le temps de recharge
                elseif text:match("Recharge %d+%.?%d*%s+sec") or
                        text:match("Cooldown %d+%.?%d*%s+sec") then
                    result.cooldown = text

                    -- Extraire le niveau requis
                elseif text:match("Niveau %d+") or
                        text:match("Requires Level %d+") then
                    result.requiredLevel = tonumber(text:match("%d+"))

                    -- Ajouter à la description (si ce n'est pas une métadonnée)
                else
                    if result.description ~= "" then
                        result.description = result.description .. " "
                    end
                    result.description = result.description .. text
                end
            end
        end
    end

    return result
end

local _ToggleSpellBook = ToggleSpellBook
function ToggleSpellBook(booktype)
    if booktype == BOOKTYPE_SPELL then
        if (PlayerSpellsFrame:IsShown()) then
            PlayerSpellsFrame:Hide()
        else
            PlayerSpellsFrame:Show()
        end
        return
    end
    _ToggleSpellBook(booktype)
end
