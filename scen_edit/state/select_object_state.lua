SelectObjectState = AbstractState:extends{}

function SelectObjectState:init(btnSelectObject)
    self.btnSelectObject = btnSelectObject
    SCEN_EDIT.SetMouseCursor("search")
end

function SelectObjectState:MousePress(x, y, button)
    if button == 1 then
        local result, objectID = Spring.TraceScreenRay(x, y)
        if (result == "unit" and self.bridge.bridgeName == "UnitBridge") or
           (result == "feature" and self.bridge.bridgeName == "FeatureBridge") then
            CallListeners(self.btnSelectObject.OnSelectObject, self.bridge.getObjectModelID(objectID))
            SCEN_EDIT.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

-- Custom unit/feature classes (just Unit for now)
SelectUnitState = SelectObjectState:extends{}
function SelectUnitState:init(...)
    SelectObjectState.init(self, ...)
    self.bridge = unitBridge
end