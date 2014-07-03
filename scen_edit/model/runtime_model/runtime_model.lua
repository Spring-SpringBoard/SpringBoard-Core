SCEN_EDIT_MODEL_RUNTIME_DIR = SCEN_EDIT_MODEL_DIR .. "runtime_model/"

RuntimeModel = LCS.class{}

function RuntimeModel:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_MODEL_RUNTIME_DIR)
    self.areaModels = {}    
    self.lastFrameUnitIds = {}
    self.fieldResolver = FieldResolver()
    self.repeatCalls = {}
    SCEN_EDIT.model.areaManager:addListener(self)
    SCEN_EDIT.model.triggerManager:addListener(self)
end

function RuntimeModel:LoadMission()
    self.lastFrameUnitIds = Spring.GetAllUnits()
    self.areaModels = {}
    self.repeatCalls = {}
   
    self.startListening = true

    local areas = SCEN_EDIT.model.areaManager:getAllAreas()
    for id, _ in pairs(areas) do
        self:onAreaAdded(id)
    end
    
    self.eventTriggers = {}
    local triggers = SCEN_EDIT.model.triggerManager:getAllTriggers()
    for _, trigger in pairs(triggers) do
        self:onTriggerAdded(trigger.id)
    end    
end

function RuntimeModel:onTriggerAdded(triggerId)
    if not self.startListening then
        return
    end
    local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
    for _, event in pairs(trigger.events) do
        if not self.eventTriggers[event.eventTypeName] then
            self.eventTriggers[event.eventTypeName] = {}
        end
        table.insert(self.eventTriggers[event.eventTypeName], trigger)
    end
end

function RuntimeModel:onTriggerRemoved(triggerId)
    if not self.startListening then
        return
    end
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
    if not self.hasStarted then
        return
    end
    local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
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
    local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_DAMAGE"] then
        for k = 1, #self.eventTriggers["UNIT_DAMAGE"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_DAMAGE"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
    if not self.hasStarted then
        return
    end
    local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
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
    local modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
    if self.eventTriggers["UNIT_FINISH"] then
        for k = 1, #self.eventTriggers["UNIT_FINISH"] do
            local params = { triggerUnitId = modelUnitId }
            local trigger = self.eventTriggers["UNIT_FINISH"][k]
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:GameFrame(frameNum)
    if not self.hasStarted then
        return
    end
    local newUnitIds = Spring.GetAllUnits()    
    local unitIds = {}
    --update area-unit models
    for i = 1, #newUnitIds do
        local newId = newUnitIds[i]
        local found = false
        for j = 1, #self.lastFrameUnitIds do
            local oldId = self.lastFrameUnitIds[j]
            if newId == oldId then
                found = true
                break
            end
        end
        if found then
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
                local enteredUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(results.entered[j])
                for k = 1, #self.eventTriggers["UNIT_ENTER_AREA"] do
                    local trigger = self.eventTriggers["UNIT_ENTER_AREA"][k]
                    if trigger.enabled then
                        local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id}
                        self:ConditionStep(trigger, params)
                    end
                end
            end
        end
        if self.eventTriggers["UNIT_LEAVE_AREA"] then
            for j = 1, #results.left do
                local leftUnitId = results.left[j]
                for k = 1, #self.eventTriggers["UNIT_LEAVE_AREA"] do
                    local trigger = self.eventTriggers["UNIT_LEAVE_AREA"][k]
                    if trigger.enabled then
                        local params = { triggerUnitId = enteredUnitId, triggerAreaId = areaModel.id }
                        self:ConditionStep(trigger, params)
                    end
                end
            end
        end
        areaModel:Populate(newUnitIds)
    end    
    self.lastFrameUnitIds = newUnitIds

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
        local actionType = SCEN_EDIT.metaModel.actionTypes[action.actionTypeName]
        self.fieldResolver:CallExpression(action, actionType, params)
    end
end

function RuntimeModel:ExecuteTriggerActions(triggerId)
    if self.hasStarted then
        local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
        self:ActionStep(trigger, {})
    end
end

function RuntimeModel:ExecuteTrigger(triggerId)
    if self.hasStarted then
        local trigger = SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
        self:ConditionStep(trigger, {})
    end
end

function RuntimeModel:ComputeTriggerConditions(trigger, params)
    for _, condition in pairs(trigger.conditions) do
        local conditionType = SCEN_EDIT.metaModel.functionTypes[condition.conditionTypeName]
        local result = self.fieldResolver:CallExpression(condition, conditionType, params)
        if not result then
            return false
        end
    end
    return true
end
