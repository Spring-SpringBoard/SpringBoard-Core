TriggerManager = Observable:extends{}

function TriggerManager:init()
    self:super('init')
    self.triggerIDCount = 0
    self.triggers = {}
end

---------------
-- CRUD methods
---------------
function TriggerManager:addTrigger(trigger)
    if trigger.id == nil then
        trigger.id = self.triggerIDCount + 1
    end
    self.triggerIDCount = math.max(trigger.id, self.triggerIDCount)
    self.triggers[trigger.id] = trigger
    self:callListeners("onTriggerAdded", trigger.id)
    return trigger.id
end

function TriggerManager:removeTrigger(triggerID)
    if triggerID == nil then
        return
    end
    if self.triggers[triggerID] then
        self.triggers[triggerID] = nil
        self:callListeners("onTriggerRemoved", triggerID)
        return true
    else
        return false
    end
end

function TriggerManager:setTrigger(triggerID, value)
    self.triggers[triggerID] = value
    self:callListeners("onTriggerUpdated", triggerID)
end

function TriggerManager:disableTrigger(triggerID)
    if self.triggers[triggerID].enabled then
        self.triggers[triggerID].enabled = false
        self:callListeners("onTriggerUpdated", triggerID)
    end
end

function TriggerManager:enableTrigger(triggerID)
    if not self.triggers[triggerID].enabled then
        self.triggers[triggerID].enabled = true
        self:callListeners("onTriggerUpdated", triggerID)
    end
end

function TriggerManager:getTrigger(triggerID)
    return self.triggers[triggerID]
end

function TriggerManager:getAllTriggers()
    return self.triggers
end

function TriggerManager:serialize()
    return SB.deepcopy(self.triggers)
--[[    local retVal = {}
    for _, trigger in pairs(self.triggers) do
        retVal[trigger.id] = trigger
    end
    return retVal--]]
end

function TriggerManager:load(data)
    for id, trigger in pairs(data) do
        self:addTrigger(trigger)
    end
end

function TriggerManager:clear()
    for triggerID, _ in pairs(self.triggers) do
        self:removeTrigger(triggerID)
    end
    self.triggerIDCount = 0
end

---------------
-- END CRUD methods
---------------

function TriggerManager:GetTriggerScopeParams(trigger)
    local triggerScopeParams = {}
    if #trigger.events == 0 then
        return triggerScopeParams
    end

    for _, event in pairs(trigger.events) do
        local typeName = event.typeName
        local eventType = SB.metaModel.eventTypes[typeName]
        for _, param in pairs(eventType.param) do
            table.insert(triggerScopeParams, {
                name = param.name,
                type = param.type,
                humanName = "Trigger: " .. param.name,
            })
        end
    end
    return triggerScopeParams
end

---------------------------------
-- Trigger verification utilities
---------------------------------
function TriggerManager:ValidateEvent(trigger, event)
    if not SB.metaModel.eventTypes[event.typeName] then
        return false, "Missing reference: " .. event.typeName
    end
    return true
end

function TriggerManager:ValidateEvents(trigger)
    for _, event in pairs(trigger.events) do
        local success, msg = self:ValidateEvent(trigger, event)
        if not success then
            return false, msg
        end
    end
    return true
end

function TriggerManager:ValidateCondition(trigger, condition)
    if not SB.metaModel.functionTypes[condition.typeName] then
        return false, "Missing reference: " .. condition.typeName
    end
    return true
end

function TriggerManager:ValidateConditions(trigger)
    for _, condition in pairs(trigger.conditions) do
        local success, msg = self:ValidateCondition(trigger, condition)
        if not success then
            return false, msg
        end
    end
    return true
end

function TriggerManager:ValidateAction(trigger, action)
    if not SB.metaModel.actionTypes[action.typeName] then
        return false, "Missing reference: " .. action.typeName
    end
    return true
end

function TriggerManager:ValidateActions(trigger)
    for _, action in pairs(trigger.actions) do
        local success, msg = self:ValidateAction(trigger, action)
        if not success then
            return false, msg
        end
    end
    return true
end

function TriggerManager:ValidateTrigger(trigger)
    local checks = {{self:ValidateEvents(trigger)},
                    {self:ValidateConditions(trigger)},
                    {self:ValidateActions(trigger)}}
    for _, check in pairs(checks) do
        local success, msg = check[1], check[2]
        if not success then
            return success, msg
        end
    end
    return true
end

function TriggerManager:ValidateTriggerRecursive(trigger)
end

function TriggerManager:GetSafeEventHumanName(trigger, event)
    if self:ValidateEvent(trigger, event) then
        return SB.metaModel.eventTypes[event.typeName].humanName
    else
        return "Invalid event: " .. tostring(event.typeName)
    end
end
------------------------------------------------
-- Listener definition
------------------------------------------------
TriggerManagerListener = LCS.class.abstract{}

function TriggerManagerListener:onTriggerAdded(triggerID)
end

function TriggerManagerListener:onTriggerRemoved(triggerID)
end

function TriggerManagerListener:onTriggerUpdated(triggerID)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
