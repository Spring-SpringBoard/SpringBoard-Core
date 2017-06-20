SB.Include(Path.Join(SB_MODEL_DIR, "feature_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddFeatureCommand = Command:extends{}

function WidgetAddFeatureCommand:init(springID, modelID)
    self.className = "WidgetAddFeatureCommand"
    self.springID = springID
    self.modelID = modelID
end

function WidgetAddFeatureCommand:execute()
    SB.model.featureManager:addFeature(self.springID, self.modelID)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveFeatureCommand = Command:extends{}

function WidgetRemoveFeatureCommand:init(modelID)
    self.className = "WidgetRemoveFeatureCommand"
    self.modelID = modelID
end

function WidgetRemoveFeatureCommand:execute()
    SB.model.featureManager:removeFeatureByModelID(self.modelID)
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

function FeatureManagerListenerGadget:onFeatureAdded(featureID, modelID)
    local cmd = WidgetAddFeatureCommand(featureID, modelID)
    SB.commandManager:execute(cmd, true)
end

function FeatureManagerListenerGadget:onFeatureRemoved(featureID, modelID)
    local cmd = WidgetRemoveFeatureCommand(modelID)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
