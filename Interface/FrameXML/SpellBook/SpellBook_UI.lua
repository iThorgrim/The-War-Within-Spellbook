SpellBook_UI = {}

--[[
 * Initializes the UI module
 *
 * @return void
--]]
function SpellBook_UI:Initialize()
    -- Register for events
    if not self.Frame then
        self.Frame = CreateFrame("Frame")
        self.Frame:SetScript("OnEvent", function(frame, event, ...)
            if self[event] then
                return self[event](self, ...)
            end
        end)
    end

    self.Frame:RegisterEvent("SPELLS_CHANGED")
end

--[[
 * Event handler for SPELLS_CHANGED
 * Updates the spell book UI when spells change
 *
 * @return void
--]]
function SpellBook_UI:SPELLS_CHANGED()
    if self.SpellBookFrame and self.SpellBookFrame:IsVisible() then
        self:UpdateSpellBookContent()
    end
end

--[[
 * Updates the spellbook content based on current filters
 *
 * @return void
--]]
function SpellBook_UI:UpdateSpellBookContent()
    local spellBookFrame = self.SpellBookFrame
    if not spellBookFrame then return end

    local searchText = self.SearchBox and self.SearchBox:GetText()
    local showAllRanks = self.RankFilterCheckbox and self.RankFilterCheckbox:GetChecked()

    if searchText == "Rechercher un sort..." then
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
end

