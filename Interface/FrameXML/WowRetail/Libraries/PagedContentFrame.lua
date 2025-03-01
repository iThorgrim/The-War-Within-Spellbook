--[[
 * PagedContentFrame for WoW 3.3.5a
 * A modular, generic pagination system for displaying elements across multiple pages
 *
 * @version 2.0
 * @author iThorgrim (Refactored by Claude)
 *
 * System designed to be reusable in different types of addons
]]

-- Global namespace for the framework
PagedContent = PagedContent or {}

-- Main mixin
PagedContentFrameMixin = {}

-- Default configuration
PagedContent.DefaultConfig = {
    viewsPerPage = 1,
    itemsPerView = 25,
    itemHeight = 40,
    headerHeight = 30,
    columnWidth = 130,
    columnSpacing = 30,
    rowHeight = 35,
    rowSpacing = 15,
    headerBottomMargin = 10,
    headerTopMargin = 15,
    maxColumnsPerRow = 3,
    fadeOutDuration = 0.2,
    fadeInDuration = 0.2,
    animationDelay = 0.1,
    throttleTime = 1.0
}

-- Render options
PagedContent.RenderMode = {
    LIST = "LIST",          -- Vertical list display
    GRID = "GRID",          -- Grid display
    CUSTOM = "CUSTOM"       -- Custom mode (requires a renderer)
}

--[[
 * Pool system for frame reuse
 *
 * @param frameType string Type of frame to create
 * @param parent table Parent for new frames
 * @param template string Template to use (optional)
 * @return table Pool instance
]]
function PagedContent:CreateFramePool(frameType, parent, template)
    local pool = {
        frameType = frameType,
        parent = parent,
        template = template,
        numActive = 0,
        frames = {},

        -- Acquire a frame from the pool
        Acquire = function(self)
            self.numActive = self.numActive + 1

            if not self.frames[self.numActive] then
                self.frames[self.numActive] = CreateFrame(self.frameType, nil, self.parent, self.template)
            end

            local frame = self.frames[self.numActive]
            frame:Show()
            return frame
        end,

        -- Release all frames
        ReleaseAll = function(self)
            for i = 1, self.numActive do
                if self.frames[i] then
                    self.frames[i]:Hide()
                    self.frames[i]:ClearAllPoints()
                end
            end
            self.numActive = 0
        end
    }

    return pool
end

--[[
 * PagedContent mixin initialization
 *
 * @return void
]]
function PagedContentFrameMixin:OnLoad()
    self.pools = {}
    self.frames = {}
    self.isAnimating = false

    -- Merge with default configuration
    self.config = self.config or {}
    for k, v in pairs(PagedContent.DefaultConfig) do
        if self.config[k] == nil then
            self.config[k] = v
        end
    end

    -- Use provided ViewFrames or create default frames
    if not self.ViewFrames or #self.ViewFrames == 0 then
        self:CreateDefaultViewFrames()
    end

    self.viewsPerPage = self.config.viewsPerPage or #self.ViewFrames
    self.currentPage = 1
    self.maxPages = 1
    self.renderMode = self.renderMode or PagedContent.RenderMode.LIST

    -- Callbacks and events
    self.callbacks = {}

    -- Create default pagination controls if needed
    if not self.noPagingControls then
        self:CreatePagingControls()
    end
end

--[[
 * Create default ViewFrames if none provided
 *
 * @return void
]]
function PagedContentFrameMixin:CreateDefaultViewFrames()
    self.ViewFrames = {}

    for i = 1, self.config.viewsPerPage do
        local viewFrame = CreateFrame("Frame", nil, self)
        viewFrame:SetSize(self:GetWidth() / self.config.viewsPerPage, self:GetHeight())

        if i == 1 then
            viewFrame:SetPoint("TOPLEFT", 0, 0)
        else
            local xOffset = (i-1) * (self:GetWidth() / self.config.viewsPerPage)
            viewFrame:SetPoint("TOPLEFT", xOffset, 0)
        end

        self.ViewFrames[i] = viewFrame
    end
end

--[[
 * Set element templates to use
 *
 * @param templateData table Template data
 * @return void
]]
function PagedContentFrameMixin:SetElementTemplateData(templateData)
    self.elementTemplateData = templateData
end

--[[
 * Configure custom render mode
 *
 * @param renderer function Custom render function
 * @return void
]]
function PagedContentFrameMixin:SetCustomRenderer(renderer)
    self.customRenderer = renderer
    self.renderMode = PagedContent.RenderMode.CUSTOM
