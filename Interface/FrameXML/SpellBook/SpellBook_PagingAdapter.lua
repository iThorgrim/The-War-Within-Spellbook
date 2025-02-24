-- Créer le module Adapter
SpellBook_PagingAdapter = {}

--[[
 * Initialise l'adaptateur et s'assure que le SpellBook est compatible
 * avec la nouvelle version de PagedContentFrame
 *
 * @return void
]]
function SpellBook_PagingAdapter:Initialize()
    self:SetupCompatibility()
end

--[[
 * Configure la compatibilité entre le nouveau système de pagination
 * et les frames SpellBook existantes
 *
 * @return void
]]
function SpellBook_PagingAdapter:SetupCompatibility()
    if not SpellBook_UI or not SpellBook_UI.PlayerFrame then
        print("SpellBook: L'adaptateur de pagination n'a pas pu trouver le frame du joueur")
        return
    end

    local frame = SpellBook_UI.PlayerFrame
    local spellBookFrame = frame.SpellBookFrame

    if not spellBookFrame then
        print("SpellBook: Frame du grimoire introuvable")
        return
    end

    -- Configurer le mode de rendu
    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    -- Configuration pour la compatibilité
    local config = {
        viewsPerPage = 2,
        itemsPerView = 25,
        columnWidth = 130,
        columnSpacing = 30,
        rowHeight = 35,
        rowSpacing = 15,
        headerHeight = 30,
        headerBottomMargin = 10,
        headerTopMargin = 15,
        maxColumnsPerRow = 3,
        fadeOutDuration = 0.2,
        fadeInDuration = 0.2,
        animationDelay = 0.1,
        throttleTime = 1.0,
        -- Nombre de sorts supplémentaires à afficher quand il n'y a pas de header
        extraRowsWithoutHeader = 2
    }

    -- Appliquer la configuration
    spellBookFrame:Configure(config)

    -- Remplacer la méthode de distribution des éléments pour prendre en compte les lignes supplémentaires
    self:ApplyCustomDistribution(spellBookFrame)

    -- Définir un fallback pour les données vides (en cas de recherche sans résultat)
    spellBookFrame:SetEmptyDataProviderFallback(function()
        return SpellBook_SpellFilter:FilterAllSpells()
    end)

    -- Adapter les méthodes existantes pour préserver la compatibilité
    self:AdaptMethods(spellBookFrame)
end

function SpellBook_PagingAdapter:ApplyCustomDistribution(spellBookFrame)
    if not spellBookFrame.originalSplitElementsIntoGrid then
        spellBookFrame.originalSplitElementsIntoGrid = spellBookFrame.SplitElementsIntoGrid
    end

    -- Nouvelle méthode qui prend en compte les lignes supplémentaires
    spellBookFrame.SplitElementsIntoGrid = function(self)
        local views = {}
        local currentView = {}
        local currentHeight = 0
        local viewHeight = self.ViewFrames[1]:GetHeight()

        -- Configuration adaptative
        local headerHeight = self.config.headerHeight or 30
        local headerTopMargin = self.config.headerTopMargin or 15
        local headerBottomMargin = self.config.headerBottomMargin or 10
        local rowHeight = self.config.rowHeight or 35
        local rowSpacing = self.config.rowSpacing or 15
        local itemsPerRow = self.config.maxColumnsPerRow or 3

        -- Nombre de sorts par défaut et supplémentaires
        local baseMaxItemsPerView = self.config.itemsPerView or 25
        local extraRows = self.config.extraRowsWithoutHeader or 2
        local extraItemsWithoutHeader = extraRows * itemsPerRow

        -- Variable pour suivre si la vue courante contient un header
        local currentViewHasHeader = false

        for _, group in ipairs(self.dataProvider) do
            -- Vérifier si ce groupe contient un header
            local hasHeader = (group.header ~= nil)
            local elementsCount = #(group.elements or {})

            -- Si ce groupe a un header
            if hasHeader then
                -- Vérifier s'il y a assez d'espace pour le header
                if currentHeight + headerHeight + headerTopMargin + headerBottomMargin > viewHeight or
                        #currentView >= baseMaxItemsPerView then
                    -- Terminer la vue actuelle et en commencer une nouvelle
                    if #currentView > 0 then
                        table.insert(views, currentView)
                        currentView = {}
                        currentHeight = 0
                        currentViewHasHeader = false
                    end
                end

                -- Ajouter le header à la vue
                group.header._isHeader = true
                table.insert(currentView, group.header)
                currentHeight = currentHeight + headerHeight + headerTopMargin + headerBottomMargin
                currentViewHasHeader = true

                -- Limiter au nombre de base d'éléments
                maxItemsPerView = baseMaxItemsPerView
            elseif not currentViewHasHeader and #currentView == 0 then
                -- Si cette vue n'a pas encore de header, on peut afficher plus d'éléments
                maxItemsPerView = baseMaxItemsPerView + extraItemsWithoutHeader
            end

            -- Traiter les éléments par rangées pour le mode grille
            local currentPos = 0

            while currentPos < elementsCount do
                local remainingInRow = math.min(itemsPerRow, elementsCount - currentPos)

                -- Vérifier si on a besoin d'une nouvelle vue
                if currentHeight + rowHeight + rowSpacing > viewHeight or
                        #currentView + remainingInRow > maxItemsPerView then
                    -- Terminer la vue actuelle et en commencer une nouvelle
                    table.insert(views, currentView)
                    currentView = {}
                    currentHeight = 0
                    currentViewHasHeader = false

                    -- Mise à jour du nombre max d'éléments pour la nouvelle vue
                    maxItemsPerView = baseMaxItemsPerView + extraItemsWithoutHeader
                end

                -- Ajouter les éléments de cette rangée
                for i = 1, remainingInRow do
                    local element = group.elements[currentPos + i]
                    element._gridPosition = i
                    element._gridSize = remainingInRow
                    table.insert(currentView, element)
                end

                currentHeight = currentHeight + rowHeight + rowSpacing
                currentPos = currentPos + remainingInRow
            end
        end

        -- Ajouter la dernière vue si non vide
        if #currentView > 0 then
            table.insert(views, currentView)
        end

        return views
    end
