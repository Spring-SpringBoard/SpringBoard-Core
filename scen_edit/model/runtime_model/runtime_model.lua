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
    self:OnEvent("GAME_START")
end

function RuntimeModel:GameStop()
    self:OnEvent("GAME_END")
    self.hasStarted = false
    self.startListening = false
end

function RuntimeModel:TeamDied(teamId)
    self:OnEvent("TEAM_DIE", { team = teamId })
end

function RuntimeModel:UnitCreated(unitId, unitDefId, teamId, builderId)
    if self:CanTrackUnit(unitDefId) then
        self.trackedUnitIDs[unitId] = unitId
    end
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    self:OnEvent("UNIT_CREATE", { unit = modelUnitId })
end

function RuntimeModel:UnitDamaged(unitId)
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    self:OnEvent("UNIT_DAMAGE", { unit = modelUnitId })
end

function RuntimeModel:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
    self.trackedUnitIDs[unitId] = nil
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    self:OnEvent("UNIT_DESTROY", { unit = modelUnitId })
end

function RuntimeModel:UnitFinished(unitId)
    local modelUnitId = SB.model.unitManager:getModelUnitId(unitId)
    self:OnEvent("UNIT_FINISH", { unit = modelUnitId })
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
        for _, areaModel in pairs(self.areaModels) do
            local results = areaModel:Populate(unitIds)
            local area = areaModel.area
            if self.eventTriggers["UNIT_ENTER_AREA"] then
                for _, unitID in pairs(results.entered) do
                    local modelUnitId = SB.model.unitManager:getModelUnitId(unitID)
                    self:OnEvent("UNIT_ENTER_AREA", {
                        unit = modelUnitId,
                        area = areaModel.id
                    })
                end
            end
            if self.eventTriggers["UNIT_LEAVE_AREA"] then
                -- TODO: check if leftUnitId really doesn't need to be the model id
                for _, leftUnitId in pairs(results) do
                    self:OnEvent("UNIT_LEAVE_AREA", {
                        unit = leftUnitId,
                        area = areaModel.id
                    })
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

function RuntimeModel:OnEvent(eventName, params)
    if not self.hasStarted then
        return
    end

    params = params or {}

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
