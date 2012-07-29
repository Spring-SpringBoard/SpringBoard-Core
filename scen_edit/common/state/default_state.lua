DefaultState = AbstractState:extends{}

function DefaultState:checkResizeIntersections(x, z)
    if self.selected == nil then
        return false
    end
    local rect = SCEN_EDIT.model.areaManager:getArea(self.selected)
    local accurancy = 20
    local toResize = false
    local resx, resz = 0, 0
    if math.abs(x - rect[1]) < accurancy then
        resx = -1
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            resz = 1
        end
        drag_diff_x = rect[1] - x
        toResize = true
    elseif math.abs(x - rect[3]) < accurancy then
        resx = 1
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            resz = 1
        end
        drag_diff_x = rect[3] - x
        toResize = true
    elseif math.abs(z - rect[2]) < accurancy then
        resx = 0
        resz = -1
        drag_diff_z = rect[2] - z
        toResize = true
    elseif math.abs(z - rect[4]) < accurancy then
        resx = 0
        resz = 1
        drag_diff_z = rect[4] - z
        toResize = true
    end
    return toResize, resx, resz
end

function DefaultState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            if self.selected ~= nil then
                toResize, resx, resz = self:checkResizeIntersections(coords[1], coords[3])
                Spring.Echo(toResize, resx, resz)
                if toResize then
                    SCEN_EDIT.stateManager:SetState(ResizeAreaState(self.selected, resx, resz))
                    return true
                else
                    local currentFrame = Spring.GetGameFrame()
                    if currentFrame - self.areaSelectTime < 5 then
                        Spring.Echo("double click")
                        local trigger = {
                            name = "Enter area " .. self.selected,
                            enabled = true,
                            actions = {},
                            events = {
                                {
                                    eventTypeName = "UNIT_ENTER_AREA",
                                },
                            },
                            conditions = {
                                {
                                    conditionTypeName = "compare_area",
                                    first = {
                                        id = self.selected,
                                        type = "pred",
                                    },
                                    relation = {
                                        cmpTypeId = 1,
                                    },
                                    second = {
                                        name = "Trigger area",
                                        type = "spec",
                                    },
                                },
                            },
                        }
                        local cmd = AddTriggerCommand(trigger)
                        SCEN_EDIT.commandManager:execute(cmd)
                    end
                end
            end
            if self.selected then
                SCEN_EDIT.view.areaViews[self.selected].selected = false
            end
            self.selected, self.dragDiffX, self.dragDiffZ = checkAreaIntersections(coords[1], coords[3])
            if self.selected ~= nil then
                self.areaSelectTime = Spring.GetGameFrame()
                Spring.SelectUnitArray({}, false)
                return true
            end
            local _, ctrl = Spring.GetModKeyState()
            if ctrl and #Spring.GetSelectedUnits() ~= 0 then
                return true
            end
        elseif result == "unit" then
            if self.selected then
                Spring.Echo("deselect")
                SCEN_EDIT.view.areaViews[self.selected].selected = false
                self.selected = nil
            end
            if #Spring.GetSelectedUnits() ~= 0 then
                self.selectedUnit = coords --coords = unit id
                local previouslySelectedUnits = Spring.GetSelectedUnits()
                for _, unitId in pairs(previouslySelectedUnits) do
                    if unitId == self.selectedUnit then
                        return true
                    end
                end
                return false
            end
        end
    end
end

function DefaultState:MouseMove(x, y, dx, dy, button)
    if self.selected ~= nil then
        SCEN_EDIT.stateManager:SetState(DragAreaState(self.selected, self.dragDiffX, self.dragDiffZ))
    elseif #Spring.GetSelectedUnits() ~= 0 then
        local _, ctrl = Spring.GetModKeyState()
        if ctrl then
            SCEN_EDIT.stateManager:SetState(RotateUnitState())
        elseif self.selected == nil then
            SCEN_EDIT.stateManager:SetState(DragUnitState(self.selectedUnit))
        end
    end
end

function DefaultState:KeyPress(key, mods, isRepeat, label, unicode)
    if key == KEYSYMS.DELETE then
        if self.selected ~= nil then
            --SCEN_EDIT.view.areaViews[self.selected] = nil
            local cmd = RemoveAreaCommand(self.selected)
            SCEN_EDIT.commandManager:execute(cmd)
            self.selected = nil
            return true
        elseif self.selected == nil then
            local selectedUnits = Spring.GetSelectedUnits()
            local removeUnitCommands = {}
            for i = 1, #selectedUnits do
                local unitId = selectedUnits[i]
                local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
                local cmd = RemoveUnitCommand(modelUnitId)
                table.insert(removeUnitCommands, cmd)
            end
            local cmd = CompoundCommand(removeUnitCommands)
            SCEN_EDIT.commandManager:execute(cmd)
            if #selectedUnits > 0 then
                return true
            end
        end
    elseif key == KEYSYMS.Z and mods.ctrl then
        if #SCEN_EDIT.commandManager.undoList > 0 then
        --    Spring.Echo("to undo")
        end
        SCEN_EDIT.commandManager:undo()
        return true
    elseif key == KEYSYMS.Y and mods.ctrl then
        if #SCEN_EDIT.commandManager.redoList > 0 then
        --    Spring.Echo("to redo")
        end
        SCEN_EDIT.commandManager:redo()
        return true
    elseif key == KEYSYMS.C and mods.ctrl then
        local selectedUnits = Spring.GetSelectedUnits()
        SCEN_EDIT.clipboard:copyUnits(selectedUnits)
        return true
    elseif key == KEYSYMS.X and mods.ctrl then
        local selectedUnits = Spring.GetSelectedUnits()
        SCEN_EDIT.clipboard:cutUnits(selectedUnits)
        return true
    elseif key == KEYSYMS.V and mods.ctrl then
        x, y = Spring.GetMouseState()
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            SCEN_EDIT.clipboard:pasteUnits(coords)
        end
        return true
    end
    return false
end
