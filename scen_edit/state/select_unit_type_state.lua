SelectUnitTypeState = AbstractState:extends{}

function SelectUnitTypeState:init(btnSelectUnitType)
    self.btnSelectUnitType = btnSelectUnitType
    SCEN_EDIT.SetMouseCursor("search")
end

function SelectUnitTypeState:MousePress(x, y, button)
    if button == 1 then
        local result, unitId = Spring.TraceScreenRay(x, y)
        if result == "unit"  then
            CallListeners(self.btnSelectUnitType.OnSelectUnitType, SCEN_EDIT.model:GetModelUnitId(unitId))
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function SelectUnitTypeState:SelectUnitType(unitTypeId)
    CallListeners(self.btnSelectUnitType.OnSelectUnitType, unitTypeId)
    SCEN_EDIT.stateManager:SetState(DefaultState())
end