end

--[[
 * Adapte les méthodes existantes pour conserver la compatibilité
 * avec le code qui utilise l'ancienne version de PagedContentFrame
 *
 * @param spellBookFrame table Le frame principal du SpellBook
 * @return void
]]
function SpellBook_PagingAdapter:AdaptMethods(spellBookFrame)
    -- S'assurer que ces méthodes restent compatibles avec le code existant

    -- Sauvegarde de la méthode originale SetDataProvider
    if not spellBookFrame._orig_SetDataProvider then
        spellBookFrame._orig_SetDataProvider = spellBookFrame.SetDataProvider
    end

    -- Remplacer par une version qui gère les cas spéciaux pour SpellBook
    spellBookFrame.SetDataProvider = function(self, dataProvider, preservePage)
        -- Pour les données vides, utiliser le système de fallback
        if not dataProvider or #dataProvider == 0 then
            if SpellBook_SpellFilter then
                dataProvider = SpellBook_SpellFilter:FilterAllSpells()
            end
        end

        -- Appeler la méthode originale
        self:_orig_SetDataProvider(dataProvider, preservePage)
    end

    -- Préserver la compatibilité avec l'ancienne méthode
    if not spellBookFrame.SetDataProviderWithFade then
        spellBookFrame.SetDataProviderWithFade = function(self, dataProvider)
            -- Vérifier si la nouvelle méthode existe (elle devrait exister maintenant)
            if self._orig_SetDataProviderWithFade then
                return self:_orig_SetDataProviderWithFade(dataProvider)
            else
                -- Fallback au cas où
                self:SetDataProvider(dataProvider)
            end
        end
    end

    -- Adaptation de UpdateElementDistribution pour ajouter des hooks si nécessaire
    if not spellBookFrame._orig_UpdateElementDistribution then
        spellBookFrame._orig_UpdateElementDistribution = spellBookFrame.UpdateElementDistribution

        spellBookFrame.UpdateElementDistribution = function(self)
            self:_orig_UpdateElementDistribution()

            -- Actions supplémentaires spécifiques à SpellBook si nécessaire
            if SpellBook_UI and SpellBook_UI.UpdatePageText then
                SpellBook_UI:UpdatePageText()
            end
        end
    end

    -- Adapter DisplayCurrentPage pour la rendre compatible avec les hooks existants
    if not spellBookFrame._orig_DisplayCurrentPage then
        spellBookFrame._orig_DisplayCurrentPage = spellBookFrame.DisplayCurrentPage

        spellBookFrame.DisplayCurrentPage = function(self)
            self:_orig_DisplayCurrentPage()

            -- Déclencher une mise à jour de l'UI si nécessaire
            if SpellBook_UI and SpellBook_UI.OnPageChanged then
                SpellBook_UI:OnPageChanged()
            end
        end
    end
end

--[[
 * Met à jour les boutons de pagination pour qu'ils utilisent le nouveau système
 *
 * @param prevButton table Bouton page précédente
 * @param nextButton table Bouton page suivante
 * @param pageText table Texte de pagination
 * @param spellBookFrame table Frame principal du SpellBook
 * @return void
]]
function SpellBook_PagingAdapter:UpdatePaginationControls(prevButton, nextButton, pageText, spellBookFrame)
    if not prevButton or not nextButton or not spellBookFrame then
        return
    end

    -- Mettre à jour les comportements des boutons
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

    -- Mettre à jour le texte de la page
    if pageText then
        spellBookFrame:RegisterCallback("OnPageChanged", function()
            if spellBookFrame.currentPage and spellBookFrame.maxPages then
                pageText:SetText(string.format("Page %d / %d", spellBookFrame.currentPage, spellBookFrame.maxPages))
            end
        end)
    end

    -- Stocker les références
    spellBookFrame.PagingButtons = {
        Prev = prevButton,
        Next = nextButton,
        Text = pageText
    }
