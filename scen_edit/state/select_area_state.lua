SelectAreaState = AbstractState:extends{}

function SelectAreaState:init(btnSelectArea)
    self.btnSelectArea = btnSelectArea
    SB.SetMouseCursor("search")
end

function SelectAreaState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground"  then
            local selected = SB.checkAreaIntersections(coords[1], coords[3])
            if selected ~= nil then
                CallListeners(self.btnSelectArea.OnSelectArea, selected)
                SB.stateManager:SetState(DefaultState())
            end
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end
