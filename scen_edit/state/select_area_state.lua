SelectAreaState = AbstractState:extends{}

function SelectAreaState:init(btnSelectArea)
    self.btnSelectArea = btnSelectArea
    SCEN_EDIT.SetMouseCursor("search")
end

function SelectAreaState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground"  then
            local selected = SCEN_EDIT.checkAreaIntersections(coords[1], coords[3])
            if selected ~= nil then
                CallListeners(self.btnSelectArea.OnSelectArea, selected)
                SCEN_EDIT.stateManager:SetState(DefaultState())
            end
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end
