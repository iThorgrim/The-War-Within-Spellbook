-- C_Timer.lua - Complete implementation for Classic WoW
if C_Timer then return end -- Already exists, no need to create it

C_Timer = {}

-- Main timer frame and timer storage
local timerFrame = CreateFrame("Frame")
local timers = {}
local idCounter = 0

timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for id, timer in pairs(timers) do
        if timer.active then
            timer.elapsed = timer.elapsed + elapsed
            
            if timer.elapsed >= timer.duration then
                if timer.isTicker then
                    -- For tickers, reset elapsed time and decrement iterations
                    timer.elapsed = 0
                    timer.callback()
                    
                    if timer.iterations then
                        timer.iterations = timer.iterations - 1
                        if timer.iterations <= 0 then
                            timer.active = false
                        end
                    end
                else
                    -- For one-time timers, mark as inactive and call
                    timer.active = false
                    timer.callback()
                end
            end
        end
    end
    
    -- Clean up inactive timers
    for id, timer in pairs(timers) do
        if not timer.active then
            timers[id] = nil
        end
    end
end)

--[[
 * Schedule a function to be called after the specified duration
 *
 * @param duration number Time in seconds before the callback is run
 * @param callback function The function to call after the duration has elapsed
 * @return object A TimerHandle structure
--]]
function C_Timer.After(duration, callback)
    assert(type(duration) == "number", "C_Timer.After: duration must be a number")
    assert(type(callback) == "function", "C_Timer.After: callback must be a function")
    
    idCounter = idCounter + 1
    
    timers[idCounter] = {
        id = idCounter,
        active = true,
        elapsed = 0,
        duration = duration,
        callback = callback,
        isTicker = false
    }
    
    return timers[idCounter]
end

--[[
 * Create a new timer that will call the callback after the specified duration
 * Same as C_Timer.After but returns a timer structure that can be canceled
 *
 * @param duration number Time in seconds before the callback is run
 * @param callback function The function to call after the duration has elapsed
 * @return object A TimerHandle structure
--]]
function C_Timer.NewTimer(duration, callback)
    return C_Timer.After(duration, callback)
end

--[[
 * Create a timer that will repeatedly call a function
 *
 * @param duration number Time in seconds between each call
 * @param callback function The function to call
 * @param iterations number|nil Optional number of iterations, infinite if nil
 * @return object A TimerHandle structure
--]]
function C_Timer.NewTicker(duration, callback, iterations)
    assert(type(duration) == "number", "C_Timer.NewTicker: duration must be a number")
    assert(type(callback) == "function", "C_Timer.NewTicker: callback must be a function")
    
    if iterations then
        assert(type(iterations) == "number", "C_Timer.NewTicker: iterations must be a number or nil")
    end
    
    idCounter = idCounter + 1
    
    timers[idCounter] = {
        id = idCounter,
        active = true,
        elapsed = 0,
        duration = duration,
        callback = callback,
        isTicker = true,
        iterations = iterations
    }
    
    return timers[idCounter]
end

--[[
 * Cancel a timer before it fires
 *
 * @param timer object The TimerHandle to cancel
--]]
function C_Timer.CancelTimer(timer)
    if type(timer) ~= "table" or not timer.id or not timers[timer.id] then
        return
    end
    
    timers[timer.id].active = false
end

--[[
 * Returns the fraction of a timer's duration that has elapsed
 *
 * @param timer object The TimerHandle to query
 * @return number The elapsed fraction (0-1)
--]]
function C_Timer.GetTimerElapsed(timer)
    if type(timer) ~= "table" or not timer.id or not timers[timer.id] then
        return 0
    end
    
    local t = timers[timer.id]
    return t.active and (t.elapsed / t.duration) or 1
end

--[[
 * Returns the remaining time for a timer
 *
 * @param timer object The TimerHandle to query
 * @return number The remaining time in seconds
--]]
function C_Timer.GetTimerRemaining(timer)
    if type(timer) ~= "table" or not timer.id or not timers[timer.id] then
        return 0
    end
    
    local t = timers[timer.id]
    return t.active and (t.duration - t.elapsed) or 0
end