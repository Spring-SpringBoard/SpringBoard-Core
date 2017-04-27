DefaultState = AbstractEditingState:extends{}

function DefaultState:init()
    self.areaSelectTime = os.clock()
    SCEN_EDIT.SetMouseCursor()
end

function DefaultState:checkResizeIntersections(areaID, x, z)
    local rect = SCEN_EDIT.model.areaManager:getArea(areaID)
    local accuracy = 20
    local toResize = false
    local resx, resz = 0, 0
    if math.abs(x - rect[1]) < accuracy then
        resx = -1
        drag_diff_x = rect[1] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(x - rect[3]) < accuracy then
        resx = 1
        drag_diff_x = rect[3] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(z - rect[2]) < accuracy then
        resx = 0
        resz = -1
        drag_diff_z = rect[2] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    elseif math.abs(z - rect[4]) < accuracy then
        resx = 0
        resz = 1
        drag_diff_z = rect[4] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    end
    return toResize, resx, resz
end

function DefaultState:MakeAreaTrigger(areaID)
    local trigger = {
        name = "Enter area " .. areaID,
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
                    id = areaID,
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
    return trigger
end

function DefaultState:MousePress(x, y, button)
    local selection = SCEN_EDIT.view.selectionManager:GetSelection()
    local selCount = #selection.units + #selection.features + #selection.areas
    if Spring.GetPressedKeys() == KEYSYMS.SPACE and button == 1 then
        local result, unitId = Spring.TraceScreenRay(x, y)
        if result == "unit" then
            UnitPropertyWindow(unitId)
            return true
        end
    end
    local _, ctrl, _, shift = Spring.GetModKeyState()
    if (ctrl or shift) and selCount > 0 then
        -- TODO: There should be a cleaner way to disable some types of editing interactions during play
        if Spring.GetGameRulesParam("sb_gameMode") == "dev" then
            return true
        else
            return false
        end
    end
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, false, false, true)

        -- transform ground to area
        if result == "ground" and SCEN_EDIT.view.displayDevelop then
            local areaID = SCEN_EDIT.checkAreaIntersections(coords[1], coords[3])
            if areaID then
                result = "area"
                coords = areaID
            end
        end

        if result == "ground" or result == "sky" then
            SCEN_EDIT.stateManager:SetState(RectangleSelectState(x, y))
        elseif result == "unit" or result == "feature" or result == "area" then
            local objectID = coords

            if not SCEN_EDIT.lockTeam and result == "unit" then
                local unitTeamID = Spring.GetUnitTeam(objectID)
                if Spring.GetMyTeamID() ~= unitTeamID or Spring.GetSpectatingState() then
                    if SCEN_EDIT.FunctionExists(Spring.AssignPlayerToTeam, "Player change") then
                        local cmd = ChangePlayerTeamCommand(Spring.GetMyPlayerID(), unitTeamID)
                        SCEN_EDIT.commandManager:execute(cmd)
                    end
                end
            end

            local objects, bridge
            if result == "unit" then
                objects = selection.units
                bridge = unitBridge
            elseif result == "feature" then
                objects = selection.features
                bridge = featureBridge
            elseif result == "area" then
                objects = selection.areas
                bridge = areaBridge
            end
            local _, coords = Spring.TraceScreenRay(x, y, true)
            local x, y, z = bridge.spGetObjectPosition(objectID)
            -- it's possible that there is no ground behind (if object is near the map edge)
            if coords == nil then
                coords = { x, y, z }
            end
            self.dragDiffX, self.dragDiffZ =  x - coords[1], z - coords[3]
            for _, oldObjectID in pairs(objects) do
                if oldObjectID == objectID then
                    if bridge == unitBridge then
                        self.dragUnitID = objectID
                    elseif bridge == featureBridge then
                        self.dragFeatureID = objectID
                    elseif bridge == areaBridge then
                        local currentTime = os.clock()
                        -- resize/double click if there's only one area
                        if selCount == 1 then
                            local areaID = SCEN_EDIT.view.selectionManager:GetSelection().areas[1]
                            local toResize, resx, resz = self:checkResizeIntersections(areaID, coords[1], coords[3])
                            if toResize then
                                SCEN_EDIT.stateManager:SetState(ResizeAreaState(areaID, resx, resz))
                                return true
                            else
                                --check if double click on area to create the default area trigger
                                if self.dragAreaID and self.areaSelectTime and currentTime - self.areaSelectTime < 0.2 then
                                    local trigger = self:MakeAreaTrigger(self.dragAreaID)
                                    local cmd = AddTriggerCommand(trigger)
                                    SCEN_EDIT.commandManager:execute(cmd)
                                    return
                                end
                            end
                        end
                        -- no resize or double click, treat as drag
                        self.areaSelectTime = currentTime
                        self.dragAreaID = objectID
                    end
                    return true
                end
            end
            if bridge == unitBridge then
                SCEN_EDIT.view.selectionManager:Select({ units = {objectID}})
            elseif bridge == featureBridge then
                SCEN_EDIT.view.selectionManager:Select({ features = {objectID}})
            elseif bridge == areaBridge then
                SCEN_EDIT.view.selectionManager:Select({ areas = {objectID}})
            end
        end
    end
