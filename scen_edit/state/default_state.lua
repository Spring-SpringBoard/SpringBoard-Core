DefaultState = AbstractEditingState:extends{}

function DefaultState:init()
    self.areaSelectTime = Spring.GetGameFrame()
    SCEN_EDIT.SetMouseCursor()
end

function DefaultState:checkResizeIntersections(x, z)
    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
    if selType ~= "areas" and #items ~= 1 then
        return false
    end
    local selected = items[1]
    local rect = SCEN_EDIT.model.areaManager:getArea(selected)
    local accurancy = 20
    local toResize = false
    local resx, resz = 0, 0
    if math.abs(x - rect[1]) < accurancy then
        resx = -1
        drag_diff_x = rect[1] - x
        toResize = true
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(x - rect[3]) < accurancy then
        resx = 1
        drag_diff_x = rect[3] - x
        toResize = true
        if z > rect[2] + accurancy and z < rect[4] - accurancy then
            resz = 0
        elseif math.abs(rect[2] - z) < accurancy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accurancy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(z - rect[2]) < accurancy then
        resx = 0
        resz = -1
        drag_diff_z = rect[2] - z
        if x > rect[1] + accurancy and x < rect[3] + accurancy then
            toResize = true
        else
            toResize = false
        end
    elseif math.abs(z - rect[4]) < accurancy then
        resx = 0
        resz = 1
        drag_diff_z = rect[4] - z
        if x > rect[1] + accurancy and x < rect[3] + accurancy then
            toResize = true
        else
            toResize = false
        end
    end
    return toResize, resx, resz
end

function DefaultState:MousePress(x, y, button)
    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
    if Spring.GetPressedKeys() == KEYSYMS.SPACE and button == 1 then
        local result, unitId = Spring.TraceScreenRay(x, y)
        if result == "unit" then
            UnitPropertyWindow(unitId)
            return true
        end
    end
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y)
        if result == "ground" then
            if SCEN_EDIT.view.displayDevelop then
                if selType == "areas" and #items ~= 0 then
                    toResize, resx, resz = self:checkResizeIntersections(coords[1], coords[3])
                    if toResize then
                        local _, resizeAreas = SCEN_EDIT.view.selectionManager:GetSelection()
                        local resizeArea = resizeAreas[1]
                        SCEN_EDIT.stateManager:SetState(ResizeAreaState(resizeArea, resx, resz))
                        return true
                    else
                        local currentFrame = Spring.GetGameFrame()
                        --check if double click on area to create the default area trigger
                        if self.dragArea and self.areaSelectTime and currentFrame - self.areaSelectTime < 5 then
                            local trigger = {
                                name = "Enter area " .. self.dragArea,
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
                                            id = self.dragArea,
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
                local _, ctrl = Spring.GetModKeyState()
                if ctrl and (selType == "units" or selType == "features") then
                    return true
                else
                    selected, self.dragDiffX, self.dragDiffZ = SCEN_EDIT.checkAreaIntersections(coords[1], coords[3])
                    if selected then
                        self.dragArea = selected
                        SCEN_EDIT.view.selectionManager:SelectAreas({selected})
                        self.areaSelectTime = Spring.GetGameFrame()
                        return true
                    end
                end
                SCEN_EDIT.stateManager:SetState(RectangleSelectState(x, y))
                return
            end
        elseif result == "unit" then
            local unitId = coords

            if not SCEN_EDIT.lockTeam then
                local unitTeamId = Spring.GetUnitTeam(unitId)
                if Spring.GetMyTeamID() ~= unitTeamId or Spring.GetSpectatingState() then
                    if SCEN_EDIT.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                        local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), unitTeamId)
                        SCEN_EDIT.commandManager:execute(cmd)
                    end
                end
            end

            local result, coords = Spring.TraceScreenRay(x, y, true)
            -- it's possible that there is no ground behind (if object is near the map edge)
            if coords ~= nil then
                local x, y, z = Spring.GetUnitPosition(unitId)
                self.dragDiffX, self.dragDiffZ =  x - coords[1], z - coords[3]

                local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
                if selType == "units" then
                    for _, oldUnitId in pairs(items) do
                        if oldUnitId == unitId then
                            self.dragUnit = unitId
                            return true
                        end
                    end
                end
            end
        elseif result == "feature" then
            local featureId = coords
            local result, coords = Spring.TraceScreenRay(x, y, true)
            -- it's possible that there is no ground behind (if object is near the map edge)
            if coords ~= nil then
                local x, y, z = Spring.GetFeaturePosition(featureId)
                self.dragDiffX, self.dragDiffZ = x - coords[1], z - coords[3]
                if selType == "features" then                
                    for _, oldFeatureId in pairs(items) do
                        if oldFeatureId == featureId then
                            self.dragFeature = featureId
                            return true
                        end
                    end
                end
            end
            SCEN_EDIT.view.selectionManager:SelectFeatures({featureId})            
        end
    end
