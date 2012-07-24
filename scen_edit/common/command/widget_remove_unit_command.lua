WidgetRemoveUnitCommand = AbstractCommand:extends{}

function WidgetRemoveUnitCommand:init(modelId)
    self.className = "WidgetRemoveUnitCommand"
    self.modelId = modelId
end

function WidgetRemoveUnitCommand:execute()
    SCEN_EDIT.model.unitManager:removeUnitByModelId(self.modelId)
end
