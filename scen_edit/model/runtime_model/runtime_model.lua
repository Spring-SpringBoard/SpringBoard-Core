SB_MODEL_RUNTIME_DIR = SB_MODEL_DIR .. "runtime_model/"

RuntimeModel = LCS.class{}

function RuntimeModel:init()
    SB.IncludeDir(SB_MODEL_RUNTIME_DIR)
    self.areaModels = {}
    self.lastFrameUnitIDs = {}
    self.fieldResolver = FieldResolver()
    self.repeatCalls = {}
    self.trackedUnitIDs = {}

    -- triggers that contain missing references that would error when running
    -- they are disabled and won't be added
    self.error_triggers = {}

    SB.model.areaManager:addListener(self)
    SB.model.triggerManager:addListener(self)
end

function RuntimeModel:CanTrackUnit(unitDefID)
    local customParams = UnitDefs[unitDefID].customParams
    if customParams.wall or customParams.effect then
        return false
    else
        return true
    end
end

function RuntimeModel:GetAllUnits()
    return self.trackedUnitIDs
end

function RuntimeModel:LoadMission()
    self.lastFrameUnitIDs = self:GetAllUnits()
    self.areaModels = {}
    self.repeatCalls = {}

    self.startListening = true

    self.error_triggers = {}

    local areas = SB.model.areaManager:getAllAreas()
    for _, id in pairs(areas) do
        self:onAreaAdded(id)
    end

    self.eventTriggers = {}
    local triggers = SB.model.triggerManager:getAllTriggers()
    for _, trigger in pairs(triggers) do
        self:onTriggerAdded(trigger.id)
    end
end

function RuntimeModel:onTriggerAdded(triggerID)
    if not self.startListening then
        return
    end
    local trigger = SB.model.triggerManager:getTrigger(triggerID)
    local success, msg = SB.model.triggerManager:ValidateTrigger(trigger)
    if not success then
        Log.Warning("Trigger error: " .. tostring(triggerID) .. ". " .. tostring(msg))
        self.error_triggers[triggerID] = true
        return
    end
    for _, event in pairs(trigger.events) do
        if not self.eventTriggers[event.typeName] then
            self.eventTriggers[event.typeName] = {}
        end
        table.insert(self.eventTriggers[event.typeName], trigger)
    end
end

function RuntimeModel:onTriggerRemoved(triggerID)
    if not self.startListening then
        return
    end
    self.error_triggers[triggerID] = nil
    for _, eventList in pairs(self.eventTriggers) do
        repeat
            local found = false
            for i, iterTrigger in pairs(eventList) do
                if iterTrigger.id == triggerID then
                    table.remove(eventList, i)
                    found = true
                    break
                end
            end
        until not found
    end
end

function RuntimeModel:onTriggerUpdated(triggerID)
    if not self.startListening then
        return
    end
    self:onTriggerRemoved(triggerID)
    self:onTriggerAdded(triggerID)
end

function RuntimeModel:onAreaAdded(areaID)
    if not self.startListening then
        return
    end
    local areaModel = AreaModel(areaID)
    areaModel:Populate(self.lastFrameUnitIDs)
    table.insert(self.areaModels, areaModel)
end

function RuntimeModel:onAreaRemoved(areaID)
    if not self.startListening then
        return
    end
    for i, areaModel in pairs(self.areaModels) do
        if areaModel.id == areaID then
            table.remove(self.areaModels, i)
            break
        end
    end
end

function RuntimeModel:onAreaChange(areaID)
    if not self.startListening then
        return
    end
    self:onAreaRemoved(areaID)
    self:onAreaAdded(areaID)
end

function RuntimeModel:GameStart()
    --TODO: assign initial variable values
    --END

    self.hasStarted = true
    self:OnEvent("GAME_START")
end

function RuntimeModel:GameStop()
    self:OnEvent("GAME_END")
    self.hasStarted = false
    self.startListening = false
end

function RuntimeModel:TeamDied(teamID)
    self:OnEvent("TEAM_DIE", { team = teamID })
end

function RuntimeModel:UnitCreated(unitID, unitDefID, teamID, builderID)
    if self:CanTrackUnit(unitDefID) then
        self.trackedUnitIDs[unitID] = unitID
    end
    local modelUnitID = SB.model.unitManager:getModelUnitID(unitID)
    self:OnEvent("UNIT_CREATE", { unit = modelUnitID })
end

function RuntimeModel:UnitDamaged(unitID)
    local modelUnitID = SB.model.unitManager:getModelUnitID(unitID)
    self:OnEvent("UNIT_DAMAGE", { unit = modelUnitID })
end