end

--[[
 * Fonction utilitaire pour convertir d'anciens formats de données vers le nouveau
 *
 * @param oldData table Données au format ancien
 * @return table Données au format compatible avec le nouveau PagedContentFrame
]]
function SpellBook_PagingAdapter:ConvertDataFormat(oldData)
    -- Si le format est déjà compatible, retourner tel quel
    if not oldData or type(oldData) ~= "table" then
        return oldData
    end

    -- Vérifier si les données sont déjà au bon format
    local hasCorrectFormat = true
    for _, item in ipairs(oldData) do
        if not item.header or not item.elements then
            hasCorrectFormat = false
            break
        end
    end

    if hasCorrectFormat then
        return oldData
    end

    -- Convertir l'ancien format vers le nouveau
    local newData = {}
    local currentGroup = nil

    for _, item in ipairs(oldData) do
        if item.isHeader then
            -- Créer un nouveau groupe
            currentGroup = {
                header = {
                    templateKey = "Header",
                    text = item.text or "Unknown"
                },
                elements = {}
            }
            table.insert(newData, currentGroup)
        elseif item.isElement and currentGroup then
            -- Ajouter l'élément au groupe courant
            table.insert(currentGroup.elements, item)
        end
    end

    return newData
end

--[[
 * Active ou désactive le mode debug pour PagedContentFrame
 *
 * @param enable boolean Activer ou désactiver le mode debug
 * @return void
]]
function SpellBook_PagingAdapter:EnableDebug(enable)
    if not SpellBook_UI or not SpellBook_UI.SpellBookFrame then
        print("SpellBook: Impossible de trouver le frame du grimoire pour le debug")
        return
    end

    local spellBookFrame = SpellBook_UI.SpellBookFrame

    if spellBookFrame.EnableDebug then
        spellBookFrame:EnableDebug(enable or false)
        print("SpellBook: Mode debug " .. (enable and "activé" or "désactivé"))
    else
        print("SpellBook: La méthode EnableDebug n'est pas disponible")
    end
end

--[[
 * Vérifie et corrige les problèmes courants dans l'implémentation PagedContentFrame
 *
 * @return void
]]
function SpellBook_PagingAdapter:DiagnoseAndFix()
    if not SpellBook_UI or not SpellBook_UI.SpellBookFrame then
        print("SpellBook: Impossible de trouver le frame du grimoire pour le diagnostic")
        return
    end

    local spellBookFrame = SpellBook_UI.SpellBookFrame
    local problems = 0

    print("|cFF00FF00Début du diagnostic PagedContentFrame:|r")

    -- Vérifier si les méthodes essentielles existent
    if not spellBookFrame.SetCurrentPageWithFade then
        print("|cFFFF0000Erreur:|r Méthode SetCurrentPageWithFade manquante")
        problems = problems + 1
    end

    if not spellBookFrame.SetDataProviderWithFade then
        print("|cFFFF0000Erreur:|r Méthode SetDataProviderWithFade manquante")
        problems = problems + 1
    end

    -- Vérifier la configuration
    if not spellBookFrame.config then
        print("|cFFFF0000Erreur:|r Configuration manquante")
        problems = problems + 1
    else
        -- Vérifier les paramètres critiques
        if not spellBookFrame.config.viewsPerPage then
            print("|cFFFF0000Erreur:|r Paramètre viewsPerPage manquant dans la configuration")
            problems = problems + 1
        end
    end

    -- Vérifier le mode de rendu
    if not spellBookFrame.renderMode then
        print("|cFFFF0000Erreur:|r Mode de rendu non défini")
        problems = problems + 1
    end

    -- Vérifier les ViewFrames
    if not spellBookFrame.ViewFrames or #spellBookFrame.ViewFrames == 0 then
        print("|cFFFF0000Erreur:|r ViewFrames manquants ou vides")
        problems = problems + 1
    end

    -- Vérifier les boutons de pagination
    if not spellBookFrame.PagingButtons then
        print("|cFFFF0000Erreur:|r Boutons de pagination manquants")
        problems = problems + 1
    elseif not spellBookFrame.PagingButtons.Prev or not spellBookFrame.PagingButtons.Next then
        print("|cFFFF0000Erreur:|r Boutons Prev/Next manquants")
        problems = problems + 1
    end

    -- Appliquer des correctifs si nécessaire
    if problems > 0 then
        print(string.format("|cFFFF9900%d problème(s) détecté(s). Tentative de correction...|r", problems))

        -- Essayer de réinitialiser et reconfigurer le PagedContentFrame
        self:ResetAndReconfigure(spellBookFrame)
    else
        print("|cFF00FF00Aucun problème détecté!|r")
    end

    -- Forcer une mise à jour de l'affichage
    if spellBookFrame.dataProvider then
        print("Mise à jour forcée de l'affichage...")
        spellBookFrame:SetDataProvider(spellBookFrame.dataProvider, true)
    end
