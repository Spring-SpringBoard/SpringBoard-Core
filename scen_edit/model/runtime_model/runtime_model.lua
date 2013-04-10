SCEN_EDIT_MODEL_RUNTIME_DIR = SCEN_EDIT_MODEL_DIR .. "runtime_model/"

RuntimeModel = LCS.class{}

function RuntimeModel:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_MODEL_RUNTIME_DIR)
    self.areaModels = {}    
    self.lastFrameUnitIds = {}
    self.fieldResolver = FieldResolver()
    self.repeatCalls = {}
end

function RuntimeModel:LoadMission()
    self.lastFrameUnitIds = Spring.GetAllUnits()
    self.areaModels = {}
    self.repeatCalls = {}
    
    local areas = SCEN_EDIT.model.areaManager:getAllAreas()
    for id, area in pairs(areas) do
        local areaModel = AreaModel(id, area)
        areaModel:Populate(self.lastFrameUnitIds)
        table.insert(self.areaModels, areaModel)        
    end
    
    self.eventTriggers = {}
    local triggers = SCEN_EDIT.model.triggerManager:getAllTriggers()
    for id, trigger in pairs(triggers) do
        for j = 1, #trigger.events do
            local event = trigger.events[j]
            if not self.eventTriggers[event.eventTypeName] then
                self.eventTriggers[event.eventTypeName] = {}
            end
            table.insert(self.eventTriggers[event.eventTypeName], trigger)
        end
    end    
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
    self.hasStarted = false
end


function RuntimeModel:UnitCreated(unitId, unitDefId, teamId, builderId)
    if not self.hasStarted then
        return
    end
    if self.eventTriggers["UNIT_CREATE"] then
        local createdUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        for k = 1, #self.eventTriggers["UNIT_CREATE"] do
            local params = { triggerUnitId = createdUnitId }
            local trigger = self.eventTriggers["UNIT_CREATE"][k]                
            self:ConditionStep(trigger, params)
        end
    end
end

function RuntimeModel:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
    if not self.hasStarted then
        return
    end
    if self.eventTriggers["UNIT_DESTROY"] then
        local destroyedUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(unitId)
        for k = 1, #self.eventTriggers["UNIT_DESTROY"] do
            local params = { triggerUnitId = destroyedUnitId }
            local trigger = self.eventTriggers["UNIT_DESTROY"][k]                
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
    self.fieldResolver.params = params
    local cndSatisfied = self:ComputeTriggerConditions(trigger, params)
    if cndSatisfied then
        self:ActionStep(trigger, params)
    end
end

function RuntimeModel:ActionStep(trigger, params)
    for i = 1, #trigger.actions do
        local action = trigger.actions[i]
        local actionType = SCEN_EDIT.metaModel.actionTypes[action.actionTypeName]
        self.fieldResolver:CallExpression(action, actionType)
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
    for i = 1, #trigger.conditions do
        local condition = trigger.conditions[i]
        local conditionType = SCEN_EDIT.metaModel.functionTypes[condition.conditionTypeName]
        local result = self.fieldResolver:CallExpression(condition, conditionType)
        if not result then
            return false
        end
    end
    return true
end
