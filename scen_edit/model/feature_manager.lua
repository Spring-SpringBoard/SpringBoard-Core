FeatureManager = Observable:extends{}

function FeatureManager:init()
    self:super('init')
    self._s2m = {}
    self._m2s = {}
    self.featureIDCounter = 0
end

function FeatureManager:populate()
    if Script.GetName() == "LuaUI" then
        return
    end

    for _, featureID in ipairs(Spring.GetAllFeatures()) do
        self:addFeature(featureID)
    end
end

function FeatureManager:addFeature(featureID, modelID)
    if self._s2m[featureID] then
        Log.Warning(string.format("%s: Trying to register existing feature. Spring ID: %d Model ID: %d",
            Script.GetName(), featureID, self._s2m[featureID]))
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
    if not self._s2m[featureID] then
        self._s2m[featureID] = modelID
    end
    if not self._m2s[modelID] then
        self._m2s[modelID] = featureID
    end
    self:callListeners("onFeatureAdded", featureID, modelID)
    return modelID
end

function FeatureManager:removeFeature(featureID)
    --assert(featureID, "Trying to remove feature with no featureID specified.")
    if featureID == nil then
        return
    end
    local modelID = self._s2m[featureID]
    if modelID then
        self._m2s[modelID] = nil
    end
    self._s2m[featureID] = nil

    self:callListeners("onFeatureRemoved", featureID, modelID)
end

function FeatureManager:removeFeatureByModelID(modelID)
    local springID = self._m2s[modelID]
    self:removeFeature(springID)
end

function FeatureManager:getSpringFeatureID(modelID)
    assert(modelID, "missing modelID argument")
    if not self._m2s[modelID] then
        if debug then
            Log.Warning(debug.traceback())
        end
        Log.Warning(("[%s] No feature springID for modelID: %d"):format(Script.GetName(), modelID))
    end
    return self._m2s[modelID]
end

function FeatureManager:getModelFeatureID(springID)
    assert(springID, "missing springID argument")
    local modelID = self._s2m[springID]
    if not modelID then
        if debug then
            Log.Warning(debug.traceback())
        end
        Log.Warning(("[%s] No feature modelID for springID: %d"):format(Script.GetName(), springID))
    end
    return modelID
end

function FeatureManager:setFeatureModelID(featureID, modelID)
    if self._s2m[featureID] then
        self:removeFeature(featureID)
    end
    if self._m2s[modelID] then
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

    for featureID, _ in pairs(self._s2m) do
        self:removeFeature(featureID)
    end
    self._s2m = {}
    self._m2s = {}
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
