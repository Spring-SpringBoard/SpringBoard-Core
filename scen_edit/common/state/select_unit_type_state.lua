SelectUnitTypeState = AbstractState:extends{}

function SelectUnitTypeState:init(btnSelectUnitType)
    self.btnSelectUnitType = btnSelectUnitType
end

function SelectUnitTypeState:enterState()
end

function SelectUnitTypeState:leaveState()
end

function SelectUnitTypeState:MousePress(x, y, button)
    if button == 1 then
        local result, unitId = Spring.TraceScreenRay(x, y)
        if result == "unit"  then
            CallListeners(self.btnSelectUnitType.OnSelectUnitType, SCEN_EDIT.model:GetModelUnitId(unitId))
        end
    elseif button == 3 then
        SCEN_EDIT.unitManager:SetState(DefaultState())
    end
end
