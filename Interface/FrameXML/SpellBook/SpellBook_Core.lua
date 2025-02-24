SpellBook = {}

SpellBook_Core = {}

-- Constants
SpellBook.BOOKTYPE_SPELL = BOOKTYPE_SPELL

-- Initialize configuration defaults
SpellBook.Config = {
    showAllRanks = false,
    searchText = ""
}

--[[
 * Initialization function called when addon is loaded
 * Sets up the main addon structure and registers events
 *
 * @return void
--]]
function SpellBook:Initialize()
    -- Register events
    -- Using Object-Oriented approach with methods as event handlers
    self.MainFrame = self.MainFrame or CreateFrame("Frame")
    self.MainFrame:SetScript("OnEvent", function(frame, event, ...)
        if self[event] then
            return self[event](self, ...)
        end
    end)
end

--[[
 * Saves current configuration to saved variables
 *
 * @return void
--]]
function SpellBook:SaveConfig()
    SpellBookDB = self.Config
end

-- Initialize the addon
SpellBook:Initialize()