FeatureManager = Observable:extends{}

function FeatureManager:init(widget)
    self:super('init')
    self.s2mFeatureIdMapping = {}
    self.m2sFeatureIdMapping = {}
    self.featureIdCounter = 0
    self.widget = widget
end

function FeatureManager:populate()
    if not self.widget then
        local allFeatures = Spring.GetAllFeatures()
        for i = 1, #allFeatures do
            local featureId = allFeatures[i]
            self:addFeature(featureId)
        end
    end
end

function FeatureManager:addFeature(featureId, modelId)
    if self.s2mFeatureIdMapping[featureId] then
        return
    end
    if modelId ~= nil then
        if self.featureIdCounter < modelId then
            self.featureIdCounter = modelId
        end
    else
        self.featureIdCounter = self.featureIdCounter + 1
        modelId = self.featureIdCounter
    end
    if not self.s2mFeatureIdMapping[featureId] then
        self.s2mFeatureIdMapping[featureId] = modelId
    end
    if not self.m2sFeatureIdMapping[modelId] then
        self.m2sFeatureIdMapping[modelId] = featureId
    end
    self:callListeners("onFeatureAdded", featureId, modelId)
    return modelId
end

function FeatureManager:removeFeature(featureId)
    if featureId == nil then
        return
    end
    local modelId = self.s2mFeatureIdMapping[featureId]
    if self.s2mFeatureIdMapping[featureId] then
        self.m2sFeatureIdMapping[modelId] = nil
    end
    self.s2mFeatureIdMapping[featureId] = nil

    self:callListeners("onFeatureRemoved", featureId, modelId)
end

function FeatureManager:removeFeatureByModelId(modelId)
    local springId = self.m2sFeatureIdMapping[modelId]
    self:removeFeature(springId)
end

function FeatureManager:getSpringFeatureId(modelFeatureId)
    return self.m2sFeatureIdMapping[modelFeatureId]
end

function FeatureManager:getModelFeatureId(springFeatureId)
    return self.s2mFeatureIdMapping[springFeatureId]
end

function FeatureManager:setFeatureModelId(featureId, modelId)
    if self.s2mFeatureIdMapping[featureId] then
        self:removeFeature(featureId)
    end
    if self.m2sFeatureIdMapping[modelId] then
        self:removeFeatureByModelId(modelId)
    end
    self:addFeature(featureId, modelId)
end

function FeatureManager:serialize()
    return featureBridge.s11n:Get(Spring.GetAllFeatures())
end

function FeatureManager:load(features)
    self.featureIdCounter = 0
    if #units > 0 then
        featureBridge.s11n:Add(features)
    end
end

function FeatureManager:clear()
    for _, featureId in pairs(Spring.GetAllFeatures()) do
        Spring.DestroyFeature(featureId, false, true)
--        self:removeFeature(featureId)
    end

    for featureId, _ in pairs(self.s2mFeatureIdMapping) do
        self:removeFeature(featureId)
    end
    self.s2mFeatureIdMapping = {}
    self.m2sFeatureIdMapping = {}
    self.featureIdCounter = 0

end
------------------------------------------------
-- Listener definition
------------------------------------------------
FeatureManagerListener = LCS.class.abstract{}

function FeatureManagerListener:onFeatureAdded(featureId, modelId)
end

function FeatureManagerListener:onFeatureRemoved(featureId, modelId)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