end

--[[
 * Set data provider
 *
 * @param dataProvider table Data to display
 * @param preservePage boolean Preserve current page (optional)
 * @return void
]]
function PagedContentFrameMixin:SetDataProvider(dataProvider, preservePage)
    if not self.elementTemplateData then
        error("SetElementTemplateData must be called before SetDataProvider")
    end

    self:ReleaseAllPools()
    self.dataProvider = dataProvider
    self:UpdateElementDistribution()

    if not preservePage then
        self:SetCurrentPage(1)
    else
        self:DisplayCurrentPage()
    end
end

--[[
 * Update element distribution across pages
 *
 * @return void
]]
function PagedContentFrameMixin:UpdateElementDistribution()
    -- Use appropriate distribution method based on render mode
    if self.renderMode == PagedContent.RenderMode.LIST then
        self.viewDataList = self:SplitElementsIntoViews()
    elseif self.renderMode == PagedContent.RenderMode.GRID then
        self.viewDataList = self:SplitElementsIntoGrid()
    elseif self.renderMode == PagedContent.RenderMode.CUSTOM and self.customSplitter then
        self.viewDataList = self.customSplitter(self.dataProvider, self.config)
    else
        -- Default to list mode
        self.viewDataList = self:SplitElementsIntoViews()
    end

    -- Update max pages
    self.maxPages = math.max(1, math.ceil(#self.viewDataList / self.viewsPerPage))

    -- Validate current page
    if self.currentPage > self.maxPages then
        self.currentPage = self.maxPages
    end
end

--[[
 * Split elements into views for list mode
 *
 * @return table List of views with their elements
]]
function PagedContentFrameMixin:SplitElementsIntoViews()
    local views = {}
    local currentView = {}
    local currentHeight = 0
    local viewHeight = self.ViewFrames[1]:GetHeight()
    local maxItemsPerView = self.config.itemsPerView
    local itemHeight = self.config.itemHeight
    local headerHeight = self.config.headerHeight

    for _, group in ipairs(self.dataProvider) do
        if group.header then
            if currentHeight + headerHeight > viewHeight or #currentView >= maxItemsPerView then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            table.insert(currentView, group.header)
            currentHeight = currentHeight + headerHeight
        end

        for _, element in ipairs(group.elements or {}) do
            if #currentView >= maxItemsPerView or currentHeight + itemHeight > viewHeight then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            table.insert(currentView, element)
            currentHeight = currentHeight + itemHeight
        end
    end

    -- Add last view if not empty
    if #currentView > 0 then
        table.insert(views, currentView)
    end

    return views
end

--[[
 * Split elements into views for grid mode
 *
 * @return table List of views with elements in grid
]]
function PagedContentFrameMixin:SplitElementsIntoGrid()
    local views = {}
    local currentView = {}
    local currentHeight = 0
    local viewHeight = self.ViewFrames[1]:GetHeight()
    local maxItemsPerView = self.config.itemsPerView
    local itemHeight = self.config.rowHeight
    local headerHeight = self.config.headerHeight
    local itemsPerRow = self.config.maxColumnsPerRow or 3

    for _, group in ipairs(self.dataProvider) do
        if group.header then
            -- If view is full, create a new one
            if currentHeight + headerHeight > viewHeight or #currentView >= maxItemsPerView then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            -- Add header
            group.header._isHeader = true
            table.insert(currentView, group.header)
            currentHeight = currentHeight + headerHeight
        end

        -- Process elements by rows for grid mode
        local elementsCount = #(group.elements or {})
        local currentPos = 0

        while currentPos < elementsCount do
            local remainingInRow = math.min(itemsPerRow, elementsCount - currentPos)

            -- Check if we need a new view
            if currentHeight + itemHeight > viewHeight or #currentView + remainingInRow > maxItemsPerView then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            -- Add elements in this row
            for i = 1, remainingInRow do
                local element = group.elements[currentPos + i]
                element._gridPosition = i
                element._gridSize = remainingInRow
                table.insert(currentView, element)
            end

            currentHeight = currentHeight + itemHeight + self.config.rowSpacing
            currentPos = currentPos + remainingInRow
        end
    end

    -- Add last view if not empty
    if #currentView > 0 then
        table.insert(views, currentView)
    end

    return views
end

--[[
 * Change page with fade animation
 *
 * @param pageNum number Target page number
 * @return void
]]
function PagedContentFrameMixin:SetCurrentPageWithFade(pageNum)
    -- Validate requested page
    pageNum = math.max(1, math.min(pageNum, self.maxPages))

    -- Do nothing if already on this page
    if self.currentPage == pageNum then
        return
    end

    -- Stop any ongoing animation
    if self.isAnimating then
        -- Stop existing animation frames
        if self.fadeInFrame then
            self.fadeInFrame:SetScript("OnUpdate", nil)
            self.fadeInFrame = nil
        end

        if self.fadeOutFrame then
            self.fadeOutFrame:SetScript("OnUpdate", nil)
            self.fadeOutFrame = nil
        end

        -- Restore alpha of all viewFrames to 1
        for _, viewFrame in ipairs(self.ViewFrames) do
            viewFrame:SetAlpha(1)
        end
    end

    -- Mark as animating
    self.isAnimating = true

    -- Disable pagination buttons during animation
    if self.PagingButtons then
        if self.PagingButtons.Prev then
            self.PagingButtons.Prev:Disable()
        end
        if self.PagingButtons.Next then
            self.PagingButtons.Next:Disable()
        end
    end

    -- Prepare frames to animate
    local viewFrames = {}
    for _, viewFrame in ipairs(self.ViewFrames) do
        table.insert(viewFrames, viewFrame)
    end

    -- Store reference to container
    local container = self
    local targetPage = pageNum

    -- Function to reactivate buttons at end of animation
    local function reactivateButtons()
        if container.PagingButtons then
            -- Reactivate based on new page
            if container.currentPage <= 1 then
                container.PagingButtons.Prev:Disable()
            else
                container.PagingButtons.Prev:Enable()
            end

            if container.currentPage >= container.maxPages then
                container.PagingButtons.Next:Disable()
            else
                container.PagingButtons.Next:Enable()
            end
        end

        -- Mark animation as finished
        container.isAnimating = false
    end

    -- Fade-in function
    local function startFadeIn()
        local startTime = GetTime()
        local duration = 0.2

        -- Stop old fadeIn frame if it exists
        if container.fadeInFrame then
            container.fadeInFrame:SetScript("OnUpdate", nil)
        end

        container.fadeInFrame = CreateFrame("Frame")
        container.fadeInFrame:SetScript("OnUpdate", function(self, elapsed)
            local progress = (GetTime() - startTime) / duration

            if progress >= 1 then
                -- Once fade-in is complete, restore alpha to 1
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(1)
                end

                -- Reactivate buttons
                reactivateButtons()

                -- Clean up
                container.fadeInFrame = nil

                -- Stop this animation
                self:SetScript("OnUpdate", nil)
            else
                -- Update alpha during fade-in
                local alpha = progress
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(alpha)
                end
            end
        end)
    end

    -- Fade-out function
    -- Stop old fadeOut frame if it exists
    if self.fadeOutFrame then
        self.fadeOutFrame:SetScript("OnUpdate", nil)
    end

    self.fadeOutFrame = CreateFrame("Frame")
    self.fadeOutFrame:SetScript("OnUpdate", function(self, elapsed)
        local startTime = GetTime()
        local duration = 0.2

        self:SetScript("OnUpdate", function(self, elapsed)
            local progress = (GetTime() - startTime) / duration

            if progress >= 1 then
                -- Once fade-out is complete, change page and start fade-in
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(0)
                end

                -- IMPORTANT: change current page
                container.currentPage = targetPage
                container:DisplayCurrentPage()

                -- Clean up
                container.fadeOutFrame = nil

                -- Start fade-in
                startFadeIn()

                -- Stop this animation
                self:SetScript("OnUpdate", nil)
            else
                -- Update alpha during fade-out
                local alpha = 1 - progress
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(alpha)
                end
            end
        end)
    end)
end

--[[
 * Change data provider with fade animation
 *
 * @param dataProvider table New data to display
 * @return void
]]
function PagedContentFrameMixin:SetDataProviderWithFade(dataProvider)
    -- Protection against multiple animations too close together
    local currentTime = GetTime()
    if self.lastFadeTime and (currentTime - self.lastFadeTime) < self.config.throttleTime then
        -- Update directly without animation
        self:SetDataProvider(dataProvider, true)
        return
    end

    if self.isAnimating then
        if self.fadeAnimationFrame then
            self.fadeAnimationFrame:SetScript("OnUpdate", nil)
        end
        self.isAnimating = false
    end

    -- Validate dataProvider
    if not dataProvider then return end

    -- If empty and a fallback is defined, use the fallback
    if #dataProvider == 0 and self.emptyDataProviderFallback then
        dataProvider = self.emptyDataProviderFallback()
    end

    -- Mark beginning of animation
    self.isAnimating = true

    -- Disable pagination buttons during animation
    if self.PagingButtons then
        if self.PagingButtons.Prev then
            self.PagingButtons.Prev:Disable()
        end
        if self.PagingButtons.Next then
            self.PagingButtons.Next:Disable()
        end
    end

    -- Create animation frame if needed
    if not self.fadeAnimationFrame then
        self.fadeAnimationFrame = CreateFrame("Frame")
    end

    -- Variables for animation
    local fadeOutDuration = self.config.fadeOutDuration
    local fadeInDuration = self.config.fadeInDuration
    local animationDelay = self.config.animationDelay
    local startTime = GetTime()
    local currentViewFrames = {}

    -- Copy frames to animate
    for _, viewFrame in ipairs(self.ViewFrames) do
        table.insert(currentViewFrames, viewFrame)
    end

    -- Store reference to current object
    local currentContainer = self
    local newData = dataProvider

    -- Mark time of last animation
    self.lastFadeTime = currentTime

    -- Fade animation
    local function FadeAnimation(animFrame, elapsed)
        local currentTime = GetTime()
        local elapsedTime = currentTime - startTime

        -- Fade Out Phase
        if elapsedTime < fadeOutDuration then
            local alpha = 1 - (elapsedTime / fadeOutDuration)
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(alpha)
            end

            -- Small delay
        elseif elapsedTime >= fadeOutDuration and elapsedTime < (fadeOutDuration + animationDelay) then
            -- Wait

            -- Content change
        elseif elapsedTime >= (fadeOutDuration + animationDelay) and
                elapsedTime <= (fadeOutDuration + animationDelay + 0.01) then
            -- Explicitly change content
            currentContainer:SetDataProvider(newData, true)

            -- Fade In Phase
        elseif elapsedTime < (fadeOutDuration + animationDelay + fadeInDuration) then
            local fadeInProgress = (elapsedTime - (fadeOutDuration + animationDelay)) / fadeInDuration
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(fadeInProgress)
            end

            -- End of animation
        else
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(1)
            end
            animFrame:SetScript("OnUpdate", nil)

            -- Mark end of animation
            currentContainer.isAnimating = false

            -- Reactivate pagination buttons based on current position
            currentContainer:UpdatePagingButtons()
        end
    end

    -- Start animation
    self.fadeAnimationFrame:SetScript("OnUpdate", FadeAnimation)
end


-- Improved UpdatePagingButtons
function PagedContentFrameMixin:UpdatePagingButtons()
    if not self.PagingButtons then return end

    -- Disable previous button on first page
    if self.currentPage <= 1 then
        self.PagingButtons.Prev:Disable()
    else
        self.PagingButtons.Prev:Enable()
    end

    -- Disable next button on last page
    if self.currentPage >= self.maxPages then
        self.PagingButtons.Next:Disable()
    else
        self.PagingButtons.Next:Enable()
    end

    -- Update page text if available
    if self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Set a fallback function for empty data
 *
 * @param fallbackFunc function Function that returns a replacement dataProvider
 * @return void
]]
function PagedContentFrameMixin:SetEmptyDataProviderFallback(fallbackFunc)
    self.emptyDataProviderFallback = fallbackFunc
