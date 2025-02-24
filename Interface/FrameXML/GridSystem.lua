--- @class Container
--- @field grid Frame The grid contained in the container
--- @field scrollOffset number The vertical scroll offset
--- @field scrollFrame Frame|nil The scroll frame (if scrolling is enabled)
--- @field scrollbar Frame|nil The scrollbar (if scrolling is enabled)
--- @field scrollChild Frame|nil The scroll child frame (if scrolling is enabled)
Container = {};

--- Creates a new container
--- @param parent Frame The parent frame
--- @param width number The container width
--- @param height number The container height
--- @param enableScrolling boolean Whether to enable scrolling
--- @return Container The created container
function Container:Create(parent, width, height, enableScrolling)
    local container = CreateFrame("Frame", nil, parent);
    
    -- Inherit Container methods
    for k, v in pairs(Container) do
        container[k] = v;
    end
    
    container:SetSize(width, height);
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0);
    container.scrollOffset = 0;
    
    if enableScrolling then
        container:CreateScrollFrame();
    end
    
    return container;
end

--- Creates the scrolling system for the container
function Container:CreateScrollFrame()
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self);
    self.scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 0);
    
    -- Create scrollbar
    self.scrollbar = CreateFrame("Slider", nil, self.scrollFrame, "UIPanelScrollBarTemplate");
    self.scrollbar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -16);
    self.scrollbar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 16);
    self.scrollbar:SetMinMaxValues(0, 100);
    self.scrollbar:SetValueStep(1);
    self.scrollbar:SetValue(0);
    
    self.scrollbar:SetScript("OnValueChanged", function(_, value)
        self.scrollFrame:SetVerticalScroll(value);
        self.scrollOffset = value;
    end);
    
    -- Create scroll child
    self.scrollChild = CreateFrame("Frame", nil, self.scrollFrame);
    self.scrollChild:SetWidth(self:GetWidth() - 16);
    self.scrollChild:SetHeight(self:GetHeight() * 2);
    self.scrollFrame:SetScrollChild(self.scrollChild);
    
    self.scrollChild:SetScript("OnSizeChanged", function()
        self:UpdateScrollbar();
    end);
end

--- Updates the scrollbar dimensions and state
function Container:UpdateScrollbar()
    local total = self.scrollChild:GetHeight();
    local visible = self.scrollFrame:GetHeight();
    local max = math.max(0, total - visible);
    self.scrollbar:SetMinMaxValues(0, max);
    if total <= visible then
        self.scrollbar:Disable();
    else
        self.scrollbar:Enable();
    end
end

--- @class Grid
--- @field rows number Number of rows
--- @field cols number Number of columns
--- @field cells table<number, table<number, Frame>> Grid cells
--- @field rowHeights table<number, number> Row heights
--- @field columnWidths table<number, number> Column widths
--- @field gridLines table Grid lines for visual display
Grid = {};

--- Creates a new grid
--- @param parent Frame The parent frame
--- @param enableScrolling boolean Whether scrolling is enabled
--- @param showGrid boolean Whether to show grid lines
--- @return Grid The created grid
function Grid:Create(parent, enableScrolling, showGrid)
    local grid = CreateFrame("Frame", nil, parent);
    
    -- Inherit Grid methods
    for k, v in pairs(Grid) do
        grid[k] = v;
    end
    
    -- Initialize all required tables
    grid.cells = {};
    grid.rowHeights = {};
    grid.columnWidths = {};
    grid.enableScrolling = enableScrolling;
    grid.showGrid = showGrid;
    grid.gridLines = {
        vertical = {},
        horizontal = {}
    };
    
    return grid;
end

