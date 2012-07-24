WidgetRemoveFeatureCommand = AbstractCommand:extends{}

function WidgetRemoveFeatureCommand:init(modelId)
    self.className = "WidgetRemoveFeatureCommand"
    self.modelId = modelId
end

function WidgetRemoveFeatureCommand:execute()
    SCEN_EDIT.model.featureManager:removeFeatureByModelId(self.modelId)
end
