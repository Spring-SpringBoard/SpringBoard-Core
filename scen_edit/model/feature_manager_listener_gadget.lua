FeatureManagerListenerGadget = FeatureManagerListener:extends{}

function FeatureManagerListenerGadget:init()
end

function FeatureManagerListenerGadget:onFeatureAdded(featureId, modelId)
    local cmd = WidgetAddFeatureCommand(featureId, modelId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end

function FeatureManagerListenerGadget:onFeatureRemoved(featureId, modelId)
    local cmd = WidgetRemoveFeatureCommand(modelId)
    SCEN_EDIT.commandManager:execute(cmd, true)
end
