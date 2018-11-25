AddRectState = AbstractState:extends{}

function AddRectState:enterState()
    AbstractState.enterState(self)

    SB.SetGlobalRenderingFunction(function(...)
        self:__DrawInfo(...)
    end)
end

function AddRectState:leaveState()
    AbstractState.leaveState(self)

    SB.SetGlobalRenderingFunction(nil)
end

function AddRectState:MousePress(mx, my, button)
    if button == 1 then
        if self.addSecondPoint then
            return
        end
        local result, coords = Spring.TraceScreenRay(mx, my, true)
        if result == "ground" then
            self.startX = coords[1]
            self.startZ = coords[3]
            self.endX = coords[1]
            self.endZ = coords[3]
            self.addSecondPoint = true
            return true
        end
    else
        SB.stateManager:SetState(DefaultState())
    end
end

function AddRectState:MouseMove(mx, my, mdx, mdy, button)
    if not self.addSecondPoint then
        return
    end

    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
        self.endX = coords[1]
        self.endZ = coords[3]
    end
end

function AddRectState:MouseRelease(mx, my, button)
    if not self.addSecondPoint then
        return
    end

    if button ~= 1 then
        return
    end

    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
        self.endX = coords[1]
        self.endZ = coords[3]
    end
    if self.endX == nil or self.endZ == nil then
        return
    end

    local cmd = AddObjectCommand(areaBridge.name, {
        pos = { x = (self.startX + self.endX)/2, y = 0, z = (self.startZ + self.endZ)/2},
        size = { x = math.abs(self.endX - self.startX), y = 0, z = math.abs(self.endZ - self.startZ)},
    })
    SB.commandManager:execute(cmd)

    SB.stateManager:SetState(DefaultState())
end

function AddRectState:DrawWorld()
    gl.PushMatrix()
    gl.Color(0, 1, 0, 0.2)
    if self.addSecondPoint then
        areaBridge.DrawObject(nil, {self.startX, self.startZ, self.endX, self.endZ})
    end
    gl.PopMatrix()
end

function AddRectState:__GetInfoText()
    return "Add area"
end

local _displayColor = {1.0, 0.7, 0.1, 0.8}
function AddRectState:__DrawInfo()
    if not self.__displayFont then
        self.__displayFont = Chili.Font:New {
            size = 12,
            color = _displayColor,
            outline = true,
        }
    end

    local mx, my, _, _, _, outsideSpring = Spring.GetMouseState()
    -- Don't draw if outside Spring
    if outsideSpring then
        return true
    end

    local _, vsy = Spring.GetViewGeometry()

    local x = mx
    local y = vsy - my - 30
    self.__displayFont:Draw(self:__GetInfoText(), x, y)

    -- return true to keep redrawing
    return true
end