end

function DefaultState:MouseMove(x, y, dx, dy, button)
    local selection = SCEN_EDIT.view.selectionManager:GetSelection()
    local selCount = #selection.units + #selection.features + #selection.areas
    if selCount == 0 then
        return
    end
    local _, ctrl, _, shift = Spring.GetModKeyState()
    if ctrl then
        SCEN_EDIT.stateManager:SetState(RotateObjectState())
    elseif shift then
        SCEN_EDIT.stateManager:SetState(DragHorizontalUnitState(y))
        SCEN_EDIT.stateManager:SetState(DragHorizontalFeatureState(y))
    else
        if self.dragUnitID then
            SCEN_EDIT.stateManager:SetState(DragUnitState(self.dragUnitID, self.dragDiffX, self.dragDiffZ))
        elseif self.dragFeatureID then
            SCEN_EDIT.stateManager:SetState(DragFeatureState(self.dragFeatureID, self.dragDiffX, self.dragDiffZ))
        elseif self.dragAreaID and SCEN_EDIT.view.displayDevelop then
            SCEN_EDIT.stateManager:SetState(DragAreaState(self.dragAreaID, self.dragDiffX, self.dragDiffZ))
        end
    end
end

function DefaultState:KeyPress(key, mods, isRepeat, label, unicode)
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end

    local gameSeconds = Spring.GetGameSeconds()
    local mouseX, mouseY, mouseLeft, mouseMiddle, mouseRight = Spring.GetMouseState()
    local selection = SCEN_EDIT.view.selectionManager:GetSelection()
    local selCount = #selection.units + #selection.features + #selection.areas
    if key == KEYSYMS.DELETE then
        if selCount == 0 then
            return false
        end
        local commands = {}
        for _, unitId in pairs(selection.units) do
            local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
            table.insert(commands, RemoveUnitCommand(modelUnitId))
        end

        for _, featureId in pairs(selection.features) do
            local modelFeatureId = SCEN_EDIT.model.featureManager:getModelFeatureId(featureId)
            table.insert(commands, RemoveFeatureCommand(modelFeatureId))
        end

        for _, areaId in pairs(selection.areas) do
            table.insert(commands, RemoveAreaCommand(areaId))
        end

        local cmd = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(cmd)
    elseif key == KEYSYMS.C and mods.ctrl then
        SCEN_EDIT.clipboard:Copy(selection)
    elseif key == KEYSYMS.X and mods.ctrl then
        SCEN_EDIT.clipboard:Cut(selection)
    elseif key == KEYSYMS.V and mods.ctrl then
        local result, coords = Spring.TraceScreenRay(mouseX, mouseY, true)
        if result == "ground" then
            SCEN_EDIT.clipboard:Paste(coords)
        end
    elseif key == KEYSYMS.A and mods.ctrl then
        local selection = {
            units = Spring.GetAllUnits(),
            features = Spring.GetAllFeatures(),
            areas = SCEN_EDIT.model.areaManager:getAllAreas(),
        }
        SCEN_EDIT.view.selectionManager:Select(selection)
    elseif key == KEYSYMS.SPACE and mouseLeft and (self.gameSeconds == nil or self.gameSeconds + 1 < gameSeconds) then
        local result, unitId = Spring.TraceScreenRay(mouseX, mouseY)
        if result == "unit" then
            self.gameSeconds = gameSeconds
            UnitPropertyWindow(unitId)
        end
    else
        return false
    end
    return true
end

function DefaultState:DrawWorldPreUnit()
end
