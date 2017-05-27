SB.Include(Path.Join(SB_MODEL_DIR, "feature_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddFeatureCommand = Command:extends{}

function WidgetAddFeatureCommand:init(springId, modelId)
    self.className = "WidgetAddFeatureCommand"
    self.springId = springId
    self.modelId = modelId
end

function WidgetAddFeatureCommand:execute()
    SB.model.featureManager:addFeature(self.springId, self.modelId)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveFeatureCommand = Command:extends{}

function WidgetRemoveFeatureCommand:init(modelId)
    self.className = "WidgetRemoveFeatureCommand"
    self.modelId = modelId
end

function WidgetRemoveFeatureCommand:execute()
    SB.model.featureManager:removeFeatureByModelId(self.modelId)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

FeatureManagerListenerGadget = FeatureManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.featureManager:addListener(FeatureManagerListenerGadget())
end)

function FeatureManagerListenerGadget:onFeatureAdded(featureId, modelId)
    local cmd = WidgetAddFeatureCommand(featureId, modelId)
    SB.commandManager:execute(cmd, true)
end

function FeatureManagerListenerGadget:onFeatureRemoved(featureId, modelId)
    local cmd = WidgetRemoveFeatureCommand(modelId)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
