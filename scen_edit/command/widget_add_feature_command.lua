WidgetAddFeatureCommand = AbstractCommand:extends{}

function WidgetAddFeatureCommand:init(springId, modelId)
    self.className = "WidgetAddFeatureCommand"
    self.springId = springId
    self.modelId = modelId
end

function WidgetAddFeatureCommand:execute()
    SB.model.featureManager:addFeature(self.springId, self.modelId)
end
