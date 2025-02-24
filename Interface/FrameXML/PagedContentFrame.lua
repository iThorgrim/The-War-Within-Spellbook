--[[
 * PagedContentFrame pour WoW 3.3.5a
 * Un système de pagination modulaire et générique pour afficher des éléments sur plusieurs pages
 *
 * @version 2.0
 * @author iThorgrim (Refactored by Claude)
 *
 * Système conçu pour être réutilisable dans différents types d'addons
]]

-- Namespace global pour le framework
PagedContent = PagedContent or {}

-- Mixin principal
PagedContentFrameMixin = {}

-- Configuration par défaut
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

-- Options de rendu
PagedContent.RenderMode = {
    LIST = "LIST",          -- Affichage vertical en liste
    GRID = "GRID",          -- Affichage en grille
    CUSTOM = "CUSTOM"       -- Mode personnalisé (requiert un renderer)
}

--[[
 * Système de Pool pour la réutilisation des frames
 *
 * @param frameType string Type de frame à créer
 * @param parent table Parent pour les nouvelles frames
 * @param template string Template à utiliser (facultatif)
 * @return table Instance du pool
]]
function PagedContent:CreateFramePool(frameType, parent, template)
    local pool = {
        frameType = frameType,
        parent = parent,
        template = template,
        numActive = 0,
        frames = {},

        -- Acquérir une frame du pool
        Acquire = function(self)
            self.numActive = self.numActive + 1

            if not self.frames[self.numActive] then
                self.frames[self.numActive] = CreateFrame(self.frameType, nil, self.parent, self.template)
            end

            local frame = self.frames[self.numActive]
            frame:Show()
            return frame
        end,

        -- Libérer toutes les frames
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
 * Initialisation du mixin PagedContent
 *
 * @return void
]]
function PagedContentFrameMixin:OnLoad()
    self.pools = {}
    self.frames = {}
    self.isAnimating = false

    -- Fusionner avec la configuration par défaut
    self.config = self.config or {}
    for k, v in pairs(PagedContent.DefaultConfig) do
        if self.config[k] == nil then
            self.config[k] = v
        end
    end

    -- Utiliser les ViewFrames fournis ou créer des frames par défaut
    if not self.ViewFrames or #self.ViewFrames == 0 then
        self:CreateDefaultViewFrames()
    end

    self.viewsPerPage = self.config.viewsPerPage or #self.ViewFrames
    self.currentPage = 1
    self.maxPages = 1
    self.renderMode = self.renderMode or PagedContent.RenderMode.LIST

    -- Callbacks et événements
    self.callbacks = {}

    -- Créer les contrôles de pagination par défaut si nécessaire
    if not self.noPagingControls then
        self:CreatePagingControls()
    end
end

--[[
 * Crée des ViewFrames par défaut si aucun n'est fourni
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
 * Définit les templates d'éléments à utiliser
 *
 * @param templateData table Données des templates
 * @return void
]]
function PagedContentFrameMixin:SetElementTemplateData(templateData)
    self.elementTemplateData = templateData
end

--[[
 * Configure un mode de rendu personnalisé
 *
 * @param renderer function Fonction de rendu personnalisée
 * @return void
]]
function PagedContentFrameMixin:SetCustomRenderer(renderer)
    self.customRenderer = renderer
    self.renderMode = PagedContent.RenderMode.CUSTOM
end

