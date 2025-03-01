SpellBook.Animation = {}

-- Animation constants
SpellBook.Animation.BOOK_CORNER_FRAMES = 8
SpellBook.Animation.FRAME_TIMING = 0.03

--[[
 * Initializes the Animation module
 *
 * @return void
--]]
function SpellBook.Animation:Initialize()
    -- Nothing to initialize currently
end

--[[
 * Retrieves the texture coordinates for a specific frame in a texture atlas.
 *
 * @param frameNum number The frame number (1-based index) to retrieve coordinates for.
 * @return number, number, number, number The left, right, top, bottom texture coordinates.
--]]
function SpellBook.Animation:GetFrameTexCoords(frameNum)
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

--[[
 * Updates the texture coordinates of a given texture to match a specific frame.
 *
 * @param texture table The texture object to update.
 * @param frameNum number The frame number (1-based index) to use for updating the texture coordinates.
 * @return void
--]]
function SpellBook.Animation:UpdateBookCornerTexCoords(texture, frameNum)
    local left, right, top, bottom = self:GetFrameTexCoords(frameNum)
    texture:SetTexCoord(left, right, top, bottom)
end

--[[
 * Starts an animation for the book corner, transitioning through frames.
 *
 * @param frame table The frame object containing the texture to animate.
 * @param reverse boolean Whether the animation should play in reverse.
 * @return void
--]]
function SpellBook.Animation:StartBookCornerAnimation(frame, reverse)
    if frame.isPlaying then
        frame.reverse = reverse
        return
    end

    frame.frameCount = self.BOOK_CORNER_FRAMES
    frame.currentFrame = reverse and frame.frameCount or 1
    frame.timing = self.FRAME_TIMING
    frame.lastUpdate = 0
    frame.isPlaying = true
    frame.reverse = reverse

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed

        if self.lastUpdate >= self.timing then
            if (not self.reverse and self.currentFrame < self.frameCount) or (self.reverse and self.currentFrame > 1) then
                self.currentFrame = self.currentFrame + (self.reverse and -1 or 1)
                SpellBook.Animation:UpdateBookCornerTexCoords(self.Texture, self.currentFrame)
            else
                self:SetScript("OnUpdate", nil)
                self.isPlaying = false
            end
            self.lastUpdate = 0
        end
    end)
end

--[[
 * Event handler for when the SpellBook corner frame is shown.
 * Sets the texture to the first frame.
 *
 * @param self table The SpellBook corner frame.
 * @return void
--]]
function SpellBookCorner_OnShow(self)
    SpellBook.Animation:UpdateBookCornerTexCoords(self.Texture, 1)
end

--[[
 * Event handler for when the cursor enters the SpellBook corner frame.
 * Starts the animation in a forward direction.
 *
 * @param self table The SpellBook corner frame.
 * @return void
--]]
function SpellBookCorner_OnEnter(self)
    if self:IsVisible() then
        SpellBook.Animation:StartBookCornerAnimation(self, false)
    end
end

--[[
 * Event handler for when the cursor leaves the SpellBook corner frame.
 * Starts the animation in reverse.
 *
 * @param self table The SpellBook corner frame.
 * @return void
--]]
function SpellBookCorner_OnLeave(self)
    if self:IsVisible() then
        SpellBook.Animation:StartBookCornerAnimation(self, true)
    end
end