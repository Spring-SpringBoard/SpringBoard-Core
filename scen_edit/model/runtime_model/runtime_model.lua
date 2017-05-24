SB_MODEL_RUNTIME_DIR = SB_MODEL_DIR .. "runtime_model/"

RuntimeModel = LCS.class{}

function RuntimeModel:init()
    SB.IncludeDir(SB_MODEL_RUNTIME_DIR)
    self.areaModels = {}
    self.lastFrameUnitIds = {}
    self.fieldResolver = FieldResolver()
    self.repeatCalls = {}
    self.trackedUnitIDs = {}

    -- triggers that contain missing references that would error when running
    -- they are disabled and won't be added
    self.error_triggers = {}

    SB.model.areaManager:addListener(self)
    SB.model.triggerManager:addListener(self)
end

function RuntimeModel:CanTrackUnit(unitDefId)
    local customParams = UnitDefs[unitDefId].customParams
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
    self.lastFrameUnitIds = self:GetAllUnits()
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

function RuntimeModel:onTriggerAdded(triggerId)
    if not self.startListening then
        return
    end
    local trigger = SB.model.triggerManager:getTrigger(triggerId)
    local success, msg = SB.model.triggerManager:ValidateTrigger(trigger)
    if not success then
        Log.Warning("Trigger error: " .. tostring(triggerId) .. ". " .. tostring(msg))
        self.error_triggers[triggerId] = true
        return
    end
    for _, event in pairs(trigger.events) do
        if not self.eventTriggers[event.typeName] then
            self.eventTriggers[event.typeName] = {}
        end
        table.insert(self.eventTriggers[event.typeName], trigger)
    end
end

function RuntimeModel:onTriggerRemoved(triggerId)
    if not self.startListening then
        return
    end
    self.error_triggers[triggerId] = nil
    for _, eventList in pairs(self.eventTriggers) do
        repeat
            local found = false
            for i, iterTrigger in pairs(eventList) do
                if iterTrigger.id == triggerId then
                    table.remove(eventList, i)
                    found = true
                    break
                end
            end
        until not found
    end
end

function RuntimeModel:onTriggerUpdated(triggerId)
    if not self.startListening then
        return
    end
    self:onTriggerRemoved(triggerId)
    self:onTriggerAdded(triggerId)
end

function RuntimeModel:onAreaAdded(areaId)
    if not self.startListening then
        return
    end
    local areaModel = AreaModel(areaId)
    areaModel:Populate(self.lastFrameUnitIds)
    table.insert(self.areaModels, areaModel)
end

function RuntimeModel:onAreaRemoved(areaId)
    if not self.startListening then
        return
    end
    for i, areaModel in pairs(self.areaModels) do
        if areaModel.id == areaId then
            table.remove(self.areaModels, i)
            break
        end
    end
end

function RuntimeModel:onAreaChange(areaId)
    if not self.startListening then
        return
    end
    self:onAreaRemoved(areaId)
    self:onAreaAdded(areaId)
end