end

--[[
 * Display elements for current page
 * This method uses the appropriate renderer based on render mode
 *
 * @return void
]]
function PagedContentFrameMixin:DisplayCurrentPage()
    -- Debug trace
    if self.debug then
        print(string.format("Displaying page %d of %d", self.currentPage, self.maxPages))
    end

    -- Release pools
    self:ReleaseAllPools()

    -- Verify data validity
    if not self.viewDataList or #self.viewDataList == 0 then
        return
    end

    -- Render based on configured mode
    if self.renderMode == PagedContent.RenderMode.CUSTOM and self.customRenderer then
        -- Custom render
        for viewIndex = 1, self.viewsPerPage do
            local viewDataIndex = ((self.currentPage - 1) * self.viewsPerPage) + viewIndex
            local viewData = self.viewDataList[viewDataIndex]

            if viewData then
                local viewFrame = self.ViewFrames[viewIndex]
                self.customRenderer(self, viewFrame, viewData)
            end
        end
    elseif self.renderMode == PagedContent.RenderMode.GRID then
        -- Grid render
        self:RenderGridLayout()
    else
        -- List render
        self:RenderListLayout()
    end

    -- Update pagination buttons
    self:UpdatePagingButtons()

    -- IMPORTANT: Force pagination text update
    self:UpdatePageText()

    -- Trigger page change event
    self:TriggerCallback("OnPageChanged")