--- Creates grid lines for visual display
function Grid:CreateGridLines()
    -- Clean up old lines
    if self.gridLines then
        if self.gridLines.vertical then
            for _, line in pairs(self.gridLines.vertical) do
                if line then
                    line:Hide();
                    line:SetParent(self);  -- Set parent to grid before cleanup
                end
            end
        end
        if self.gridLines.horizontal then
            for _, line in pairs(self.gridLines.horizontal) do
                if line then
                    line:Hide();
                    line:SetParent(self);  -- Set parent to grid before cleanup
                end
            end
        end
    end
    
    self.gridLines = {
        vertical = {},
        horizontal = {}
    };

    if not self.showGrid then return end

    -- Create vertical lines
    for col = 1, (self.cols or 0) + 1 do
        local line = self:CreateTexture(nil, "OVERLAY");
        line:SetTexture(1, 1, 1, 0.5);
        line:SetWidth(1);
        table.insert(self.gridLines.vertical, line);
    end

    -- Create horizontal lines
    for row = 1, (self.cells and #self.cells or 0) + 1 do
        local line = self:CreateTexture(nil, "OVERLAY");
        line:SetTexture(1, 1, 1, 0.5);
        line:SetHeight(1);
        table.insert(self.gridLines.horizontal, line);
    end
end

--- Adds a new row to the grid
--- @return number The index of the new row
function Grid:AddRow()
    -- Initialize cells if it doesn't exist
    if not self.cells then
        self.cells = {};
    end

    local newRowIndex = #self.cells + 1;
    self.cells[newRowIndex] = {};
    
    -- Create cells for the new row
    for col = 1, self.cols do
        local cell = CreateFrame("Frame", nil, self);
        cell.row = newRowIndex;
        cell.col = col;
        self.cells[newRowIndex][col] = cell;
    end
    
    -- Add default height
    if not self.rowHeights then
        self.rowHeights = {};
    end
    self.rowHeights[newRowIndex] = 40;
    
    -- Recreate grid lines to include the new row
    self:CreateGridLines();
    self:UpdateLayout();
    
    return newRowIndex;
end

--- Adds a new column to the grid
--- @return number The index of the new column
function Grid:AddColumn()
    local newColIndex = self.cols + 1;
    self.cols = newColIndex;
    
    -- Add a cell in each existing row
    for row = 1, #self.cells do
        local cell = CreateFrame("Frame", nil, self);
        cell.row = row;
        cell.col = newColIndex;
        self.cells[row][newColIndex] = cell;
    end
    
    -- Add default width
    self.columnWidths[newColIndex] = floor(self:GetParent():GetWidth() / self.cols);
    
    self:UpdateLayout();
    return newColIndex;
end

--- Removes a row from the grid
--- @param rowIndex number The index of the row to remove
function Grid:RemoveRow(rowIndex)
    -- Vérifications de sécurité
    if not self.cells or #self.cells <= 1 then return end
    if not rowIndex or rowIndex <= 0 or rowIndex > #self.cells then return end

    -- Suppression des cellules de la ligne
    if self.cells[rowIndex] then
        for col = 1, self.cols do
            local cell = self.cells[rowIndex][col];
            if cell then
                cell:Hide();
                cell:SetParent(nil);
            end
        end
    end
    
    -- Suppression de la ligne
    table.remove(self.cells, rowIndex);
    if self.rowHeights then
        table.remove(self.rowHeights, rowIndex);
    end
    
    -- Mise à jour des indices des lignes suivantes
    for row = rowIndex, #self.cells do
        if self.cells[row] then
            for col = 1, self.cols do
                if self.cells[row][col] then
                    self.cells[row][col].row = row;
                end
            end
        end
    end
    
    -- Mise à jour complète de la grille
    self:UpdateLayout();
    self:CreateGridLines();
end

--- Removes a column from the grid
--- @param colIndex number The index of the column to remove
function Grid:RemoveColumn(colIndex)
    -- Check if we have any columns left and if the index is valid
    if not self.cols or self.cols <= 1 or not colIndex then return end
    if colIndex > self.cols then colIndex = self.cols end

    -- Remove the corresponding cell in each row
    for row = 1, #self.cells do
        if self.cells[row] and self.cells[row][colIndex] then
            local cell = self.cells[row][colIndex];
            if cell then
                cell:Hide();
                cell:SetParent(self);  -- Set parent back to grid before removing
            end
            table.remove(self.cells[row], colIndex);
        end
    end
    
    -- Update following columns indices
    for row = 1, #self.cells do
        if self.cells[row] then
            for col = colIndex, #self.cells[row] do
                if self.cells[row][col] then
                    self.cells[row][col].col = col;
                end
            end
        end
    end
    
    if self.columnWidths and #self.columnWidths >= colIndex then
        table.remove(self.columnWidths, colIndex);
    end
    self.cols = self.cols - 1;
    
    self:UpdateLayout();
end

--- Gets a cell at the specified position
--- @param row number The row index
--- @param col number The column index
--- @return Frame|nil The cell at the specified position
function Grid:GetCell(row, col)
    if self.cells[row] and self.cells[row][col] then
        return self.cells[row][col];
    end
    return nil;
end

--- Updates the grid layout
function Grid:UpdateLayout()
    if not self.cells then
        self.cells = {};
    end

    local totalWidth = 0;
    local totalHeight = 0;

    -- Calculate total dimensions
    for col = 1, self.cols do
        totalWidth = totalWidth + (self.columnWidths[col] or 40);
    end
    
    for row = 1, #self.cells do
        totalHeight = totalHeight + (self.rowHeights[row] or 40);
    end

    -- Update dimensions
    self:SetSize(totalWidth, totalHeight);

    -- Position cells
    local yOffset = 0;
    for row = 1, #self.cells do
        local xOffset = 0;
        for col = 1, self.cols do
            local cell = self:GetCell(row, col);
            if cell then
                cell:ClearAllPoints();
                cell:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, -yOffset);
                cell:SetSize(self.columnWidths[col] or 40, self.rowHeights[row] or 40);
                xOffset = xOffset + (self.columnWidths[col] or 40);
            end
        end
        yOffset = yOffset + (self.rowHeights[row] or 40);
    end

    -- Update grid lines
    if self.showGrid then
        self:UpdateGridLines();
    end