end

function DefaultState:MouseMove(x, y, dx, dy, button)
    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
    if selType == "areas" and SCEN_EDIT.view.displayDevelop then
        SCEN_EDIT.stateManager:SetState(DragAreaState(self.dragArea, self.dragDiffX, self.dragDiffZ))
    elseif selType == "units" then
        local _, ctrl = Spring.GetModKeyState()
        if ctrl then
            SCEN_EDIT.stateManager:SetState(RotateUnitState())
        else
            SCEN_EDIT.stateManager:SetState(DragUnitState(self.dragUnit, self.dragDiffX, self.dragDiffZ))
        end
    elseif selType == "features" then
        local _, ctrl = Spring.GetModKeyState()
        if ctrl then
            SCEN_EDIT.stateManager:SetState(RotateFeatureState(items[1]))
        else
            SCEN_EDIT.stateManager:SetState(DragFeatureState(self.dragFeature, self.dragDiffX, self.dragDiffZ))
        end
    end
end

function DefaultState:KeyPress(key, mods, isRepeat, label, unicode)
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end

    local gameSeconds = Spring.GetGameSeconds()
    local mouseX, mouseY, mouseLeft, mouseMiddle, mouseRight = Spring.GetMouseState()
    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
    if key == KEYSYMS.DELETE then
        if selType == "areas" then
            local commands = {}
            for _, areaId in pairs(items) do
                table.insert(commands, RemoveAreaCommand(areaId))
            end
            --SCEN_EDIT.view.areaViews[self.selected] = nil
            local cmd = CompoundCommand(commands)
            SCEN_EDIT.commandManager:execute(cmd)
            return true
        elseif selType == "units" then
            local removeUnitCommands = {}
            for _, unitId in pairs(items) do
                local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
                local cmd = RemoveUnitCommand(modelUnitId)
                table.insert(removeUnitCommands, cmd)
            end
            local cmd = CompoundCommand(removeUnitCommands)
            SCEN_EDIT.commandManager:execute(cmd)
            return true
        elseif selType == "features" then
            local commands = {}
            for _, featureId in pairs(items) do
                local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
                local cmd = RemoveFeatureCommand(modelFeatureId)
                table.insert(commands, cmd)
            end
            local cmd = CompoundCommand(commands)
            SCEN_EDIT.commandManager:execute(cmd)
            return true
        end
    elseif key == KEYSYMS.C and mods.ctrl then
        if selType == "units" then
            SCEN_EDIT.clipboard:CopyUnits(items)
            return true
        elseif selType == "features" then
            SCEN_EDIT.clipboard:CopyFeatures(items)
            return true
        end
    elseif key == KEYSYMS.X and mods.ctrl then
        if selType == "units" then
            SCEN_EDIT.clipboard:CutUnits(items)
            return true
        elseif selType == "features" then
            SCEN_EDIT.clipboard:CutFeatures(items)
            return true
        end
    elseif key == KEYSYMS.V and mods.ctrl then
        local result, coords = Spring.TraceScreenRay(mouseX, mouseY, true)
        if result == "ground" then
            SCEN_EDIT.clipboard:Paste(coords)
            return true
        end
    elseif key == KEYSYMS.SPACE and mouseLeft and (self.gameSeconds == nil or self.gameSeconds + 1 < gameSeconds) then
        local result, unitId = Spring.TraceScreenRay(mouseX, mouseY)
        if result == "unit" then
            self.gameSeconds = gameSeconds
            UnitPropertyWindow(unitId)
        end
    end 
    return false
end

function DefaultState:DrawWorldPreUnit()
end
