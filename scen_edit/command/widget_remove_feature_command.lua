WidgetRemoveFeatureCommand = AbstractCommand:extends{}

function WidgetRemoveFeatureCommand:init(modelId)
    self.className = "WidgetRemoveFeatureCommand"
    self.modelId = modelId
end

function WidgetRemoveFeatureCommand:execute()
    SB.model.featureManager:removeFeatureByModelId(self.modelId)
end