--[[
 * Creates the pagination system for the spellbook
 *
 * @param parentFrame table The parent frame to attach pagination controls to
 * @return void
--]]
function SpellBook_UI:CreatePaginationSystem(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame

    -- Create previous page button
    local prevButton = CreateFrame("Button", nil, spellBookFrame)
    prevButton:SetSize(32, 32)
    prevButton:SetPoint("BOTTOMRIGHT", spellBookFrame.PageView2, "BOTTOMRIGHT", -150, 0)

    local prevTexture = prevButton:CreateTexture(nil, "ARTWORK")
    prevTexture:SetAllPoints()
    prevTexture:SetTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up")
    prevButton:SetNormalTexture(prevTexture)

    local prevTexturePressed = prevButton:CreateTexture(nil, "ARTWORK")
    prevTexturePressed:SetAllPoints()
    prevTexturePressed:SetTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down")
    prevButton:SetPushedTexture(prevTexturePressed)

    local prevTextureDisabled = prevButton:CreateTexture(nil, "ARTWORK")
    prevTextureDisabled:SetAllPoints()
    prevTextureDisabled:SetTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Disabled")
    prevButton:SetDisabledTexture(prevTextureDisabled)

    -- Create next page button
    local nextButton = CreateFrame("Button", nil, spellBookFrame)
    nextButton:SetSize(32, 32)
    nextButton:SetPoint("BOTTOMRIGHT", spellBookFrame.PageView2, "BOTTOMRIGHT", -110, 0)

    -- Connect to animation system
    nextButton:SetScript("OnEnter", function(self)
        SpellBookCorner_OnEnter(self:GetParent():GetParent().BookCornerFlipbook)
    end)
    nextButton:SetScript("OnLeave", function(self)
        SpellBookCorner_OnLeave(self:GetParent():GetParent().BookCornerFlipbook)
    end)

    local nextTexture = nextButton:CreateTexture(nil, "ARTWORK")
    nextTexture:SetAllPoints()
    nextTexture:SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
    nextButton:SetNormalTexture(nextTexture)

    local nextTexturePressed = nextButton:CreateTexture(nil, "ARTWORK")
    nextTexturePressed:SetAllPoints()
    nextTexturePressed:SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down")
    nextButton:SetPushedTexture(nextTexturePressed)

    local nextTextureDisabled = nextButton:CreateTexture(nil, "ARTWORK")
    nextTextureDisabled:SetAllPoints()
    nextTextureDisabled:SetTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Disabled")
    nextButton:SetDisabledTexture(nextTextureDisabled)

    -- Store button references
    spellBookFrame.PagingButtons = {
        Prev = prevButton,
        Next = nextButton
    }

    -- Set up paging logic
    prevButton:SetScript("OnClick", function()
        local currentPage = spellBookFrame.currentPage
        if currentPage > 1 then
            spellBookFrame:SetCurrentPageWithFade(currentPage - 1)
        end
    end)

    nextButton:SetScript("OnClick", function()
        local currentPage = spellBookFrame.currentPage
        local maxPages = spellBookFrame.maxPages
        if currentPage < maxPages then
            spellBookFrame:SetCurrentPageWithFade(currentPage + 1)
        end
    end)

    spellBookFrame.PagingButtons = {
        Prev = prevButton,
        Next = nextButton
    }

    -- Create page text display
    local pageTextFrame = CreateFrame("Frame", nil, spellBookFrame)
    pageTextFrame:SetSize(100, 30)
    pageTextFrame:SetPoint("BOTTOMRIGHT", spellBookFrame.PageView2, "BOTTOMRIGHT", -190, 2)

    local pageText = pageTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetAllPoints(true)
    pageText:SetJustifyH("RIGHT")

    spellBookFrame.PageText = pageText

    -- Update page text when page changes
    spellBookFrame:RegisterCallback("OnPageChanged", function()
        if spellBookFrame.currentPage and spellBookFrame.maxPages then
            pageText:SetText(string.format("Page %d / %d", spellBookFrame.currentPage, spellBookFrame.maxPages))
        end
    end)
end

--[[
 * Creates the filter controls for the spellbook
 *
 * @param parentFrame table The parent frame to attach controls to
 * @return void
--]]
function SpellBook_UI:CreateFilterControls(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame

    -- Create rank filter checkbox
    local rankFilterCheckbox = CreateFrame("CheckButton", nil, spellBookFrame, "UICheckButtonTemplate")
    rankFilterCheckbox:SetSize(24, 24)
    rankFilterCheckbox:SetPoint("BOTTOMLEFT", spellBookFrame.PageView1, "TOPLEFT", 0, 5)

    local rankFilterText = spellBookFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankFilterText:SetPoint("LEFT", rankFilterCheckbox, "RIGHT", 0, 0)
    rankFilterText:SetText("Afficher tous les rangs")

    rankFilterCheckbox:SetHitRectInsets(-100, 0, 0, 0)

    -- Create search box
    local searchBox = CreateFrame("EditBox", nil, spellBookFrame, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("BOTTOMLEFT", rankFilterCheckbox, "TOPLEFT", 0, 5)
    searchBox:SetAutoFocus(false)

    -- Set initial checkbox state
    rankFilterCheckbox:SetChecked(SpellBook.Config.showAllRanks)

    -- Store references
    self.SearchBox = searchBox
    self.RankFilterCheckbox = rankFilterCheckbox
    spellBookFrame.SearchBox = searchBox
    spellBookFrame.RankFilterCheckbox = rankFilterCheckbox

    -- Set up search box behavior
    self:SetupSearchBox(searchBox)

    -- Set up rank filter behavior
    rankFilterCheckbox:SetScript("OnClick", function(self)
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

--[[
 * Creates the spell button template
 * Sets up the initialization function for spell buttons
 *
 * @param spellBookFrame table The main spell book frame
 * @return void
--]]
function SpellBook_UI:SetupSpellButtonTemplate(spellBookFrame)
    spellBookFrame:SetElementTemplateData({
        ["Sort"] = {
            template = "SpellBookItemTemplate",
            initFunc = function(button, data)
                local spellName, rank = GetSpellName(data.spellIndex, data.bookType)
                local texture = GetSpellTexture(data.spellIndex, data.bookType)

                -- Clean the spell name
                local cleanName = SpellBook_Util:CleanSpellName(spellName)

                -- Create the icon if it doesn't exist
                if not button.icon then
                    button.icon = button:CreateTexture(nil, "ARTWORK")
                    button.icon:SetSize(24, 24)
                    button.icon:SetPoint("LEFT", button, "LEFT", 5, 0)
                end
                button.icon:SetTexture(texture)

                -- Set the cleaned name
                button.TextContainer.Name:SetText(cleanName)

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

                -- Store the spell index for tooltips
                button.spellIndex = data.spellIndex

                -- Setup tooltip behavior
                button:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpell(self.spellIndex, data.bookType)

                    -- Show original name in tooltip if it was cleaned
                    if cleanName ~= spellName then
                        GameTooltip:AddLine("Nom original : " .. spellName, 1, 1, 1)
                    end

                    GameTooltip:Show()
                end)

                button:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                -- Add casting functionality (left-click to cast)
                button:SetScript("OnClick", function(self, button)
                    if button == "LeftButton" then
                        CastSpell(self.spellIndex, data.bookType)
                    end
                end)
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

--[[
 * Sets up the paged content mixin for the spell book frame
 * Creates a mixin to handle page navigation
 *
 * @param parentFrame table The parent frame containing the spell book frame
 * @return void
--]]
function SpellBook_UI:SetupPagedContentMixin(parentFrame)
    local spellBookFrame = parentFrame.SpellBookFrame
    local pageView1 = spellBookFrame.PageView1
    local pageView2 = spellBookFrame.PageView2

    -- Appliquer le mixin
    for k, v in pairs(PagedContentFrameMixin) do
        spellBookFrame[k] = v
    end

    -- Configuration pour le SpellBook
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

    -- Utiliser le mode d'affichage en grille
    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    -- Définir les ViewFrames
    spellBookFrame.ViewFrames = {pageView1, pageView2}

    -- Initialiser
    spellBookFrame:OnLoad()

    -- Configurer un fallback pour les recherches vides
    spellBookFrame:SetEmptyDataProviderFallback(function()
        return SpellBook_SpellFilter:FilterAllSpells()
    end)
end

--[[
 * Event handler for SPELLS_CHANGED
 * Updates the spell book UI when spells change
 *
 * @return void
--]]
function SpellBook_UI:SPELLS_CHANGED()
    if self.SpellBookFrame and self.SpellBookFrame:IsVisible() then
        self:UpdateSpellBookContent()
    end
end

--[[
 * Sets up the search box behavior
 *
 * @param searchBox table The search box EditBox frame
 * @return void
--]]
function SpellBook_UI:SetupSearchBox(searchBox)
    -- Variables for search throttling
    local lastSearchText = ""
    local lastSearchTime = 0
    local searchThrottleTime = 0.5 -- seconds

    -- Set up placeholder text
    searchBox:SetText("Rechercher un sort...")

    -- Handle focus changes
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Rechercher un sort..." then
            self:SetText("")
        end
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Rechercher un sort...")
        end
    end)

    -- Handle text changes with throttling
    searchBox:SetScript("OnUpdate", function(self, elapsed)
        local currentText = self:GetText()
        local currentTime = GetTime()

        -- Only update search if text has changed and enough time has passed
        if currentText ~= "Rechercher un sort..." and
                currentText ~= lastSearchText and
                (currentTime - lastSearchTime) >= searchThrottleTime then

            -- Don't search with very short text
            if #currentText >= 3 or currentText == "" then
                SpellBook_UI:UpdateSpellBookContent()

                lastSearchTime = currentTime
                lastSearchText = currentText
            end
        end
    end)

    -- Handle escape key
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText("Rechercher un sort...")

        -- Reset search and update display
        SpellBook_UI:UpdateSpellBookContent()
    end)

    -- Handle enter key
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
end


--[[
 * Sets up the event handlers for the player spell frame
 *
 * @param frame table The player spell frame
 * @return void
--]]
function PlayerSpellsFrame_OnLoad(frame)
    -- Store a reference for the UI module
    SpellBook_UI.PlayerFrame = frame
    SpellBook_UI.SpellBookFrame = frame.SpellBookFrame

    -- Setup paged content system
    SpellBook_UI:SetupPagedContentMixin(frame)

    -- Setup spell button template
    SpellBook_UI:SetupSpellButtonTemplate(frame.SpellBookFrame)

    -- Create pagination system
    SpellBook_UI:CreatePaginationSystem(frame)

    -- Create filter controls
    SpellBook_UI:CreateFilterControls(frame)
end

--[[
 * Event handler for when the player spell frame is shown
 *
 * @param frame table The player spell frame
 * @return void
--]]
function PlayerSpellsFrame_OnShow(frame)
    -- Show multibar slots and update micro buttons for compatibility
    if MultiActionBar_ShowAllGrids then
        MultiActionBar_ShowAllGrids()
    end

    if UpdateMicroButtons then
        UpdateMicroButtons()
    end

    -- Play sound effect
    PlaySound("igSpellBookOpen")

    -- Update the spell book content
    SpellBook_UI:UpdateSpellBookContent()
end

SpellBook_UI:Initialize()