--[[
 * Définit le provider de données
 *
 * @param dataProvider table Données à afficher
 * @param preservePage boolean Conserver la page actuelle (facultatif)
 * @return void
]]
function PagedContentFrameMixin:SetDataProvider(dataProvider, preservePage)
    if not self.elementTemplateData then
        error("SetElementTemplateData doit être appelé avant SetDataProvider")
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
 * Met à jour la distribution des éléments sur les pages
 *
 * @return void
]]
function PagedContentFrameMixin:UpdateElementDistribution()
    -- Utiliser la méthode de distribution appropriée selon le mode de rendu
    if self.renderMode == PagedContent.RenderMode.LIST then
        self.viewDataList = self:SplitElementsIntoViews()
    elseif self.renderMode == PagedContent.RenderMode.GRID then
        self.viewDataList = self:SplitElementsIntoGrid()
    elseif self.renderMode == PagedContent.RenderMode.CUSTOM and self.customSplitter then
        self.viewDataList = self.customSplitter(self.dataProvider, self.config)
    else
        -- Par défaut, utiliser le mode liste
        self.viewDataList = self:SplitElementsIntoViews()
    end

    -- Mettre à jour le nombre maximal de pages
    self.maxPages = math.max(1, math.ceil(#self.viewDataList / self.viewsPerPage))

    -- Valider la page courante
    if self.currentPage > self.maxPages then
        self.currentPage = self.maxPages
    end
end

--[[
 * Répartit les éléments en vues pour le mode liste
 *
 * @return table Liste des vues avec leurs éléments
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

    -- Ajouter la dernière vue si non vide
    if #currentView > 0 then
        table.insert(views, currentView)
    end

    return views
end

--[[
 * Répartit les éléments en vues pour le mode grille
 *
 * @return table Liste des vues avec leurs éléments en grille
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
            -- Si la vue est pleine, en créer une nouvelle
            if currentHeight + headerHeight > viewHeight or #currentView >= maxItemsPerView then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            -- Ajouter le header
            group.header._isHeader = true
            table.insert(currentView, group.header)
            currentHeight = currentHeight + headerHeight
        end

        -- Traiter les éléments par rangées pour le mode grille
        local elementsCount = #(group.elements or {})
        local currentPos = 0

        while currentPos < elementsCount do
            local remainingInRow = math.min(itemsPerRow, elementsCount - currentPos)

            -- Vérifier si on a besoin d'une nouvelle vue
            if currentHeight + itemHeight > viewHeight or #currentView + remainingInRow > maxItemsPerView then
                table.insert(views, currentView)
                currentView = {}
                currentHeight = 0
            end

            -- Ajouter les éléments de cette rangée
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

    -- Ajouter la dernière vue si non vide
    if #currentView > 0 then
        table.insert(views, currentView)
    end

    return views
end

--[[
 * Change de page avec animation de fondu
 *
 * @param pageNum number Numéro de la page cible
 * @return void
]]
function PagedContentFrameMixin:SetCurrentPageWithFade(pageNum)
    -- Valider la page demandée
    pageNum = math.max(1, math.min(pageNum, self.maxPages))

    -- Ne rien faire si on est déjà sur cette page
    if self.currentPage == pageNum then
        return
    end

    -- Arrêter toute animation en cours
    if self.isAnimating then
        -- Arrêter les frames d'animation existantes
        if self.fadeInFrame then
            self.fadeInFrame:SetScript("OnUpdate", nil)
            self.fadeInFrame = nil
        end

        if self.fadeOutFrame then
            self.fadeOutFrame:SetScript("OnUpdate", nil)
            self.fadeOutFrame = nil
        end

        -- Restaurer l'alpha de tous les viewFrames à 1
        for _, viewFrame in ipairs(self.ViewFrames) do
            viewFrame:SetAlpha(1)
        end
    end

    -- Marquer comme animation en cours
    self.isAnimating = true

    -- Désactiver les boutons de pagination pendant l'animation
    if self.PagingButtons then
        if self.PagingButtons.Prev then
            self.PagingButtons.Prev:Disable()
        end
        if self.PagingButtons.Next then
            self.PagingButtons.Next:Disable()
        end
    end

    -- Préparer les frames à animer
    local viewFrames = {}
    for _, viewFrame in ipairs(self.ViewFrames) do
        table.insert(viewFrames, viewFrame)
    end

    -- Enregistrer une référence au conteneur
    local container = self
    local targetPage = pageNum

    -- Fonction pour réactiver les boutons à la fin de l'animation
    local function reactivateButtons()
        if container.PagingButtons then
            -- Réactiver en fonction de la nouvelle page
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

        -- Marquer l'animation comme terminée
        container.isAnimating = false
    end

    -- Fonction de fade-in
    local function startFadeIn()
        local startTime = GetTime()
        local duration = 0.2

        -- Arrêter l'ancien frame fadeIn s'il existe
        if container.fadeInFrame then
            container.fadeInFrame:SetScript("OnUpdate", nil)
        end

        container.fadeInFrame = CreateFrame("Frame")
        container.fadeInFrame:SetScript("OnUpdate", function(self, elapsed)
            local progress = (GetTime() - startTime) / duration

            if progress >= 1 then
                -- Une fois le fade-in terminé, rétablir l'alpha à 1
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(1)
                end

                -- Réactiver les boutons
                reactivateButtons()

                -- Nettoyer
                container.fadeInFrame = nil

                -- Arrêter cette animation
                self:SetScript("OnUpdate", nil)
            else
                -- Mettre à jour l'alpha pendant le fade-in
                local alpha = progress
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(alpha)
                end
            end
        end)
    end

    -- Fonction de fade-out
    -- Arrêter l'ancien frame fadeOut s'il existe
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
                -- Une fois le fade-out terminé, changer la page et lancer le fade-in
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(0)
                end

                -- IMPORTANT: changer la page actuelle
                container.currentPage = targetPage
                container:DisplayCurrentPage()

                -- Nettoyer
                container.fadeOutFrame = nil

                -- Lancer le fade-in
                startFadeIn()

                -- Arrêter cette animation
                self:SetScript("OnUpdate", nil)
            else
                -- Mettre à jour l'alpha pendant le fade-out
                local alpha = 1 - progress
                for _, viewFrame in ipairs(viewFrames) do
                    viewFrame:SetAlpha(alpha)
                end
            end
        end)
    end)
end

--[[
 * Change le provider de données avec animation de fondu
 *
 * @param dataProvider table Nouvelles données à afficher
 * @return void
]]
function PagedContentFrameMixin:SetDataProviderWithFade(dataProvider)
    -- Protection contre les animations multiples trop rapprochées
    local currentTime = GetTime()
    if self.lastFadeTime and (currentTime - self.lastFadeTime) < self.config.throttleTime then
        -- Mettre à jour directement sans animation
        self:SetDataProvider(dataProvider, true)
        return
    end

    if self.isAnimating then
        if self.fadeAnimationFrame then
            self.fadeAnimationFrame:SetScript("OnUpdate", nil)
        end
        self.isAnimating = false
    end

    -- Valider le dataProvider
    if not dataProvider then return end

    -- Si vide et qu'un fallback est défini, utiliser le fallback
    if #dataProvider == 0 and self.emptyDataProviderFallback then
        dataProvider = self.emptyDataProviderFallback()
    end

    -- Marquer le début de l'animation
    self.isAnimating = true

    -- Désactiver les boutons de pagination pendant l'animation
    if self.PagingButtons then
        if self.PagingButtons.Prev then
            self.PagingButtons.Prev:Disable()
        end
        if self.PagingButtons.Next then
            self.PagingButtons.Next:Disable()
        end
    end

    -- Créer un frame d'animation si nécessaire
    if not self.fadeAnimationFrame then
        self.fadeAnimationFrame = CreateFrame("Frame")
    end

    -- Variables pour l'animation
    local fadeOutDuration = self.config.fadeOutDuration
    local fadeInDuration = self.config.fadeInDuration
    local animationDelay = self.config.animationDelay
    local startTime = GetTime()
    local currentViewFrames = {}

    -- Copier les frames à animer
    for _, viewFrame in ipairs(self.ViewFrames) do
        table.insert(currentViewFrames, viewFrame)
    end

    -- Stocker une référence à l'objet courant
    local currentContainer = self
    local newData = dataProvider

    -- Marquer le temps de la dernière animation
    self.lastFadeTime = currentTime

    -- Animation de fondu
    local function FadeAnimation(animFrame, elapsed)
        local currentTime = GetTime()
        local elapsedTime = currentTime - startTime

        -- Phase de Fade Out
        if elapsedTime < fadeOutDuration then
            local alpha = 1 - (elapsedTime / fadeOutDuration)
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(alpha)
            end

            -- Petit délai
        elseif elapsedTime >= fadeOutDuration and elapsedTime < (fadeOutDuration + animationDelay) then
            -- Attendre

            -- Changement de contenu
        elseif elapsedTime >= (fadeOutDuration + animationDelay) and
                elapsedTime <= (fadeOutDuration + animationDelay + 0.01) then
            -- Changer le contenu explicitement
            currentContainer:SetDataProvider(newData, true)

            -- Phase de Fade In
        elseif elapsedTime < (fadeOutDuration + animationDelay + fadeInDuration) then
            local fadeInProgress = (elapsedTime - (fadeOutDuration + animationDelay)) / fadeInDuration
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(fadeInProgress)
            end

            -- Fin de l'animation
        else
            for _, viewFrame in ipairs(currentViewFrames) do
                viewFrame:SetAlpha(1)
            end
            animFrame:SetScript("OnUpdate", nil)

            -- Marquer la fin de l'animation
            currentContainer.isAnimating = false

            -- Réactiver les boutons de pagination selon la position actuelle
            currentContainer:UpdatePagingButtons()
        end
    end

    -- Démarrer l'animation
    self.fadeAnimationFrame:SetScript("OnUpdate", FadeAnimation)
end


-- Amélioration de UpdatePagingButtons
function PagedContentFrameMixin:UpdatePagingButtons()
    if not self.PagingButtons then return end

    -- Désactiver le bouton précédent sur la première page
    if self.currentPage <= 1 then
        self.PagingButtons.Prev:Disable()
    else
        self.PagingButtons.Prev:Enable()
    end

    -- Désactiver le bouton suivant sur la dernière page
    if self.currentPage >= self.maxPages then
        self.PagingButtons.Next:Disable()
    else
        self.PagingButtons.Next:Enable()
    end

    -- Mettre à jour le texte de la page si disponible
    if self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Définit une fonction de fallback pour les données vides
 *
 * @param fallbackFunc function Fonction qui retourne un dataProvider de remplacement
 * @return void
]]
function PagedContentFrameMixin:SetEmptyDataProviderFallback(fallbackFunc)
    self.emptyDataProviderFallback = fallbackFunc
end

--[[
 * Affiche les éléments pour la page courante
 * Cette méthode utilise le renderer approprié selon le mode de rendu
 *
 * @return void
]]
function PagedContentFrameMixin:DisplayCurrentPage()
    -- Trace de débogage
    if self.debug then
        print(string.format("Affichage de la page %d sur %d", self.currentPage, self.maxPages))
    end

    -- Libérer les pools
    self:ReleaseAllPools()

    -- Vérifier la validité des données
    if not self.viewDataList or #self.viewDataList == 0 then
        return
    end

    -- Effectuer le rendu selon le mode configuré
    if self.renderMode == PagedContent.RenderMode.CUSTOM and self.customRenderer then
        -- Rendu personnalisé
        for viewIndex = 1, self.viewsPerPage do
            local viewDataIndex = ((self.currentPage - 1) * self.viewsPerPage) + viewIndex
            local viewData = self.viewDataList[viewDataIndex]

            if viewData then
                local viewFrame = self.ViewFrames[viewIndex]
                self.customRenderer(self, viewFrame, viewData)
            end
        end
    elseif self.renderMode == PagedContent.RenderMode.GRID then
        -- Rendu en grille
        self:RenderGridLayout()
    else
        -- Rendu en liste
        self:RenderListLayout()
    end

    -- Mettre à jour les boutons de pagination
    self:UpdatePagingButtons()

    -- IMPORTANT: Forcer la mise à jour du texte de pagination
    self:UpdatePageText()

    -- Déclencher l'événement de changement de page
    self:TriggerCallback("OnPageChanged")
end

-- Ajoute une méthode dédiée pour mettre à jour le texte de pagination
function PagedContentFrameMixin:UpdatePageText()
    -- Si un texte de pagination existe
    if self.PageText then
        self.PageText:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))

        -- Si le texte est dans les boutons de pagination
    elseif self.PagingButtons and self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end

    -- Trace de débogage
    if self.debug then
        print(string.format("Texte de pagination mis à jour: Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Rend les éléments en mode liste
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
                    error(string.format("Template non trouvé pour la clé: %s", templateKey))
                end

                local pool = self:GetOrCreatePool(templateInfo.template)
                local frame = pool:Acquire()
                frame:SetParent(viewFrame)
                frame:ClearAllPoints()

                -- Positionner et initialiser l'élément
                frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 0, -yOffset)
                frame:SetPoint("RIGHT", viewFrame, "RIGHT", 0, 0)

                if templateInfo.initFunc then
                    templateInfo.initFunc(frame, elementData)
                end

                frame:Show()

                -- Mise à jour de la position verticale
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
 * Rend les éléments en mode grille
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
                    error(string.format("Template non trouvé pour la clé: %s", templateKey))
                end

                local pool = self:GetOrCreatePool(templateInfo.template)
                local frame = pool:Acquire()
                frame:SetParent(viewFrame)
                frame:ClearAllPoints()

                -- Si c'est un header ou marqué comme tel
                if templateKey == "Header" or elementData._isHeader then
                    -- Si on était en train de remplir une ligne
                    if currentColumn > 0 then
                        yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
                        currentColumn = 0
                    end

                    -- Ajouter de l'espace avant le header
                    yOffset = yOffset + self.config.headerTopMargin

                    frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 0, -yOffset)
                    frame:SetPoint("RIGHT", viewFrame, "RIGHT", 0, 0)

                    if templateInfo.initFunc then
                        templateInfo.initFunc(frame, elementData)
                    end

                    frame:Show()
                    yOffset = yOffset + self.config.headerHeight + self.config.headerBottomMargin
                else
                    -- Pour un élément normal, utiliser la mise en page en grille
                    local xOffset = currentColumn * (self.config.columnWidth + self.config.columnSpacing)
                    frame:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", xOffset, -yOffset)
                    frame:SetWidth(self.config.columnWidth)

                    if templateInfo.initFunc then
                        templateInfo.initFunc(frame, elementData)
                    end

                    frame:Show()

                    -- Gestion des colonnes et lignes
                    currentColumn = currentColumn + 1
                    if currentColumn >= self.config.maxColumnsPerRow or
                            (elementData._gridPosition and elementData._gridPosition == elementData._gridSize) then
                        currentColumn = 0
                        yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
                    end
                end
            end

            -- S'assurer que la dernière ligne est complètement affichée
            if currentColumn > 0 then
                yOffset = yOffset + self.config.rowHeight + self.config.rowSpacing
            end
        end
    end
