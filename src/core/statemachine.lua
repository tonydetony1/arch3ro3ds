-- src/core/statemachine.lua
-- Machine d'états propre et extensible (Menu, Jeu, Draft/Pause, GameOver)

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
    local self = setmetatable({}, StateMachine)
    self.states = {}
    self.stack = {}
    self.current = nil
    return self
end

function StateMachine:add(name, state)
    self.states[name] = state
end

-- Bascule d'un état à un autre en écrasant l'état courant
function StateMachine:switch(name, ...)
    assert(self.states[name], "State does not exist: " .. tostring(name))
    
    if self.current and self.current.exit then
        self.current:exit()
    end
    
    self.current = self.states[name]
    self.stack = { self.current }
    
    if self.current.enter then
        self.current:enter(...)
    end
end

-- Empile un nouvel état par-dessus l'existant (ex: Écran de Draft / Pause)
function StateMachine:push(name, ...)
    assert(self.states[name], "State does not exist: " .. tostring(name))
    
    if self.current and self.current.pause then
        self.current:pause()
    end
    
    local nextState = self.states[name]
    table.insert(self.stack, nextState)
    self.current = nextState
    
    if self.current.enter then
        self.current:enter(...)
    end
end

-- Dépile l'état courant et reprend l'état précédent
function StateMachine:pop(...)
    if #self.stack <= 1 then return end
    
    if self.current and self.current.exit then
        self.current:exit()
    end
    
    table.remove(self.stack)
    self.current = self.stack[#self.stack]
    
    if self.current and self.current.resume then
        self.current:resume(...)
    end
end

function StateMachine:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function StateMachine:drawTop(eye)
    if self.current and self.current.drawTop then
        self.current:drawTop(eye)
    end
end

function StateMachine:drawBottom()
    if self.current and self.current.drawBottom then
        self.current:drawBottom()
    end
end

function StateMachine:keypressed(key)
    if self.current and self.current.keypressed then
        self.current:keypressed(key)
    end
end

function StateMachine:gamepadaxis(joystick, axis, value)
    if self.current and self.current.gamepadaxis then
        self.current:gamepadaxis(joystick, axis, value)
    end
end

function StateMachine:gamepadpressed(joystick, button)
    if self.current and self.current.gamepadpressed then
        self.current:gamepadpressed(joystick, button)
    elseif self.current and self.current.keypressed then
        self.current:keypressed(button)
    end
end

function StateMachine:touchpressed(id, x, y)
    if self.current and self.current.touchpressed then
        self.current:touchpressed(id, x, y)
    end
end

function StateMachine:touchmoved(id, x, y, dx, dy)
    if self.current and self.current.touchmoved then
        self.current:touchmoved(id, x, y, dx, dy)
    end
end

function StateMachine:touchreleased(id, x, y)
    if self.current and self.current.touchreleased then
        self.current:touchreleased(id, x, y)
    end
end

return StateMachine