end

-- Add dedicated method to update pagination text
function PagedContentFrameMixin:UpdatePageText()
    -- If pagination text exists
    if self.PageText then
        self.PageText:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))

        -- If text is in pagination buttons
    elseif self.PagingButtons and self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end

    -- Debug trace
    if self.debug then
        print(string.format("Pagination text updated: Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Render elements in list mode
 *
 * @return void
]]
function PagedContentFrameMixin:RenderListLayout()
    for viewIndex = 1, self.viewsPerPage do
        local viewDataIndex = ((self.currentPage - 1) * self.viewsPerPage) + viewIndex
        local viewData = self.viewDataList[viewDataIndex]

        if viewData then
            local viewFrame = self.ViewFrames[viewIndex]
            local yOffset = 0

            for _, elementData in ipairs(viewData) do
                local templateKey = elementData.templateKey
                local templateInfo = self.elementTemplateData[templateKey]

                if not templateInfo then
                    error(string.format("Template not found for key: %s", templateKey))
                end

                local pool = self:GetOrCreatePool(templateInfo.template)
                local frame = pool:Acquire()
                frame:SetParent(viewFrame)
                frame:ClearAllPoints()

                -- Position and initialize element
                frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 0, -yOffset)
                frame:SetPoint("RIGHT", viewFrame, "RIGHT", 0, 0)

                if templateInfo.initFunc then
                    templateInfo.initFunc(frame, elementData)
                end

                frame:Show()

                -- Update vertical position
                if templateKey == "Header" or elementData._isHeader then
                    yOffset = yOffset + self.config.headerHeight + self.config.headerBottomMargin
                else
                    yOffset = yOffset + self.config.itemHeight
                end
            end
        end
    end
