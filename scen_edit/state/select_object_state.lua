SB.Include(SB_STATE_DIR .. "abstract_state.lua")

SelectObjectState = AbstractState:extends{}

function SelectObjectState:init(callback)
    self.callback = callback
    SB.SetMouseCursor("search")
end

function SelectObjectState:MousePress(x, y, button)
    if button == 1 then
        local result, objectID = Spring.TraceScreenRay(x, y)
        if (result == "unit" and self.bridge.bridgeName == "UnitBridge") or
           (result == "feature" and self.bridge.bridgeName == "FeatureBridge") then
            self.callback(self.bridge.getObjectModelID(objectID))
            SB.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end

-- Custom unit/feature classes
SelectUnitState = SelectObjectState:extends{}
function SelectUnitState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = unitBridge
end

SelectFeatureState = SelectObjectState:extends{}
function SelectFeatureState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = featureBridge
end
