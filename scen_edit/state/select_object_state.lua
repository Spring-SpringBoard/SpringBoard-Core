SB.Include(SB_STATE_DIR .. "abstract_state.lua")

SelectObjectState = AbstractState:extends{}

function SelectObjectState:init(callback)
    AbstractState.init(self)

    self.callback = callback
    SB.SetMouseCursor("search")

    SB.SetGlobalRenderingFunction(function(...)
        self:__DrawInfo(...)
    end)
end

function SelectObjectState:leaveState()
    AbstractState.leaveState(self)
    SB.SetGlobalRenderingFunction(nil)
end

function SelectObjectState:MousePress(x, y, button)
    if button == 1 then
        local success, objectID = self:__MaybeTraceObject(x, y)
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

    local x, y, _, _, _, outsideSpring = Spring.GetMouseState()
    -- Don't draw if outside Spring
    if outsideSpring then
        return true
    end

    local vsx, vsy = Spring.GetViewGeometry()
    y = vsy - y

    self.__displayFont:Draw(self:__GetInfoText(), x, y - 30)

    -- return true to keep redrawing
    return true
end

--------------------------
-- Custom object classes
--------------------------

--------------------------
-- Unit
--------------------------
SelectUnitState = SelectObjectState:extends{}
function SelectUnitState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = unitBridge
end

function SelectUnitState:__MaybeTraceObject(x, y)
    local result, objectID = Spring.TraceScreenRay(x, y)
    if result == "unit" then
        return true, objectID
    end
end

--------------------------
-- Feature
--------------------------
SelectFeatureState = SelectObjectState:extends{}
function SelectFeatureState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = featureBridge
end

function SelectFeatureState:__MaybeTraceObject(x, y)
    local result, objectID = Spring.TraceScreenRay(x, y)
    if result == "feature" then
        return true, objectID
    end
end

--------------------------
-- Area
--------------------------
SelectAreaState = SelectObjectState:extends{}
function SelectAreaState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = areaBridge
end

function SelectAreaState:__MaybeTraceObject(x, y)
    local result, coords = Spring.TraceScreenRay(x, y)
    if result == "ground" then
        local selected = SB.model.areaManager:GetAreaIn(coords[1], coords[3])
        if selected ~= nil then
            return true, selected
        end
    end
end

--------------------------
-- Position
--------------------------
SelectPositionState = SelectObjectState:extends{}
function SelectPositionState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = positionBridge
end

function SelectPositionState:__MaybeTraceObject(x, y)
    local result, coords = Spring.TraceScreenRay(x, y)
    if result == "ground"  then
        local position = {
            x = coords[1],
            y = coords[2],
            z = coords[3],
        }
        return true, position
    end
end