end

--- Updates the grid lines positions
function Grid:UpdateGridLines()
    local xOffset = 0;
    for i, line in ipairs(self.gridLines.vertical) do
        line:ClearAllPoints();
        line:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, 0);
        line:SetHeight(self:GetHeight());
        if i <= self.cols then
            xOffset = xOffset + (self.columnWidths[i] or 40);
        end
    end

    local yOffset = 0;
    for i, line in ipairs(self.gridLines.horizontal) do
        line:ClearAllPoints();
        line:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -yOffset);
        line:SetWidth(self:GetWidth());
        if i <= #self.cells then
            yOffset = yOffset + (self.rowHeights[i] or 40);
        end
    end
end

--- Toggles the grid lines visibility
--- @param show boolean Whether to show the grid lines
function Grid:ToggleGrid(show)
    self.showGrid = show;
    self:CreateGridLines();
    self:UpdateLayout();
end

--- Sets the background color of a cell
--- @param row number The row index
--- @param col number The column index
--- @param r number Red component (0-1)
--- @param g number Green component (0-1)
--- @param b number Blue component (0-1)
--- @param a number Alpha component (0-1)
function Grid:SetCellColor(row, col, r, g, b, a)
    local cell = self:GetCell(row, col);
    if cell then
        if not cell.background then
            cell.background = cell:CreateTexture(nil, "BACKGROUND");
            cell.background:SetAllPoints();
        end
        cell.background:SetVertexColor(r, g, b, a or 1);
    end
end

--- Sets the height of a specific row
--- @param row number The row index
--- @param height number The height to set
function Grid:SetRowHeight(row, height)
    if row > 0 and row <= #self.cells then
        self.rowHeights[row] = height;
        self:UpdateLayout();
    end
