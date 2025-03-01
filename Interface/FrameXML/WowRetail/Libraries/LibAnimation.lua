-- EnhancedAnimationLibrary.lua
-- Advanced Animation Framework for World of Warcraft 3.3.5a
-- Version 2.0

local AddonName = "EnhancedAnimations"

-- Base Animation Library
local AnimLib = {
    version = 2.0,
    animationTypes = {},
    activeAnimations = {},
    easingFunctions = {},
    debugMode = false
}

-- Utility Functions
local function Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function PrintDebug(message)
    if AnimLib.debugMode then
        print("|cFF00FF00[AnimLib Debug]|r " .. tostring(message))
    end
end

-- Easing Functions
AnimLib.easingFunctions = {
    Linear = function(t) return t end,
    
    -- Quadratic Easings
    QuadIn = function(t) return t * t end,
    QuadOut = function(t) return t * (2 - t) end,
    QuadInOut = function(t) 
        return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t 
    end,
    
    -- Cubic Easings
    CubicIn = function(t) return t * t * t end,
    CubicOut = function(t) return 1 + (t - 1) * t * t end,
    
    -- Elastic Easing
    ElasticOut = function(t)
        local p = 0.3
        return (t == 0) and 0 or (t == 1) and 1 or 
               math.pow(2, -10 * t) * math.sin((t - p/4) * (2 * math.pi) / p) + 1
    end,
    
    -- Bounce Easing
    BounceOut = function(t)
        if t < 1/2.75 then
            return 7.5625 * t * t
        elseif t < 2/2.75 then
            t = t - 1.5/2.75
            return 7.5625 * t * t + 0.75
        elseif t < 2.5/2.75 then
            t = t - 2.25/2.75
            return 7.5625 * t * t + 0.9375
        else
            t = t - 2.625/2.75
            return 7.5625 * t * t + 0.984375
        end
    end
}

-- Animation Types
AnimLib.animationTypes = {
    FADE = "fade",
    MOVE = "move", 
    SCALE = "scale",
    ROTATE = "rotate",
    COLOR = "color",
    SHAKE = "shake",
    PULSE = "pulse",
    ORBIT = "orbit",
    BOUNCE = "bounce",
    RIPPLE = "ripple",
    ELASTIC = "elastic"
}

-- Create Master Animation Frame
local animationFrame = CreateFrame("Frame")
animationFrame:Hide()

-- Animation Update Logic
local function AnimationUpdateHandler(self, elapsed)
    for key, animation in pairs(AnimLib.activeAnimations) do
        animation.elapsed = animation.elapsed + elapsed
        local progress = math.min(animation.elapsed / animation.duration, 1)
        local easedProgress = animation.easingFunc(progress)
        
        -- Call update function
        local success, errorMsg = pcall(animation.updateFunc, animation, easedProgress, elapsed)
        
        if not success then
            PrintDebug("Animation Error: " .. tostring(errorMsg))
            AnimLib.activeAnimations[key] = nil
        end
        
        -- Check for completion
        if progress >= 1 then
            if animation.onComplete then
                pcall(animation.onComplete, animation)
            end
            AnimLib.activeAnimations[key] = nil
        end
    end
    
    -- Stop frame if no active animations
    if not next(AnimLib.activeAnimations) then
        self:Hide()
    end
end
animationFrame:SetScript("OnUpdate", AnimationUpdateHandler)

