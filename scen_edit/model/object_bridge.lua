SB_COMMAND_DIR = SB_DIR .. "command/"
SB.Include(SB_COMMAND_DIR .. 'abstract_command.lua')
SB.Include(SB_COMMAND_DIR .. 'undoable_command.lua')
SB.IncludeDir(SB_COMMAND_DIR)

ObjectBridge = LCS.class.abstract{}

-- UNIT

function DrawObject(params, bridge)
    gl.PushMatrix()
    local pos           = params.pos
    local angle         = params.angle
    local objectDefID   = params.objectDefID
    local objectTeamID  = params.objectTeamID
    local color         = params.color
    gl.Color(color.r, color.g, color.b, color.a)
    gl.Translate(pos.x, pos.y, pos.z)
    gl.Rotate(angle.x, 1, 0, 0)
    gl.Rotate(angle.y, 0, 1, 0)
    gl.Rotate(angle.z, 0, 0, 1)
    bridge.glObjectShapeTextures(objectDefID, true)
    bridge.glObjectShape(objectDefID, objectTeamID, true)
    bridge.glObjectShapeTextures(objectDefID, false)
    gl.PopMatrix()
end

UnitBridge = ObjectBridge:extends{}
UnitBridge.bridgeName                      = "UnitBridge"
UnitBridge.spGetObjectsInCylinder          = Spring.GetUnitsInCylinder
UnitBridge.spGetObjectDefID                = Spring.GetUnitDefID
UnitBridge.spGetObjectPosition             = Spring.GetUnitPosition
UnitBridge.spValidObject                   = Spring.ValidUnitID
UnitBridge.spGetObjectTeam                 = Spring.GetUnitTeam
UnitBridge.spGetObjectDirection            = Spring.GetUnitDirection
UnitBridge.spGetAllObjects                 = Spring.GetAllUnits
UnitBridge.spDestroyObject                 = Spring.DestroyUnit

UnitBridge.AddObjectCommand                = AddUnitCommand
UnitBridge.RemoveObjectCommand             = RemoveUnitCommand
UnitBridge.SetObjectParamCommand           = SetUnitParamCommand
UnitBridge.DrawObject                      = function(params)
    DrawObject(params, unitBridge)
end
UnitBridge.getObjectSpringID               = function(modelID)
    return SB.model.unitManager:getSpringUnitId(modelID)
end
UnitBridge.getObjectModelID                = function(objectID)
    return SB.model.unitManager:getModelUnitId(objectID)
end
UnitBridge.setObjectModelID                = function(objectID, modelID)
    SB.model.unitManager:setUnitModelId(objectID, modelID)
end
unitBridge = UnitBridge()
unitBridge.s11n                            = s11n:GetUnitBridge()
unitBridge.ObjectDefs                      = UnitDefs
if gl then
    unitBridge.glObjectShape               = gl.UnitShape
    unitBridge.glObjectShapeTextures       = gl.UnitShapeTextures
end

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.bridgeName                      = "FeatureBridge"
FeatureBridge.spGetObjectsInCylinder          = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID                = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition             = Spring.GetFeaturePosition
FeatureBridge.spValidObject                   = Spring.ValidFeatureID
FeatureBridge.spGetObjectTeam                 = Spring.GetFeatureTeam
FeatureBridge.spGetObjectDirection            = Spring.GetFeatureDirection
FeatureBridge.spGetAllObjects                 = Spring.GetAllFeatures
FeatureBridge.spDestroyObject                 = Spring.DestroyFeature

FeatureBridge.AddObjectCommand                = AddFeatureCommand
FeatureBridge.RemoveObjectCommand             = RemoveFeatureCommand
FeatureBridge.SetObjectParamCommand           = SetFeatureParamCommand
FeatureBridge.DrawObject                      = function(params)
    DrawObject(params, featureBridge)
--     local featureDef    = FeatureDefs[objectDefID]
-- 
--     if featureDef.drawType ~= 0 then
--         Log.Warning("engine-tree, not sure what to do")
--     end
end
FeatureBridge.getObjectSpringID               = function(modelID)
    return SB.model.featureManager:getSpringFeatureId(modelID)
end
FeatureBridge.getObjectModelID                = function(objectID)
    return SB.model.featureManager:getModelFeatureId(objectID)
end
FeatureBridge.setObjectModelID                = function(objectID, modelID)
    SB.model.featureManager:setFeatureModelId(objectID, modelID)
end
featureBridge = FeatureBridge()
featureBridge.s11n                            = s11n:GetFeatureBridge()
featureBridge.ObjectDefs                      = FeatureDefs
if gl then
    featureBridge.glObjectShape               = gl.FeatureShape
    featureBridge.glObjectShapeTextures       = gl.FeatureShapeTextures
end

-- AREA

AreaBridge = ObjectBridge:extends{}
AreaBridge.bridgeName                   = "AreaBridge"
AreaBridge.spGetObjectPosition          = function(objectID)
    local pos = SB.model.areaManager:getArea(objectID)
    local x, z = (pos[1] + pos[3]) / 2, (pos[2] + pos[4]) / 2
    local y = Spring.GetGroundHeight(x, z)
    return x, y, z
end
AreaBridge.spGetAllObjects              = function()
    return SB.model.areaManager:getAllAreas()
end
AreaBridge.spValidObject                = function(objectID)
    return SB.model.areaManager:getArea(objectID) ~= nil
end

areaBridge = AreaBridge()
