SelectObjectTypeState = SelectObjectState:extends{}

function SelectObjectTypeState:init(callback)
    SelectObjectState.init(self, callback)
end

function SelectObjectTypeState:MousePress(x, y, button)
    if button == 1 then
        local success, objectID = self:__MaybeTraceObject(x, y)
        if success then
            local objectDefID = self.bridge.GetObjectDefID(objectID)
            self:SelectObjectType(objectDefID)
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end

function SelectObjectTypeState:__GetInfoText()
    return SelectObjectState.__GetInfoText(self) .. " type"
end

function SelectObjectTypeState:SelectObjectType(objectDefID)
    self.callback(objectDefID)
    SB.stateManager:SetState(DefaultState())
end

--------------------------
-- Custom object classes
--------------------------

--------------------------
-- Unit
--------------------------
SelectUnitTypeState = SelectObjectTypeState:extends{}
function SelectUnitTypeState:init(...)
    SelectObjectTypeState.init(self, ...)
    self.bridge = unitBridge
end

function SelectUnitTypeState:__MaybeTraceObject(x, y)
    return SelectUnitState.__MaybeTraceObject(self, x, y)
end


--------------------------
-- Feature
--------------------------
SelectFeatureTypeState = SelectObjectTypeState:extends{}
function SelectFeatureTypeState:init(...)
    SelectObjectTypeState.init(self, ...)
    self.bridge = featureBridge
end

function SelectFeatureTypeState:__MaybeTraceObject(x, y)
    return SelectFeatureState.__MaybeTraceObject(self, x, y)
end