-- Core Animation Creation Function
function AnimLib:CreateAnimation(frame, animationType, duration, options)
    if not frame or type(frame) ~= "table" then
        error("Invalid frame for animation", 2)
    end
    
    options = options or {}
    local animation = {
        frame = frame,
        duration = duration or 1,
        elapsed = 0,
        easingFunc = options.easingFunc or self.easingFunctions.Linear,
        onComplete = options.onComplete
    }
    
    -- Animation Type Implementations
    local animationImplementations = {
        [self.animationTypes.FADE] = function()
            local startAlpha = options.startAlpha or frame:GetAlpha()
            local endAlpha = options.endAlpha or (startAlpha == 0 and 1 or 0)
            
            animation.updateFunc = function(self, progress)
                self.frame:SetAlpha(startAlpha + (endAlpha - startAlpha) * progress)
            end
        end,
        
        [self.animationTypes.MOVE] = function()
            local startX = options.startX or 0
            local startY = options.startY or 0
            local endX = options.endX or startX
            local endY = options.endY or startY
            
            animation.updateFunc = function(self, progress)
                local x = startX + (endX - startX) * progress
                local y = startY + (endY - startY) * progress
                self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
            end
        end,
        
        [self.animationTypes.SCALE] = function()
            local startScale = options.startScale or 1
            local endScale = options.endScale or 1.5
            
            animation.updateFunc = function(self, progress)
                local scale = startScale + (endScale - startScale) * progress
                self.frame:SetScale(scale)
            end
        end,
        
        [self.animationTypes.ROTATE] = function()
            local startAngle = options.startAngle or 0
            local endAngle = options.endAngle or 360
            
            animation.updateFunc = function(self, progress)
                local angle = startAngle + (endAngle - startAngle) * progress
                self.frame:SetRotation(math.rad(angle))
            end
        end,
        
        [self.animationTypes.COLOR] = function()
            local startR, startG, startB = options.startR or 1, options.startG or 1, options.startB or 1
            local endR, endG, endB = options.endR or 0, options.endG or 0, options.endB or 0
            
            animation.updateFunc = function(self, progress)
                local r = startR + (endR - startR) * progress
                local g = startG + (endG - startG) * progress
                local b = startB + (endB - startB) * progress
                self.frame:SetVertexColor(r, g, b)
            end
        end,
        
        [self.animationTypes.SHAKE] = function()
            local intensity = options.intensity or 5
            local frequency = options.frequency or 10
            
            animation.updateFunc = function(self, progress)
                local offset = math.sin(progress * frequency * math.pi * 2) * intensity * (1 - progress)
                self.frame:SetPoint("CENTER", UIParent, "CENTER", offset, offset)
            end
        end,
        
        [self.animationTypes.PULSE] = function()
            local minScale = options.minScale or 0.8
            local maxScale = options.maxScale or 1.2

            animation.updateFunc = function(self, progress)
                local scale = minScale + (maxScale - minScale) * math.sin(progress * math.pi)
                
                -- Alternative à SetScale() pour les textures
                if self.frame.SetTexCoord then
                    local centerX, centerY = 0.5, 0.5
                    local ULx, ULy = centerX - (centerX * scale), centerY - (centerY * scale)
                    local LLx, LLy = centerX - (centerX * scale), centerY + (centerY * scale)
                    local URx, URy = centerX + (centerX * scale), centerY - (centerY * scale)
                    local LRx, LRy = centerX + (centerX * scale), centerY + (centerY * scale)
                    
                    self.frame:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
                
                -- Pour les frames qui ne sont pas des textures
                elseif self.frame.SetWidth then
                    local originalWidth = self.frame:GetWidth() / (self.frame:GetScale() or 1)
                    local originalHeight = self.frame:GetHeight() / (self.frame:GetScale() or 1)
                    
                    self.frame:SetWidth(originalWidth * scale)
                    self.frame:SetHeight(originalHeight * scale)
                end
            end
        end,
        
        [self.animationTypes.ORBIT] = function()
            local radius = options.radius or 50
            local speed = options.speed or 1
            
            animation.updateFunc = function(self, progress)
                local angle = progress * 2 * math.pi * speed
                local x = math.cos(angle) * radius
                local y = math.sin(angle) * radius
                self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
            end
        end,
        
        [self.animationTypes.BOUNCE] = function()
            local height = options.height or 30
            
            animation.updateFunc = function(self, progress)
                local y = height * math.sin(progress * math.pi)
                self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
            end
        end,
        
        [self.animationTypes.RIPPLE] = function()
            local amplitude = options.amplitude or 10
            local frequency = options.frequency or 5
            
            animation.updateFunc = function(self, progress)
                local offset = math.sin(progress * frequency * math.pi * 2) * amplitude * (1 - progress)
                self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, offset)
            end
        end,
        
        [self.animationTypes.ELASTIC] = function()
            local startX, startY = 0, 0
            local endX = options.endX or 100
            local endY = options.endY or 100
            local bounces = options.bounces or 3
            
            animation.updateFunc = function(self, progress)
                local scaledProgress = progress * bounces
                local amplitude = math.exp(-scaledProgress) * math.sin(scaledProgress * math.pi * 2)
                
                local x = startX + (endX - startX) * progress
                local y = startY + (endY - startY) * progress + amplitude * 50
                
                self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
            end
        end
    }
    
    -- Create the specific animation type
    local createFunc = animationImplementations[animationType]
    if createFunc then
        createFunc()
    else
        error("Unsupported animation type: " .. tostring(animationType), 2)
    end
    
    return animation
end

-- Start Animation
function AnimLib:StartAnimation(animation)
    if not animation then return end
    
    self.activeAnimations[animation] = animation
    animationFrame:Show()
    return animation
end

-- Stop Animation
function AnimLib:StopAnimation(animation)
    if animation and self.activeAnimations[animation] then
        self.activeAnimations[animation] = nil
    end
end

-- Debug Toggle
function AnimLib:SetDebugMode(enable)
    self.debugMode = enable and true or false
end

-- Global Exposure
_G["EnhancedAnimationLibrary"] = AnimLib

return AnimLib