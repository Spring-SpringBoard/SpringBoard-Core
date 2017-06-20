TriggerPanel = AbstractTypePanel:extends{}

function TriggerPanel:MakePredefinedOpt()
    local stackTriggerPanel = MakeComponentPanel(self.parent)
    local lblAttrType = Label:New {
        caption = "Trigger:",
        right = 100 + 10,
        x = 1,
        parent = stackTriggerPanel,
    }
    local triggerNames = {}
    local triggerIDs = {}
    for id, trigger in pairs(SB.model.triggerManager:getAllTriggers()) do
        table.insert(triggerNames, trigger.name)
        table.insert(triggerIDs, trigger.id)
    end
    self.cmbTrigger = ComboBox:New {
        right = 1,
        width = 100,
        height = SB.conf.B_HEIGHT,
        parent = stackTriggerPanel,
        items = triggerNames,
        triggerIDs = triggerIDs,
    }
end

function TriggerPanel:UpdateModel(field)
    field.value = self.cmbTrigger.triggerIDs[self.cmbTrigger.selected]
    field.type = "pred"
    return true
end

function TriggerPanel:UpdatePanel(field)
    for i = 1, #self.cmbTrigger.triggerIDs do
        local triggerID = self.cmbTrigger.triggerIDs[i]
        if triggerID == field.value then
            self.cmbTrigger:Select(i)
            return true
        end
    end
    return false
end