end

--- Sets the width of a specific column
--- @param col number The column index
--- @param width number The width to set
function Grid:SetColumnWidth(col, width)
    if col > 0 and col <= self.cols then
        self.columnWidths[col] = width;
        self:UpdateLayout();
    end
end

--- Merges cells in the grid
--- @param startRow number Starting row
--- @param startCol number Starting column
--- @param endRow number Ending row
--- @param endCol number Ending column
function Grid:MergeCells(startRow, startCol, endRow, endCol)
    -- Validate parameters
    if startRow > endRow or startCol > endCol then return end
    if not self:GetCell(startRow, startCol) or not self:GetCell(endRow, endCol) then return end

    -- Hide all cells in the merge range except the first one
    local mainCell = self:GetCell(startRow, startCol);
    mainCell.mergeInfo = {
        startRow = startRow,
        startCol = startCol,
        endRow = endRow,
        endCol = endCol
    };

    -- Hide other cells
    for row = startRow, endRow do
        for col = startCol, endCol do
            if row ~= startRow or col ~= startCol then
                local cell = self:GetCell(row, col);
                if cell then
                    cell:Hide();
                end
            end
        end
    end

    self:UpdateLayout();
end

--- @class GridSystem
--- Main system for creating and managing grids
GridSystem = {};

--- Creates a new grid system
--- @param parent Frame The parent frame
--- @param rows number The initial number of rows
--- @param cols number The initial number of columns
--- @param enableScrolling boolean Whether to enable scrolling
--- @param showGrid boolean Whether to show grid lines (optional, default: true)
--- @return Container The container containing the grid
function GridSystem:CreateGrid(parent, rows, cols, enableScrolling, showGrid)
    showGrid = showGrid ~= false;
    
    -- Create container
    local container = Container:Create(parent, parent:GetWidth(), parent:GetHeight(), enableScrolling);
    
    -- Create grid
    local grid = Grid:Create(enableScrolling and container.scrollChild or container, enableScrolling, showGrid);
    grid.rows = rows;
    grid.cols = cols;
    
    -- Initialize grid
    for row = 1, rows do
        grid.cells[row] = {};
        grid.rowHeights[row] = 40;
        for col = 1, cols do
            local cell = CreateFrame("Frame", nil, grid);
            cell.row = row;
            cell.col = col;
            grid.cells[row][col] = cell;
            if row == 1 then
                grid.columnWidths[col] = floor(container:GetWidth() / cols);
            end
        end
    end

    -- Setup grid
    grid:SetPoint("TOPLEFT", enableScrolling and container.scrollChild or container, "TOPLEFT", 0, 0);
    grid:CreateGridLines();
    grid:UpdateLayout();

    -- Link container and grid
    container.grid = grid;
    
    -- Add proxy methods to container
    container.GetCell = function(self, row, col)
        return self.grid:GetCell(row, col)
    end

    container.AddRow = function(self)
        return self.grid:AddRow()
    end

    container.AddColumn = function(self)
        return self.grid:AddColumn()
    end

    container.RemoveRow = function(self, rowIndex)
        return self.grid:RemoveRow(rowIndex)
    end

    container.RemoveColumn = function(self, colIndex)
        return self.grid:RemoveColumn(colIndex)
    end

    container.ToggleGrid = function(self, show)
        return self.grid:ToggleGrid(show)
    end

    container.SetCellColor = function(self, row, col, r, g, b, a)
        return self.grid:SetCellColor(row, col, r, g, b, a)
    end
    
    container.SetRowHeight = function(self, row, height)
        return self.grid:SetRowHeight(row, height)
    end
    
    container.SetColumnWidth = function(self, col, width)
        return self.grid:SetColumnWidth(col, width)
    end
    
    container.MergeCells = function(self, startRow, startCol, endRow, endCol)
        return self.grid:MergeCells(startRow, startCol, endRow, endCol)
    end

    return container;
end