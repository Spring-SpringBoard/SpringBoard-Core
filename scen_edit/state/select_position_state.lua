SelectPositionState = AbstractState:extends{}

function SelectPositionState:init(btnSelectPosition)
    self.btnSelectPosition = btnSelectPosition
    SB.SetMouseCursor("search")
end

function SelectPositionState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground"  then
            local position = {
                x = coords[1],
                y = coords[2],
                z = coords[3],
            }
            CallListeners(self.btnSelectPosition.OnSelectPosition, position)
            SB.stateManager:SetState(DefaultState())
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end
