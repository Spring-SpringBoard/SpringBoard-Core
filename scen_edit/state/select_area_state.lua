SelectAreaState = AbstractState:extends{}

function SelectAreaState:init(callback)
    self.callback = callback
    SB.SetMouseCursor("search")
end

function SelectAreaState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground"  then
            local selected = SB.checkAreaIntersections(coords[1], coords[3])
            if selected ~= nil then
                self.callback(selected)
                SB.stateManager:SetState(DefaultState())
            end
        end
    elseif button == 3 then
        SB.stateManager:SetState(DefaultState())
    end
end
