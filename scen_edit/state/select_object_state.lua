SB.Include(SB_STATE_DIR .. "abstract_state.lua")

SelectObjectState = AbstractState:extends{}

function SelectObjectState:init(bridge, callback)
    AbstractState.init(self)

    self.bridge = bridge
    self.callback = callback
end

function SelectObjectState:enterState()
    AbstractState.enterState(self)

    SB.SetMouseCursor("search")
    SB.SetGlobalRenderingFunction(function(...)
        self:__DrawInfo(...)
    end)
end

function SelectObjectState:leaveState()
    AbstractState.leaveState(self)

    SB.SetGlobalRenderingFunction(nil)
end

function SelectObjectState:MousePress(mx, my, button)
    if button == 1 then
        local onlyCoords = self.bridge == positionBridge
        local success, objectID = SB.TraceScreenRay(mx, my, {
            onlyCoords = onlyCoords,
            type = self.bridge.name,
        })
        if success then
            self.callback(self.bridge.getObjectModelID(objectID))
            SB.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
    return true
end

function SelectObjectState:__GetInfoText()
    return "Select " .. tostring(self.bridge.humanName)
end

local _displayColor = {1.0, 0.7, 0.1, 0.8}
function SelectObjectState:__DrawInfo()
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

    local vsx, vsy = Spring.GetViewGeometry()

    local x = mx
    local y = vsy - my - 30
    self.__displayFont:Draw(self:__GetInfoText(), x, y)

    -- return true to keep redrawing
    return true
end
