--- Retrieves the texture coordinates for a specific frame in a texture atlas.
-- @param frameNum The frame number (1-based index) to retrieve coordinates for.
-- @return left The left texture coordinate.
-- @return right The right texture coordinate.
-- @return top The top texture coordinate.
-- @return bottom The bottom texture coordinate.
local function GetFrameTexCoords(frameNum)
    local totalLeft = 0.000976562
    local totalRight = 0.586914
    local totalTop = 0.000976562
    local totalBottom = 0.303711

    local frameWidth = (totalRight - totalLeft) / 4
    local frameHeight = (totalBottom - totalTop) / 2

    local column = (frameNum - 1) % 4
    local row = math.floor((frameNum - 1) / 4)

    local left = totalLeft + (column * frameWidth)
    local right = left + frameWidth
    local top = totalTop + (row * frameHeight)
    local bottom = top + frameHeight

    return left, right, top, bottom
end

--- Updates the texture coordinates of a given texture to match a specific frame.
-- @param texture The texture object to update.
-- @param frameNum The frame number (1-based index) to use for updating the texture coordinates.
local function UpdateBookCornerTexCoords(texture, frameNum)
    local left, right, top, bottom = GetFrameTexCoords(frameNum)
    texture:SetTexCoord(left, right, top, bottom)
end

--- Starts an animation for the book corner, transitioning through frames.
-- @param frame The frame object containing the texture to animate.
-- @param reverse Whether the animation should play in reverse.
local function StartBookCornerAnimation(frame, reverse)
    if frame.isPlaying then
        frame.reverse = reverse
        return
    end

    frame.frameCount = 8
    frame.currentFrame = reverse and frame.frameCount or 1
    frame.timing = 0.03
    frame.lastUpdate = 0
    frame.isPlaying = true
    frame.reverse = reverse

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed

        if self.lastUpdate >= self.timing then
            if (not self.reverse and self.currentFrame < self.frameCount) or (self.reverse and self.currentFrame > 1) then
                self.currentFrame = self.currentFrame + (self.reverse and -1 or 1)
                UpdateBookCornerTexCoords(self.Texture, self.currentFrame)
            else
                self:SetScript("OnUpdate", nil)
                self.isPlaying = false
            end
            self.lastUpdate = 0
        end
    end)
end

--- Event handler for when the SpellBook corner frame is shown.
-- Sets the texture to the first frame.
-- @param self The SpellBook corner frame.
function SpellBookCorner_OnShow(self)
    UpdateBookCornerTexCoords(self.Texture, 1)
end

--- Event handler for when the cursor enters the SpellBook corner frame.
-- Starts the animation in a forward direction.
-- @param self The SpellBook corner frame.
function SpellBookCorner_OnEnter(self)
    if self:IsVisible() then
        StartBookCornerAnimation(self, false)
    end
end

--- Event handler for when the cursor leaves the SpellBook corner frame.
-- Starts the animation in reverse.
-- @param self The SpellBook corner frame.
function SpellBookCorner_OnLeave(self)
    if self:IsVisible() then
        StartBookCornerAnimation(self, true)
    end
end