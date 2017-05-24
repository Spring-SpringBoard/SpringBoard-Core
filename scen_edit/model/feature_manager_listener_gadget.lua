FeatureManagerListenerGadget = FeatureManagerListener:extends{}

function FeatureManagerListenerGadget:init()
end

function FeatureManagerListenerGadget:onFeatureAdded(featureId, modelId)
    local cmd = WidgetAddFeatureCommand(featureId, modelId)
    SB.commandManager:execute(cmd, true)
end

function FeatureManagerListenerGadget:onFeatureRemoved(featureId, modelId)
    local cmd = WidgetRemoveFeatureCommand(modelId)
    SB.commandManager:execute(cmd, true)
end