end

--[[
 * Render elements in grid mode
 *
 * @return void
]]
function PagedContentFrameMixin:RenderGridLayout()
    for viewIndex = 1, self.viewsPerPage do
        local viewDataIndex = ((self.currentPage - 1) * self.viewsPerPage) + viewIndex
        local viewData = self.viewDataList[viewDataIndex]

        if viewData then
            local viewFrame = self.ViewFrames[viewIndex]
            local yOffset = 0
            local currentColumn = 0

            for i, elementData in ipairs(viewData) do
                local templateKey = elementData.templateKey
                local templateInfo = self.elementTemplateData[templateKey]

                if not templateInfo then
                    error(string.format("Template not found for key: %s", templateKey))
                end

                local pool = self:GetOrCreatePool(templateInfo.template)
                local frame = pool:Acquire()
                frame:SetParent(viewFrame)
                frame:ClearAllPoints()

                -- If it's a header or marked as such
                if templateKey == "Header" or elementData._isHeader then
                    -- If we were filling a row
                    if currentColumn > 0 then
                        yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
                        currentColumn = 0
                    end

                    -- Add space before header
                    yOffset = yOffset + self.config.headerTopMargin

                    frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 0, -yOffset)
                    frame:SetPoint("RIGHT", viewFrame, "RIGHT", 0, 0)

                    if templateInfo.initFunc then
                        templateInfo.initFunc(frame, elementData)
                    end

                    frame:Show()
                    yOffset = yOffset + self.config.headerHeight + self.config.headerBottomMargin
                else
                    -- For normal element, use grid layout
                    local xOffset = currentColumn * (self.config.columnWidth + self.config.columnSpacing)
                    frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", xOffset, -yOffset)
                    frame:SetWidth(self.config.columnWidth)

                    if templateInfo.initFunc then
                        templateInfo.initFunc(frame, elementData)
                    end

                    frame:Show()

                    -- Column and row management
                    currentColumn = currentColumn + 1
                    if currentColumn >= self.config.maxColumnsPerRow or
                            (elementData._gridPosition and elementData._gridPosition == elementData._gridSize) then
                        currentColumn = 0
                        yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
                    end
                end
            end

            -- Ensure last row is fully displayed
            if currentColumn > 0 then
                yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
            end
        end
    end
end

