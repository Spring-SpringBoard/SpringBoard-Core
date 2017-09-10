SelectObjectTypeState = SelectObjectState:extends{}

function SelectObjectTypeState:init(bridge, callback)
    SelectObjectState.init(self, bridge, callback)
end

function SelectObjectTypeState:MousePress(x, y, button)
    if button == 1 then
        local success, objectID = SB.TraceScreenRay(x, y, {
            type = self.bridge.name,
        })
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