function RuntimeModel:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
    self.trackedUnitIDs[unitID] = nil
    local modelUnitID = SB.model.unitManager:getModelUnitID(unitID)
    self:OnEvent("UNIT_DESTROY", { unit = modelUnitID })
end

function RuntimeModel:UnitFinished(unitID)
    local modelUnitID = SB.model.unitManager:getModelUnitID(unitID)
    self:OnEvent("UNIT_FINISH", { unit = modelUnitID })
end

local checkRate = 10
function RuntimeModel:GameFrame(frameNum)
    if not self.hasStarted then
        return
    end

    if Spring.GetGameFrame() % checkRate == 0 then
        local newUnitIDs = self:GetAllUnits()
        local unitIDs = {}
        --update area-unit models
        for _, newID in pairs(newUnitIDs) do
            if self.lastFrameUnitIDs[newID] then
                table.insert(unitIDs, newID)
            end
        end
        --check for any enter/leave area events
        for _, areaModel in pairs(self.areaModels) do
            local results = areaModel:Populate(unitIDs)
            local area = areaModel.area
            if self.eventTriggers["UNIT_ENTER_AREA"] then
                for _, unitID in pairs(results.entered) do
                    local modelUnitID = SB.model.unitManager:getModelUnitID(unitID)
                    self:OnEvent("UNIT_ENTER_AREA", {
                        unit = modelUnitID,
                        area = areaModel.id
                    })
                end
            end
            if self.eventTriggers["UNIT_LEAVE_AREA"] then
                -- TODO: check if leftUnitID really doesn't need to be the model id
                for _, leftUnitID in pairs(results) do
                    self:OnEvent("UNIT_LEAVE_AREA", {
                        unit = leftUnitID,
                        area = areaModel.id
                    })
                end
            end
            areaModel:Populate(newUnitIDs)
        end
        self.lastFrameUnitIDs = newUnitIDs
    end

    local newCalls = {}
    for _, call in pairs(self.repeatCalls) do
        local exprType = call.exprType
        local resolvedInputs = call.resolvedInputs
        local result = exprType.execute(resolvedInputs)
        if result then
            table.insert(newCalls, call)
        end
    end
    self.repeatCalls = newCalls
end

function RuntimeModel:OnEvent(eventName, params)
    if not self.hasStarted then
        return
    end

    params = params or {}
    Spring.Echo("Event: " .. eventName, table.show(params))

    if self.eventTriggers[eventName] then
        for _, trigger in pairs(self.eventTriggers[eventName]) do
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:ConditionStep(trigger, params)
    if not trigger.enabled then
        return
    end
    local cndSatisfied = self:ComputeTriggerConditions(trigger, params)
    Spring.Echo("[Trigger:" .. tostring(trigger.id) .. "] Condition check: " ..
        tostring(cndSatisfied))
    if cndSatisfied then
        self:ActionStep(trigger, params)
    end
end

function RuntimeModel:ActionStep(trigger, params)
    for _, action in pairs(trigger.actions) do
        local actionType = SB.metaModel.actionTypes[action.typeName]
        Spring.Echo("[Trigger:" .. tostring(trigger.id) .. "] Action:" .. tostring(action.typeName))
        self.fieldResolver:CallExpression(action, actionType, params, true)
    end
end

function RuntimeModel:ExecuteTriggerActions(triggerID)
    if not self.hasStarted then
        return
    end

    if self.error_triggers[triggerID] then
        Log.Warning("Cannot execute trigger with errors: " .. tostring(triggerID))
        return
    end

    local trigger = SB.model.triggerManager:getTrigger(triggerID)
    self:ActionStep(trigger, {})
end

function RuntimeModel:ExecuteTrigger(triggerID)
    if not self.hasStarted then
        return
    end

    if self.error_triggers[triggerID] then
        Log.Warning("Cannot execute trigger with errors: " .. tostring(triggerID))
        return
    end

    local trigger = SB.model.triggerManager:getTrigger(triggerID)
    self:ConditionStep(trigger, {})
end

function RuntimeModel:ComputeTriggerConditions(trigger, params)
    for _, condition in pairs(trigger.conditions) do
        local conditionType = SB.metaModel.functionTypes[condition.typeName]
        table.echo(condition)
        table.echo(params)
        table.echo(conditionType)
        local result = self.fieldResolver:CallExpression(condition, conditionType, params)
        if not result then
            return false
        end
    end
    return true
end

function RuntimeModel:ExecuteUnsynced(typeName, resolvedInputs)
    local cmd = WidgetExecuteUnsyncedActionCommand(typeName, resolvedInputs)
    SB.commandManager:execute(cmd, true)
end