end

--[[
 * Met à jour l'état des boutons de pagination
 *
 * @return void
]]
function PagedContentFrameMixin:UpdatePagingButtons()
    if not self.PagingButtons then return end

    -- Gérer le bouton Précédent
    if self.currentPage <= 1 then
        self.PagingButtons.Prev:Disable()
    else
        self.PagingButtons.Prev:Enable()
    end

    -- Gérer le bouton Suivant
    if self.currentPage >= self.maxPages then
        self.PagingButtons.Next:Disable()
    else
        self.PagingButtons.Next:Enable()
    end

    -- Mettre à jour le texte de pagination (si présent dans les boutons)
    if self.PagingButtons.Text then
        self.PagingButtons.Text:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
    end
end

--[[
 * Obtient ou crée un pool de frames pour un template donné
 *
 * @param template string Nom du template
 * @return table Pool de frames
]]
function PagedContentFrameMixin:GetOrCreatePool(template)
    if not self.pools[template] then
        self.pools[template] = PagedContent:CreateFramePool("Button", self, template)
    end
    return self.pools[template]
end

--[[
 * Libère tous les pools de frames
 *
 * @return void
]]
function PagedContentFrameMixin:ReleaseAllPools()
    for _, pool in pairs(self.pools) do
        pool:ReleaseAll()
    end
