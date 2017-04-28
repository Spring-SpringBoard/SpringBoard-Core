TriggerPanel = AbstractTypePanel:extends{}

function TriggerPanel:init(...)
    self:super('init', 'trigger', ...)
end

function TriggerPanel:MakePredefinedOpt()
    local stackTriggerPanel = MakeComponentPanel(self.parent)
    local lblAttrType = Label:New {
        caption = "Trigger:",
        right = 100 + 10,
        x = 1,
        parent = stackTriggerPanel,
    }
    local triggerNames = {}
    local triggerIds = {}
    for id, trigger in pairs(SCEN_EDIT.model.triggerManager:getAllTriggers()) do
        table.insert(triggerNames, trigger.name)
        table.insert(triggerIds, trigger.id)
    end
    self.cmbTrigger = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackTriggerPanel,
        items = triggerNames,
        triggerIds = triggerIds,
    }
end

function TriggerPanel:UpdateModel(field)
    field.id = self.cmbTrigger.triggerIds[self.cmbTrigger.selected]
    field.type = "pred"
    return true
end

function TriggerPanel:UpdatePanel(field)
    for i = 1, #self.cmbTrigger.triggerIds do
        local triggerId = self.cmbTrigger.triggerIds[i]
        if triggerId == field.id then
            self.cmbTrigger:Select(i)
            return true
        end
    end
    return false
end