--[[
 * Update pagination button state
 *
 * @return void
]]
function PagedContentFrameMixin:UpdatePagingButtons()
    if not self.PagingButtons then return end

    -- Handle Previous button
    if self.currentPage <= 1 then
        self.PagingButtons.Prev:Disable()
    else
        self.PagingButtons.Prev:Enable()
    end

    -- Handle Next button
    if self.currentPage >= self.maxPages then
        self.PagingButtons.Next:Disable()
    else
        self.PagingButtons.Next:Enable()
    end

    -- Update pagination text (if present in buttons)
    if self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Get or create a frame pool for given template
 *
 * @param template string Template name
 * @return table Frame pool
]]
function PagedContentFrameMixin:GetOrCreatePool(template)
    if not self.pools[template] then
        self.pools[template] = PagedContent:CreateFramePool("Button", self, template)
    end
    return self.pools[template]
end

--[[
 * Release all frame pools
 *
 * @return void
]]
function PagedContentFrameMixin:ReleaseAllPools()
    for _, pool in pairs(self.pools) do
        pool:ReleaseAll()
    end
end

--[[
 * Change current page without animation
 *
 * @param pageNum number Target page number
 * @return void
]]
function PagedContentFrameMixin:SetCurrentPage(pageNum)
    -- Validate requested page
    pageNum = math.max(1, math.min(pageNum, self.maxPages))

    -- Update current page and display
    if self.currentPage ~= pageNum then
        self.currentPage = pageNum
        self:DisplayCurrentPage()

        -- Update pagination buttons
        if self.PagingButtons then
            if self.currentPage <= 1 then
                self.PagingButtons.Prev:Disable()
            else
                self.PagingButtons.Prev:Enable()
            end

            if self.currentPage >= self.maxPages then
                self.PagingButtons.Next:Disable()
            else
                self.PagingButtons.Next:Enable()
            end
        end

        -- Update pagination text
        if self.PageText then
            self.PageText:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
        end

        -- Trigger page change event
        self:TriggerCallback("OnPageChanged")

        return true
    end

    return false
end

--[[
 * Create basic pagination controls
 *
 * @return void
]]
function PagedContentFrameMixin:CreatePagingControls()
    -- Create navigation buttons
    local prev = CreateFrame("Button", nil, self)
    prev:SetSize(32, 590)
    prev:SetPoint("LEFT", self, "LEFT", -2, -25)
    prev:SetFrameStrata("TOOLTIP")

    prev:SetScript("OnClick", function()
        local currentPage = self.currentPage
        if currentPage > 1 then
            self:SetCurrentPageWithFade(currentPage - 1)
        end
    end)

    local next = CreateFrame("Button", nil, self)
    next:SetSize(32, 590)
    next:SetPoint("RIGHT", self, "RIGHT", -2, -25)

    next:SetScript("OnEnter", function()
        SpellBookCorner_OnEnter(PlayerSpellsFrame.BookCornerFlipbook)
    end)

    next:SetScript("OnLeave", function()
        SpellBookCorner_OnLeave(PlayerSpellsFrame.BookCornerFlipbook)
    end)

    next:SetScript("OnClick", function()
        if self.SetCurrentPageWithFade then
            self:SetCurrentPageWithFade(self.currentPage + 1)
        else
            self:SetCurrentPage(self.currentPage + 1)
        end
    end)

    self.PagingButtons = {
        Prev = prev,
        Next = next
    }
end

--[[
 * Register callback function for an event
 *
 * @param event string Event name
 * @param callback function Callback function
 * @return void
]]
function PagedContentFrameMixin:RegisterCallback(event, callback)
    self.callbacks[event] = callback
end

--[[
 * Trigger callback for an event
 *
 * @param event string Event name
 * @param ... any Additional arguments to pass to callback
 * @return void
]]
function PagedContentFrameMixin:TriggerCallback(event, ...)
    if self.callbacks[event] then
        self.callbacks[event](self, ...)
    end
end

--[[
 * Configure render parameters
 *
 * @param config table Configuration to apply
 * @return void
]]
function PagedContentFrameMixin:Configure(config)
    if not config then return end

    for k, v in pairs(config) do
        self.config[k] = v
    end

    -- Update if needed
    if self.dataProvider then
        self:UpdateElementDistribution()
        self:DisplayCurrentPage()
    end
end

--[[
 * Enable debug mode to facilitate troubleshooting
 *
 * @param enable boolean Whether to enable debug mode
 * @return void
]]
function PagedContentFrameMixin:EnableDebug(enable)
    self.debug = enable or false
end