function RuntimeModel:GameStart()
    --TODO: assign initial variable values
    --END

    self.hasStarted = true
    if self.eventTriggers["GAME_START"] then
        for k = 1, #self.eventTriggers["GAME_START"] do
            local params = { }
            local trigger = self.eventTriggers["GAME_START"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:GameStop()
    if self.eventTriggers["GAME_END"] then
        for k = 1, #self.eventTriggers["GAME_END"] do
            local params = { }
            local trigger = self.eventTriggers["GAME_END"][k]
            self:ConditionStep(trigger, params)
        end
    end
    self.hasStarted = false
    self.startListening = false
end

function RuntimeModel:TeamDied(teamId)
    if not self.hasStarted then
        return
    end
    if self.eventTriggers["TEAM_DIE"] then
        for k = 1, #self.eventTriggers["TEAM_DIE"] do
            local params = { triggerTeamId = teamId }
            local trigger = self.eventTriggers["TEAM_DIE"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitCreated(unitId, unitDefId, teamId, builderId)
    if self:CanTrackUnit(unitDefId) then
        self.trackedUnitIDs[unitId] = unitId
    end
    if not self.hasStarted then
        return
    end
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_CREATE"] then
        for k = 1, #self.eventTriggers["UNIT_CREATE"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_CREATE"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitDamaged(unitId)
    if not self.hasStarted then
        return
    end
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_DAMAGE"] then
        for k = 1, #self.eventTriggers["UNIT_DAMAGE"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_DAMAGE"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
    self.trackedUnitIDs[unitId] = nil
    if not self.hasStarted then
        return
    end
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_DESTROY"] then
        for k = 1, #self.eventTriggers["UNIT_DESTROY"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_DESTROY"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitFinished(unitId)
    if not self.hasStarted then
        return
    end
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_FINISH"] then
        for k = 1, #self.eventTriggers["UNIT_FINISH"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_FINISH"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

local checkRate = 10
function RuntimeModel:GameFrame(frameNum)
    if not self.hasStarted then
        return
    end

    if Spring.GetGameFrame() % 10 == 0 then
        local newUnitIds = self:GetAllUnits()
        local unitIds = {}
        --update area-unit models
        for _, newId in pairs(newUnitIds) do
            if self.lastFrameUnitIds[newId] then
                table.insert(unitIds, newId)
            end
        end
        --check for any enter/leave area events
        for i = 1, #self.areaModels do
            local areaModel = self.areaModels[i]
            local results = areaModel:Populate(unitIds)
            local area = areaModel.area
            if self.eventTriggers["UNIT_ENTER_AREA"] then
                for j = 1, #results.entered do
                    local enteredUnitId = SB.model.unitManager:getModelUnitId(results.entered[j])
                    for k = 1, #self.eventTriggers["UNIT_ENTER_AREA"] do
                        local trigger = self.eventTriggers["UNIT_ENTER_AREA"][k]
                        local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id}
                        self:ConditionStep(trigger, params)
                    end
                end
            end
            if self.eventTriggers["UNIT_LEAVE_AREA"] then
                for j = 1, #results.left do
                    local leftUnitId = results.left[j]
                    for k = 1, #self.eventTriggers["UNIT_LEAVE_AREA"] do
                        local trigger = self.eventTriggers["UNIT_LEAVE_AREA"][k]
                        local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id }
                        self:ConditionStep(trigger, params)
                    end
                end
            end
            areaModel:Populate(newUnitIds)
        end
        self.lastFrameUnitIds = newUnitIds
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

function RuntimeModel:ConditionStep(trigger, params)
    if not trigger.enabled then
        return
    end
    local cndSatisfied = self:ComputeTriggerConditions(trigger, params)
    if cndSatisfied then
        self:ActionStep(trigger, params)
    end
end

function RuntimeModel:ActionStep(trigger, params)
    for _, action in pairs(trigger.actions) do
        local actionType = SB.metaModel.actionTypes[action.typeName]
        self.fieldResolver:CallExpression(action, actionType, params, true)
    end
end

function RuntimeModel:ExecuteTriggerActions(triggerId)
    if not self.hasStarted then
        return
    end

    if self.error_triggers[triggerId] then
        Log.Warning("Cannot execute trigger with errors: " .. tostring(triggerId))
        return
    end

    local trigger = SB.model.triggerManager:getTrigger(triggerId)
    self:ActionStep(trigger, {})
end

function RuntimeModel:ExecuteTrigger(triggerId)
    if not self.hasStarted then
        return
    end

    if self.error_triggers[triggerId] then
        Log.Warning("Cannot execute trigger with errors: " .. tostring(triggerId))
        return
    end

    local trigger = SB.model.triggerManager:getTrigger(triggerId)
    self:ConditionStep(trigger, {})
end

function RuntimeModel:ComputeTriggerConditions(trigger, params)
    for _, condition in pairs(trigger.conditions) do
        local conditionType = SB.metaModel.functionTypes[condition.typeName]
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
