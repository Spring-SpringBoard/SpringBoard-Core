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
    local retVal = {}
    for _, feature in pairs(self.features) do
        table.insert(retVal, 
            {
                feature = feature,
            }
        )
    end
    return retVal
end

function FeatureManager:load(data)
    self:clear()
    self.featureIdCount = 0
    for _, kv in pairs(data) do
        id = kv.id
        feature = kv.feature
        self:addFeature(feature)
    end
end

function FeatureManager:clear()
    for featureId, _ in pairs(self.s2mFeatureIdMapping) do
        self:removeFeature(featureId)
    end
    self.s2mFeatureIdMapping = {}
    self.m2sFeatureIdMapping = {}
    self.featureIdCounter = 0
end
