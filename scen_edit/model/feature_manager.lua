FeatureManager = Observable:extends{}

function FeatureManager:init(widget)
    self:super('init')
    self.s2mFeatureIDMapping = {}
    self.m2sFeatureIDMapping = {}
    self.featureIDCounter = 0
    self.widget = widget
end

function FeatureManager:populate()
    if not self.widget then
        local allFeatures = Spring.GetAllFeatures()
        for i = 1, #allFeatures do
            local featureID = allFeatures[i]
            self:addFeature(featureID)
        end
    end
end

function FeatureManager:addFeature(featureID, modelID)
    if self.s2mFeatureIDMapping[featureID] then
        return
    end
    if modelID ~= nil then
        if self.featureIDCounter < modelID then
            self.featureIDCounter = modelID
        end
    else
        self.featureIDCounter = self.featureIDCounter + 1
        modelID = self.featureIDCounter
    end
    if not self.s2mFeatureIDMapping[featureID] then
        self.s2mFeatureIDMapping[featureID] = modelID
    end
    if not self.m2sFeatureIDMapping[modelID] then
        self.m2sFeatureIDMapping[modelID] = featureID
    end
    self:callListeners("onFeatureAdded", featureID, modelID)
    return modelID
end

function FeatureManager:removeFeature(featureID)
    if featureID == nil then
        return
    end
    local modelID = self.s2mFeatureIDMapping[featureID]
    if self.s2mFeatureIDMapping[featureID] then
        self.m2sFeatureIDMapping[modelID] = nil
    end
    self.s2mFeatureIDMapping[featureID] = nil

    self:callListeners("onFeatureRemoved", featureID, modelID)
end

function FeatureManager:removeFeatureByModelID(modelID)
    local springID = self.m2sFeatureIDMapping[modelID]
    self:removeFeature(springID)
end

function FeatureManager:getSpringFeatureID(modelFeatureID)
    return self.m2sFeatureIDMapping[modelFeatureID]
end

function FeatureManager:getModelFeatureID(springFeatureID)
    return self.s2mFeatureIDMapping[springFeatureID]
end

function FeatureManager:setFeatureModelID(featureID, modelID)
    if self.s2mFeatureIDMapping[featureID] then
        self:removeFeature(featureID)
    end
    if self.m2sFeatureIDMapping[modelID] then
        self:removeFeatureByModelID(modelID)
    end
    self:addFeature(featureID, modelID)
end

function FeatureManager:serialize()
    return featureBridge.s11n:Get(Spring.GetAllFeatures())
end

function FeatureManager:load(features)
    self.featureIDCounter = 0
    featureBridge.s11n:Add(features)
end

function FeatureManager:clear()
    for _, featureID in pairs(Spring.GetAllFeatures()) do
        Spring.DestroyFeature(featureID, false, true)
--        self:removeFeature(featureID)
    end

    for featureID, _ in pairs(self.s2mFeatureIDMapping) do
        self:removeFeature(featureID)
    end
    self.s2mFeatureIDMapping = {}
    self.m2sFeatureIDMapping = {}
    self.featureIDCounter = 0

end
------------------------------------------------
-- Listener definition
------------------------------------------------
FeatureManagerListener = LCS.class.abstract{}

function FeatureManagerListener:onFeatureAdded(featureID, modelID)
end

function FeatureManagerListener:onFeatureRemoved(featureID, modelID)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
