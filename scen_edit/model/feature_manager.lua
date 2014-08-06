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
    local featureId = self.m2sFeatureIdMapping[modelFeatureId]
    if featureId ~= nil then
        return featureId
    else
        return modelFeatureId
    end
end

function FeatureManager:getModelFeatureId(springFeatureId)
    local featureId = self.s2mFeatureIdMapping[springFeatureId]
    if featureId ~= nil then
        return featureId
    else
        return springFeatureId
    end
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

function FeatureManager:serializeFeature(featureId)
    local feature = {}

    local featureDefId = Spring.GetFeatureDefID(featureId)
    feature.featureDefName = FeatureDefs[featureDefId].name
    feature.x, _, feature.y = Spring.GetFeaturePosition(featureId)
    feature.player = Spring.GetFeatureTeam(featureId)
    feature.id = self.featureManager:getModelFeatureId(featureId)
    local dirX, dirY, dirZ = Spring.GetFeatureDirection(featureId)
    feature.angle = math.atan2(dirX, dirZ) * 180 / math.pi

    return feature
end


function FeatureManager:serialize()
    local features = {}
    for _, featureId in pairs(Spring.GetAllFeatures()) do
        local feature = self:serializeFeature(featureId)
        table.insert(features, feature)
    end
    return features
end

function FeatureManager:loadFeature(feature)
    local featureId = Spring.CreateFeature(feature.featureDefName, feature.x, 0, feature.y, feature.player)
    local x = math.sin(math.rad(feature.angle))
    local z = math.cos(math.rad(feature.angle))
    Spring.SetFeatureDirection(featureId, x, 0, z)
    self:setFeatureModelId(featureId, feature.id)
end

function FeatureManager:load(features)
    self:clear()

    for _, feature in pairs(features) do
        self:loadFeature(feature)
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
