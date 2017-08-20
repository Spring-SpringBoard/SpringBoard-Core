SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.humanName                       = "Feature"
FeatureBridge.GetObjectsInCylinder            = Spring.GetFeaturesInCylinder
FeatureBridge.GetObjectDefID                  = Spring.GetFeatureDefID
FeatureBridge.ValidObject                     = Spring.ValidFeatureID
FeatureBridge.GetObjectDirection              = Spring.GetFeatureDirection
FeatureBridge.GetAllObjects                   = Spring.GetAllFeatures
FeatureBridge.DestroyObject                   = Spring.DestroyFeature

FeatureBridge.SelectObjectTypeState           = SelectFeatureTypeState

FeatureBridge.DrawObject                      = function(params)
    DrawObject(params, featureBridge)
--     local featureDef    = FeatureDefs[objectDefID]
--
--     if featureDef.drawType ~= 0 then
--         Log.Warning("engine-tree, not sure what to do")
--     end
end
-- we cache minx, maxx, minz, maxz for each feature def
-- this saves us a lot of memory
local __cachedDefs = {}
local function _GetFeatureDefSize(featureDefID)
    if __cachedDefs[featureDefID] == nil then
        local featureDef = FeatureDefs[featureDefID]
        local minx, maxx = featureDef.model.minx or -10, featureDef.model.maxx or 10
        local minz, maxz = featureDef.model.minz or -10, featureDef.model.maxz or 10
        if maxx - minx < 20 then
            minx, maxx = -10, 10
        end
        if maxz - minz < 20 then
            minz, maxz = -10, 10
        end
        __cachedDefs[featureDefID] = {minx, maxx, minz, maxz}
    end
    local c = __cachedDefs[featureDefID]
    return c[1], c[2], c[3], c[4]
end

local function DrawLines(x1, x2, z1, z2, by)
    gl.Vertex(x1, by, z1)
    gl.Vertex(x2, by, z1)
    gl.Vertex(x2, by, z2)
    gl.Vertex(x1, by, z2)
    gl.Vertex(x1, by, z1)
end
FeatureBridge.DrawSelected                    = function(objectID)
    local bx, by, bz = Spring.GetFeaturePosition(objectID)
    local minx, maxx, minz, maxz = _GetFeatureDefSize(Spring.GetFeatureDefID(objectID))
    local x1, z1 = bx + minx - 5, bz + minz + 5
    local x2, z2 = bx + maxx - 5, bz + maxz + 5
    gl.BeginEnd(GL.LINE_STRIP, DrawLines, x1, x2, z1, z2, by)
end

FeatureBridge.getObjectSpringID               = function(modelID)
    return SB.model.featureManager:getSpringFeatureID(modelID)
end
FeatureBridge.getObjectModelID                = function(objectID)
    return SB.model.featureManager:getModelFeatureID(objectID)
end
FeatureBridge.setObjectModelID                = function(objectID, modelID)
    SB.model.featureManager:setFeatureModelID(objectID, modelID)
end
featureBridge = FeatureBridge()
featureBridge.s11n                            = s11n:GetFeatureBridge()
featureBridge.ObjectDefs                      = FeatureDefs
if gl then
    featureBridge.glObjectShape               = gl.FeatureShape
    featureBridge.glObjectShapeTextures       = gl.FeatureShapeTextures
end
featureBridge.s11nFieldOrder = {"pos", "rot", "vel"}
featureBridge.blockedFields = {
    "dir", "defName", "collision", "blocking", "radiusHeight", "midAimPos",
    "team",
}
ObjectBridge.Register("feature", featureBridge)
