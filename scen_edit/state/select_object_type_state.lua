SelectObjectTypeState = AbstractState:extends{}

function SelectObjectTypeState:init(btnSelectObjectType)
    self.btnSelectObjectType = btnSelectObjectType
    SB.SetMouseCursor("search")
end

function SelectObjectTypeState:MousePress(x, y, button)
    if button == 1 then
        local result, objectID = Spring.TraceScreenRay(x, y)
        if (result == "unit" and self.bridge.bridgeName == "UnitBridge") or
           (result == "feature" and self.bridge.bridgeName == "FeatureBridge") then
            local objectDefID = self.bridge.spGetObjectDefID(objectID)
            CallListeners(self.btnSelectObjectType.OnSelectObjectType, objectDefID)
            SB.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end

function SelectObjectTypeState:SelectObjectType(objectDefID)
    CallListeners(self.btnSelectObjectType.OnSelectObjectType, objectDefID)
    SB.stateManager:SetState(DefaultState())
end

-- Custom unit/feature classes
SelectUnitTypeState = SelectObjectTypeState:extends{}
function SelectUnitTypeState:init(...)
    SelectObjectTypeState.init(self, ...)
    self.bridge = unitBridge
end

SelectFeatureTypeState = SelectObjectTypeState:extends{}
function SelectFeatureTypeState:init(...)
    SelectObjectTypeState.init(self, ...)
    self.bridge = featureBridge
end