end

--[[
 * Change la page courante sans animation
 *
 * @param pageNum number Numéro de la page cible
 * @return void
]]
function PagedContentFrameMixin:SetCurrentPage(pageNum)
    -- Valider la page demandée
    pageNum = math.max(1, math.min(pageNum, self.maxPages))

    -- Mettre à jour la page actuelle et l'affichage
    if self.currentPage ~= pageNum then
        self.currentPage = pageNum
        self:DisplayCurrentPage()

        -- Mettre à jour les boutons de pagination
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

        -- Mettre à jour le texte de pagination
        if self.PageText then
            self.PageText:SetText(string.format("Page %d / %d", self.currentPage, self.maxPages))
        end

        -- Déclencher l'événement de changement de page
        self:TriggerCallback("OnPageChanged")

        return true
    end

    return false
end

--[[
 * Crée les contrôles de pagination de base
 *
 * @return void
]]
function PagedContentFrameMixin:CreatePagingControls()
    -- Création des boutons de navigation
    local prev = CreateFrame("Button", nil, self)
    prev:SetSize(32, 32)
    prev:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 10, 10)
    prev:SetScript("OnClick", function()
        if self.SetCurrentPageWithFade then
            self:SetCurrentPageWithFade(self.currentPage - 1)
        else
            self:SetCurrentPage(self.currentPage - 1)
        end
    end)

    local next = CreateFrame("Button", nil, self)
    next:SetSize(32, 32)
    next:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -10, 10)
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
 * Enregistre une fonction de callback pour un événement
 *
 * @param event string Nom de l'événement
 * @param callback function Fonction de callback
 * @return void
]]
function PagedContentFrameMixin:RegisterCallback(event, callback)
    self.callbacks[event] = callback
end

--[[
 * Déclenche un callback pour un événement
 *
 * @param event string Nom de l'événement
 * @param ... any Arguments supplémentaires à passer au callback
 * @return void
]]
function PagedContentFrameMixin:TriggerCallback(event, ...)
    if self.callbacks[event] then
        self.callbacks[event](self, ...)
    end
end

--[[
 * Configure les paramètres de rendu
 *
 * @param config table Configuration à appliquer
 * @return void
]]
function PagedContentFrameMixin:Configure(config)
    if not config then return end

    for k, v in pairs(config) do
        self.config[k] = v
    end

    -- Mettre à jour si nécessaire
    if self.dataProvider then
        self:UpdateElementDistribution()
        self:DisplayCurrentPage()
    end
end

-- Active le mode debug pour faciliter le dépannage
function PagedContentFrameMixin:EnableDebug(enable)
    self.debug = enable or false
end