end

--[[
 * Réinitialise et reconfigure PagedContentFrame en cas de problème
 *
 * @param spellBookFrame table Le frame principal du SpellBook
 * @return void
]]
function SpellBook_PagingAdapter:ResetAndReconfigure(spellBookFrame)
    if not spellBookFrame then return end

    -- Recréer la configuration
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
        maxColumnsPerRow = 3,
        fadeOutDuration = 0.2,
        fadeInDuration = 0.2,
        animationDelay = 0.1,
        throttleTime = 1.0
    }

    -- S'assurer que le mode de rendu est défini
    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    -- Revérifier les ViewFrames
    if not spellBookFrame.ViewFrames or #spellBookFrame.ViewFrames == 0 then
        if spellBookFrame.PageView1 and spellBookFrame.PageView2 then
            spellBookFrame.ViewFrames = {spellBookFrame.PageView1, spellBookFrame.PageView2}
            print("ViewFrames reconfigurés")
        else
            print("|cFFFF0000Impossible de reconfigurer les ViewFrames: PageView1/2 introuvables|r")
        end
    end

    -- Recréer les boutons de pagination si nécessaire
    if not spellBookFrame.PagingButtons then
        -- Les boutons doivent être créés par SpellBook_UI:CreatePaginationSystem
        print("|cFFFF9900Les boutons de pagination doivent être recréés manuellement|r")
    end

    -- Ajouter un flag pour forcer la mise à jour
    spellBookFrame.forceUpdate = true

    print("|cFF00FF00Reconfiguration terminée|r")
end

function SpellBook_PagingAdapter:FixPageSynchronization(spellBookFrame)
    if not spellBookFrame then
        print("SpellBook: Frame du grimoire introuvable")
        return false
    end

    print("Application des correctifs de synchronisation...")

    -- Définir une fonction de mise à jour explicite pour le texte de page
    if not spellBookFrame.PageText then
        -- Chercher le texte de pagination
        for _, region in ipairs({spellBookFrame:GetRegions()}) do
            if region:GetObjectType() == "FontString" and region:GetText() and
                    region:GetText():match("Page %d+ / %d+") then
                spellBookFrame.PageText = region
                print("Texte de pagination trouvé automatiquement")
                break
            end
        end
    end

    -- S'assurer que la méthode UpdatePageText est disponible
    if not spellBookFrame.UpdatePageText then
        spellBookFrame.UpdatePageText = PagedContentFrameMixin.UpdatePageText
    end

    -- Créer un hook pour s'assurer que le texte est toujours à jour
    if spellBookFrame.SetCurrentPage and not spellBookFrame._originalSetCurrentPage then
        spellBookFrame._originalSetCurrentPage = spellBookFrame.SetCurrentPage

        spellBookFrame.SetCurrentPage = function(self, pageNum)
            local result = self:_originalSetCurrentPage(pageNum)
            -- Forcer la mise à jour du texte
            self:UpdatePageText()
            return result
        end
    end

    -- Forcer une mise à jour immédiate
    if spellBookFrame.currentPage and spellBookFrame.maxPages then
        spellBookFrame:UpdatePageText()
    end

    print("Correctifs de synchronisation appliqués")
    return true
end

SLASH_SBDIAG1 = "/sbdiag"
SlashCmdList["SBDIAG"] = function(msg)
    if SpellBook_PagingAdapter then
        if msg == "debug" then
            SpellBook_PagingAdapter:EnableDebug(true)
        elseif msg == "nodebug" then
            SpellBook_PagingAdapter:EnableDebug(false)
        else
            SpellBook_PagingAdapter:DiagnoseAndFix()
        end
    else
        print("SpellBook: Module PagingAdapter non disponible")
    end
end

SLASH_SBFIXSYNC1 = "/sbfixsync"
SlashCmdList["SBFIXSYNC"] = function()
    if SpellBook_PagingAdapter and SpellBook_UI and SpellBook_UI.SpellBookFrame then
        SpellBook_PagingAdapter:FixPageSynchronization(SpellBook_UI.SpellBookFrame)
    else
        print("SpellBook: Composants requis non disponibles")
    end
end

-- Initialiser l'adaptateur
SpellBook_PagingAdapter:Initialize()