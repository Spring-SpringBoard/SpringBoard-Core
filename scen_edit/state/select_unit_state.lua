SelectUnitState = AbstractState:extends{}
Spring.AssignMouseCursor('search', 'search', false)

function SelectUnitState:init(btnSelectUnit)
    self.btnSelectUnit = btnSelectUnit
    SCEN_EDIT.SetMouseCursor("search")
end

function SelectUnitState:MousePress(x, y, button)
    if button == 1 then
        local result, unitId = Spring.TraceScreenRay(x, y)
        if result == "unit"  then
            CallListeners(self.btnSelectUnit.OnSelectUnit, SCEN_EDIT.model.unitManager:getModelUnitId(unitId))
            SCEN_EDIT.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function SelectUnitState:KeyPress(key, mods, isRepeat, label, unicode)
end
