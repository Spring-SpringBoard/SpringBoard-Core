local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

TriggerPanel = {
}

function TriggerPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function TriggerPanel:Initialize()
    local stackTriggerPanel = MakeComponentPanel(self.parent)
    local lblAttrType = Chili.Label:New {
        caption = "Trigger:",
        right = 100 + 10,
        x = 1,
        parent = stackTriggerPanel,
    }
    local triggerNames = {}
    local triggerIds = {}
    for i = 1, #self.model.triggers do
        table.insert(triggerNames, self.model.triggers[i].name)
        table.insert(triggerIds, self.model.triggers[i].id)
    end
    self.cmbTrigger = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackTriggerPanel,
        items = triggerNames,
        triggerIds = triggerIds,
    }
end

function TriggerPanel:UpdateModel(field)
    field.id = self.cmbTrigger.triggerIds[self.cmbTrigger.selected]
end

function TriggerPanel:UpdatePanel(field)
    for i = 1, #self.cmbTrigger.triggerIds do
        local triggerId = self.cmbTrigger.triggerIds[i]
        if triggerId == field.id then
            self.cmbTrigger:Select(i)
            break
        end
    end
end
