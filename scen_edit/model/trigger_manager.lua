TriggerManager = Observable:extends{}

function TriggerManager:init()
    self:super('init')
    self.triggerIdCount = 0
    self.triggers = {}
end

---------------
-- CRUD methods
---------------
function TriggerManager:addTrigger(trigger)
    if trigger.id == nil then
        trigger.id = self.triggerIdCount + 1
    end
    self.triggerIdCount = math.max(trigger.id, self.triggerIdCount)
    self.triggers[trigger.id] = trigger
    self:callListeners("onTriggerAdded", trigger.id)
    return trigger.id
end

function TriggerManager:removeTrigger(triggerId)
    if triggerId == nil then
        return
    end
    if self.triggers[triggerId] then
        self.triggers[triggerId] = nil
        self:callListeners("onTriggerRemoved", triggerId)
        return true
    else
        return false
    end
end

function TriggerManager:setTrigger(triggerId, value)
    self.triggers[triggerId] = value
    self:callListeners("onTriggerUpdated", triggerId)
end

function TriggerManager:disableTrigger(triggerId)
    if self.triggers[triggerId].enabled then
        self.triggers[triggerId].enabled = false
        self:callListeners("onTriggerUpdated", triggerId)
    end
end

function TriggerManager:enableTrigger(triggerId)
    if not self.triggers[triggerId].enabled then
        self.triggers[triggerId].enabled = true
        self:callListeners("onTriggerUpdated", triggerId)
    end
end

function TriggerManager:getTrigger(triggerId)
    return self.triggers[triggerId]
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
    for triggerId, _ in pairs(self.triggers) do
        self:removeTrigger(triggerId)
    end
    self.triggerIdCount = 0
end

---------------
-- CRUD methods
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
                humanName = "Trigger: " .. name,
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

function TriggerManagerListener:onTriggerAdded(triggerId)
end

function TriggerManagerListener:onTriggerRemoved(triggerId)
end

function TriggerManagerListener:onTriggerUpdated(triggerId)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
