WidgetAddUnitCommand = AbstractCommand:extends{}

function WidgetAddUnitCommand:init(springId, modelId)
    self.className = "WidgetAddUnitCommand"
    self.springId = springId
    self.modelId = modelId
end

function WidgetAddUnitCommand:execute()
    SCEN_EDIT.model.unitManager:addUnit(self.springId, self.modelId)
end
